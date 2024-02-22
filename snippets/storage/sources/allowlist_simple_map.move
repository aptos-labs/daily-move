/// Simple map
///
/// Simple map is best used for a small map.  It's stored as a non-sorted vector.
///
/// As a result, lookup of any value or checking for a value is O(n), and insertion is similarly O(n).
/// This is because you need to iterate over the whole list and then insert a value (or replace the value).
///
/// Insertion: O(n)
/// Removal: O(n)
/// Lookup: O(n)
///
/// Results will be not ordered when iterating out of the map.
module deploy_addr::allowlist_simple_map {

    use std::signer;
    use std::vector;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::object::{Self, Object};
    use deploy_addr::object_management;

    /// Address and amount size mismatch
    const E_VECTOR_MISMATCH: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Allowlist has key {
        allowlist: SimpleMap<address, u8>
    }

    /// Creates an object to hold a table for allowlist
    ///
    /// 504 gas units
    entry fun init(caller: &signer) {
        let object_signer = object_management::create_object(caller);
        move_to(&object_signer, Allowlist {
            allowlist: simple_map::new()
        });
    }

    /// 1 -> 3 gas
    /// 5 -> 4 gas
    /// 10 -> 4 gas
    /// 293 -> 6957, gas
    entry fun add(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
        amounts: vector<u8>
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = borrow_global_mut<Allowlist>(object_address);

        let accounts_length = vector::length(&accounts);
        let amounts_length = vector::length(&accounts);
        assert!(accounts_length == amounts_length, E_VECTOR_MISMATCH);

        for (i in 0..accounts_length) {
            let account = vector::pop_back(&mut accounts);
            let amount = vector::pop_back(&mut amounts);
            simple_map::upsert(&mut allowlist.allowlist, account, amount);
        };
    }

    /// Remove accounts by value
    /// 293 -> 2361 gas
    entry fun remove(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = borrow_global_mut<Allowlist>(object_address);

        vector::for_each(accounts, |account| {
            simple_map::remove(&mut allowlist.allowlist, &account);
        })
    }

    /// This should actually be a view function, but we want to measure gas from an entry function standpoint
    /// It will lookup values and then do nothing
    ///
    /// Lookup 10 items out of 10 -> 6 gas
    /// 293 items -> 2893 gas
    entry fun lookup(
        object: Object<Allowlist>,
        accounts: vector<address>
    ) acquires Allowlist {
        let object_address = object::object_address(&object);
        let allowlist = borrow_global<Allowlist>(object_address);
        vector::for_each_ref(&accounts, |account| {
            if (simple_map::contains_key(&allowlist.allowlist, account)) {
                simple_map::borrow(&allowlist.allowlist, account)
            } else {
                &0
            };
        })
    }
}
