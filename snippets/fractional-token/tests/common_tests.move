#[test_only]
module fraction_addr::common_tests {

    use std::option;
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_std::string_utils;
    use aptos_framework::account::create_account_for_test;
    use aptos_framework::genesis;
    use aptos_framework::object;
    use aptos_framework::object::Object;

    use aptos_token_objects::collection;
    use aptos_token_objects::collection::Collection;
    use aptos_token_objects::token;
    use aptos_token_objects::token::Token;

    use minter::collection_components;
    use minter::token_components;

    #[test_only]
    const COLLECTION_NAME: vector<u8> = b"MyCollection";
    #[test_only]
    const ASSET_NAME: vector<u8> = b"LiquidToken";
    #[test_only]
    const ASSET_SYMBOL: vector<u8> = b"L-NFT";
    #[test_only]
    const TOKEN_NAME: vector<u8> = b"Token";
    #[test_only]
    const TOKEN_DESCRIPTION: vector<u8> = b"Token description";

    #[test_only]
    public fun setup_test(creator: &signer, collector: &signer): (address, address) {
        genesis::setup();
        let creator_address = signer::address_of(creator);
        let collector_address = signer::address_of(collector);
        create_account_for_test(creator_address);
        create_account_for_test(collector_address);
        (creator_address, collector_address)
    }

    #[test_only]
    public fun create_collection(creator: &signer): Object<Collection> {
        create_token_collection_with_name(creator, string::utf8(COLLECTION_NAME))
    }

    #[test_only]
    public fun create_token_collection_with_name(creator: &signer, name: String): Object<Collection> {
        let constructor_ref = &collection::create_unlimited_collection(
            creator,
            string::utf8(b"Collection description"),
            name,
            option::none(),
            string::utf8(b"https://collectionUri"),
        );
        collection_components::create_refs_and_properties(constructor_ref);

        object::object_from_constructor_ref(constructor_ref)
    }

    #[test_only]
    public fun create_tokens(creator: &signer): vector<Object<Token>> {
        let collection_name = string::utf8(COLLECTION_NAME);
        let tokens = vector[];
        for (i in 0..5) {
            let constructor_ref = &token::create(
                creator,
                collection_name,
                token_description(i),
                token_name(i),
                option::none(),
                string::utf8(b"http://tokenUri.com"),
            );
            let refs = token_components::create_refs(constructor_ref);
            tokens.push_back(object::convert(refs));
        };

        tokens
    }

    #[test_only]
    public fun token_name(i: u64): String {
        string_utils::format2(&b"{}:{}", string::utf8(TOKEN_NAME), i)
    }

    #[test_only]
    public fun token_description(i: u64): String {
        string_utils::format2(&b"{}:{}", string::utf8(TOKEN_DESCRIPTION), i)
    }
}
