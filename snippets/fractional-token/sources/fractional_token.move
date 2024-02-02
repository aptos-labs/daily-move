/// An example on how to fractionalize an already existing Digital asset
///
/// This shows some of the beauty of objects, and how they can be used for locking up other objects
/// extending to add fungibility, as well as recooping storage gas at the end.
///
/// This approach here requires the number of shares to be determined up front, and for simplicity
/// no decimals are added.
module fraction_addr::fractional_token {

    use std::option;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::string_utils;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{Metadata, BurnRef};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::token::{Self, Token as TokenObject};

    /// Can't create fractionalize digital asset, not owner of token
    const E_NOT_OWNER: u64 = 1;
    /// Can't defractionalize digital asset, not owner of all pieces
    const E_NOT_COMPLETE_OWNER: u64 = 2;
    /// Metadata object isn't for a fractionalized digital asset
    const E_NOT_FRACTIONALIZED_DIGITAL_ASSET: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A locker for a digital asset and fractionalizes it accordingly
    struct FractionalDigitalAsset has key {
        /// The address of the locked up token
        asset: Object<TokenObject>,
        /// For transferring the locked up token back out
        extend_ref: ExtendRef,
        /// For burning the tokens at the end
        burn_ref: BurnRef,
    }

    /// Fractionalizes an asset.  We specifically keep it below u128 for simplicity
    entry fun fractionalize_asset(caller: &signer, asset: Object<TokenObject>, supply: u64) {
        // Assert ownership before fractionalizing
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(asset, caller_address), E_NOT_OWNER);

        // Pull data from the original asset
        let asset_name = token::name(asset);
        let asset_uri = token::uri(asset);

        // Build the object to hold the fractionalized asset
        // This must be a sticky object (a non-deleteable object) to be fungible
        let constructor = object::create_sticky_object(caller_address);
        let extend_ref = object::generate_extend_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        let object_address = object::address_from_constructor_ref(&constructor);

        // Create names based on the asset's name
        let name = string_utils::format1(&b"Fractionalized {}", asset_name);
        let asset_name_bytes = string::bytes(&asset_name);
        let symbol = string_utils::format1(&b"FRAC-{}", string::utf8(vector[*vector::borrow(asset_name_bytes, 0)]));

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor,
            option::some((supply as u128)),
            name,
            symbol,
            0,
            asset_uri,
            string::utf8(b"") // Empty project URI, maybe put something else here
        );

        // Add mint and burn refs, to be able to burn the shares at the end.
        let mint_ref = fungible_asset::generate_mint_ref(&constructor);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor);
        move_to(&object_signer, FractionalDigitalAsset {
            asset,
            extend_ref,
            burn_ref,
        });

        // Lock asset up in the object
        object::transfer(caller, asset, object_address);

        // Mint fungible asset, and store at the owner
        primary_fungible_store::mint(&mint_ref, caller_address, supply);
    }

    /// A fractionalized asset can be removed, if and only if the owner controls all of the fungible assets
    /// in the primary store
    entry fun recombine_asset(caller: &signer, metadata_object: Object<Metadata>) acquires FractionalDigitalAsset {
        let caller_address = signer::address_of(caller);

        // Check that this is a fractionalized asset
        let metadata_object_address = object::object_address(&metadata_object);
        assert!(exists<FractionalDigitalAsset>(metadata_object_address), E_NOT_FRACTIONALIZED_DIGITAL_ASSET);

        // Check the balance to ensure you have the whole asset
        // We enforce that balance must be u64 and exist
        let caller_balance = primary_fungible_store::balance(caller_address, metadata_object);
        let total_supply = (option::destroy_some(fungible_asset::supply(metadata_object)) as u64);
        assert!(caller_balance == total_supply, E_NOT_COMPLETE_OWNER);

        // Move the asset back to the owner
        let asset_object = borrow_global<FractionalDigitalAsset>(metadata_object_address);
        let object_signer = object::generate_signer_for_extending(&asset_object.extend_ref);
        object::transfer(&object_signer, asset_object.asset, caller_address);

        // Burn the digital assets, then destroy as much as possible to recoop gas
        primary_fungible_store::burn(&asset_object.burn_ref, caller_address, total_supply);
        let FractionalDigitalAsset {
            asset: _,
            extend_ref: _,
            burn_ref: _,
        } = move_from<FractionalDigitalAsset>(metadata_object_address);

        // Note that the fungible asset metadata will stay around forever in the object, but no actual fungible assets
        // will exist.
    }
}
