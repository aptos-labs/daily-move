/// Smart table
///
/// Smart table is a combination between a vector and a table.  It uses bucketing to decrease the amount of execution
/// for the vector.
///
/// Insertion: O(bucket_size)
/// Removal: O(bucket_size)
/// Lookup: O(bucket_size)
///
/// Results will be not ordered when iterating out of the map.
module deploy_addr::allowlist_smart_table {

    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::object::{Self, Object};
    use deploy_addr::object_management;

    /// Address and amount size mismatch
    const E_VECTOR_MISMATCH: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Allowlist has key {
        allowlist: SmartTable<address, u8>
    }

    /// Creates an object to hold a table for allowlist
    ///
    /// Example object 0x6dd94ce639361237d83e3d0e612e33b7441675656db3350f9ae57de1081bec55
    ///
    /// 1505 gas units
    entry fun init(caller: &signer) {
        let object_signer = object_management::create_object(caller);
        move_to(&object_signer, Allowlist {
            allowlist: smart_table::new()
        });
    }

    /// Adds items to the allowlist
    ///
    /// Add 1 item -> 5 gas
    /// Add 5 items -> 7 gas
    /// Add 10 items -> 9 gas
    /// Add 293 items -> 9723 gas
    /// Update 293 addresses that already existed -> 2129 gas
    entry fun add(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
        amounts: vector<u8>
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = &mut Allowlist[object_address];

        let accounts_length = accounts.length();
        let amounts_length = accounts.length();
        assert!(accounts_length == amounts_length, E_VECTOR_MISMATCH);
        for (i in 0..accounts_length) {
            let account = accounts.pop_back();
            let amount = amounts.pop_back();
            allowlist.allowlist.upsert(account, amount);
        };
    }

    /// Removes items from the table
    ///
    /// To remove 10, gas cost is 7 gas
    /// 293 -> 1884 gas
    entry fun remove(
        caller: &signer,
        object: Object<Allowlist>,
        accounts: vector<address>,
    ) acquires Allowlist {
        let caller_address = signer::address_of(caller);
        object_management::check_owner(caller_address, object);

        let object_address = object::object_address(&object);
        let allowlist = &mut Allowlist[object_address];

        accounts.for_each(|account| {
            if (allowlist.allowlist.contains(account)) {
                allowlist.allowlist.remove(account);
            }
        })
    }

    /// This should actually be a view function, but we want to measure gas from an entry function standpoint
    /// It will lookup values and then do nothing
    ///
    /// For 10 items, out of 10 items -> 8 gas
    /// 293 items -> 1963 gas
    entry fun lookup(
        object: Object<Allowlist>,
        accounts: vector<address>
    ) acquires Allowlist {
        let object_address = object::object_address(&object);
        let allowlist = &Allowlist[object_address];
        accounts.for_each(|account| {
            allowlist.allowlist.borrow_with_default(account, &0);
        })
    }
}
