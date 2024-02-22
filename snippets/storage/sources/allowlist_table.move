/// Table
///
/// Table stores every item at a different hash storage on chain.  This gives easy lookup for each item, but doesn't
/// have iteration.
///
/// Insertion: O(1)
/// Removal: O(1)
/// Lookup: O(1)
/// No iteration
module deploy_addr::allowlist_table {

    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::object::{Self, Object};
    use deploy_addr::object_management;

    /// Address and amount size mismatch
    const E_VECTOR_MISMATCH: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Allowlist has key {
        allowlist: Table<address, u8>
    }

    /// Creates an object to hold a table for allowlist
    ///
    /// 504 gas units
    entry fun init(caller: &signer) {
        let object_signer = object_management::create_object(caller);
        move_to(&object_signer, Allowlist {
            allowlist: table::new()
        });
    }

    /// Adds an item to the table
    /// 0x7e780e2b8ce5a1d6e2c9e350552ba0cdbded2cf41aef8b50d4543cf5a97b05cb
    /// 1 item -> 504 gas
    /// 2 item -> 1004 gas
    /// 5 items -> 2506 gas
    /// 10 items -> 5008 gas
    /// 293 items -> 149538 gas
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
            table::upsert(&mut allowlist.allowlist, account, amount);
        };
    }

    /// Remove 10 -> 14 gas
    /// 293 -> 2108 gas
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
            table::remove(&mut allowlist.allowlist, account);
        })
    }

    /// This should actually be a view function, but we want to measure gas from an entry function standpoint
    /// It will lookup values and then do nothing
    ///
    /// For 10 items out of 10 items -> 13 gas
    /// 293 items -> 2090 gas
    entry fun lookup(
        object: Object<Allowlist>,
        accounts: vector<address>
    ) acquires Allowlist {
        let object_address = object::object_address(&object);
        let allowlist = borrow_global<Allowlist>(object_address);
        vector::for_each(accounts, |account| {
            table::borrow_with_default(&allowlist.allowlist, account, &0);
        })
    }
}
