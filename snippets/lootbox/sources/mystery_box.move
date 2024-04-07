/// A mystery loot box which allows for people to enter loot boxes, and they're
/// added to the pool
module mystery_addr::mystery_box {

    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self, Object, ExtendRef, DeleteRef, TransferRef, LinearTransferRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::randomness;
    use aptos_token_objects::collection::{Self, create_unlimited_collection};
    use aptos_token_objects::token::{Self, Token, BurnRef};

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A global mystery box registry for whoever wants mystery boxes
    struct MysteryBoxRegistry has key {
        extend_ref: ExtendRef,
        /// Allowlist of who can add to the registry.  If it is option::none, anyone can add
        add_allowlist: Option<vector<address>>,
        /// List of all the boxes ever created
        boxes: SmartVector<Object<MysteryBox>>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A redeemable ticket for a mystery box
    ///
    /// This could be a fungible asset instead
    struct Ticket has key {
        transfer_ref: TransferRef,
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A typed mystery box that can contain multiple items inside
    struct MysteryBox has key {
        types: vector<u8>,
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A box to hold a specific coin
    struct CoinBox<phantom CoinType> has key {
        coins: Coin<CoinType>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A box to hold a fungible asset
    struct FungibleAssetBox has key {
        fas: vector<DeleteRef>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A box to hold legacy tokens
    struct LegacyTokenBox has key {
        tokens: vector<aptos_token::token::Token>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A box to hold digital assets
    struct DigitalAssetBox has key {
        tokens: vector<Object<aptos_token_objects::token::Token>>
    }

    /// Withdrawing coin is not registered
    const E_COIN_NOT_REGISTERED: u64 = 1;
    /// Not enough coins to withdraw from account
    const E_NOT_ENOUGH_COINS: u64 = 2;
    /// Registry already exists
    const E_REGISTRY_ALREADY_EXISTS: u64 = 3;
    /// Registry doesn't exist
    const E_REGISTRY_DOESNT_EXIST: u64 = 4;
    /// Code path not yet implemented
    const E_NOT_IMPLEMENTED: u64 = 5;
    /// Not allowed to add to mystery box registry.  Not In allowlist
    const E_NOT_ALLOWED: u64 = 6;
    /// Registry has no boxes available
    const E_NO_BOXES_AVAILABLE: u64 = 7;
    /// Not allowed to mint tickets, not owner of registry
    const E_NOT_ADMIN: u64 = 8;
    /// Not enough boxes to mint tickets
    const E_NOT_ENOUGH_BOXES: u64 = 9;
    /// Not owner of the ticket, can't redeem
    const E_NOT_OWNER: u64 = 10;
    /// Only allowed to create a box with 3 types or less
    const E_TOO_MANY_COIN_TYPES: u64 = 11;
    /// FA Inputs mismatch in length
    const E_FA_LENGTH_MISMATCH: u64 = 12;
    /// Legacy token Inputs mismatch in length
    const E_LEGACY_TOKEN_LENGTH_MISMATCH: u64 = 13;

    const COIN_TYPE: u8 = 1;
    const FA_TYPE: u8 = 2;
    const LEGACY_TOKEN_TYPE: u8 = 3;
    const DA_TYPE: u8 = 3;

    /// Creates a registry along with the corresponding ticket collection
    ///
    /// If add_allowlist is option::none(), then anyone can push loot boxes
    public entry fun create_registry(
        caller: &signer,
        name: String,
        description: String,
        uri: String,
        add_allowlist: Option<vector<address>>
    ) {
        // Create an unlimited ticket collection, we're not going to limit ourselves
        let collection_constructor = create_unlimited_collection(
            caller,
            description,
            name,
            option::none(),
            uri
        );
        let object_signer = object::generate_signer(&collection_constructor);
        let extend_ref = object::generate_extend_ref(&collection_constructor);

        move_to(&object_signer, MysteryBoxRegistry {
            extend_ref,
            add_allowlist,
            boxes: smart_vector::new(),
        })
    }

