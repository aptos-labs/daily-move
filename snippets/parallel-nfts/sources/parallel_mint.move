/// An Eth style contract account NFT collection
///
/// The contract allows for an object to own the collection, where this allows others to mint the collection.
///
/// The collection is:
/// 1. Parallelized
/// 2. Unlmiited supply
/// 3. Can be minted by anyone
///
/// The tokens allow for:
/// 1. Changing the URI by the owner of the NFT
/// 2. Changing the description by the owner of the NFT
/// 3. The creator can reset the description
/// 4. The creator can also reset the image
///
/// TODO: Future
/// 1. Allow burning by user and creator
/// 2. Add some extensions for more fun
module deploy_addr::parallel_mint {

    use std::option;
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token::{Self, MutatorRef};

    /// Only the creator can change the URI of AptosToken
    const E_NOT_CREATOR: u64 = 1;
    /// Only the owner of the token can modify it
    const E_NOT_OWNER: u64 = 2;
    /// Mint is current disabled
    const E_MINT_DISABLED: u64 = 3;

    /// Collection name
    const COLLECTION_NAME: vector<u8> = b"MakeYourOwnNFT";

    /// A default image for the collection using the IPFS URI
    const DEFAULT_IMAGE_URI: vector<u8> = b"ipfs://QmRrSYjA8GLsPAxeFuFwMbYXSi86Qxo4UcfG3WAY6WxQ6D";

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
        /// Allows for disabling the unlimited mint
        mint_enabled: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a token
    struct TokenRefs has key {
        extend_ref: object::ExtendRef,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
    }

    /// This will create the collection on publish of the contract
    ///
    /// In order to allow others to mint directly, you must either use an object or a resource account as the owner
    /// of the collection.  In this case, I use an object
    fun init_module(caller: &signer) {
        // This allows other users to mint
        let owner_signer = create_collection_owner(caller);
        create_custom_collection(&owner_signer);
    }

    /// Creates an object to own the collection, stores the extend ref for later
    ///
    /// This is purposely not deletable, as we want the collection owner to always exist.
    inline fun create_collection_owner(caller: &signer): signer {
        // Create a named object so that it can be derived in the mint function
        let constructor_ref = object::create_named_object(caller, COLLECTION_NAME);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let owner_signer = object::generate_signer(&constructor_ref);

        move_to(&owner_signer, CollectionOwner {
            extend_ref
        });
        owner_signer
    }

    /// Let's create a custom collection, this collection has no royalty, and is similar to
    inline fun create_custom_collection(caller: &signer) {
        // Create the collection
        let constructor_ref = collection::create_unlimited_collection(
            caller,
            string::utf8(b"A collection where anyone can modify their own NFT"),
            string::utf8(COLLECTION_NAME),
            option::none(), // No royalty
            string::utf8(DEFAULT_IMAGE_URI),
        );

        // Store the references for being able to modify the collection later
        // Also enable the mint by default
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, CollectionRefs { mint_enabled: true, extend_ref, mutator_ref });
    }

    /// Enables allowing others to mint
    public entry fun enable_mint(caller: &signer) acquires CollectionRefs {
        assert_creator(caller);

        let collection_address = collection_object();
        CollectionRefs[collection_address].mint_enabled = true;
    }

    /// Disables allowing others to mint
    public entry fun disable_mint(caller: &signer) acquires CollectionRefs {
        assert_creator(caller);

        let collection_address = collection_object();
        CollectionRefs[collection_address].mint_enabled = false;
    }

    /// Allow others to mint the token with the default image
    ///
    /// If `mint_enabled` is fals, it will prevent users from minting
    public entry fun mint(caller: &signer) acquires CollectionOwner, CollectionRefs {
        let caller_address = signer::address_of(caller);
        let collection_owner_address = collection_owner();
        let owner_extend_ref = &CollectionOwner[collection_owner_address].extend_ref;
        let owner_signer = object::generate_signer_for_extending(owner_extend_ref);

        // Check that the mint is enabled
        let collection_address = collection_object();
        assert!(CollectionRefs[collection_address].mint_enabled, E_MINT_DISABLED);

        // Create the token, specifically making it in a completely parallelizable way while still having it numbered
        // It will create an NFT like #1, #2, ..., #10, etc.
        let constructor_ref = token::create_numbered_token(
            &owner_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(b"Choose your own adventure NFT"), // Description
            string::utf8(b"#"), // Prefix
            string::utf8(b""),
            option::none(), // No royalty
            string::utf8(DEFAULT_IMAGE_URI),
        );

        // Save references to allow for modifying the NFT after minting
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, TokenRefs { extend_ref, burn_ref, mutator_ref });

        // Transfer NFT to the caller
        let object = object::object_from_constructor_ref<TokenRefs>(&constructor_ref);
        object::transfer(&owner_signer, object, caller_address);
    }

    /// Change the NFT description, which can be done by the owner of the NFT
    public entry fun change_token_description(
        caller: &signer,
        token: Object<TokenRefs>,
        new_description: String
    ) acquires TokenRefs {
        let mutator_ref = get_owner_mutator(caller, token);
        token::set_description(mutator_ref, new_description);
    }

    /// Change the NFT image, which can be done by the owner of the NFT
    public entry fun change_token_uri(
        caller: &signer,
        token: Object<TokenRefs>,
        new_uri: String
    ) acquires TokenRefs {
        let mutator_ref = get_owner_mutator(caller, token);
        token::set_uri(mutator_ref, new_uri);
    }

    /// Resets the description back to the original description by the creator
    public entry fun reset_token_description(
        caller: &signer,
        token: Object<TokenRefs>,
    ) acquires TokenRefs {
        let mutator_ref = get_creator_mutator(caller, token);
        token::set_description(mutator_ref, string::utf8(b""));
    }

    /// Resets the URI back to the original image by the creator
    public entry fun reset_token_uri(
        caller: &signer,
        token: Object<TokenRefs>,
    ) acquires TokenRefs {
        let mutator_ref = get_creator_mutator(caller, token);
        token::set_uri(mutator_ref, string::utf8(DEFAULT_IMAGE_URI));
    }

    /// Asserts that the owner is the caller of the function and returns a mutator ref
    inline fun get_owner_mutator(caller: &signer, token: Object<TokenRefs>): &MutatorRef {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(token, caller_address), E_NOT_OWNER);
        let token_address = object::object_address(&token);
        &TokenRefs[token_address].mutator_ref
    }

    /// Asserts that the creator is the caller of the function and returns a mutator ref
    inline fun get_creator_mutator(caller: &signer, token: Object<TokenRefs>): &MutatorRef {
        assert_creator(caller);
        let token_address = object::object_address(&token);
        &TokenRefs[token_address].mutator_ref
    }

    /// Asserts that the creator is the caller of the function
    inline fun assert_creator(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @deploy_addr, E_NOT_CREATOR);
    }

    #[view]
    /// Returns the address of the owner object of the collection
    public fun collection_owner(): address {
        object::create_object_address(&@deploy_addr, COLLECTION_NAME)
    }

    #[view]
    /// Returns the address of the collection object
    public fun collection_object(): address {
        collection::create_collection_address(&collection_owner(), &string::utf8(COLLECTION_NAME))
    }
}
