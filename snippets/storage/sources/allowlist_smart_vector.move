/// Smart Vector
///
/// Smart Vectors are best used for larger known data sets and scale over the maximum number of items in a vector.
///
/// This is handled by creating vector buckets over a table.  This allows it to scale over the max vector size and
/// scale better from a gas standpoint.
///
/// Insertion: O(1) at end O(n) anywhere else
/// Removal: O(1) minimally if order doesn't matter, by index, O(n) if removing by value, or order matters
/// Lookup: O(1) by index, O(n) by value
///
/// Results will be not ordered unless, a custom sort is used.
module deploy_addr::allowlist_smart_vector {

    use std::signer;
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::SmartVector;
    use aptos_framework::object::{Self, Object};
    use deploy_addr::object_management;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Allowlist has key {
        allowlist: SmartVector<address>
    }

    /// Creates an object to hold a table for allowlist
    /// 504 gas units
    entry fun init(caller: &signer) {
        let object_signer = object_management::create_object(caller);
        move_to(&object_signer, Allowlist {
            allowlist: smart_vector::new()
        });
    }

    /// 293 items -> 7042 gas
    entry fun add(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = &mut Allowlist[object_address];

        allowlist.allowlist.add_all(accounts);
    }

    /// 293 items -> 5354 gas
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
            // Note, smart vector can be very big, so removing by value is not a good idea, but to compare we'll keep it
            let i = 0;
            let length = allowlist.allowlist.length();
            while (i < length) {
                if (account == allowlist.allowlist.borrow(i)) {
                    allowlist.allowlist.swap_remove(i);
                    break
                };

                i += 1;
            };
        })
    }

    /// This should actually be a view function, but we want to measure gas from an entry function standpoint
    /// It will lookup values and then do nothing
    ///
    /// 293 items -> 2394 gas
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
