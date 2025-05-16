/// Simple design pattern to create an object that can be used to get an autonomous signer
module deploy_address::base {

    use std::option::{Self, Option};
    use std::signer;
    use aptos_framework::object::{Self, ExtendRef, DeleteRef, TransferRef, ConstructorRef};

    /// The unique seed for the object on this account
    const OBJECT_SEED: vector<u8> = b"object_seed";

    // -- Error codes for this module -- //

    /// The caller is not the owner of the object
    const E_NOT_OBJECT_OWNER: u64 = 1;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A sticky note with a message for others to read
    struct ObjectRefs has key {
        extend_ref: ExtendRef,
        transfer_ref: Option<TransferRef>,
        delete_ref: Option<DeleteRef>,
    }

    /// Initialize the module, specifically making a single
    fun init_module(deployer: &signer) {
        // DESIGN PATTERN (Autonomous Object): Creates an object that can be used to get an autonomous signer
        //
        // This is a simple design pattern to create an object that can be used to get a signer to do actions programmatically
        // not requiring the owner of the assets to call the transaction.
        let constructor_ref = object::create_named_object(deployer, OBJECT_SEED);
        setup_object(&constructor_ref, false);
    }

    /// Sets up the object
    fun setup_object(constructor_ref: &ConstructorRef, can_transfer: bool) {
        // -- Generate references --
        // These references let you control what is possible with an object

        // Lets you get a signer of the object to do anything with it
        let extend_ref = object::generate_extend_ref(constructor_ref);

        // Lets you gate the ability to transfer the object
        //
        // In this case, we allow for "soulbound" or non-transferring objects
        let transfer_ref = if (can_transfer) {
            option::some(object::generate_transfer_ref(constructor_ref))
        } else {
            option::none()
        };

        // Lets you delete this object, if possible
        // Sticky objects and named objects can't be deleted
        let delete_ref = if (object::can_generate_delete_ref(constructor_ref)) {
            option::some(object::generate_delete_ref(constructor_ref))
        } else {
            option::none()
        };

        // -- Store references --
        // A creator of the object can choose which of these to save, and move them into any object alongside
        // In this case, we'll save all of them so we can illustrate what you can do with them.
        //
        // If any of the references are not created and stored during object creation, they cannot be added
        // later.

        // Move the References to be stored at the object address
        let object_signer = object::generate_signer(constructor_ref);

        move_to(&object_signer, ObjectRefs {
            extend_ref,
            transfer_ref,
            delete_ref,
        });
    }

    /// Fetches the address of the object
    public fun fetch_object_address(): address {
        // Note we don't check that the object doesn't exist
        // Because it must be create by deployment of the code
        object::create_object_address(&@deploy_address, OBJECT_SEED)
    }

    /// Fetches the object signer for the object
    ///
    /// Note that a call like this must have some permissions checks, if you do not it's a security issue.  This leads
    /// to our owner ownership permission design pattern.
    public fun get_object_signer(caller: &signer): signer acquires ObjectRefs {
        // DESIGN PATTERN (Object Ownership Permission): Ensure that the caller is the owner of the object
        // This is a general design pattern to ensure that only the owner of the object can do something with it
        let caller_address = signer::address_of(caller);
        let object_address = fetch_object_address();
        let object = object::address_to_object<ObjectRefs>(object_address);
        assert!(caller_address == object::owner(object), E_NOT_OBJECT_OWNER);

        // Note you can alternatively use `owns` but, it checks recursively owners on the objects
        assert!(object::owns(object, caller_address), E_NOT_OBJECT_OWNER);

        let refs = &ObjectRefs[object_address];
        object::generate_signer_for_extending(&refs.extend_ref)
    }
}

