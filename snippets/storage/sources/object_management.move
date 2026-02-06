/// Shared object management utilities for the storage pattern examples.
///
/// This module provides common functions for creating, extending, and deleting objects used across
/// the allowlist data structure examples (Vector, SimpleMap, Table, SmartTable, SmartVector).
///
/// Uses `public(friend)` visibility to restrict access to only the allowlist modules, preventing
/// arbitrary external callers from creating or controlling objects.
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
    /// Stores references needed to extend (get signer) or delete an object.
    /// Lives on the object itself as part of the ObjectGroup resource group.
    struct ObjectController has key {
        /// Allows generating a signer for this object after creation
        extend_ref: ExtendRef,
        /// Allows deleting this object to reclaim storage gas
        delete_ref: DeleteRef,
    }

    /// The caller is not the owner of the object
    const E_NOT_AUTHORIZED: u64 = 1;

    /// Creates a new deletable object owned by the caller, with `ObjectController` stored on it.
    ///
    /// Returns the object's signer so the caller can `move_to` additional resources onto it.
    ///
    /// Note: This is `public(friend)` -- only the allowlist modules can call it.
    public(friend) fun create_object(caller: &signer): signer {
        let caller_address = signer::address_of(caller);
        let constructor = object::create_object(caller_address);
        create_object_inner(constructor)
    }

    /// Internal helper: generates and stores the extend/delete refs from a constructor.
    /// Returns the object signer for further resource setup.
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

    /// Retrieves the signer for extending the object, after verifying the caller is the owner.
    ///
    /// WARNING: This is `public(friend)` for security. If this were `public`, any external module
    /// could obtain the object's signer and perform arbitrary operations on it.
    public(friend) fun get_signer<T: key>(caller: &signer, object: Object<T>): signer acquires ObjectController {
        let caller_address = signer::address_of(caller);
        check_owner(caller_address, object);
        object::generate_signer_for_extending(&ObjectController[caller_address].extend_ref)
    }

    /// Retrieves the signer and permanently deletes the object, reclaiming its storage gas.
    ///
    /// Returns the signer so the caller can `move_from` any remaining resources before deletion.
    ///
    /// WARNING: This is `public(friend)` for security -- same reasoning as `get_signer`.
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

    /// Asserts that `caller_address` is the direct owner of `object`.
    /// Aborts with `E_NOT_AUTHORIZED` if not.
    public(friend) fun check_owner<T: key>(caller_address: address, object: Object<T>) {
        assert!(object::is_owner(object, caller_address), E_NOT_AUTHORIZED);
    }
}
