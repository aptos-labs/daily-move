/// Shared utility functions for all liquid NFT implementations.
///
/// This module uses `public(friend)` visibility so that the three liquid NFT modules
/// (`liquid_coin`, `liquid_coin_legacy`, `liquid_fungible_asset`) can share common logic
/// for object creation, coin/FA minting, decimal calculations, and pseudorandom number generation,
/// without exposing these internals to external callers.
module fraction_addr::common {

    use std::bcs;
    use std::hash;
    use std::option;
    use std::string::String;
    use aptos_std::from_bcs;
    use aptos_std::math64;
    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, destroy_mint_cap, destroy_freeze_cap, destroy_burn_cap};
    use aptos_framework::fungible_asset;
    use aptos_framework::object::{Self, ExtendRef, ConstructorRef, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_framework::transaction_context;
    #[test_only]
    use std::signer;
    #[test_only]
    use std::string;
    #[test_only]
    use aptos_std::string_utils;
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    #[test_only]
    use aptos_framework::genesis;

    // These friends allow for other modules to use the friend functions in this module
    friend fraction_addr::liquid_coin;
    friend fraction_addr::liquid_coin_legacy;
    friend fraction_addr::liquid_fungible_asset;

    /// Common logic for creating sticky object for the liquid NFTs
    public(friend) inline fun create_sticky_object(
        caller_address: address
    ): (ConstructorRef, ExtendRef, signer, address) {
        let constructor = object::create_sticky_object(caller_address);
        let extend_ref = object::generate_extend_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        let object_address = object::address_from_constructor_ref(&constructor);
        (constructor, extend_ref, object_signer, object_address)
    }

    /// Mint the supply of the liquid token, destroying the mint capability afterwards
    public(friend) inline fun create_coin<LiquidCoin>(
        caller: &signer,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
        asset_supply: u64,
        destination_address: address,
    ) {
        // Create the coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LiquidCoin>(
            caller,
            asset_name,
            asset_symbol,
            decimals,
            false
        );

        // Mint the whole supply, and destroy the capabilities for mint, freeze, burn
        let coins = coin::mint(asset_supply, &mint_cap);
        aptos_account::deposit_coins(destination_address, coins);
        destroy_mint_cap(mint_cap);
        destroy_freeze_cap(freeze_cap);
        destroy_burn_cap(burn_cap);
    }

    /// Common logic for creating a fungible asset
    public(friend) inline fun create_fungible_asset(
        object_address: address,
        constructor: &ConstructorRef,
        asset_supply: u64,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
        collection_uri: String,
        project_uri: String,
    ) {
        // Create a fungible asset that can use a primary fungible store
        // the primary fungible store makes it simple to use like a Coin, where there is a primary
        // store that carries all the assets
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor,
            option::some((asset_supply as u128)),
            asset_name,
            asset_symbol,
            decimals,
            collection_uri,
            project_uri
        );

        // Mint the supply of the liquid token
        // Note: The mint ref is dropped, so no more can be minted afterwards
        let mint_ref = fungible_asset::generate_mint_ref(constructor);
        primary_fungible_store::mint(&mint_ref, object_address, asset_supply);
    }

    /// A convenience function, to get the entirety of 1 NFT in a coin's value
    /// 10^decimals = 1.0...
    public(friend) inline fun one_nft_in_coins<LiquidCoin>(): u64 {
        one_token_from_decimals((coin::decimals<LiquidCoin>()))
    }

    /// A convenience function, to get the entirety of 1 NFT in a fungible asset's value
    /// 10^decimals = 1.0...
    public(friend) inline fun one_nft_in_fungible_assets<T: key>(metadata: Object<T>): u64 {
        one_token_from_decimals(fungible_asset::decimals(metadata))
    }

    public(friend) inline fun one_token_from_decimals(decimals: u8): u64 {
        math64::pow(10, (decimals as u64))
    }

    /// Generate a pseudorandom number
    ///
    /// We use AUID to generate a number from the transaction hash and a globally unique
    /// number, which allows us to spin this multiple times in a single transaction.
    ///
    /// We use timestamp to ensure that people can't predict it.
    ///
    public(friend) inline fun pseudorandom_u64(size: u64): u64 {
        let auid = transaction_context::generate_auid_address();
        let bytes = bcs::to_bytes(&auid);
        let time_bytes = bcs::to_bytes(&timestamp::now_microseconds());
        bytes.append(time_bytes);

        // Hash that together, and mod by the expected size
        let hash = hash::sha3_256(bytes);
        let val = from_bcs::to_u256(hash) % (size as u256);
        (val as u64)
    }

    #[test_only]
    const COLLECTION_NAME: vector<u8> = b"MyCollection";
    #[test_only]
    const ASSET_NAME: vector<u8> = b"LiquidToken";
    #[test_only]
    const ASSET_SYMBOL: vector<u8> = b"L-NFT";
    #[test_only]
    const TOKEN_NAME: vector<u8> = b"Token";

    #[test_only]
    public(friend) fun setup_test(creator: &signer, collector: &signer): (address, address) {
        genesis::setup();
        let creator_address = signer::address_of(creator);
        let collector_address = signer::address_of(collector);
        create_account_for_test(creator_address);
        create_account_for_test(collector_address);
        (creator_address, collector_address)
    }

    #[test_only]
    public(friend) fun create_token_collection(creator: &signer) {
        create_token_collection_with_name(creator, string::utf8(COLLECTION_NAME))
    }

    #[test_only]
    public(friend) fun create_token_collection_with_name(creator: &signer, name: String) {
        aptos_token::token::create_collection_script(creator,
            name,
            string::utf8(b""),
            string::utf8(b""),
            5,
            vector[false, false, false],
        );
    }

    #[test_only]
    public(friend) fun create_tokens(creator: &signer, collector: &signer) {
        let collection_name = string::utf8(COLLECTION_NAME);
        let creator_address = signer::address_of(creator);
        for (i in 0..5) {
            let name = token_name(i);
            aptos_token::token::create_token_script(
                creator,
                collection_name,
                name,
                string::utf8(b""),
                1,
                1,
                string::utf8(b""),
                signer::address_of(creator),
                1,
                0,
                vector[false, false, false, false, false],
                vector[],
                vector[],
                vector[],
            );

            let token_id = token_id(creator_address, i);
            aptos_token::token::direct_transfer(creator, collector, token_id, 1);
        }
    }

    #[test_only]
    public(friend) fun token_id(creator_address: address, i: u64): aptos_token::token::TokenId {
        let token_data_id = aptos_token::token::create_token_data_id(
            creator_address,
            string::utf8(COLLECTION_NAME),
            token_name(i)
        );
        aptos_token::token::create_token_id(
            token_data_id,
            aptos_token::token::get_tokendata_largest_property_version(creator_address, token_data_id)
        )
    }

    #[test_only]
    public(friend) fun token_name(i: u64): String {
        string_utils::format2(&b"{}:{}", string::utf8(TOKEN_NAME), i)
    }

    #[test_only]
    /// Create a collection just for testing
    public(friend) fun create_token_objects_collection(
        creator: &signer
    ): Object<aptos_token_objects::collection::Collection> {
        let constructor = aptos_token_objects::collection::create_fixed_collection(
            creator,
            string::utf8(b""),
            5,
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(b""),
        );
        object::object_from_constructor_ref(&constructor)
    }

    #[test_only]
    /// Create tokens and transfer them all to the collector
    public(friend) fun create_token_objects(
        creator: &signer,
        collector: &signer
    ): vector<Object<aptos_token_objects::token::Token>> {
        let tokens = vector[];
        let collection_name = string::utf8(COLLECTION_NAME);
        let collector_address = signer::address_of(collector);

        // Create 5 tokens with different names
        for (i in 0..5) {
            let name = token_name(i);
            let constructor = aptos_token_objects::token::create(
                creator,
                collection_name,
                string::utf8(b""),
                name,
                option::none(),
                string::utf8(b""),
            );

            let token = object::object_from_constructor_ref(&constructor);
            tokens.push_back(token);

            // Transfer tokens to the collector
            object::transfer(creator, token, collector_address);
        };

        tokens
    }
}