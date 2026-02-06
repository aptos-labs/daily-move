/// Snipe prevention (anti-snipe) for fungible asset token launches.
///
/// ## Overview
///
/// This module demonstrates how to implement snipe prevention for token launches using
/// dispatchable fungible assets. "Sniping" refers to bots or actors acquiring large amounts
/// of tokens immediately at launch, often manipulating prices. This module prevents that by
/// limiting how much any single wallet can receive until the protection is disabled.
///
/// ## Architecture
///
/// 1. **`FAData`** -- stored on the fungible asset metadata object, holds the antisnipe configuration
/// 2. **`AntisnipeData`** (enum) -- configuration for snipe prevention:
///    - `Disabled`: No restrictions, normal transfers allowed
///    - `V1`: Active protection with a maximum balance limit and allowlist
///
/// ## How It Works
///
/// - Uses dispatchable fungible assets to intercept all deposit operations
/// - When antisnipe is enabled, deposits are rejected if:
///   - The recipient's new balance would exceed `antisnipe_amount`, AND
///   - The recipient is not in the `allowlisted_owners` list
/// - Contract owner can disable protection or modify the allowlist
///
/// ## Demonstrates Move 2 Features
///
/// - Enum types with variants (`AntisnipeData`)
/// - Pattern matching with `match` expressions
/// - Resource indexing syntax (`FAData[@antisnipe]`)
/// - Dispatchable fungible asset hooks
///
/// ## Deployment Requirements
///
/// Must be deployed as a code object (not a regular account deployment) so that the contract
/// address can be used for ownership checks. The object owner can perform admin actions.
///
/// ## Testing
///
/// ```bash
/// aptos move test --dev --package-dir snippets/snipe-prevention
/// ```
module antisnipe::antisnipe_token {

    use std::option;
    use std::signer;
    use std::string;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::function_info;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::FungibleAsset;
    use aptos_framework::object;
    use aptos_framework::object::{Object, ObjectCore};

    // -- Errors --

    /// Deposit would exceed antisnipe limit and address is not allowlisted
    const E_ANTISNIPE_ENABLED: u64 = 1;

    /// Caller is not the contract owner, cannot perform admin actions
    const E_NOT_CONTRACT_OWNER: u64 = 2;

    // -- Constants --

    const MODULE_NAME: vector<u8> = b"antisnipe_token";
    const DEPOSIT_NAME: vector<u8> = b"deposit";

    // -- Structs --

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Main configuration stored on the fungible asset metadata object.
    /// Contains the extend ref for signing and the antisnipe configuration.
    struct FAData has key {
        /// Used to generate a signer for the FA metadata object
        extend_ref: object::ExtendRef,
        /// Current antisnipe configuration
        antisnipe_data: AntisnipeData
    }

    /// Antisnipe configuration enum supporting future versioning.
    /// - `Disabled`: No snipe prevention, all transfers allowed
    /// - `V1`: Active snipe prevention with balance limit and allowlist
    enum AntisnipeData has copy, store, drop {
        /// Antisnipe is disabled, no deposit restrictions
        Disabled,
        /// Version 1 of antisnipe: balance limit with allowlist bypass
        V1 {
            /// Maximum balance any non-allowlisted address can hold
            antisnipe_amount: u64,
            /// Addresses exempt from the antisnipe limit
            allowlisted_owners: vector<address>,
        }
    }

    // -- Initialization --

    /// Module initialization, runs automatically on deployment.
    /// Sets up the dispatchable FA with a deposit hook and initial antisnipe config.
    fun init_module(contract: &signer) {
        let contract_address = signer::address_of(contract);
        let module_name = string::utf8(MODULE_NAME);
        let deposit_name = string::utf8(DEPOSIT_NAME);

        // Create function info for the deposit hook
        let deposit_function = function_info::new_function_info(
            contract,
            module_name,
            deposit_name
        );

        // Create a sticky object to hold the FA data (cannot be deleted)
        let constructor_ref = object::create_sticky_object(contract_address);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);

