/// Liquid coin allows for a coin liquidity on a set of TokenObjects
///
/// Note that tokens are mixed together in as if they were all the same value, and are
/// randomly chosen when withdrawing.  This might have consequences where too many
/// deposits & withdrawals happen in a short period of time, which can be counteracted with
/// a timestamp cooldown either for an individual account, or for the whole pool.
///
/// How does this work?
/// - User calls `liquify()` to get a set of liquid tokens associated with the NFT
/// - They can now trade the coin directly
/// - User can call `claim` which will withdraw a random NFT from the pool in exchange for tokens
module fraction_addr::liquid_coin {

    use std::bcs;
    use std::option;
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_std::from_bcs;
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::object::{Self, Object, ExtendRef, object_address, is_owner};
    use aptos_framework::transaction_context;
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::token;
    use aptos_token_objects::token::{Token as TokenObject};
    use fraction_addr::common;

    /// Can't create fractionalize digital asset, not owner of collection
    const E_NOT_OWNER_OF_COLLECTION: u64 = 1;
    /// Can't liquify, not owner of token
    const E_NOT_OWNER_OF_TOKEN: u64 = 2;
    /// Can't redeem for tokens, not enough liquid tokens
    const E_NOT_ENOUGH_LIQUID_TOKENS: u64 = 3;
    /// Metadata object isn't for a fractionalized digital asset
    const E_NOT_FRACTIONALIZED_DIGITAL_ASSET: u64 = 4;
    /// Supply is not fixed, so we can't liquify this collection
    const E_NOT_FIXED_SUPPLY: u64 = 5;
    /// Token being liquified is not in the collection for the LiquidToken
    const E_NOT_IN_COLLECTION: u64 = 6;

    /// Metadata for a liquidity token for a collection
    struct LiquidCoinMetadata<phantom LiquidCoin> has key {
        /// The collection associated with the liquid token
        collection: Object<Collection>,
        /// Used for transferring objects
        extend_ref: ExtendRef,
        /// The list of all tokens locked up in the contract
        token_pool: SmartVector<Object<TokenObject>>
    }

    /// Create a liquid token for a collection.
    ///
    /// The collection is assumed to be fixed, if the collection is not fixed, then this doesn't work quite correctly
    entry fun create_liquid_token<LiquidCoin>(
        caller: &signer,
        collection: Object<Collection>,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
    ) {
        // Assert ownership before fractionalizing, this is to ensure there are not duplicates of it
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(collection, caller_address), E_NOT_OWNER_OF_COLLECTION);

        // Ensure collection is fixed, and determine the number of tokens to mint
        let maybe_collection_supply = collection::count(collection);
        assert!(option::is_some(&maybe_collection_supply), E_NOT_FIXED_SUPPLY);
        let collection_supply = option::destroy_some(maybe_collection_supply);
        let asset_supply = collection_supply * (decimals as u64);

        // Build the object to hold the liquid token
        // This must be a sticky object (a non-deleteable object) to be fungible
        let (_, extend_ref, object_signer, object_address) = common::create_sticky_object(caller_address);

        // Mint the supply of the liquid token, destroying the mint capability afterwards
        common::create_coin<LiquidCoin>(caller, asset_name, asset_symbol, decimals, asset_supply, object_address);

        move_to(&object_signer, LiquidCoinMetadata<LiquidCoin> {
            collection, extend_ref, token_pool: smart_vector::new()
        })
    }

    /// Allows for claiming a token from the collection
    ///
    /// The token claim is random from all the tokens stored in the contract
    entry fun claim<LiquidCoin>(
        caller: &signer,
        metadata: Object<LiquidCoinMetadata<LiquidCoin>>,
        count: u64
    ) acquires LiquidCoinMetadata {
        let caller_address = signer::address_of(caller);
        let redeem_amount = one_token<LiquidCoin>() * count;

        assert!(coin::balance<LiquidCoin>(caller_address) >= redeem_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        let object_address = object_address(&metadata);
        let liquid_token = borrow_global_mut<LiquidCoinMetadata<LiquidCoin>>(object_address);
        let num_tokens = smart_vector::length(&liquid_token.token_pool);

        // Transfer random token to caller
        let random_nft_index = pseudorandom_u64(num_tokens);
        let token = smart_vector::swap_remove(&mut liquid_token.token_pool, random_nft_index);
        let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);
        object::transfer(&object_signer, token, caller_address);
    }

    /// Allows for liquifying a token from the collection
    ///
    /// Note: once a token is put into the
    ///
    entry fun liquify<LiquidCoin>(
        caller: &signer,
        metadata: Object<LiquidCoinMetadata<LiquidCoin>>,
        tokens: vector<Object<TokenObject>>
    ) acquires LiquidCoinMetadata {
        let caller_address = signer::address_of(caller);
        let liquidify_amount = one_token<LiquidCoin>() * vector::length(&tokens);
        let object_address = object_address(&metadata);
        let liquid_token = borrow_global_mut<LiquidCoinMetadata<LiquidCoin>>(object_address);

        // Check ownership on all tokens and that they're in the collection
        vector::for_each_ref(&tokens, |token| {
            assert!(is_owner(*token, caller_address), E_NOT_OWNER_OF_TOKEN);
            assert!(token::collection_object(*token) == liquid_token.collection, E_NOT_IN_COLLECTION);
        });

        // Ensure there's enough liquid tokens to send out
        assert!(coin::balance<LiquidCoin>(object_address) >= liquidify_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        // Take tokens add them to the pool
        vector::for_each(tokens, |token| {
            object::transfer(caller, token, object_address);
            smart_vector::push_back(&mut liquid_token.token_pool, token);
        });

        // Return to caller liquidity coins
        let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);
        aptos_account::transfer_coins<LiquidCoin>(&object_signer, caller_address, liquidify_amount);
    }

    inline fun one_token<LiquidCoin>(): u64 {
        (coin::decimals<LiquidCoin>() as u64)
    }

    inline fun pseudorandom_u64(size: u64): u64 {
        let auid = transaction_context::generate_auid_address();
        let bytes = bcs::to_bytes(&auid);
        let val = from_bcs::to_u256(bytes) % (size as u256);
        (val as u64)
    }
}
