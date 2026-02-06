/// An example controlled mint, to mint NFTs to multiple users
///
/// The important thing here is it allows for extensibility later when URIs and other information wants to be changed
///
/// To use:
/// 1. Publish the contract `aptos move publish --named-addresses deploy_addr=<my_awesome_address>`
/// 1. Call create_collection to create the associated collection
/// 2. Lookup the collection's address and save it
/// 3. Call mint with the appropriate details using the collection's address
module deploy_addr::controlled_mint {

    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::royalty::{Self, Royalty};
    use aptos_token_objects::token;

    /// Only the creator can change the URI of AptosToken
    const E_NOT_CREATOR: u64 = 1;
    /// Only the owner of the token can modify it
    const E_NOT_OWNER: u64 = 2;
    /// Royalty config for NFTs is wrong
    const E_INVALID_ROYALTY_CONFIG: u64 = 4;
    /// Mismatch between num descriptions and num uris
    const E_MISMATCH_DESCRIPTION_URI_LENGTH: u64 = 5;
    /// Mismatch between num descriptions and num destinations
    const E_MISMATCH_DESCRIPTION_ADDRESS_LENGTH: u64 = 6;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct that contains the owner of the collection for others to mint
    struct CollectionOwner has key {
        extend_ref: object::ExtendRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a collection
    struct CollectionRefs has key {
        extend_ref: object::ExtendRef,
        mutator_ref: collection::MutatorRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a token
    struct TokenRefs has key {
        extend_ref: object::ExtendRef,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
    }

    /// Creates a collection
    entry fun create_collection(
        caller: &signer,
        collection_name: String,
        description: String,
        uri: String,
        royalty_numerator: Option<u64>,
        royalty_denominator: Option<u64>,
        royalty_address: Option<address>,
    ) {
        let owner_signer = create_collection_owner(caller, collection_name);

        // Convert the royalty
        let royalty = parse_royalty(royalty_numerator, royalty_denominator, royalty_address);

        create_custom_collection(&owner_signer, collection_name, description, uri, royalty);
    }

    /// Parses royalty from input options
    inline fun parse_royalty(
        royalty_numerator: Option<u64>,
        royalty_denominator: Option<u64>,
        royalty_address: Option<address>,
    ): Option<Royalty> {
        if (royalty_address.is_none() && royalty_denominator.is_none() && royalty_address.is_none()) {
            option::none()
        } else if (royalty_address.is_some() && royalty_denominator.is_some() && royalty_address.is_some()) {
            option::some(royalty::create(
                royalty_numerator.destroy_some(),
                royalty_denominator.destroy_some(),
                royalty_address.destroy_some()
            ))
        } else {
            abort E_INVALID_ROYALTY_CONFIG
        }
    }

    /// Creates an object to own the collection, stores the extend ref for later
    ///
    /// This is purposely not deletable, as we want the collection owner to always exist.
    inline fun create_collection_owner(caller: &signer, collection_name: String): signer {
        // Create a named object so that it can be derived in the mint function
        let constructor_ref = object::create_named_object(caller, *collection_name.bytes());
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let owner_signer = object::generate_signer(&constructor_ref);

        move_to(&owner_signer, CollectionOwner {
            extend_ref
        });
        owner_signer
    }

    /// Let's create a custom collection, this collection has no royalty, and is similar to
    inline fun create_custom_collection(
        caller: &signer,
        collection_name: String,
        description: String,
        uri: String,
        royalty: Option<Royalty>,
    ) {
        // Create the collection
        let constructor_ref = collection::create_unlimited_collection(
            caller,
            description,
            collection_name,
            royalty,
            uri
        );

        // Store the references for being able to modify the collection later
        // Also enable the mint by default
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, CollectionRefs { extend_ref, mutator_ref });
    }

    /// Mints many NFTs to users, this is entirely controlled by the creator
    ///
    /// Note: This will only with collections created with this contract
    entry fun mint(
        caller: &signer,
        collection_object: Object<Collection>,
        token_name_prefix: String,
        descriptions: vector<String>,
        uris: vector<String>,
        destinations: vector<address>,
    ) acquires CollectionOwner {
        // Validate input, the lengths must be the same
        let num_items = descriptions.length();
        assert!(num_items == uris.length(), E_MISMATCH_DESCRIPTION_URI_LENGTH);
        assert!(num_items == destinations.length(), E_MISMATCH_DESCRIPTION_ADDRESS_LENGTH);

        // Ensure only the owner of the collection can mint
        let caller_address = signer::address_of(caller);
        let collection_owner_address = object::owner(collection_object);
        let collection_owner_object = object::address_to_object<CollectionOwner>(collection_owner_address);
        assert!(object::owns(collection_owner_object, caller_address), E_NOT_CREATOR);

        let owner_extend_ref = &CollectionOwner[collection_owner_address].extend_ref;
        let owner_signer = object::generate_signer_for_extending(owner_extend_ref);

        let collection_name = collection::name(collection_object);

        // Go through each, and mint accordingly
        for (i in 0..num_items) {
            let last = num_items - i - 1;
            // TODO: wonder if swap remove or borrow and copy are more gas efficient
            let description = descriptions.swap_remove(last);
            let uri = uris.swap_remove(last);
            let destination = destinations.swap_remove(last);
            mint_token(
                &owner_signer,
                collection_name,
                token_name_prefix,
                description,
                uri,
                destination
            )
        }
    }

