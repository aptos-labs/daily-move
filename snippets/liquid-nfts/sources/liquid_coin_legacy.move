/// Liquid coin legacy allows for a coin liquidity on a set of Legacy Tokens (Token V1)
///
/// Note that tokens are mixed together in as if they were all the same value, and are
/// randomly chosen when withdrawing.  This might have consequences where too many
/// deposits & withdrawals happen in a short period of time, which can be counteracted with
/// a timestamp cooldown either for an individual account, or for the whole pool.
///
/// How does this work?
/// - Creator creates a token by calling `create_liquid_token()`
/// - User calls `liquify()` to get a set of liquid tokens associated with the NFT
/// - They can now trade the coin directly
/// - User can call `claim` which will withdraw a random NFT from the pool in exchange for tokens
///
/// Note that withdrawals and deposits of Legacy Tokens can be expensive from a gas perspective
module fraction_addr::liquid_coin_legacy {

    use std::signer;
    use std::string::String;
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::object::{Self, Object, ExtendRef, object_address};
    use aptos_token::token::{Self, check_collection_exists, get_collection_supply};
    use fraction_addr::common::{one_nft_in_coins, pseudorandom_u64, create_sticky_object, create_coin,
        one_token_from_decimals
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
    /// Can't liquify, token not an NFT
    const E_NOT_A_NON_FUNGIBLE_TOKEN: u64 = 7;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Metadata for a liquidity token for a collection
    struct LiquidCoinMetadata<phantom LiquidCoin> has key {
        creator: address,
        /// The collection associated with the liquid token
        collection_name: String,
        /// Used for transferring objects
        extend_ref: ExtendRef,
        /// The list of all tokens locked up in the contract
        token_pool: SmartVector<String>
    }

    /// Create a liquid token for a collection.
    ///
    /// The collection is assumed to be fixed, if the collection is not fixed, then this doesn't work quite correctly
    entry fun create_liquid_token<LiquidCoin>(
        caller: &signer,
        collection_name: String,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
    ) {
        create_liquid_token_internal<LiquidCoin>(caller, collection_name, asset_name, asset_symbol, decimals);
    }

    /// An internal version of the above function so we can use it for unit testing
    fun create_liquid_token_internal<LiquidCoin>(
        caller: &signer,
        collection_name: String,
        asset_name: String,
        asset_symbol: String,
        decimals: u8,
    ): Object<LiquidCoinMetadata<LiquidCoin>> {
        // Assert ownership before fractionalizing, this is to ensure there are not duplicates of it
        let caller_address = signer::address_of(caller);
        assert!(check_collection_exists(caller_address, collection_name), E_NOT_OWNER_OF_COLLECTION);

        // Ensure collection is fixed, and determine the number of tokens to mint
        let maybe_collection_supply = get_collection_supply(caller_address, collection_name);
        assert!(maybe_collection_supply.is_some(), E_NOT_FIXED_SUPPLY);
        let collection_supply = maybe_collection_supply.destroy_some();
        let asset_supply = collection_supply * one_token_from_decimals(decimals);

        // Build the object to hold the liquid token
        // This must be a sticky object (a non-deleteable object) to be fungible
        let (_, extend_ref, object_signer, object_address) = create_sticky_object(caller_address);

        // Mint the supply of the liquid token, destroying the mint capability afterwards
        create_coin<LiquidCoin>(caller, asset_name, asset_symbol, decimals, asset_supply, object_address);

        // Add the Metadata, and return the object
        move_to(&object_signer, LiquidCoinMetadata<LiquidCoin> {
            creator: caller_address, collection_name, extend_ref, token_pool: smart_vector::new()
        });
        object::address_to_object(object_address)
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
        let redeem_amount = one_nft_in_coins<LiquidCoin>() * count;

        assert!(coin::balance<LiquidCoin>(caller_address) >= redeem_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        // Take coins
        let object_address = object_address(&metadata);
        coin::transfer<LiquidCoin>(caller, object_address, redeem_amount);

        // Transfer tokens
        let liquid_token = &mut LiquidCoinMetadata<LiquidCoin>[object_address];
        let num_tokens = liquid_token.token_pool.length();
        for (i in 0..count) {
            // Transfer random token to caller
            let random_nft_index = pseudorandom_u64(num_tokens);
            let token_name = liquid_token.token_pool.swap_remove(random_nft_index);
            let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);

            // Build up the token id
            let creator_address = liquid_token.creator;
            let collection_name = liquid_token.collection_name;
            let data_id = token::create_token_data_id(creator_address, collection_name, token_name);
            let latest_property_version = token::get_tokendata_largest_property_version(creator_address, data_id);
            let token_id = token::create_token_id(data_id, latest_property_version);

            // Direct transfer to caller, assuming only 1 for an NFT
            token::direct_transfer(&object_signer, caller, token_id, 1);
            num_tokens -= 1;
        }
    }

    /// Deposits legacy tokens (V1) into the liquidity pool in exchange for liquid coins.
    ///
    /// The caller transfers their legacy tokens to the pool and receives fungible coins equal to
    /// `one_nft_in_coins * number_of_tokens`. Once deposited, the specific tokens cannot be
    /// chosen when claiming -- a random one is returned instead.
    entry fun liquify<LiquidCoin>(
        caller: &signer,
        metadata: Object<LiquidCoinMetadata<LiquidCoin>>,
        token_names: vector<String>
    ) acquires LiquidCoinMetadata {
        let caller_address = signer::address_of(caller);
        let liquidify_amount = one_nft_in_coins<LiquidCoin>() * token_names.length();
        let object_address = object_address(&metadata);
        let liquid_token = &mut LiquidCoinMetadata<LiquidCoin>[object_address];
        let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);

        // Ensure there's enough liquid tokens to send out
        assert!(coin::balance<LiquidCoin>(object_address) >= liquidify_amount,
            E_NOT_ENOUGH_LIQUID_TOKENS
        );

        // Check ownership on all tokens and that they're in the collection
        token_names.for_each(|token_name| {
            // Check that the token exists
            let creator_address = liquid_token.creator;
            let collection_name = liquid_token.collection_name;
            let data_id = token::create_token_data_id(creator_address, collection_name, token_name);

            // Ensure this is an NFT
            assert!(token::check_tokendata_exists(creator_address, collection_name, token_name), E_NOT_IN_COLLECTION);
            let token_supply = token::get_token_supply(creator_address, data_id);
            assert!(
                token_supply.is_some() && token_supply.destroy_some() == 1,
                E_NOT_A_NON_FUNGIBLE_TOKEN
            );

            // Build token ID
            let latest_property_version = token::get_tokendata_largest_property_version(creator_address, data_id);
            let token_id = token::create_token_id(data_id, latest_property_version);

            // Direct transfer to object, assuming only 1 for an NFT
            assert!(token::balance_of(caller_address, token_id) == 1, E_NOT_OWNER_OF_TOKEN);
            token::direct_transfer(caller, &object_signer, token_id, 1);
            liquid_token.token_pool.push_back(token_name);
        });

        // Return to caller liquidity coins
        let object_signer = object::generate_signer_for_extending(&liquid_token.extend_ref);
        aptos_account::transfer_coins<LiquidCoin>(&object_signer, caller_address, liquidify_amount);
    }

