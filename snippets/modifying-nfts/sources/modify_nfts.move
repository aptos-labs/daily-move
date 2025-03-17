/// Modifying NFTs
///
/// This is an example of how to modify properties of an NFT and a collection
module deploy_addr::modify_nfts {

    use std::option;
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_token_objects::aptos_token;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    /// Only the creator can change the URI of AptosToken
    const E_NOT_CREATOR: u64 = 1;
    /// Only the creator or owner can change the URI of the Token
    const E_NOT_CREATOR_OR_OWNER: u64 = 2;
    /// Collection points already initialized
    const E_COLLECTION_ALREADY_EXTENDED: u64 = 3;
    /// Collection points haven't been initialized yet
    const E_COLLECTION_NOT_EXTENDED: u64 = 4;
    /// Collection doesn't have enough points to give to token
    const E_NOT_ENOUGH_POINTS: u64 = 5;

    /// Collection max supply
    const MAX_SUPPLY: u64 = 10000;

    /// A URI we're using here for the demo, this could be anything, mp4, ipfs, svg, png, gif, jpg, etc.
    const URI: vector<u8> = b"https://aptosfoundation.org/_next/static/media/globe.f620f2d6.svg";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a collection
    struct CollectionController has key {
        extend_ref: object::ExtendRef,
        mutator_ref: collection::MutatorRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct for representing extension of a collection
    struct CollectionPoints has key {
        total_points: u64
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a token
    struct TokenController has key {
        extend_ref: object::ExtendRef,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct for representing extension of a token
    struct TokenPoints has key {
        points: u64
    }

    /// Creates a collection with most items defaulted for an easy function
    entry fun create_simple_collection(caller: &signer, collection_name: String, description: String) {
        aptos_token::create_collection(
            caller,
            description,
            MAX_SUPPLY,
            collection_name,
            string::utf8(URI),
            true, // collection description mutable
            true, // collection royalty mutable
            true, // collection URI mutable
            true, // token description mutable
            true, // token name mutable
            true, // token properties mutable
            true, // Token URI mutable
            true, // tokens burnable
            true, // tokens freezable
            0, // Royalty numerator
            100, // Royalty denominator
        );
    }

    entry fun mint_simple_token(creator: &signer, collection: String, token_name: String) {
        aptos_token::mint(
            creator,
            collection,
            string::utf8(b""), // description
            token_name,
            string::utf8(URI),
            vector[], // property keys
            vector[], // property types
            vector[], // property values
        )
    }

    /// Let's create a custom collection, this collection has no royalty, and is similar to
    entry fun create_custom_collection(caller: &signer, collection_name: String, description: String) {
        // Create the collection
        let constructor_ref = collection::create_fixed_collection(
            caller,
            description,
            MAX_SUPPLY,
            collection_name,
            option::none(), // No royalty
            string::utf8(URI),
        );

        // Here you can extend a collection to do anything, the amazing thing about objects!

        // Store the mutator ref for modifying collection properties later
        // Extend ref to extend the collection at a later time
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, CollectionController { extend_ref, mutator_ref });
    }

    /// Extend the collection to have points information
    entry fun add_points_to_collection(
        caller: &signer,
        collection: Object<CollectionController>,
        total_points: u64,
    ) acquires CollectionController {
        // Check if the collection has been extended already
        let collection_address = object::object_address(&collection);
        assert!(!exists<CollectionPoints>(collection_address), E_COLLECTION_ALREADY_EXTENDED);

        // Creator or owner can add points to the collection for extending
        let caller_address = signer::address_of(caller);
        let is_owner = object::is_owner(collection, caller_address);
        let is_creator = caller_address == collection::creator(collection);
        assert!(is_owner || is_creator, E_NOT_CREATOR_OR_OWNER);

        // Extend the collection object, now there's a points system
        let controller = &CollectionController[collection_address];
        let object_signer = object::generate_signer_for_extending(&controller.extend_ref);
        move_to(&object_signer, CollectionPoints {
            total_points
        })
    }

    /// Let's let the owner of the NFT or the creator change the URI
    entry fun change_custom_collection_uri(
        caller: &signer,
        collection: Object<CollectionController>,
        new_uri: String
    ) acquires CollectionController {
        // Verify the caller is either the owner of the creator of the NFT
        let caller_address = signer::address_of(caller);
        let is_owner = object::is_owner(collection, caller_address);
        let is_creator = caller_address == collection::creator(collection);
        assert!(is_owner || is_creator, E_NOT_CREATOR_OR_OWNER);

        // Set the URI on the token
        let token_address = object::object_address(&collection);
        let mutator_ref = &CollectionController[token_address].mutator_ref;
        collection::set_uri(mutator_ref, new_uri);
    }

