/// An example payment escrow system
///
/// Similar to something like Venmo, where users will pay others, and can
/// cancel the payment before it's withdrawn.  Additionally, the reciever
/// can either transfer the payment to someone else, reject it, or withdraw
/// it.
///
/// To run the prover, run `aptos move prove --dev`
module deployer::payment_escrow {
    spec module {
        pragma verify = true;
    }

    use std::signer;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::object;
    use aptos_framework::object::{Object, DeleteRef};

    /// Can't claim escrow, not owner of object
    const E_NOT_OWNER: u64 = 1;
    /// Can't claim escrow, not owner of object or creator of escrow
    const E_NOT_OWNER_OR_CREATOR: u64 = 2;
    /// Can't escrow zero coins
    const E_CANT_ESCROW_ZERO: u64 = 3;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// An Escrow object
    struct Escrow<phantom CoinType> has key {
        /// The creator of the escrow object
        creator: address,
        delete_ref: DeleteRef,
        coins: Coin<CoinType>
    }

    spec Escrow {
        // Ensure that there is never an empty escrow
        invariant coins.value > 0;
        // Ensure it can be any u64 value
        invariant coins.value <= MAX_U64;
    }

    /// Transfers coins to an escrow object, where only the owner can retrieve the coins.
    ///
    /// Additionally, the owner can choose to instead transfer this to someone else who can retrieve the coins
    entry fun escrow_coins<CoinType>(caller: &signer, receiver: address, amount: u64) {
        escrow_coins_inner<CoinType>(caller, receiver, amount);
    }

    /// This is separated out specifically for specification and testing purposes
    fun escrow_coins_inner<CoinType>(caller: &signer, receiver: address, amount: u64): Object<Escrow<CoinType>> {
        let object = create_escrow_object<CoinType>(caller, amount);
        object::transfer(caller, object, receiver);
        object
    }

    spec escrow_coins_inner {
        // Ensure that the amount in escrow is always the amount expected
        ensures amount == get_escrow(result).coins.value;
        // Ensure that the creator in escrow is always the caller
        ensures signer::address_of(caller) == get_escrow(result).creator;
        // Ensure that the delete ref is for the same object address
        ensures result.inner == get_escrow(result).delete_ref.self;
    }

    /// Return the escrow coins back to the original caller, done by the creator or owner of the escrow
    entry fun cancel_escrow<CoinType>(caller: &signer, escrow_object: Object<Escrow<CoinType>>) acquires Escrow {
        let caller_address = signer::address_of(caller);
        ensure_is_owner_or_creator(caller_address, escrow_object);
        let (creator, coins) = destroy_escrow_object(escrow_object);

        // Deposit coins into the creator's address
        aptos_account::deposit_coins(creator, coins);
    }

    spec cancel_escrow {
        // Ensure the caller is creator or owner
        include CallerIsCreatorOrOwner<CoinType> {
            escrow_object,
            caller_address: signer::address_of(caller),
        };

        let escrow = get_escrow(escrow_object);

        // Ensure coins go back to the creator
        ensures global<coin::CoinStore<CoinType>>(escrow.creator).coin.value > 0;
    }

    /// As owner of the object, extracts the coins, and destroys the object
    entry fun take_escrow<CoinType>(caller: &signer, escrow_object: Object<Escrow<CoinType>>) acquires Escrow {
        let caller_address = signer::address_of(caller);
        ensure_is_owner(caller_address, escrow_object);
        let (_, coins) = destroy_escrow_object(escrow_object);

        // Deposit coins into the caller's address
        aptos_account::deposit_coins(caller_address, coins);
    }

    spec take_escrow {
        include CallerIsOwner<CoinType> {
            escrow_object,
            caller_address: signer::address_of(caller)
        };
    }

    /// Create the object, and move coins into it
    fun create_escrow_object<CoinType>(caller: &signer, amount: u64): Object<Escrow<CoinType>> {
        // Comment out the line below to show how proving can fail
        assert!(amount > 0, E_CANT_ESCROW_ZERO);
        let caller_address = signer::address_of(caller);
        let constructor_ref = object::create_object(caller_address);
        let object_signer = object::generate_signer(&constructor_ref);
        let delete_ref = object::generate_delete_ref(&constructor_ref);
        let coins = coin::withdraw<CoinType>(caller, amount);

        move_to(&object_signer, Escrow<CoinType> {
            creator: caller_address,
            delete_ref,
            coins,
        });
        object::object_from_constructor_ref<Escrow<CoinType>>(&constructor_ref)
    }

    spec create_escrow_object {
        // Ensure that the amount in escrow is always the amount expected
        ensures amount == get_escrow(result).coins.value;
        // Ensure that the creator in escrow is always the caller
        ensures signer::address_of(caller) == get_escrow(result).creator;
        // Ensure that the delete ref is for the same object address
        ensures result.inner == get_escrow(result).delete_ref.self;
        // Ensure that the amount is greater than 0
        ensures amount > 0;
    }

    /// Delete the object and extract the coins
    fun destroy_escrow_object<CoinType>(
        escrow_object: Object<Escrow<CoinType>>
    ): (address, Coin<CoinType>) acquires Escrow {
        let object_address = object::object_address(&escrow_object);

        // Withdraw coins
        let Escrow {
            creator,
            delete_ref,
            coins
        } = move_from<Escrow<CoinType>>(object_address);

        // Delete object to recover gas
        object::delete(delete_ref);
        (creator, coins)
    }

    spec destroy_escrow_object {
        //Ensures that outputs come from the escrow object
        ensures result_1 == get_escrow(escrow_object).creator;
        ensures result_2 == get_escrow(escrow_object).coins;

        // Ensure that the object is deleted
        ensures !exists<Escrow<CoinType>>(escrow_object.inner);
    }

    fun ensure_is_owner<CoinType>(
        caller_address: address,
        escrow_object: Object<Escrow<CoinType>>
    ) {
        assert!(object::is_owner(escrow_object, caller_address), E_NOT_OWNER);
    }

    spec ensure_is_owner {
        include CallerIsOwner<CoinType> {
            escrow_object,
            caller_address
        };
    }

    fun ensure_is_owner_or_creator<CoinType>(
        caller_address: address,
        escrow_object: Object<Escrow<CoinType>>
    ) acquires Escrow {
        if (!object::is_owner(escrow_object, caller_address)) {
            let object_address = object::object_address(&escrow_object);
            let escrow = &Escrow<CoinType>[object_address];

            assert!(escrow.creator == caller_address, E_NOT_OWNER_OR_CREATOR);
        }
    }
    spec ensure_is_owner_or_creator {
        include CallerIsCreatorOrOwner<CoinType> {
            escrow_object,
            caller_address
        };
    }

    /// Helper function to retrieve escrow based on the object
    spec fun get_escrow<CoinType>(object: Object<Escrow<CoinType>>): Escrow<CoinType> {
        global<Escrow<CoinType>>(object::object_address(object))
    }

    /// Checks that the owner is the caller
    spec schema CallerIsOwner<CoinType> {
        escrow_object: Object<Escrow<CoinType>>;
        caller_address: address;
        let is_owner = object::is_owner(escrow_object, caller_address);

        // Ensure only the owner
        ensures is_owner;
    }

    /// Ensure that the caller is the creator or owner
    spec schema CallerIsCreatorOrOwner<CoinType> {
        escrow_object: Object<Escrow<CoinType>>;
        caller_address: address;
        let is_owner = object::is_owner(escrow_object, caller_address);
        let creator = get_escrow(escrow_object).creator;

        ensures is_owner || creator == caller_address;
    }
}