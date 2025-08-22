/// An example for an antisnipe token launcher, must be used with a code object deployment.
///
/// TODO: Add events, and minting, etc.
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

    /// Cannot deposit more, antisnipe is enabled
    const E_ANTISNIPE_ENABLED: u64 = 1;

    /// Not contract owner, cannot do admin actions
    const E_NOT_CONTRACT_OWNER: u64 = 99;

    const MODULE_NAME: vector<u8> = b"antisnipe_token";
    const DEPOSIT_NAME: vector<u8> = b"deposit";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// The main data for the module, stored under the metadata of a FungibleStore
    struct FAData has key {
        extend_ref: object::ExtendRef,
        antisnipe_data: AntisnipeData
    }

    /// Antisnipe data, if set to disabled, no checks are done
    enum AntisnipeData has copy, store, drop {
        Disabled,
        V1 {
            antisnipe_amount: u64,
            allowlisted_owners: vector<address>,
        }
    }

    /// Initializes module, only runs once
    fun init_module(contract: &signer) {
        let contract_address = signer::address_of(contract);
        let module_name = string::utf8(MODULE_NAME);
        let deposit_name = string::utf8(DEPOSIT_NAME);

        // Register overrides for deposit and withdraw
        let deposit_function = function_info::new_function_info(
            contract,
            module_name,
            deposit_name
        );

        // Create the collection
        let constructor_ref = object::create_sticky_object(contract_address);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);

        move_to(&object_signer, FAData {
            extend_ref,
            antisnipe_data: AntisnipeData::V1 {
                antisnipe_amount: 10000,
                allowlisted_owners: vector[],
            }
        });

        // Override deposit
        dispatchable_fungible_asset::register_dispatch_functions(
            &constructor_ref,
            option::none(),
            option::some(deposit_function),
            option::none()
        )
    }

    public entry fun disable_antisnipe(caller: &signer) acquires FAData {
        let caller_address = signer::address_of(caller);

        // We're assuming we publish with an object
        let contract_object = object::address_to_object<ObjectCore>(@antisnipe);
        assert!(caller_address == object::owner(contract_object), E_NOT_CONTRACT_OWNER);
        FAData[@antisnipe].antisnipe_data = AntisnipeData::Disabled;
    }

    public entry fun change_antisnipe_allowlisted_owsners(
        caller: &signer,
        new_owners: vector<address>
    ) acquires FAData {
        let caller_address = signer::address_of(caller);

        // We're assuming we publish with an object
        let contract_object = object::address_to_object<ObjectCore>(@antisnipe);
        assert!(caller_address == object::owner(contract_object), E_NOT_CONTRACT_OWNER);

        // Update the allowlisted owners
        let data = &mut FAData[@antisnipe].antisnipe_data;
        match (data) {
            AntisnipeData::Disabled => {},
            AntisnipeData::V1 { allowlisted_owners, .. } => {
                *allowlisted_owners = new_owners;
            }
        };
    }

    /// Transfer provides functionality used for dynamic dispatch
    ///
    /// This will not be called by any other functions.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ) acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => {},
            AntisnipeData::V1 { antisnipe_amount, allowlisted_owners } => {
                // Check withdraw amount first against antisnipe
                let new_balance = fungible_asset::balance(store) + fungible_asset::amount(&fa);
                let store_owner = object::owner(store);

                // Check antisnipe conditions
                assert!(
                    new_balance < *antisnipe_amount || allowlisted_owners.contains(
                        &store_owner
                    ),
                    E_ANTISNIPE_ENABLED
                );
            }
        };

        // Proceed with deposit
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    #[view]
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
    public fun get_antisnipe_data<T: key>(store: Object<T>): option::Option<AntisnipeData> acquires FAData {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let data = &FAData[metadata_address].antisnipe_data;

        match (data) {
            AntisnipeData::Disabled => option::none(),
            _ => option::some(*data),
        }
    }
}
