module fraction_addr::common {

    use std::option;
    use std::string::String;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::coin::{destroy_mint_cap, destroy_freeze_cap, destroy_burn_cap};
    use aptos_framework::fungible_asset;
    use aptos_framework::object;
    use aptos_framework::object::{ExtendRef, ConstructorRef};
    use aptos_framework::primary_fungible_store;

    friend fraction_addr::liquid_coin;
    friend fraction_addr::liquid_coin_legacy;
    friend fraction_addr::liquid_fungible_asset;

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
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LiquidCoin>(
            caller,
            asset_name,
            asset_symbol,
            decimals,
            false
        );
        let coins = coin::mint(asset_supply, &mint_cap);
        aptos_account::deposit_coins(destination_address, coins);
        destroy_mint_cap(mint_cap);
        destroy_freeze_cap(freeze_cap);
        destroy_burn_cap(burn_cap);
    }

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
        let mint_ref = fungible_asset::generate_mint_ref(constructor);
        primary_fungible_store::mint(&mint_ref, object_address, asset_supply);
    }
}