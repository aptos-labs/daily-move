/// Liquid fungible asset allows for a fungible asset liquidity on a set of TokenObjects (Token V2)
///
/// Note that tokens are mixed together in as if they were all the same value, and are
/// randomly chosen when withdrawing.  This might have consequences where too many
/// deposits & withdrawals happen in a short period of time, which can be counteracted with
/// a timestamp cooldown either for an individual account, or for the whole pool.
///
/// How does this work?
/// - User calls `liquify()` to get a set of liquid tokens associated with the NFT
/// - They can now trade the fungible asset directly
/// - User can call `claim` which will withdraw a random NFT from the pool in exchange for tokens
module fraction_addr::liquid_fungible_asset {

    use std::signer;
    use std::string::String;
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_framework::object::{Self, Object, ExtendRef, object_address, is_owner};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::token::{Self, Token as TokenObject};
    use fraction_addr::common::{one_nft_in_fungible_assets, pseudorandom_u64, create_sticky_object,
        create_fungible_asset, one_token_from_decimals
    };

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

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Metadata for a liquidity token for a collection
    struct LiquidTokenMetadata has key {
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
    entry fun create_liquid_token(
        caller: &signer,
        collection: Object<Collection>,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
        project_uri: String,
    ) {
        create_liquid_token_internal(caller, collection, asset_name, asset_symbol, decimals, project_uri);
    }

    /// Internal version of the above function for testing
    fun create_liquid_token_internal(
        caller: &signer,
        collection: Object<Collection>,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
        project_uri: String,
    ): Object<LiquidTokenMetadata> {
        // Assert ownership before fractionalizing, this is to ensure there are not duplicates of it
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(collection, caller_address), E_NOT_OWNER_OF_COLLECTION);

        // Ensure collection is fixed, and determine the number of tokens to mint
        let maybe_collection_supply = collection::count(collection);
        assert!(maybe_collection_supply.is_some(), E_NOT_FIXED_SUPPLY);
        let collection_supply = maybe_collection_supply.destroy_some();
        let asset_supply = collection_supply * one_token_from_decimals(decimals);

        // Build the object to hold the liquid token
        // This must be a sticky object (a non-deleteable object) to be fungible
        let (constructor, extend_ref, object_signer, object_address) = create_sticky_object(caller_address);
        let collection_uri = collection::uri(collection);
        create_fungible_asset(
            object_address,
            &constructor,
            asset_supply,
            asset_name,
            asset_symbol,
            decimals,
            collection_uri,
            project_uri
        );

        move_to(&object_signer, LiquidTokenMetadata {
            collection, extend_ref, token_pool: smart_vector::new()
        });

        object::address_to_object(object_address)
    }

    /// Allows for claiming a token from the collection
    ///
    /// The token claim is random from all the tokens stored in the contract
    entry fun claim(caller: &signer, metadata: Object<LiquidTokenMetadata>, count: u64) acquires LiquidTokenMetadata {
        let caller_address = signer::address_of(caller);
        let redeem_amount = one_nft_in_fungible_assets(metadata) * count;

        assert!(primary_fungible_store::balance(caller_address, metadata) >= redeem_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        let object_address = object_address(&metadata);
        let liquid_token = &mut LiquidTokenMetadata[object_address];

        // Take liquid tokens back to the object
        primary_fungible_store::transfer(caller, metadata, object_address, redeem_amount);

        // Transfer random token to caller
        // Transfer tokens
        let num_tokens = liquid_token.token_pool.length();
        for (i in 0..count) {
            let random_nft_index = pseudorandom_u64(num_tokens);
            let token = liquid_token.token_pool.swap_remove(random_nft_index);
            let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);
            object::transfer(&object_signer, token, caller_address);
            num_tokens -= 1;
        }
    }