    /// Mints a mystery box ticket to an account
    public entry fun mint_tickets(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        receivers: vector<address>
    ) acquires MysteryBoxRegistry {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(registry_obj, caller_address), E_NOT_ALLOWED);
        let registry = get_registry(registry_obj);
        let collection_name = collection::name(registry_obj);
        let collection_description = collection::description(registry_obj);
        let collection_uri = collection::uri(registry_obj);
        let registry_signer = object::generate_signer_for_extending(&registry.extend_ref);

        // Note, this prevents parallelization, but is meant to ensure it doesn't go over the ticket amount
        let box_size = smart_vector::length(&registry.boxes);
        let collection_size = option::destroy_some(collection::count(registry_obj));
        let num_recievers = vector::length(&receivers);

        assert!(collection_size + num_recievers <= box_size, E_NOT_ENOUGH_BOXES);

        // Mint each ticket to each user
        vector::for_each(receivers, |receiver| {
            let ticket_transfer_ref = mint_ticket_in_collection(
                &registry_signer,
                collection_name,
                collection_description,
                collection_uri
            );

            // Transfer soulbound ticket
            object::transfer_with_ref(ticket_transfer_ref, receiver);
        })
    }

    /// Mints a new ticket
    fun mint_ticket_in_collection(
        registry_signer: &signer,
        collection_name: String,
        collection_description: String,
        collection_uri: String,
    ): LinearTransferRef {
        let constructor = aptos_token_objects::token::create_numbered_token(
            registry_signer,
            collection_name,
            collection_description,
            collection_name,
            string::utf8(b""),
            option::none(),
            collection_uri
        );

        // Make ticket soulbound by default
        let transfer_ref = object::generate_transfer_ref(&constructor);
        object::disable_ungated_transfer(&transfer_ref);
        let delete_ref = object::generate_delete_ref(&constructor);
        let extend_ref = object::generate_extend_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        let burn_ref = token::generate_burn_ref(&constructor);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);

        // TODO: Do we make ticket fungible?
        move_to(&object_signer, Ticket {
            extend_ref,
            delete_ref,
            transfer_ref,
            burn_ref,
        });

        linear_transfer_ref
    }

    #[randomness]
    /// Opens a box by redeeming a ticket
    ///
    /// Limited to only 3 coin types, and no more must be added to the box.
    ///
    /// This must be private, because it uses randomness
    entry fun open_box<CoinType0, CoinType1, CoinType2>(
        caller: &signer,
        ticket: Object<Ticket>
    ) acquires CoinBox, MysteryBox, MysteryBoxRegistry, Ticket, FungibleAssetBox, LegacyTokenBox, DigitalAssetBox {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(ticket, caller_address), E_NOT_OWNER);

        // Redeem and burn ticket
        let ticket_token: Object<Token> = object::convert(ticket);
        let ticket_collection = token::collection_object(ticket_token);
        let registry_address = object::object_address(&ticket_collection);
        let Ticket {
            extend_ref: _,
            transfer_ref: _,
            delete_ref,
            burn_ref,
        } = move_from<Ticket>(object::object_address(&ticket));
        token::burn(burn_ref);
        object::delete(delete_ref);

        // Randomly choose an available box, and open it
        let registry = borrow_global_mut<MysteryBoxRegistry>(registry_address);
        let num_boxes = smart_vector::length(&registry.boxes);
        assert!(num_boxes > 0, E_NO_BOXES_AVAILABLE);

        let index = randomness::u64_range(0, num_boxes);
        let box_object = smart_vector::swap_remove(&mut registry.boxes, index);
        let box_address = object::object_address(&box_object);
        let MysteryBox {
            types,
            extend_ref,
            delete_ref
        } = move_from<MysteryBox>(box_address);

        let coin_type_counter = 0;
        let box_signer = object::generate_signer_for_extending(&extend_ref);

