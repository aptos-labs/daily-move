/// Vector
///
/// Vectors are best used for small known data sets, that won't get too large.  If there are too many items in the
/// vector, gas costs increase significantly, and there is a maximum number of items in a vector.
///
/// Insertion: O(1) at end O(n) anywhere else
/// Removal: O(1) minimally if order doesn't matter, by index, O(n) if removing by value, or order matters
/// Lookup: O(1) by index, O(n) by value
///
/// Results will be not ordered unless, a custom sort is used.
module deploy_addr::allowlist_vector {

    use std::signer;
    use aptos_framework::object::{Self, Object};
    use deploy_addr::object_management;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Allowlist has key {
        allowlist: vector<address>
    }

    /// Creates an object to hold a table for allowlist
    ///
    /// 504 gas units
    entry fun init(caller: &signer) {
        let object_signer = object_management::create_object(caller);
        move_to(&object_signer, Allowlist {
            allowlist: vector[]
        });
    }

    /// 293 items -> 6193 gas
    entry fun add(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = &mut Allowlist[object_address];

        allowlist.allowlist.append(accounts);
    }

    /// 293 items -> 2266 gas
    entry fun remove(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = &mut Allowlist[object_address];

        accounts.for_each_ref(|account| {
            allowlist.allowlist.remove_value(account);
        })
    }

    /// This should actually be a view function, but we want to measure gas from an entry function standpoint
    /// It will lookup values and then do nothing
    ///
    /// 293 items -> 2268 gas
    entry fun lookup(
        object: Object<Allowlist>,
        accounts: vector<address>
    ) acquires Allowlist {
        let object_address = object::object_address(&object);
        let allowlist = &Allowlist[object_address];
        accounts.for_each_ref(|account| {
            allowlist.allowlist.contains(account);
        })
    }
}