    /// Deposits NFTs into the liquidity pool in exchange for liquid fungible asset tokens.
    ///
    /// The caller transfers their NFTs to the pool and receives fungible tokens equal to
    /// `one_nft_in_fungible_assets * number_of_tokens`. Once deposited, the specific NFTs
    /// cannot be chosen when claiming -- a random one is returned instead.
    entry fun liquify(
        caller: &signer,
        metadata: Object<LiquidTokenMetadata>,
        tokens: vector<Object<TokenObject>>
    ) acquires LiquidTokenMetadata {
        let caller_address = signer::address_of(caller);
        let liquidify_amount = one_nft_in_fungible_assets(metadata) * tokens.length();
        let object_address = object_address(&metadata);
        let liquid_token = &mut LiquidTokenMetadata[object_address];

        // Check ownership on all tokens and that they're in the collection
        tokens.for_each_ref(|token| {
            assert!(is_owner(*token, caller_address), E_NOT_OWNER_OF_TOKEN);
            assert!(token::collection_object(*token) == liquid_token.collection, E_NOT_IN_COLLECTION);
        });

        // Ensure there's enough liquid tokens to send out
        assert!(primary_fungible_store::balance(object_address, metadata) >= liquidify_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        // Take tokens add them to the pool
        tokens.for_each(|token| {
            object::transfer(caller, token, object_address);
            liquid_token.token_pool.push_back(token);
        });

        // Return to caller liquidity tokens
        let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);
        primary_fungible_store::transfer(&object_signer, metadata, caller_address, liquidify_amount);
    }

    #[test_only]
    use std::string;
    #[test_only]
    use fraction_addr::common::{setup_test, create_token_objects_collection, create_token_objects};

    #[test_only]
    struct TestToken {}

    #[test_only]
    const COLLECTION_NAME: vector<u8> = b"MyCollection";
    #[test_only]
    const ASSET_NAME: vector<u8> = b"LiquidToken";
    #[test_only]
    const ASSET_SYMBOL: vector<u8> = b"L-NFT";
    #[test_only]
    const TOKEN_NAME: vector<u8> = b"Token";

    #[test(creator = @fraction_addr, collector = @0xbeef)]
    fun test_nft_e2e(creator: &signer, collector: &signer) acquires LiquidTokenMetadata {
        let (_, collector_address) = setup_test(creator, collector);

        // Setup collection
        let collection = create_token_objects_collection(creator);
        let tokens = create_token_objects(creator, collector);

        // Create liquid token
        let metadata_object = create_liquid_token_internal(
            creator,
            collection,
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
            string::utf8(b""),
        );
        let object_address = object::object_address(&metadata_object);

        // Liquify some tokens
        assert!(0 == primary_fungible_store::balance(collector_address, metadata_object), 1);

        liquify(collector, metadata_object, vector[tokens[0], tokens[2]]);

        assert!(
            primary_fungible_store::balance(collector_address, metadata_object) == 2 * one_nft_in_fungible_assets(
                metadata_object
            ),
            2
        );

        let metadata = &LiquidTokenMetadata[object_address];
        assert!(2 == metadata.token_pool.length(), 3);

        // Claim the NFTs back
        claim(collector, metadata_object, 2);

        assert!(primary_fungible_store::balance(collector_address, metadata_object) == 0, 4);
        let metadata = &LiquidTokenMetadata[object_address];
        assert!(0 == metadata.token_pool.length(), 5);
    }


    #[test(creator = @fraction_addr, collector = @0xbeef)]
    #[expected_failure(abort_code = E_NOT_OWNER_OF_COLLECTION, location = Self)]
    fun test_not_owner_of_collection(creator: &signer, collector: &signer) {
        let (_, _) = setup_test(creator, collector);

        // Setup collection, moving all to a collector
        let collection = create_token_objects_collection(creator);
        create_token_objects(creator, collector);
        create_liquid_token_internal(
            collector,
            collection,
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
            string::utf8(b"")
        );
    }

    #[test(creator = @fraction_addr, collector = @0xbeef)]
    #[expected_failure(abort_code = E_NOT_OWNER_OF_TOKEN, location = Self)]
    fun test_not_owner_of_token(creator: &signer, collector: &signer) acquires LiquidTokenMetadata {
        let (_, _) = setup_test(creator, collector);

        // Setup collection, moving all to a collector
        let collection = create_token_objects_collection(creator);
        let tokens = create_token_objects(creator, collector);
        let metadata_object = create_liquid_token_internal(
            creator,
            collection,
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
            string::utf8(b"")
        );
        liquify(creator, metadata_object, tokens);
    }
}
