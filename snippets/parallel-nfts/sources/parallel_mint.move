/// An Eth style contract account NFT collection
///
/// This allows for parallel mints, but with Numbered NFTs
module deploy_addr::parallel_mint {

    use std::option;
    use std::signer;
    use std::string;
    use std::string::String;
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::token::MutatorRef;

    /// Only the creator can change the URI of AptosToken
    const E_NOT_CREATOR: u64 = 1;
    /// Onlyl the owner of the token can modify it
    const E_NOT_OWNER: u64 = 2;

    /// Collection name
    const COLLECTION_NAME: vector<u8> = b"MakeYourOwnNFT";
    const DEFAULT_IMAGE: vector<u8> = b"ipfs://QmRrSYjA8GLsPAxeFuFwMbYXSi86Qxo4UcfG3WAY6WxQ6D";

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
        mint_enabled: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A struct holding items to control properties of a token
    struct TokenRefs has key {
        extend_ref: object::ExtendRef,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
    }

    fun init_module(caller: &signer) {
        create_custom_collection(caller);
    }

    fun create_collection_owner(caller: &signer) {
        let constructor_ref = object::create_named_object(caller, COLLECTION_NAME);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let owner_signer = object::generate_signer(&constructor_ref);

        move_to(&owner_signer, CollectionOwner {
            extend_ref
        });
    }

    /// Let's create a custom collection, this collection has no royalty, and is similar to
    fun create_custom_collection(caller: &signer) {
        // Create the collection
        let constructor_ref = collection::create_unlimited_collection(
            caller,
            string::utf8(b"A collection where anyone can modify their own NFT"),
            string::utf8(COLLECTION_NAME),
            option::none(), // No royalty
            string::utf8(DEFAULT_IMAGE),
        );

        // Store the mutator ref for modifying collection properties later
        // Extend ref to extend the collection at a later time
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, CollectionRefs { mint_enabled: true, extend_ref, mutator_ref });
    }

    entry fun enable_mint(caller: &signer) acquires CollectionRefs {
        let collection = collection_object();
        assert_creator(caller);

        // Set the URI on the token
        let token_address = object::object_address(&collection);
        borrow_global_mut<CollectionRefs>(token_address).mint_enabled = true;
    }

    entry fun disable_mint(caller: &signer) acquires CollectionRefs {
        let collection = collection_object();
        assert_creator(caller);

        // Set the URI on the token
        let token_address = object::object_address(&collection);
        borrow_global_mut<CollectionRefs>(token_address).mint_enabled = false;
    }

    /// Let's create a custom token that looks similar to AptosToken
    entry fun mint(caller: &signer) acquires CollectionOwner {
        let caller_address = signer::address_of(caller);
        let collection_owner_address = collection_owner();
        let owner_extend_ref = &borrow_global<CollectionOwner>(collection_owner_address).extend_ref;
        let owner_signer = object::generate_signer_for_extending(owner_extend_ref);

        // Create the token, specifically making it in a completely parallelizable way
        let constructor_ref = token::create_numbered_token(
            &owner_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(b"Choose your own adventure NFT"), // Description
            string::utf8(b"#"), // Prefix
            string::utf8(b""),
            option::none(), // No royalty
            string::utf8(DEFAULT_IMAGE),
        );

        // Create a mutator ref to change properties later
        // and create a burn ref to burn tokens later
        // Extend ref to extend the token at a later time
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, TokenRefs { extend_ref, burn_ref, mutator_ref });

        // Transfer NFT to the caller
        let object = object::object_from_constructor_ref<TokenRefs>(&constructor_ref);
        object::transfer(&owner_signer, object, caller_address);
    }

    /// Let's let the owner of the NFT or the creator change the URI
    ///
    /// Owner can change it to anything
    entry fun change_token_description(
        caller: &signer,
        token: Object<TokenRefs>,
        new_uri: String
    ) acquires TokenRefs {
        let mutator_ref = get_owner_mutator(caller, token);
        token::set_uri(mutator_ref, new_uri);
    }

    /// Let's let the owner of the NFT or the creator change the URI
    ///
    /// Owner can change it to anything
    entry fun change_token_uri(
        caller: &signer,
        token: Object<TokenRefs>,
        new_uri: String
    ) acquires TokenRefs {
        let mutator_ref = get_owner_mutator(caller, token);
        token::set_uri(mutator_ref, new_uri);
    }

    /// Resets the description back to the original description
    ///
    /// creator can do this
    entry fun reset_description(
        caller: &signer,
        token: Object<TokenRefs>,
    ) acquires TokenRefs {
        let mutator_ref = get_creator_mutator(caller, token);
        token::set_description(mutator_ref, string::utf8(b""));
    }

    /// Resets the URI back to the original image
    ///
    /// creator can do this
    entry fun reset_uri(
        caller: &signer,
        token: Object<TokenRefs>,
    ) acquires TokenRefs {
        let mutator_ref = get_creator_mutator(caller, token);
        token::set_uri(mutator_ref, string::utf8(DEFAULT_IMAGE));
    }

    inline fun get_owner_mutator(caller: &signer, token: Object<TokenRefs>): &MutatorRef {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(token, caller_address), E_NOT_OWNER);
        let token_address = object::object_address(&token);
        &borrow_global<TokenRefs>(token_address).mutator_ref
    }

    inline fun get_creator_mutator(caller: &signer, token: Object<TokenRefs>): &MutatorRef {
        assert_creator(caller);
        let token_address = object::object_address(&token);
        &borrow_global<TokenRefs>(token_address).mutator_ref
    }

    inline fun assert_creator(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @deploy_addr, E_NOT_CREATOR);
    }

    #[view]
    public(friend) fun collection_owner(): address {
        object::create_object_address(&@deploy_addr, COLLECTION_NAME)
    }

    #[view]
    public(friend) fun collection_object(): Object<CollectionRefs> {
        object::address_to_object(
            collection::create_collection_address(&collection_owner(), &string::utf8(COLLECTION_NAME))
        )
    }
}