    /// Let's create a custom token that looks similar to AptosToken
    entry fun create_custom_token(caller: &signer, collection_name: String, token_name: String) {
        // Create the token, specifically making it in a completely parallelizable way
        let constructor_ref = token::create(
            caller,
            collection_name,
            string::utf8(b""), // Description
            token_name,
            option::none(), // No royalty
            string::utf8(URI),
        );

        // Here you can extend a token to do anything, including making it fungible!

        // Create a mutator ref to change properties later
        // and create a burn ref to burn tokens later
        // Extend ref to extend the token at a later time
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, TokenController { extend_ref, burn_ref, mutator_ref });
    }

    /// Let's let the owner of the NFT or the creator change the URI
    entry fun change_custom_token_uri(
        caller: &signer,
        token: Object<TokenController>,
        new_uri: String
    ) acquires TokenController {
        // Verify the caller is either the owner of the creator of the NFT
        let caller_address = signer::address_of(caller);
        let is_owner = object::is_owner(token, caller_address);
        let is_creator = caller_address == token::creator(token);
        assert!(is_owner || is_creator, E_NOT_CREATOR_OR_OWNER);

        // Set the URI on the token
        let token_address = object::object_address(&token);
        let mutator_ref = &TokenController[token_address].mutator_ref;
        token::set_uri(mutator_ref, new_uri);
    }

    /// Burn the tokens!  Let either the owner or the creator do it
    entry fun burn_custom_token(
        caller: &signer,
        token: Object<TokenController>
    ) acquires TokenController, TokenPoints {
        // Verify the caller is either the owner of the creator of the NFT
        let caller_address = signer::address_of(caller);
        let is_owner = object::is_owner(token, caller_address);
        let is_creator = caller_address == token::creator(token);
        assert!(is_owner || is_creator, E_NOT_CREATOR_OR_OWNER);

        // If the token was extended, burn the points!
        let token_address = object::object_address(&token);
        if (exists<TokenPoints>(token_address)) {
            let TokenPoints {
                points: _
            } = move_from<TokenPoints>(token_address);
        };

        // Burn the token
        // Specifically, we want to move_from so we can clean up all resources from the object
        let TokenController {
            burn_ref,
            extend_ref: _, // destroy the extend ref
            mutator_ref: _, // destroy the mutator ref too
        } = move_from<TokenController>(token_address);
        token::burn(burn_ref)
    }

    /// Let either the creator add points to the token
    entry fun extend_token(
        caller: &signer,
        token: Object<TokenController>,
        points: u64,
    ) acquires TokenController, CollectionPoints, TokenPoints {
        // Verify the caller is either the owner of the creator of the NFT
        let caller_address = signer::address_of(caller);
        let is_creator = caller_address == token::creator(token);
        assert!(is_creator, E_NOT_CREATOR);

        // Ensure that there are points attached to the token
        let token_address = object::object_address(&token);
        if (!exists<TokenPoints>(token_address)) {
            let token_controller = &TokenController[token_address];
            let object_signer = object::generate_signer_for_extending(&token_controller.extend_ref);
            move_to(&object_signer, TokenPoints {
                points: 0
            });
        };

        // Retrieve the shared points
        let collection = token::collection_object(token);
        let collection_address = object::object_address(&collection);
        let collection_points = &mut CollectionPoints[collection_address];

        // Ensure we have enough to give to the token
        assert!(collection_points.total_points >= points, E_NOT_ENOUGH_POINTS);

        // Move the points to the token
        collection_points.total_points -= points;
        let token_points = &mut TokenPoints[token_address];
        token_points.points += points;
    }

    #[view]
    public fun collection_points(collection: Object<CollectionController>): u64 acquires CollectionPoints {
        let collection_address = object::object_address(&collection);
        if (exists<CollectionPoints>(collection_address)) {
            CollectionPoints[collection_address].total_points
        } else {
            0
        }
    }

    #[view]
    public fun token_points(token: Object<TokenController>): u64 acquires TokenPoints {
        let token_address = object::object_address(&token);
        if (exists<TokenPoints>(token_address)) {
            TokenPoints[token_address].points
        } else {
            0
        }
    }
}
