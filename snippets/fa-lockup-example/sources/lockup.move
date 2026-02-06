/// Time-locked fungible asset escrow supporting multiple depositors to a single recipient.
///
/// ## Architecture:
/// 1. **`LockupRef`** -- stored in the lockup creator's account, pointing to the Lockup object
/// 2. **`Lockup`** (enum, ST variant) -- an object holding a SmartTable mapping (FA + user) to escrow addresses
/// 3. **`Escrow`** (enum) -- per-user, per-FA escrow objects that hold the actual funds
///    - `Simple` variant: no time lock, funds can be returned immediately
///    - `TimeUnlock` variant: funds locked until `unlock_secs` timestamp passes
///
/// ## Demonstrates Move 2 features:
/// - Enum types (`Lockup`, `EscrowKey`, `Escrow`)
/// - Pattern matching with `match` expressions
/// - Dispatchable fungible asset transfers
/// - Full object lifecycle (create, use, delete with storage recovery)
///
/// ## Testing:
/// ```bash
/// aptos move test --move-2 --dev
/// ```
///
/// TODO: Add cleanup for `Lockup` itself
/// TODO: Add Tree instead of SmartTable as an option in the future
module lockup_deployer::fa_lockup {

    use std::option::{Self, Option};
    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};
    use aptos_framework::object::{Self, Object, ExtendRef, DeleteRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;

    /// The lookup to object for escrow in an easily addressible spot
    ///
    /// The main purpose here is to provide fully removable types to allow for full recovery of storage refunds, and not
    /// have a duplicate object.
    struct LockupRef has key {
        lockup_address: address,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A single lockup, which has the same lockup period for all of them
    ///
    /// These are stored on objects, which map to the appropriate escrows
    enum Lockup has key {
        /// SmartTable implementation, which can be replaced with a newer version later
        ST {
            // Creator of the lockup
            creator: address,
            /// Used to control funds in the escrows
            extend_ref: ExtendRef,
            /// Used to cleanup the Lockup object
            delete_ref: DeleteRef,
            /// Normally with coin, we could escrow in the table, but we have to escrow in owned objects for the purposes of FA
            escrows: SmartTable<EscrowKey, address>
        }
    }

    /// A key used for keeping track of all escrows in an easy to find place
    enum EscrowKey has store, copy, drop {
        FAPerUser {
            /// Marker for which FA is stored
            fa_metadata: Object<Metadata>,
            /// The user in which it's being stored for
            user: address,
        }
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// An escrow object for a single user and a single FA
    enum Escrow has key {
        Simple {
            /// The original owner
            original_owner: address,
            /// Used for cleaning up the escrow
            delete_ref: DeleteRef,
        },
        TimeUnlock {
            /// The original owner
            original_owner: address,
            /// Time that the funds can be unlocked
            unlock_secs: u64,
            /// Used for cleaning up the escrow
            delete_ref: DeleteRef,
        }
    }

    // -- Errors --

    /// Lockup already exists at this address
    const E_LOCKUP_ALREADY_EXISTS: u64 = 1;
    /// Lockup not found at address
    const E_LOCKUP_NOT_FOUND: u64 = 2;
    /// No lockup was found for this user and this FA
    const E_NO_USER_LOCKUP: u64 = 3;
    /// Unlock time has not yet passed
    const E_UNLOCK_TIME_NOT_YET: u64 = 4;
    /// Not original owner or lockup owner
    const E_NOT_ORIGINAL_OR_LOCKUP_OWNER: u64 = 5;
    /// Not a time lockup
    const E_NOT_TIME_LOCKUP: u64 = 6;
    /// Not a simple lockup
    const E_NOT_SIMPLE_LOCKUP: u64 = 7;
    /// Can't shorten lockup time
    const E_CANNOT_SHORTEN_LOCKUP_TIME: u64 = 8;

    /// Initializes a lockup at an address
    public entry fun initialize_lockup(
        caller: &signer,
    ) {
        init_lockup(caller);
    }

    inline fun init_lockup(caller: &signer): Object<Lockup> {
        let caller_address = signer::address_of(caller);

        // Create the object only if it doesn't exist, otherwise quit out
        assert!(!exists<LockupRef>(caller_address), E_LOCKUP_ALREADY_EXISTS);

        // Create the object
        let constructor_ref = object::create_object(@0x0);
        let lockup_address = object::address_from_constructor_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let delete_ref = object::generate_delete_ref(&constructor_ref);
        let obj_signer = object::generate_signer(&constructor_ref);
        move_to(&obj_signer, Lockup::ST {
            creator: caller_address,
            escrows: smart_table::new(),
            extend_ref,
            delete_ref
        });

        // This is specifically to ensure that we don't create two lockup objects, we put a marker in the account
        move_to(caller, LockupRef {
            lockup_address
        });
        object::object_from_constructor_ref(&constructor_ref)
    }

    /// Escrows funds with a user defined lockup time
    public entry fun escrow_funds_with_no_lockup(
        caller: &signer,
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        amount: u64,
    ) acquires Lockup, Escrow {
        let caller_address = signer::address_of(caller);
        let lockup_address = object::object_address(&lockup_obj);
        let lockup = &mut Lockup[lockup_address];

        let lockup_key = EscrowKey::FAPerUser {
            fa_metadata,
            user: caller_address
        };

        let escrow_address = lockup.escrows.borrow_mut_with_default(lockup_key, @0x0);

        // If we haven't found it, create a new escrow object
        if (escrow_address == &@0x0) {
            let constructor_ref = object::create_object(lockup_address);
            let object_signer = object::generate_signer(&constructor_ref);
            let object_delete_ref = object::generate_delete_ref(&constructor_ref);

            // Make it a store to keep the escrow funds
            fungible_asset::create_store(&constructor_ref, fa_metadata);

            // Store the appropriate info for the funds
            move_to(&object_signer, Escrow::Simple {
                original_owner: caller_address,
                delete_ref: object_delete_ref
            });
            // Save it to the table
            *escrow_address = object::address_from_constructor_ref(&constructor_ref);
        } else {
            // Otherwise, we'll reset the unlock time to the new time
            let escrow = &Escrow[*escrow_address];
            match (escrow) {
                Simple { .. } => {
                    // Do nothing
                }
                TimeUnlock { .. } => {
                    abort E_NOT_SIMPLE_LOCKUP;
                }
            };
        };

        // Now transfer funds into the escrow
        escrow_funds(caller, fa_metadata, *escrow_address, caller_address, amount);
    }

    /// Escrows funds with a user defined lockup time
    public entry fun escrow_funds_with_time(
        caller: &signer,
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        amount: u64,
        lockup_time_secs: u64,
    ) acquires Lockup, Escrow {
        let caller_address = signer::address_of(caller);
        let lockup_address = object::object_address(&lockup_obj);
        let lockup = &mut Lockup[lockup_address];

        let lockup_key = EscrowKey::FAPerUser {
            fa_metadata,
            user: caller_address
        };


        let escrow_address = lockup.escrows.borrow_mut_with_default(lockup_key, @0x0);
        // TODO: Do we make this specified by the contract rather than user?
        let new_unlock_secs = timestamp::now_seconds() + lockup_time_secs;

        // If we haven't found it, create a new escrow object
        if (escrow_address == &@0x0) {
            // We specifically make this object on @0x0, so that the creator doesn't have the ability to pull the funds
            // out without the contract
            let constructor_ref = object::create_object(lockup_address);
            let object_signer = object::generate_signer(&constructor_ref);
            let object_delete_ref = object::generate_delete_ref(&constructor_ref);

            // Make it a store to keep the escrow funds
            fungible_asset::create_store(&constructor_ref, fa_metadata);

            // Store the appropriate info for the funds
            move_to(&object_signer, Escrow::TimeUnlock {
                original_owner: caller_address,
                unlock_secs: new_unlock_secs,
                delete_ref: object_delete_ref
            });
            // Save it to the table
            *escrow_address = object::address_from_constructor_ref(&constructor_ref);
        } else {
            // Otherwise, we'll reset the unlock time to the new time
            let escrow = &mut Escrow[*escrow_address];
            match (escrow) {
                Simple { .. } => {
                    abort E_NOT_TIME_LOCKUP;
                }
                TimeUnlock { unlock_secs, .. } => {
                    // We however, cannot shorten the unlock time
                    if (*unlock_secs > new_unlock_secs) {
                        abort E_CANNOT_SHORTEN_LOCKUP_TIME;
                    } else {
                        *unlock_secs = new_unlock_secs
                    }
                }
            };
        };

        // Now transfer funds into the escrow
        escrow_funds(caller, fa_metadata, *escrow_address, caller_address, amount);
    }

    /// Claims an escrow by the owner of the escrow
    public entry fun claim_escrow(
        caller: &signer,
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        user: address,
    ) acquires Lockup, Escrow {
        let caller_address = signer::address_of(caller);
        let lockup = get_lockup_mut(&lockup_obj);
        assert!(caller_address == lockup.creator, E_NOT_ORIGINAL_OR_LOCKUP_OWNER);
        let (lockup_key, escrow_address) = lockup.get_escrow(
            fa_metadata,
            user
        );

        // Take funds from lockup
        lockup.take_funds(fa_metadata, escrow_address);

        // Clean up the object
        lockup.delete_escrow(lockup_key);
    }

    /// Returns funds for the user
    ///
    /// TODO: add additional entry function for using LockupRef
    public entry fun return_user_funds(
        caller: &signer,
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        user: address,
    ) acquires Lockup, Escrow {
        let caller_address = signer::address_of(caller);
        let lockup = get_lockup_mut(&lockup_obj);
        assert!(caller_address == lockup.creator, E_NOT_ORIGINAL_OR_LOCKUP_OWNER);
        let (lockup_key, escrow_address) = lockup.get_escrow(
            fa_metadata,
            user
        );

        // Determine original owner, and any conditions on returning
        let original_owner = match (&Escrow[escrow_address]) {
            Escrow::Simple { original_owner, .. } => {
                *original_owner
            }
            Escrow::TimeUnlock { original_owner, .. } => {
                // Note, the lockup owner can reject the unlock faster than the unlock time
                *original_owner
            }
        };

        lockup.return_funds(fa_metadata, escrow_address, original_owner);

        // Clean up the object
        lockup.delete_escrow(lockup_key);
    }

    /// Returns funds for the caller
    ///
    /// TODO: add additional entry function for using LockupRef
    public entry fun return_my_funds(
        caller: &signer,
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
    ) acquires Lockup, Escrow {
        let caller_address = signer::address_of(caller);
        let lockup = get_lockup_mut(&lockup_obj);
        let (lockup_key, escrow_address) = lockup.get_escrow(
            fa_metadata,
            caller_address
        );

        // Determine original owner, and any conditions on returning
        let original_owner = match (&Escrow[escrow_address]) {
            Escrow::Simple { original_owner, .. } => {
                *original_owner
            }
            Escrow::TimeUnlock { original_owner, unlock_secs, .. } => {
                assert!(timestamp::now_seconds() >= *unlock_secs, E_UNLOCK_TIME_NOT_YET);
                *original_owner
            }
        };

        // To prevent others from being annoying, only the original owner can return funds
        assert!(original_owner == caller_address, E_NOT_ORIGINAL_OR_LOCKUP_OWNER);
        lockup.return_funds(fa_metadata, escrow_address, original_owner);

        // Clean up the object
        lockup.delete_escrow(lockup_key);
    }

    /// Retrieves the lockup object for mutation
    inline fun get_lockup_mut(
        lockup_obj: &Object<Lockup>,
    ): &mut Lockup {
        let lockup_address = object::object_address(lockup_obj);
        &mut Lockup[lockup_address]
    }

    /// Retrieves the lockup object for reading
    inline fun get_lockup(
        lockup_obj: &Object<Lockup>,
    ): &Lockup {
        let lockup_address = object::object_address(lockup_obj);
        &Lockup[lockup_address]
    }

    /// Retrieves the lockup object for removal
    inline fun get_escrow(
        self: &mut Lockup,
        fa_metadata: Object<Metadata>,
        user: address
    ): (EscrowKey, address) {
        let lockup_key = EscrowKey::FAPerUser {
            fa_metadata,
            user,
        };

        assert!(self.escrows.contains(lockup_key), E_NO_USER_LOCKUP);

        (lockup_key, *self.escrows.borrow(lockup_key))
    }

    /// Escrows an amount of funds to the escrow object
    inline fun escrow_funds(
        caller: &signer,
        fa_metadata: Object<Metadata>,
        escrow_address: address,
        caller_address: address,
        amount: u64
    ) {
        let store_obj = object::address_to_object<FungibleStore>(escrow_address);
        let caller_primary_store = primary_fungible_store::primary_store_inlined(caller_address, fa_metadata);
        dispatchable_fungible_asset::transfer(caller, caller_primary_store, store_obj, amount);
    }

    /// Returns all outstanding funds
    inline fun take_funds(
        self: &Lockup,
        fa_metadata: Object<Metadata>,
        escrow_address: address,
    ) {
        // Transfer funds back to the original owner
        let escrow_object = object::address_to_object<FungibleStore>(escrow_address);
        let balance = fungible_asset::balance(escrow_object);
        let primary_store = primary_fungible_store::ensure_primary_store_exists(self.creator, fa_metadata);

        // Use dispatchable because we don't know if it uses it
        let lockup_signer = object::generate_signer_for_extending(&self.extend_ref);
        dispatchable_fungible_asset::transfer(&lockup_signer, escrow_object, primary_store, balance);
    }

    /// Returns all outstanding funds
    inline fun return_funds(
        self: &Lockup,
        fa_metadata: Object<Metadata>,
        escrow_address: address,
        original_owner: address
    ) {
        // Transfer funds back to the original owner
        let escrow_object = object::address_to_object<FungibleStore>(escrow_address);
        let balance = fungible_asset::balance(escrow_object);
        let original_owner_primary_store = primary_fungible_store::primary_store_inlined(
            original_owner,
            fa_metadata
        );
        // Use dispatchable because we don't know if it uses it
        let lockup_signer = object::generate_signer_for_extending(&self.extend_ref);
        dispatchable_fungible_asset::transfer(&lockup_signer, escrow_object, original_owner_primary_store, balance);
    }

    /// Deletes an escrow object
    inline fun delete_escrow(self: &mut Lockup, lockup_key: EscrowKey) {
        let escrow_addr = self.escrows.remove(lockup_key);

        // The following lines will return the storage deposit
        let delete_ref = match (move_from<Escrow>(escrow_addr)) {
            Escrow::Simple { delete_ref, .. } => {
                delete_ref
            }
            Escrow::TimeUnlock { delete_ref, .. } => {
                delete_ref
            }
        };
        fungible_asset::remove_store(&delete_ref);
        object::delete(delete_ref);
    }

    #[view]
    /// Tells the lockup address for the user who created the original lockup
    public fun lockup_address(escrow_account: address): address acquires LockupRef {
        LockupRef[escrow_account].lockup_address
    }

    #[view]
    /// Tells the amount of escrowed funds currently available
    public fun escrowed_funds(
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        user: address
    ): Option<u64> acquires Lockup {
        let lockup = get_lockup(&lockup_obj);
        let escrow_key = EscrowKey::FAPerUser {
            fa_metadata,
            user
        };
        if (lockup.escrows.contains(escrow_key)) {
            let escrow_address = lockup.escrows.borrow(escrow_key);
            let escrow_obj = object::address_to_object<Escrow>(*escrow_address);
            option::some(fungible_asset::balance(escrow_obj))
        } else {
            option::none()
        }
    }

    #[view]
    /// Tells the amount of escrowed funds currently available
    public fun remaining_escrow_time(
        lockup_obj: Object<Lockup>,
        fa_metadata: Object<Metadata>,
        user: address
    ): Option<u64> acquires Lockup, Escrow {
        let lockup = get_lockup(&lockup_obj);
        let escrow_key = EscrowKey::FAPerUser {
            fa_metadata,
            user
        };
        if (lockup.escrows.contains(escrow_key)) {
            let escrow_address = lockup.escrows.borrow(escrow_key);
            let remaining_secs = match (&Escrow[*escrow_address]) {
                Simple { .. } => { 0 }
                TimeUnlock { unlock_secs, .. } => {
                    let now = timestamp::now_seconds();
                    if (now >= *unlock_secs) {
                        0
                    } else {
                        *unlock_secs - now
                    }
                }
            };
            option::some(remaining_secs)
        } else {
            option::none()
        }
    }

    #[test_only]
    const TWO_HOURS_SECS: u64 = 2 * 60 * 60;

    #[test_only]
    fun setup_for_test(
        framework: &signer,
        asset: &signer,
        creator: &signer,
        user: &signer
    ): (address, address, Object<Metadata>, Object<Lockup>) {
        timestamp::set_time_has_started_for_testing(framework);
        let (creator_ref, metadata) = fungible_asset::create_test_token(asset);
        let (mint_ref, _transfer_ref, _burn_ref) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(
            &creator_ref
        );
        let creator_address = signer::address_of(creator);
        let user_address = signer::address_of(user);
        primary_fungible_store::mint(&mint_ref, user_address, 100);
        let fa_metadata: Object<Metadata> = object::convert(metadata);
        let lockup_obj = init_lockup(creator);
        (creator_address, user_address, fa_metadata, lockup_obj)
    }

    #[test(framework = @0x1, asset = @0xAAAAA, creator = @0x10C0, user = @0xCAFE)]
    fun test_out_flow(framework: &signer, asset: &signer, creator: &signer, user: &signer) acquires Lockup, Escrow {
        let (creator_address, user_address, fa_metadata, lockup_obj) = setup_for_test(framework, asset, creator, user);

        escrow_funds_with_no_lockup(user, lockup_obj, fa_metadata, 5);

        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 95);

        // Check view functions
        assert!(remaining_escrow_time(lockup_obj, fa_metadata, user_address) == option::some(0));
        assert!(escrowed_funds(lockup_obj, fa_metadata, user_address) == option::some(5));
        assert!(remaining_escrow_time(lockup_obj, fa_metadata, @0x1234567) == option::none());
        assert!(escrowed_funds(lockup_obj, fa_metadata, @0x1234567) == option::none());

        // Should be able to return funds immediately
        return_user_funds(creator, lockup_obj, fa_metadata, user_address);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 100);

        // Same with the user
        escrow_funds_with_no_lockup(user, lockup_obj, fa_metadata, 5);
        return_my_funds(user, lockup_obj, fa_metadata);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 100);

        // Claim an escrow
        escrow_funds_with_no_lockup(user, lockup_obj, fa_metadata, 5);
        claim_escrow(creator, lockup_obj, fa_metadata, user_address);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 95);
        assert!(primary_fungible_store::balance(creator_address, fa_metadata) == 5);

        // -- Now test with time lockup --

        escrow_funds_with_time(user, lockup_obj, fa_metadata, 5, TWO_HOURS_SECS);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 90);

        // Check view functions
        assert!(remaining_escrow_time(lockup_obj, fa_metadata, user_address) == option::some(TWO_HOURS_SECS));
        assert!(escrowed_funds(lockup_obj, fa_metadata, user_address) == option::some(5));

        // Should be able to return funds immediately
        return_user_funds(creator, lockup_obj, fa_metadata, user_address);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 95);

        escrow_funds_with_time(user, lockup_obj, fa_metadata, 5, TWO_HOURS_SECS);

        // User can't unescrow without time passing, let's go forward 2 hours
        timestamp::fast_forward_seconds(TWO_HOURS_SECS);
        return_my_funds(user, lockup_obj, fa_metadata);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 95);

        // Claim an escrow, can be immediate
        escrow_funds_with_time(user, lockup_obj, fa_metadata, 5, TWO_HOURS_SECS);
        claim_escrow(creator, lockup_obj, fa_metadata, user_address);
        assert!(primary_fungible_store::balance(user_address, fa_metadata) == 90);
        assert!(primary_fungible_store::balance(creator_address, fa_metadata) == 10);
    }

    #[test(framework = @0x1, asset = @0xAAAAA, creator = @0x10C0, user = @0xCAFE)]
    #[expected_failure(abort_code = E_UNLOCK_TIME_NOT_YET, location = lockup_deployer::fa_lockup)]
    fun test_too_short_lockup(
        framework: &signer,
        asset: &signer,
        creator: &signer,
        user: &signer
    ) acquires Lockup, Escrow {
        let (_creator_address, _user_address, fa_metadata, lockup_obj) = setup_for_test(
            framework,
            asset,
            creator,
            user
        );
        escrow_funds_with_time(user, lockup_obj, fa_metadata, 5, TWO_HOURS_SECS);

        // User can't return funds without waiting for lockup
        return_my_funds(user, lockup_obj, fa_metadata);
    }
}