        // Retrieve all associated types and transfer assets
        vector::for_each(types, |type| {
            // Note, the proper coin types must be passed, otherwise, they will be lost forever.
            if (type == COIN_TYPE) {
                if (coin_type_counter == 0) {
                    open_coin_box<CoinType0>(caller_address, box_address);
                } else if (coin_type_counter == 1) {
                    open_coin_box<CoinType1>(caller_address, box_address);
                } else if (coin_type_counter == 2) {
                    open_coin_box<CoinType2>(caller_address, box_address);
                };

                coin_type_counter = coin_type_counter + 1;
            } else if (type == FA_TYPE) {
                open_fa_box(&box_signer, caller_address, box_address);
            } else if (type == LEGACY_TOKEN_TYPE) {
                open_legacy_token_box(caller, box_address);
            } else if (type == DA_TYPE) {
                open_digital_asset_box(&box_signer, caller_address, box_address);
            } else {
                abort E_NOT_IMPLEMENTED
            }
        });

        // Delete the object once all the parts are pulled from the loot box
        object::delete(delete_ref);
    }

    /// Transfer all of the coin back to the user, requires to know the coin type in advance
    inline fun open_coin_box<CoinType>(caller_address: address, box_address: address) {
        let CoinBox<CoinType> {
            coins
        } = move_from<CoinBox<CoinType>>(box_address);
        aptos_account::deposit_coins(caller_address, coins);
    }

    /// Opens the Fungible asset box, and transfers all to the primary store of the caller
    inline fun open_fa_box(box_signer: &signer, caller_address: address, box_address: address) {
        let FungibleAssetBox {
            fas
        } = move_from<FungibleAssetBox>(box_address);

        vector::for_each(fas, |fa_delete_ref| {
            let fa = object::object_from_delete_ref<FungibleStore>(&fa_delete_ref);
            // Withdraw all
            let amount = fungible_asset::balance(fa);
            let assets = fungible_asset::withdraw(box_signer, fa, amount);

            // Delete store
            fungible_asset::remove_store(&fa_delete_ref);

            // Deposit all in primary store of user
            primary_fungible_store::deposit(caller_address, assets);
        })
    }

    inline fun open_digital_asset_box(box_signer: &signer, caller_address: address, box_address: address) {
        let DigitalAssetBox {
            tokens
        } = move_from<DigitalAssetBox>(box_address);

        // Transfer digital assets
        vector::for_each(tokens, |token| {
            object::transfer(box_signer, token, caller_address);
        })
    }

    inline fun open_legacy_token_box(caller: &signer, box_address: address) {
        let LegacyTokenBox {
            tokens
        } = move_from<LegacyTokenBox>(box_address);

        // Deposit tokens
        vector::for_each(tokens, |token| {
            aptos_token::token::deposit_token(caller, token);
        })
    }

