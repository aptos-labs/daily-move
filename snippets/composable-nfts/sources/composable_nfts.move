/// This contract shows how to create dynamic composable NFTs
///
/// The system here is that there is a Face NFT.  The face NFT can equip a
/// sailor hat NFT, and it will change the image directly.
module deploy_addr::composable_nfts {

    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::string_utils;
    use aptos_framework::object::{Self, Object, ExtendRef, ConstructorRef, TransferRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::token::{Self, MutatorRef, BurnRef};

    /// Caller is not owner of the NFT
    const E_NOT_OWNER: u64 = 1;

    /// Face doesn't have a hat on
    const E_NO_HAT_ON: u64 = 2;

    /// Face already has a hat on
    const E_HAT_ALREADY_ON: u64 = 3;

    /// Face doesn't own the hat, this is an invalid state!
    const E_HAT_NOT_OWNED_BY_FACE: u64 = 4;

    /// No transfer ref, this is an invalid state!
    const E_NO_TRANSFER_REF: u64 = 5;

    /// Unsupported hat, can't equip
    const E_UNSUPPORTED_HAT: u64 = 5;

    const OBJECT_SEED: vector<u8> = b"Some random seed that doesn't conflict today";

    const FACES: vector<u8> = b"Faces";
    const HATS: vector<u8> = b"HATS";
    const FACES_WIF_HATS: vector<u8> = b"Faces wif hats";
    const FACE: vector<u8> = b"Face";
    const FACE_WIFOUT_HAT: vector<u8> = b"Face wifout hat";
    const FACE_WIF_HAT: vector<u8> = b"Face wif";
    const FACE_WIF_BANDANA: vector<u8> = b"Face wif Bandana";
    const SAILOR_HAT: vector<u8> = b"Sailor hat";
    const BANDANA: vector<u8> = b"Bandana";

    const SAILOR_HAT_URI: vector<u8> = b"ipfs://QmTkWHotvv6JbeXiNvtrhVceH4zTLxJUhXw5DKZLK1FPk6/sailor_hat.png";
    const FACE_URI: vector<u8> = b"ipfs://QmTkWHotvv6JbeXiNvtrhVceH4zTLxJUhXw5DKZLK1FPk6/face.png";
    const FACE_WITH_SAILOR_HAT_URI: vector<u8> = b"ipfs://QmTkWHotvv6JbeXiNvtrhVceH4zTLxJUhXw5DKZLK1FPk6/face_with_hat.png";
    const FACE_WITH_BANDANA_URI: vector<u8> = b"ipfs://QmTkWHotvv6JbeXiNvtrhVceH4zTLxJUhXw5DKZLK1FPk6/face_with_bandana.png";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A resource for keeping track of the object and being able to extend it
    struct ObjectController has key {
        extend_ref: ExtendRef,
        transfer_ref: Option<TransferRef>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A resource for token to be able to modify the token descriptions and URIs
    struct TokenController has key {
        mutator_ref: MutatorRef,
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A face token, that can wear a hat and dynamically change
    struct Face has key {
        hat: Option<Object<Hat>>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A hat with a description of what the hat is
    struct Hat has key {
        type: String
    }

    /// Sets up the collections on publish of the contract
    fun init_module(creator: &signer) {
        setup(creator);
    }

    /// Sets up the collection
    ///
    /// This specifically exists for testing, so that we can set it up outside of creation of the module
    fun setup(creator: &signer): (address, address, address) {
        // Create an object that will hold the collections
        let constructor_ref = object::create_named_object(creator, OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let collection_owner_signer = object::generate_signer(&constructor_ref);
        move_to(&collection_owner_signer, ObjectController {
            extend_ref,
            transfer_ref: option::none()
        });

        // Create the face collection
        let face_collection_name = string::utf8(FACES);
        let face_collection_constructor = create_collection(
            &collection_owner_signer,
            string::utf8(FACES_WIF_HATS),
            face_collection_name,
            string::utf8(FACE_WITH_SAILOR_HAT_URI)
        );

        // Make hat collection
        let hat_collection_name = string::utf8(HATS);
        let hat_collection_constructor = create_collection(
            &collection_owner_signer,
            hat_collection_name,
            hat_collection_name,
            string::utf8(SAILOR_HAT_URI)
        );

        // Return the three addresses for testing purposes
        (
            object::address_from_constructor_ref(&constructor_ref),
            object::address_from_constructor_ref(&face_collection_constructor),
            object::address_from_constructor_ref(&hat_collection_constructor)
        )
    }

    /// Mints a new blank face
    entry fun mint_face(collector: &signer) acquires ObjectController {
        mint_face_internal(collector);
    }

    /// An internal function so the object can be used directly in testing
    fun mint_face_internal(collector: &signer): Object<Face> acquires ObjectController {
        let collection_owner_signer = get_collection_owner_signer();
        // Mint token
        let face_collection_name = string::utf8(FACES);
        let face_constructor = create_token(
            collection_owner_signer,
            face_collection_name,
            string::utf8(FACE),
            string::utf8(FACE_URI),
            string::utf8(FACE_WIFOUT_HAT)
        );

        // Add face properties
        let face_signer = object::generate_signer(&face_constructor);
        move_to(&face_signer, Face {
            hat: option::none() // Starts without a hat
        });

        // Transfer face to collector
        let face_object = object::object_from_constructor_ref<Face>(&face_constructor);
        object::transfer(collection_owner_signer, face_object, signer::address_of(collector));
        face_object
    }

    /// Mints a new sailor hat
    entry fun mint_sailor_hat(collector: &signer) acquires ObjectController {
        mint_sailor_hat_internal(collector);
    }

    /// An internal function so the object can be used directly in testing
    fun mint_sailor_hat_internal(collector: &signer): Object<Hat> acquires ObjectController {
        let collection_owner_signer = get_collection_owner_signer();

        // Mint token
        let hat_collection_name = string::utf8(HATS);
        let hat_constructor = create_token(
            collection_owner_signer,
            hat_collection_name,
            string::utf8(SAILOR_HAT),
            string::utf8(SAILOR_HAT_URI),
            string::utf8(SAILOR_HAT)
        );

        // Attach hat properties
        let hat_signer = object::generate_signer(&hat_constructor);
        move_to(&hat_signer, Hat {
            type: string::utf8(SAILOR_HAT)
        });

        // Transfer hat to collector
        let hat_object = object::object_from_constructor_ref<Hat>(&hat_constructor);
        object::transfer(collection_owner_signer, hat_object, signer::address_of(collector));

        hat_object
    }

    /// Attaches a hat from the owner's inventory
    ///
    /// The hat must not be already owned by the face, and there should be no hat already worn.
    entry fun add_hat(
        caller: &signer,
        face_object: Object<Face>,
        hat_object: Object<Hat>
    ) acquires Face, Hat, ObjectController, TokenController {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == object::owner(face_object), E_NOT_OWNER);
        assert!(caller_address == object::owner(hat_object), E_NOT_OWNER);

        let face_address = object::object_address(&face_object);
        let hat_address = object::object_address(&hat_object);

        // Transfer hat to face
        object::transfer(caller, hat_object, face_address);

        // Attach hat to face
        let face = &mut Face[face_address];
        assert!(face.hat.is_none(), E_HAT_ALREADY_ON);
        face.hat.fill(hat_object);

        let hat = &Hat[hat_address];
        let token_controller = &TokenController[face_address];

        // Update the URI for the dynamic nFT
        // TODO: Support more hats
        if (hat.type == string::utf8(SAILOR_HAT)) {
            token::set_uri(&token_controller.mutator_ref, string::utf8(FACE_WITH_SAILOR_HAT_URI))
        } else {
            abort E_UNSUPPORTED_HAT
        };

        // Updates the description to have the new hat
        token::set_description(
            &token_controller.mutator_ref,
            string_utils::format2(&b"{} {}", string::utf8(FACE_WIF_HAT), hat.type)
        );

        // Disable transfer of hat (so it stays attached)
        let hat_controller = &ObjectController[hat_address];
        assert!(hat_controller.transfer_ref.is_some(), E_NO_TRANSFER_REF);
        let hat_transfer_ref = hat_controller.transfer_ref.borrow();
        object::disable_ungated_transfer(hat_transfer_ref);
    }

    /// Removes a hat that is already being worn
    ///
    /// Returns the hat to the owner's inventory
    entry fun remove_hat(
        caller: &signer,
        face_object: Object<Face>
    ) acquires Face, ObjectController, TokenController {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == object::owner(face_object), E_NOT_OWNER);

        let face_address = object::object_address(&face_object);

        // Remove hat
        let face = &mut Face[face_address];
        assert!(face.hat.is_some(), E_NO_HAT_ON);
        let hat_object = face.hat.extract();
        assert!(object::owner(hat_object) == face_address, E_HAT_NOT_OWNED_BY_FACE);

        // Remove hat from description
        let token_controller = &TokenController[face_address];
        token::set_description(&token_controller.mutator_ref, string::utf8(FACE_WIFOUT_HAT));
        token::set_uri(&token_controller.mutator_ref, string::utf8(FACE_URI));

        // Re-enable ability to transfer hat
        let hat_address = object::object_address(&hat_object);
        let hat_controller = &ObjectController[hat_address];
        assert!(hat_controller.transfer_ref.is_some(), E_NO_TRANSFER_REF);
        let hat_transfer_ref = hat_controller.transfer_ref.borrow();
        object::enable_ungated_transfer(hat_transfer_ref);

        // Return hat to user
        let face_controller = &ObjectController[face_address];
        let face_signer = object::generate_signer_for_extending(&face_controller.extend_ref);
        object::transfer(&face_signer, hat_object, caller_address);
    }

    #[view]
    /// Shows the face that's wearing the hat if it is on a face.  Otherwise, it will return none.
    fun face_wearing_hat(hat_object: Object<Hat>): Option<Object<Face>> {
        let owner = object::owner(hat_object);
        if (exists<Face>(owner)) {
            option::some(object::address_to_object(owner))
        } else {
            option::none()
        }
    }

    #[view]
    /// Tells us if a face has a hat
    fun has_hat(face_object: Object<Face>): bool acquires Face {
        let face_address = object::object_address(&face_object);
        Face[face_address].hat.is_some()
    }

    #[view]
    /// Show's the address if the face has a hat
    fun hat_address(face_object: Object<Face>): Object<Hat> acquires Face {
        let face_address = object::object_address(&face_object);
        *Face[face_address].hat.borrow()
    }

    /// Creates a collection generically with the ability to extend it later
    inline fun create_collection(creator: &signer, description: String, name: String, uri: String): ConstructorRef {
        let collection_constructor = collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(), // No royalties!
            uri
        );

        // Allow the collection to be modified in the future
        let collection_signer = object::generate_signer(&collection_constructor);
        let collection_extend_ref = object::generate_extend_ref(&collection_constructor);
        move_to(&collection_signer, ObjectController {
            extend_ref: collection_extend_ref,
            transfer_ref: option::none()
        });

        collection_constructor
    }

    /// Creates a token generically for whichever collection it is with the ability to extend later
    inline fun create_token(
        creator: &signer,
        collection_name: String,
        name: String,
        uri: String,
        description: String
    ): ConstructorRef {
        // Build a token with no royalties
        let token_constructor = token::create(
            creator,
            collection_name,
            description,
            name,
            option::none(),
            uri
        );

        // Generate references that will allow the token object to be modified in the future
        let token_signer = object::generate_signer(&token_constructor);
        let token_extend_ref = object::generate_extend_ref(&token_constructor);
        let transfer_ref = object::generate_transfer_ref(&token_constructor);
        move_to(&token_signer, ObjectController {
            extend_ref: token_extend_ref,
            transfer_ref: option::some(transfer_ref)
        });

        // Generate references that will allow token metadata to be modified in the future
        let mutator_ref = token::generate_mutator_ref(&token_constructor);
        let burn_ref = token::generate_burn_ref(&token_constructor);
        move_to(&token_signer, TokenController {
            mutator_ref,
            burn_ref
        });

        token_constructor
    }

    /// Retrieve the collection owner's signer from the object
    ///
    /// An inline function allows for common code to be inlined
    /// This case I'm using it so I can use a reference as a return value when it's inlined
    inline fun get_collection_owner_signer(): &signer {
        let address = object::create_object_address(&@deploy_addr, OBJECT_SEED);
        let object_controller = &ObjectController[address];
        &object::generate_signer_for_extending(&object_controller.extend_ref)
    }

    #[test_only]
    /// Face not connected
    const E_FACE_NOT_CONNECTED: u64 = 22;
    #[test_only]
    /// Face is connected, and it's not supposed to be
    const E_FACE_CONNECTED: u64 = 23;

    #[test(creator = @deploy_addr, collector = @0xbeef)]
    /// Tests minting and putting the hat on the face
    fun test_composability(
        creator: &signer,
        collector: &signer
    ) acquires ObjectController, Face, Hat, TokenController {
        // Setup collections
        setup(creator);

        // Mint the individual NFTs
        let face = mint_face_internal(collector);
        let hat = mint_sailor_hat_internal(collector);

        // Check that the hat can be put on
        add_hat(collector, face, hat);
        assert!(face_wearing_hat(hat) == option::some(face), E_FACE_NOT_CONNECTED);
        assert!(has_hat(face), E_FACE_NOT_CONNECTED);
        assert!(hat_address(face) == hat, E_FACE_NOT_CONNECTED);

        // Check that the hat can be taken off
        remove_hat(collector, face);
        assert!(face_wearing_hat(hat) != option::some(face), E_FACE_NOT_CONNECTED);
        assert!(!has_hat(face), E_FACE_NOT_CONNECTED);
    }
}