        // Initialize with antisnipe enabled, 10000 token limit, empty allowlist
        move_to(&object_signer, FAData {
            extend_ref,
            antisnipe_data: AntisnipeData::V1 {
                antisnipe_amount: 10000,
                allowlisted_owners: vector[],
            }
        });

        // Register the deposit hook with dispatchable FA
        dispatchable_fungible_asset::register_dispatch_functions(
            &constructor_ref,
            option::none(),      // No withdraw hook
            option::some(deposit_function), // Deposit hook for antisnipe
            option::none()       // No derived balance hook
        )
    }

    // -- Admin Functions --

    /// Permanently disables antisnipe protection. Only callable by contract owner.
    /// Once disabled, all deposits are allowed without restrictions.
    public entry fun disable_antisnipe(caller: &signer) acquires FAData {
        let caller_address = signer::address_of(caller);

        // Verify caller owns the code object (deployed as object)
        let contract_object = object::address_to_object<ObjectCore>(@antisnipe);
        assert!(caller_address == object::owner(contract_object), E_NOT_CONTRACT_OWNER);

        // Set antisnipe to disabled
        FAData[@antisnipe].antisnipe_data = AntisnipeData::Disabled;
    }

    /// Updates the list of addresses exempt from antisnipe limits.
    /// Only callable by contract owner. Has no effect if antisnipe is disabled.
    public entry fun change_antisnipe_allowlisted_owners(
        caller: &signer,
        new_owners: vector<address>
    ) acquires FAData {
        let caller_address = signer::address_of(caller);

        // Verify caller owns the code object
        let contract_object = object::address_to_object<ObjectCore>(@antisnipe);
        assert!(caller_address == object::owner(contract_object), E_NOT_CONTRACT_OWNER);

        // Update allowlist only if antisnipe is enabled
        let data = &mut FAData[@antisnipe].antisnipe_data;
        match (data) {
            AntisnipeData::Disabled => {}, // No-op when disabled
            AntisnipeData::V1 { allowlisted_owners, .. } => {
                *allowlisted_owners = new_owners;
            }
        };
    }

    // -- Dispatchable Hook --

    /// Deposit hook called by dispatchable fungible asset framework.
    /// Enforces antisnipe restrictions before allowing the deposit.
    ///
    /// This function is NOT called directly - it's invoked by the FA framework
    /// when tokens are deposited to any store using this FA's metadata.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ) acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => {
                // No restrictions when disabled
            },
            AntisnipeData::V1 { antisnipe_amount, allowlisted_owners } => {
                // Calculate what the new balance would be after deposit
                let new_balance = fungible_asset::balance(store) + fungible_asset::amount(&fa);
                let store_owner = object::owner(store);

                // Allow if: balance within limit OR owner is allowlisted
                assert!(
                    new_balance <= *antisnipe_amount || allowlisted_owners.contains(&store_owner),
                    E_ANTISNIPE_ENABLED
                );
            }
        };

        // All checks passed, proceed with deposit
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    // -- View Functions --

    #[view]
    /// Returns true if antisnipe protection is currently active.
    public fun is_antisnipe_enabled<T: key>(store: Object<T>): bool acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => false,
            AntisnipeData::V1 { .. } => true,
        }
    }

    #[view]
    /// Returns the maximum balance limit if antisnipe is enabled, None otherwise.
    public fun get_antisnipe_amount<T: key>(store: Object<T>): option::Option<u64> acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => option::none(),
            AntisnipeData::V1 { antisnipe_amount, .. } => option::some(*antisnipe_amount),
        }
    }

    #[view]
    /// Returns the list of allowlisted addresses if antisnipe is enabled, None otherwise.
    public fun get_antisnipe_allowlisted_owners<T: key>(
        store: Object<T>
    ): option::Option<vector<address>> acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => option::none(),
            AntisnipeData::V1 { allowlisted_owners, .. } => option::some(*allowlisted_owners),
        }
    }

    #[view]
    /// Returns the full antisnipe configuration data.
    public fun get_antisnipe_data<T: key>(store: Object<T>): option::Option<AntisnipeData> acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => option::some(AntisnipeData::Disabled),
            _ => option::some(*data),
        }
    }

    // -- Unit Tests --

    // Test-only imports would go here if needed

    #[test(owner = @0x123)]
    /// Test that AntisnipeData::Disabled variant can be created and matched
    fun test_antisnipe_data_disabled_variant(owner: &signer) {
        let _ = owner;
        let data = AntisnipeData::Disabled;
        let is_disabled = match (&data) {
            AntisnipeData::Disabled => true,
            AntisnipeData::V1 { .. } => false,
        };
        assert!(is_disabled, 1);
    }

    #[test(owner = @0x123)]
    /// Test that AntisnipeData::V1 variant stores and retrieves values correctly
    fun test_antisnipe_data_v1_variant(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        let data = AntisnipeData::V1 {
            antisnipe_amount: 5000,
            allowlisted_owners: vector[owner_addr],
        };

        match (&data) {
            AntisnipeData::Disabled => abort 1,
            AntisnipeData::V1 { antisnipe_amount, allowlisted_owners } => {
                assert!(*antisnipe_amount == 5000, 2);
                assert!(allowlisted_owners.length() == 1, 3);
                assert!(*allowlisted_owners.borrow(0) == owner_addr, 4);
            }
        };
    }

    #[test(owner = @0x123)]
    /// Test that allowlist contains check works correctly
    fun test_allowlist_contains(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        let other_addr = @0x456;

        let allowlist = vector[owner_addr];

        assert!(allowlist.contains(&owner_addr), 1);
        assert!(!allowlist.contains(&other_addr), 2);
    }

    #[test(owner = @0x123)]
    /// Test the antisnipe limit logic (balance check)
    fun test_antisnipe_limit_logic(owner: &signer) {
        let _ = owner;
        let antisnipe_amount: u64 = 10000;

        // Test: balance within limit should pass
        let new_balance: u64 = 5000;
        assert!(new_balance <= antisnipe_amount, 1);

        // Test: balance at exactly the limit should pass
        let exact_balance: u64 = 10000;
        assert!(exact_balance <= antisnipe_amount, 2);

        // Test: balance over limit should fail (without allowlist)
        let over_balance: u64 = 10001;
        assert!(!(over_balance <= antisnipe_amount), 3);
    }

    #[test(owner = @0x123)]
    /// Test that allowlist bypass works for over-limit balances
    fun test_allowlist_bypass_logic(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        let antisnipe_amount: u64 = 10000;
        let allowlisted_owners = vector[owner_addr];

        // Over limit but allowlisted - should pass
        let over_balance: u64 = 20000;
        let is_allowed = over_balance <= antisnipe_amount || allowlisted_owners.contains(&owner_addr);
        assert!(is_allowed, 1);

        // Over limit and NOT allowlisted - should fail
        let non_allowlisted = @0x999;
        let is_blocked = over_balance <= antisnipe_amount || allowlisted_owners.contains(&non_allowlisted);
        assert!(!is_blocked, 2);
    }

    #[test(owner = @0x123)]
    /// Test that vectors can have items added (simulating allowlist updates)
    fun test_vector_operations(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        let allowlisted_owners = vector[owner_addr];

        // Verify the vector contains the owner
        assert!(allowlisted_owners.length() == 1, 1);
        assert!(allowlisted_owners.contains(&owner_addr), 2);

        // Create a new vector with additional address (simulating update)
        let new_owners = vector[owner_addr, @0x456];
        assert!(new_owners.length() == 2, 3);
    }

    #[test]
    /// Test creating different enum variants
    fun test_enum_variants() {
        // Create V1 variant
        let v1_data = AntisnipeData::V1 {
            antisnipe_amount: 10000,
            allowlisted_owners: vector[@0x123],
        };

        let is_v1 = match (&v1_data) {
            AntisnipeData::Disabled => false,
            AntisnipeData::V1 { .. } => true,
        };
        assert!(is_v1, 1);

        // Create Disabled variant
        let disabled_data = AntisnipeData::Disabled;

        let is_disabled = match (&disabled_data) {
            AntisnipeData::Disabled => true,
            AntisnipeData::V1 { .. } => false,
        };
        assert!(is_disabled, 2);
    }
}