    public entry fun create_multi_box<CoinType1, CoinType2, CoinType3>(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        coin_amounts: vector<u64>,
        fa_metadatas: vector<Object<Metadata>>,
        fa_amounts: vector<u64>,
        legacy_token_creator_addresses: vector<address>,
        legacy_token_collection_names: vector<String>,
        legacy_token_token_names: vector<String>,
        digital_assets: vector<Object<Token>>
    ) acquires FungibleAssetBox, LegacyTokenBox, DigitalAssetBox, MysteryBoxRegistry {
        let registry_address = object::object_address(&registry_obj);

        // Prep types and do input validation
        let types = vector[];
        let num_coins = vector::length(&coin_amounts);
        assert!(num_coins <= 3, E_TOO_MANY_COIN_TYPES);
        for (_i in 0..num_coins) {
            vector::push_back(&mut types, COIN_TYPE);
        };

        let num_fa = vector::length(&fa_amounts);
        assert!(num_fa != vector::length(&fa_metadatas), E_FA_LENGTH_MISMATCH);
        for (_i in 0..num_fa) {
            vector::push_back(&mut types, FA_TYPE);
        };

        let num_legacy_token = vector::length(&legacy_token_token_names);
        assert!(
            num_legacy_token == vector::length(&legacy_token_collection_names) && num_legacy_token == vector::length(
                &legacy_token_creator_addresses
            ),
            E_LEGACY_TOKEN_LENGTH_MISMATCH
        );
        for (_i in 0..num_legacy_token) {
            vector::push_back(&mut types, LEGACY_TOKEN_TYPE);
        };

        let num_digital_assets = vector::length(&digital_assets);
        for (_i in 0..num_digital_assets) {
            vector::push_back(&mut types, DA_TYPE);
        };

        // Build box, and add all associated items
        let box_signer = create_box(registry_address, types);
        if (num_coins > 0) {
            add_coin<CoinType1>(&box_signer, caller, *vector::borrow(&coin_amounts, 0))
        };
        if (num_coins > 1) {
            add_coin<CoinType2>(&box_signer, caller, *vector::borrow(&coin_amounts, 1))
        };
        if (num_coins > 2) {
            add_coin<CoinType3>(&box_signer, caller, *vector::borrow(&coin_amounts, 2))
        };
        for (i in 0..num_fa) {
            add_fungible_asset(&box_signer, caller, *vector::borrow(&fa_metadatas, i), *vector::borrow(&fa_amounts, i))
        };
        for (i in 0..num_legacy_token) {
            add_legacy_token(
                &box_signer,
                caller,
                *vector::borrow(&legacy_token_creator_addresses, i),
                *vector::borrow(&legacy_token_collection_names, i),
                *vector::borrow(&legacy_token_token_names, i)
            )
        };
        vector::for_each(digital_assets, |digital_asset| {
            add_digital_asset(
                &box_signer,
                caller,
                digital_asset
            )
        });

        // Store the box into the registry
        let box_object = object::address_to_object(signer::address_of(&box_signer));
        store_in_registry(caller, registry_obj, box_object);
    }

    /// Creates a box to contain a single coin type
    public entry fun create_coin_box<CoinType>(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        amount: u64
    ) acquires MysteryBoxRegistry {
        let registry_address = object::object_address(&registry_obj);
        let object_signer = create_box(registry_address, vector[COIN_TYPE]);
        add_coin<CoinType>(&object_signer, caller, amount);

        let object = object::address_to_object(signer::address_of(&object_signer));
        store_in_registry(caller, registry_obj, object);
    }

    public entry fun create_fa_box(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        metadata: Object<Metadata>,
        amount: u64
    ) acquires MysteryBoxRegistry, FungibleAssetBox {
        let registry_address = object::object_address(&registry_obj);
        let object_signer = create_box(registry_address, vector[COIN_TYPE]);
        add_fungible_asset(&object_signer, caller, metadata, amount);

        let object = object::address_to_object(signer::address_of(&object_signer));
        store_in_registry(caller, registry_obj, object);
    }

    public entry fun create_legacy_token_box(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        creator_address: address,
        collection_name: String,
        token_name: String,
    ) acquires MysteryBoxRegistry, LegacyTokenBox {
        let registry_address = object::object_address(&registry_obj);
        let object_signer = create_box(registry_address, vector[COIN_TYPE]);
        add_legacy_token(&object_signer, caller, creator_address, collection_name, token_name);

        let object = object::address_to_object(signer::address_of(&object_signer));
        store_in_registry(caller, registry_obj, object);
    }

    public entry fun create_digital_asset_box(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        token: Object<Token>
    ) acquires MysteryBoxRegistry, DigitalAssetBox {
        let registry_address = object::object_address(&registry_obj);
        let object_signer = create_box(registry_address, vector[COIN_TYPE]);
        add_digital_asset(&object_signer, caller, token);

        let object = object::address_to_object(signer::address_of(&object_signer));
        store_in_registry(caller, registry_obj, object);
    }

    inline fun add_coin<CoinType>(object_signer: &signer, caller: &signer, amount: u64) {
        // Check some entry conditions
        let caller_address = signer::address_of(caller);
        assert!(coin::is_account_registered<CoinType>(caller_address), E_COIN_NOT_REGISTERED);
        assert!(coin::balance<CoinType>(caller_address) >= amount, E_NOT_ENOUGH_COINS);

        move_to(object_signer, CoinBox<CoinType> {
            coins: coin::withdraw(caller, amount)
        });
    }