    #[test_only]
    use std::string;
    #[test_only]
    use fraction_addr::common::{token_name, create_token_collection, create_tokens, setup_test};

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
    fun test_nft_e2e(creator: &signer, collector: &signer) acquires LiquidCoinMetadata {
        let (creator_address, collector_address) = setup_test(creator, collector);

        // Setup collection
        create_token_collection(creator);
        create_tokens(creator, collector);

        // Create liquid token
        let metadata_object = create_liquid_token_internal<TestToken>(
            creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
        );
        let object_address = object::object_address(&metadata_object);

        // Liquify some tokens
        assert!(!coin::is_account_registered<TestToken>(collector_address), 0);
        let collection_name = string::utf8(COLLECTION_NAME);
        assert!(token::check_tokendata_exists(creator_address, collection_name, token_name(0)), 1);

        liquify(collector, metadata_object, vector[token_name(0), token_name(2)]);

        assert!(coin::balance<TestToken>(collector_address) == 2 * one_nft_in_coins<TestToken>(), 2);

        let metadata = &LiquidCoinMetadata<TestToken>[object_address];
        assert!(2 == metadata.token_pool.length(), 3);

        // Claim the NFTs back
        claim(collector, metadata_object, 2);

        assert!(coin::balance<TestToken>(collector_address) == 0, 4);
        let metadata = &LiquidCoinMetadata<TestToken>[object_address];
        assert!(0 == metadata.token_pool.length(), 5);
    }


    #[test(creator = @fraction_addr, collector = @0xbeef)]
    #[expected_failure(abort_code = 393217, location = aptos_token::token)]
    fun test_not_owner_of_collection(creator: &signer, collector: &signer) {
        let (_, _) = setup_test(creator, collector);

        // Setup collection, moving all to a collector
        create_token_collection(creator);
        create_tokens(creator, collector);
        create_liquid_token_internal<TestToken>(
            collector,
            string::utf8(COLLECTION_NAME),
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
        );
    }

    #[test(creator = @fraction_addr, collector = @0xbeef)]
    #[expected_failure(abort_code = E_NOT_OWNER_OF_TOKEN, location = Self)]
    fun test_not_owner_of_token(creator: &signer, collector: &signer) acquires LiquidCoinMetadata {
        let (_, _) = setup_test(creator, collector);

        // Setup collection, moving all to a collector
        create_token_collection(creator);
        create_tokens(creator, collector);
        let metadata_object = create_liquid_token_internal<TestToken>(
            creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
        );
        liquify(creator, metadata_object, vector[token_name(0), token_name(2)]);
    }
}