    /// Mint a single token
    inline fun mint_token(
        owner_signer: &signer,
        collection_name: String,
        token_name_prefix: String,
        description: String,
        uri: String,
        destination: address
    ) {
        // Create the token, specifically making it in a completely parallelizable way while still having it numbered
        // Note that it won't be parallized, because there's only one minter in this case
        // It will create an NFT like #1, #2, ..., #10, etc.
        let constructor_ref = token::create_numbered_token(
            owner_signer,
            collection_name,
            description, // Description
            token_name_prefix, // Prefix
            string::utf8(b""), // No suffix
            option::none(), // No royalty, we handle that at the collection level
            uri,
        );

        // Save references to allow for modifying the NFT after minting
        // These are optional, if you don't want to modify it, you can just get rid of it
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, TokenRefs { extend_ref, burn_ref, mutator_ref });

        // Transfer NFT to the caller
        let object = object::object_from_constructor_ref<TokenRefs>(&constructor_ref);
        object::transfer(owner_signer, object, destination);
    }

    // ---- Tests ----

    #[test(caller = @deploy_addr)]
    /// Tests that a collection can be created successfully without royalties
    fun test_create_collection_no_royalty(caller: &signer) {
        use std::option;

        create_collection(
            caller,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection"),
            string::utf8(b"https://example.com/collection"),
            option::none(),
            option::none(),
            option::none(),
        );
    }

    #[test(caller = @deploy_addr)]
    /// Tests creating a collection with royalty configuration
    fun test_create_collection_with_royalty(caller: &signer) {
        use std::option;

        create_collection(
            caller,
            string::utf8(b"Royalty Collection"),
            string::utf8(b"A collection with royalties"),
            string::utf8(b"https://example.com/royalty"),
            option::some(5),
            option::some(100),
            option::some(@deploy_addr),
        );
    }

    #[test(caller = @deploy_addr)]
    #[expected_failure(abort_code = E_INVALID_ROYALTY_CONFIG)]
    /// Tests that partial royalty config causes an error (address provided but numerator/denominator missing)
    fun test_create_collection_invalid_royalty(caller: &signer) {
        use std::option;

        create_collection(
            caller,
            string::utf8(b"Bad Collection"),
            string::utf8(b"Should fail"),
            string::utf8(b"https://example.com/bad"),
            option::none(),          // Missing numerator
            option::none(),          // Missing denominator
            option::some(@0xCAFE),   // Address provided
        );
    }

    #[test(caller = @deploy_addr)]
    /// Tests minting NFTs to destinations
    fun test_mint_to_destinations(caller: &signer) acquires CollectionOwner {
        use std::option;

        create_collection(
            caller,
            string::utf8(b"Mint Collection"),
            string::utf8(b"A mintable collection"),
            string::utf8(b"https://example.com/mint"),
            option::none(),
            option::none(),
            option::none(),
        );

        let collection_owner_address = object::create_object_address(&@deploy_addr, b"Mint Collection");
        let collection_address = collection::create_collection_address(&collection_owner_address, &string::utf8(b"Mint Collection"));
        let collection_object = object::address_to_object<Collection>(collection_address);

        mint(
            caller,
            collection_object,
            string::utf8(b"NFT #"),
            vector[string::utf8(b"First NFT"), string::utf8(b"Second NFT")],
            vector[string::utf8(b"https://example.com/1"), string::utf8(b"https://example.com/2")],
            vector[@0xCAFE, @0xBEEF],
        );
    }

    #[test(caller = @deploy_addr)]
    #[expected_failure(abort_code = E_MISMATCH_DESCRIPTION_URI_LENGTH)]
    /// Tests that mismatched description/uri lengths cause an error
    fun test_mint_mismatched_lengths(caller: &signer) acquires CollectionOwner {
        use std::option;

        create_collection(
            caller,
            string::utf8(b"Mismatch Collection"),
            string::utf8(b"Test"),
            string::utf8(b"https://example.com"),
            option::none(),
            option::none(),
            option::none(),
        );

        let collection_owner_address = object::create_object_address(&@deploy_addr, b"Mismatch Collection");
        let collection_address = collection::create_collection_address(&collection_owner_address, &string::utf8(b"Mismatch Collection"));
        let collection_object = object::address_to_object<Collection>(collection_address);

        mint(
            caller,
            collection_object,
            string::utf8(b"NFT #"),
            vector[string::utf8(b"One"), string::utf8(b"Two")],
            vector[string::utf8(b"https://example.com/1")], // Only 1 URI for 2 descriptions
            vector[@0xCAFE, @0xBEEF],
        );
    }
}