    inline fun add_fungible_asset(box_signer: &signer, caller: &signer, metadata: Object<Metadata>, amount: u64) {
        let box_address = signer::address_of(box_signer);

        // Transfer from a user's primary store into a temporary store
        let constructor = object::create_object(box_address);
        let fungible_store = fungible_asset::create_store(&constructor, metadata);
        let delete_ref = object::generate_delete_ref(&constructor);
        let assets = primary_fungible_store::withdraw(caller, metadata, amount);
        fungible_asset::deposit(fungible_store, assets);

        // Add FA to the existing box or create a new one
        if (!exists<FungibleAssetBox>(box_address)) {
            move_to(box_signer, FungibleAssetBox {
                fas: vector[]
            });
        };

        vector::push_back(&mut borrow_global_mut<FungibleAssetBox>(box_address).fas, delete_ref);
    }

    inline fun add_legacy_token(
        box_signer: &signer,
        caller: &signer,
        creator_address: address,
        collection_name: String,
        token_name: String
    ) {
        let box_address = signer::address_of(box_signer);

        // Transfer to the box
        let caller_address = signer::address_of(caller);
        let token_data_id = aptos_token::token::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = aptos_token::token::create_token_id(
            token_data_id,
            aptos_token::token::get_tokendata_largest_property_version(creator_address, token_data_id)
        );
        let token = aptos_token::token::withdraw_token(
            caller,
            token_id,
            aptos_token::token::balance_of(caller_address, token_id)
        );

        if (!exists<LegacyTokenBox>(box_address)) {
            move_to(box_signer, LegacyTokenBox {
                tokens: vector[]
            });
        };

        vector::push_back(&mut borrow_global_mut<LegacyTokenBox>(box_address).tokens, token);
    }

    inline fun add_digital_asset(box_signer: &signer, caller: &signer, token: Object<Token>) {
        let box_address = signer::address_of(box_signer);

        // Transfer to the box
        object::transfer(caller, token, box_address);

        // Add FA to the existing box or create a new one
        if (!exists<DigitalAssetBox>(box_address)) {
            move_to(box_signer, DigitalAssetBox {
                tokens: vector[]
            });
        };

        vector::push_back(&mut borrow_global_mut<DigitalAssetBox>(box_address).tokens, token);
    }

    inline fun create_box(registry_address: address, types: vector<u8>): signer {
        let constructor_ref = object::create_object(registry_address);
        let object_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let delete_ref = object::generate_delete_ref(&constructor_ref);

        move_to(&object_signer, MysteryBox {
            types,
            extend_ref,
            delete_ref
        });
        object_signer
    }

    /// Adds the box to the supply
    inline fun store_in_registry(
        caller: &signer,
        registry_obj: Object<MysteryBoxRegistry>,
        object: Object<MysteryBox>
    ) acquires MysteryBoxRegistry {
        // Retrieve registry
        let registry = get_registry_mut(registry_obj);

        // Ensure user can push to the registry
        if (option::is_some(&registry.add_allowlist)) {
            let caller_address = signer::address_of(caller);
            assert!(vector::contains(option::borrow(&registry.add_allowlist), &caller_address), E_NOT_ALLOWED)
        };

        // Store the box
        smart_vector::push_back(&mut registry.boxes, object);
    }

    inline fun get_registry(
        registry_obj: Object<MysteryBoxRegistry>,
    ): &MysteryBoxRegistry {
        let registry_address = object::object_address(&registry_obj);
        assert!(exists<MysteryBoxRegistry>(registry_address), E_REGISTRY_DOESNT_EXIST);
        borrow_global<MysteryBoxRegistry>(registry_address)
    }

    inline fun get_registry_mut(
        registry_obj: Object<MysteryBoxRegistry>,
    ): &mut MysteryBoxRegistry {
        let registry_address = object::object_address(&registry_obj);
        assert!(exists<MysteryBoxRegistry>(registry_address), E_REGISTRY_DOESNT_EXIST);
        borrow_global_mut<MysteryBoxRegistry>(registry_address)
    }
}