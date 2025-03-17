module deploy_addr::object_management {

    use std::signer;
    use aptos_framework::object;
    use aptos_framework::object::{ExtendRef, DeleteRef, Object, ConstructorRef};

    friend deploy_addr::allowlist_simple_map;
    friend deploy_addr::allowlist_smart_table;
    friend deploy_addr::allowlist_table;
    friend deploy_addr::allowlist_vector;
    friend deploy_addr::allowlist_smart_vector;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Struct containing resources to control the objects
    struct ObjectController has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
    }

    /// Not owner of object
    const E_NOT_AUTHORIZED: u64 = 1;

    /// Creates an object for usage across these examples
    ///
    /// Note, that this is purposely for friends only, and all functions in this module will be
    public(friend) fun create_object(caller: &signer): signer {
        let caller_address = signer::address_of(caller);
        let constructor = object::create_object(caller_address);
        create_object_inner(constructor)
    }

    /// Sets up struct with extend and delete refs
    inline fun create_object_inner(constructor: ConstructorRef): signer {
        let extend_ref = object::generate_extend_ref(&constructor);
        let delete_ref = object::generate_delete_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        move_to(&object_signer, ObjectController {
            extend_ref,
            delete_ref
        });
        object_signer
    }

    /// Retrieve the signer for extending the object
    ///
    /// Note: This is purposely a friend function, or some unexpected behavior could occur allowing others to get
    /// the signer of the object arbitrarily.
    public(friend) fun get_signer<T: key>(caller: &signer, object: Object<T>): signer acquires ObjectController {
        let caller_address = signer::address_of(caller);
        check_owner(caller_address, object);
        object::generate_signer_for_extending(&ObjectController[caller_address].extend_ref)
    }

    /// Retrieve the signer for and delete the object, this allows fully deleting the object
    ///
    /// Note: This is purposely a friend function, or some unexpected behavior could occur allowing others to get
    /// the signer of the object arbitrarily.
    public(friend) fun delete_object<T: key>(caller: &signer, object: Object<T>): signer acquires ObjectController {
        let caller_address = signer::address_of(caller);
        check_owner(caller_address, object);

        let ObjectController {
            extend_ref,
            delete_ref,
        } = move_from<ObjectController>(caller_address);
        let object_signer = object::generate_signer_for_extending(&extend_ref);
        // Delete object
        object::delete(delete_ref);

        // Return signer for cleaning up the rest of the object
        object_signer
    }

    /// Checks the owner to ensure they're authorized for the function
    public(friend) fun check_owner<T: key>(caller_address: address, object: Object<T>) {
        assert!(object::is_owner(object, caller_address), E_NOT_AUTHORIZED);
    }
}
