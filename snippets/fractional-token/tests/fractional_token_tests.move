#[test_only]
module fraction_addr::fractional_token_tests {
    use std::signer::address_of;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object;

    use fraction_addr::common_tests::{create_collection, create_tokens, setup_test};
    use fraction_addr::fractional_token::{fractionalize_asset_test_only, metadata_object_address,
        recombine_asset_test_only
    };

    #[test(creator = @fraction_addr, collector = @0xbeef)]
    fun test_fractionalize_nft_e2e(creator: &signer, collector: &signer) {
        let creator_addr = address_of(creator);
        setup_test(creator, collector);

        // Setup collection
        create_collection(creator);
        let tokens = create_tokens(creator);
        let token = tokens[0];

        // Fractionalize token into 10 fungible tokens
        fractionalize_asset_test_only(creator, token, 10);

        let object_metadata_address = metadata_object_address(creator_addr);
        assert!(object::owner(token) == object_metadata_address, 0);

        let metadata = object::address_to_object<Metadata>(object_metadata_address);
        // Recombine token
        recombine_asset_test_only(creator, metadata);

        assert!(object::owner(token) == creator_addr, 0);
    }

    #[test(creator = @fraction_addr, collector = @0xbeef)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::object)]
    fun exception_when_user_tries_to_transfer_token_after_fractionalizing(creator: &signer, collector: &signer) {
        let creator_addr = address_of(creator);
        setup_test(creator, collector);

        // Setup collection
        create_collection(creator);
        let tokens = create_tokens(creator);
        let token = tokens[0];

        // Fractionalize token into 10 fungible tokens
        fractionalize_asset_test_only(creator, token, 10);

        // Try to transfer the token back to the user, this will fail as they have not recombined the token
        object::transfer(creator, token, creator_addr);
    }
}
