/// Mailbox system demonstrating struct capability patterns in Move.
///
/// Users can send envelopes containing coins, legacy tokens, and objects to other users. This
/// demonstrates how Move's type system enforces safety through struct abilities:
///
/// - `Envelope` cannot be dropped (because `Coin` and `Token` lack `drop`), forcing proper handling
/// - `Envelope` cannot be copied (because `Coin` and `Token` lack `copy`), preventing duplication
/// - `MailboxId` has `copy` and `drop`, showing when these abilities are useful for keys
///
/// ## Workflow:
/// 1. A sender calls `send_mail` with coins, objects, and/or tokens
/// 2. The receiver can `open_envelope` to claim contents
/// 3. Or the sender can `return_envelope` to get contents back
/// 4. Empty mailboxes can be destroyed to reclaim storage gas
module deploy_addr::mailbox {

    use std::option::{Self, Option};
    use std::signer;
    use std::string::String;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::object::{Self, Object, ObjectCore, ExtendRef};
    use aptos_token::token::{Self, Token, TokenId};

    /// Not all of the token inputs (creator_addresses, collection_names, token_names) match in length
    const E_TOKEN_INPUT_LENGTH_MISMATCH: u64 = 2;

    /// No mailbox exists for receiver
    const E_NO_MAILBOX_EXISTS: u64 = 3;

    /// Mailbox not empty, cannot delete it
    const E_MAILBOX_NOT_EMPTY: u64 = 4;

    /// Mailbox is empty
    const E_MAILBOX_EMPTY: u64 = 5;

    /// Mail index is out of bounds, it may have already been opened
    const E_OUT_OF_BOUNDS: u64 = 6;

    /// Can't return envelope, caller is not the sender of the envelope
    const E_NOT_SENDER: u64 = 7;

    const SEED: vector<u8> = b"Mailbox";

    /// A struct representing the mailboxes in a shared location
    ///
    /// In this example, it can only exist in the object created at contract creation time
    struct MailboxRouter has key {
        mailboxes: SmartTable<MailboxId, Mailbox>,
        extend_ref: ExtendRef,
    }

    /// This is a struct used for a key in the smart table
    ///
    /// It must have store, in order to be put into a collection like a SmartTable or vector
    ///
    /// It must have copy to be able to be dereferenced or "copied" from a referenced version.
    ///
    /// For example:
    /// ```move
    /// let id = MailboxId { receiver: @0x1 }
    /// let reference = &id;
    /// let copied_id = *reference;
    /// ```
    ///
    /// If it is not copy, then it cannot be copied directly, and instead it's contents will be manually carried over:
    /// e.g.
    /// ```move
    /// let id = MailboxId { receiver: @0x1 }
    /// let reference = &id;
    /// let copied_id = MailboxId { reciever: *reference.receiver };
    /// ```
    struct MailboxId has store, copy, drop {
        receiver: address
    }

    /// A mailbox that keeps track of all envelopes in a chronological
    /// insert order
    struct Mailbox has store {
        mail: SmartVector<Envelope>,
    }

    /// An envelope that stores items to be sent to the receiver
    ///
    /// This type cannot be copy or drop, because Coin and Token cannot be copied or dropped.
    ///
    /// The purpose of those items not being copied or dropped is so an NFT isn't lost and a Coin isn't lost.
    ///
    /// However, Envelope can be taken apart with decomposition, which would allow for removing each of the pieces
    /// directly e.g.:
    /// ```move
    /// let Envelope {
    ///   sender,
    ///   note,
    ///   coins,
    ///   legacy_tokens,
    ///   objects
    /// } = envelope;
    /// ```
    struct Envelope has store {
        /// The sender of the envelope
        /// This is required in order to be able to return the envelope
        sender: address,
        /// A string note for the receiver
        note: Option<String>,
        /// This only supports AptosCoin, but could be extended
        coins: Option<Coin<AptosCoin>>,
        /// Legacy token standard
        legacy_tokens: vector<Token>,
        /// Any objects, including Digital Assets
        objects: vector<Object<ObjectCore>>
    }

    /// Setup on deployment of this contract, the only instance of the mailbox in an object
    fun init_module(deployer: &signer) {
        let constructor_ref = object::create_named_object(deployer, SEED);
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        // Disable transfer of mailbox object, and drop it so no one can transfer the mailboxes
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);

        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, MailboxRouter {
            mailboxes: smart_table::new(),
            extend_ref
        });
    }

    /// Sends an envelope, with objects, coins, tokens, and a note to an address
    entry fun send_mail(
        caller: &signer,
        receiver: address,
        note: Option<String>,
        coin_amount: u64,
        objects: vector<Object<ObjectCore>>,
        legacy_token_creator_addresses: vector<address>,
        legacy_token_collection_names: vector<String>,
        legacy_token_names: vector<String>,
    ) acquires MailboxRouter {
        // Ensure inputs all match in length (token ids will be valid)
        assert!(
            legacy_token_creator_addresses.length() == legacy_token_collection_names.length(),
            E_TOKEN_INPUT_LENGTH_MISMATCH
        );
        assert!(
            legacy_token_creator_addresses.length() == legacy_token_names.length(),
            E_TOKEN_INPUT_LENGTH_MISMATCH
        );

        // Build the token Ids for the Legacy tokens
        let token_ids = vector[];
        let length = legacy_token_names.length();
        for (i in 0..length) {
            let creator_address = legacy_token_creator_addresses[i];
            let collection_name = legacy_token_collection_names[i];
            let token_name = legacy_token_names[i];
            let data_id = token::create_token_data_id(creator_address, collection_name, token_name);
            let latest_property_version = token::get_tokendata_largest_property_version(creator_address, data_id);
            let token_id = token::create_token_id(data_id, latest_property_version);
            token_ids.push_back(token_id);
        };

        send_mail_internal(caller, receiver, note, coin_amount, objects, token_ids);
    }

    /// Opens the latest envelope
    entry fun open_latest_envelope(caller: &signer) acquires MailboxRouter {
        let mailbox = get_mailbox(signer::address_of(caller));
        let length = mailbox.mail.length();
        open_envelope(caller, length - 1)
    }

    /// Opens the oldest envelope
    entry fun open_oldest_envelope(caller: &signer) acquires MailboxRouter {
        open_envelope(caller, 0)
    }

    /// Opens any number envelope
    entry fun open_envelope(caller: &signer, num: u64) acquires MailboxRouter {
        let caller_address = signer::address_of(caller);
        let envelope = open_mail(caller_address, num);

        deposit_contents(caller, envelope);
    }

    /// Returns the envelope to the sender, but only if the person had sent the mail
    entry fun return_envelope(sender: &signer, receiver: address, num: u64) acquires MailboxRouter {
        let envelope = open_mail(receiver, num);

        // Only the sender can take the envelope contents back
        assert!(envelope.sender == signer::address_of(sender), E_NOT_SENDER);
        deposit_contents(sender, envelope);
    }

    /// Deposits contents of the envelope
    fun deposit_contents(receiver: &signer, envelope: Envelope) acquires MailboxRouter {
        let receiver_address = signer::address_of(receiver);

        // Since Envelope isn't droppable, it has to be broken into it's parts to destroy it
        let Envelope {
            sender: _, // You can drop a field not needed later by putting _ instead of a name
            note: _, // Drop the note, only for viewing in transactions
            coins,
            legacy_tokens,
            objects,
        } = envelope;

        // Deposit coins, if there were any, these can't be dropped
        if (coins.is_some()) {
            coin::deposit(receiver_address, coins.destroy_some())
        } else {
            coins.destroy_none();
        };

        // Deposit all legacy tokens, these can't be dropped
        legacy_tokens.for_each(|legacy_token| {
            token::deposit_token(receiver, legacy_token);
        });

        // Deposit all objects, if this is missed, the objects will be stuck on the router account
        let mailbox_signer = get_mailbox_signer();
        objects.for_each(|obj| {
            object::transfer(mailbox_signer, obj, receiver_address)
        });

        // At this point, all pieces are transferred to the receiver
    }

    /// Remove your mailbox, and retrieve the storage gas
    entry fun destroy_mailbox(caller: &signer) acquires MailboxRouter {
        let receiver = signer::address_of(caller);
        let router = get_mailbox_router_mut();

        let mailbox_id = MailboxId { receiver };

        if (router.mailboxes.contains(mailbox_id)) {
            let is_empty = router.mailboxes.borrow(mailbox_id).mail.is_empty();
            assert!(is_empty, E_MAILBOX_NOT_EMPTY);

            // Decompose and destroy mailbox
            let Mailbox {
                mail,
            } = router.mailboxes.remove(mailbox_id);
            mail.destroy_empty();
        }
    }

    /// Sends mail to another account
    fun send_mail_internal(
        caller: &signer,
        receiver: address,
        note: Option<String>,
        coin_amount: u64,
        objects: vector<Object<ObjectCore>>,
        legacy_token_ids: vector<TokenId>
    ) acquires MailboxRouter {
        // Put coins in the envelope
        let coins = coin::withdraw<AptosCoin>(caller, coin_amount);

        // For purposes of this demo we transfer ownership of objects and tokens to the contract, but usually this can
        // be done without the middle man

        // Transfer all objects to the contract
        objects.for_each_ref(|obj| {
            object::transfer(caller, *obj, @deploy_addr);
        });

        // Retrieve all tokens for the envelope
        let legacy_tokens = legacy_token_ids.map(|token_id| {
            // For this demo, we'll only consider non-fungible tokens
            token::withdraw_token(caller, token_id, 1)
        });

        let envelope = Envelope {
            sender: signer::address_of(caller),
            note,
            objects,
            legacy_tokens,
            coins: option::some(coins),
        };

        // Retrieve the mailbox, creating it if it doesn't exist
        let router = get_mailbox_router_mut();
        let mailbox_id = MailboxId {
            receiver
        };
        if (!router.mailboxes.contains(mailbox_id)) {
            router.mailboxes.add(mailbox_id, Mailbox {
                mail: smart_vector::new(),
            })
        };

        let mailbox = router.mailboxes.borrow_mut(mailbox_id);

        // Push the envelope onto the mailbox
        mailbox.mail.push_back(envelope);
    }

    /// Opens an indexed piece of mail
    fun open_mail(receiver: address, num: u64): Envelope acquires MailboxRouter {
        let mailbox = get_mailbox_mut(receiver);

        // Check that num is removable
        let length = mailbox.mail.length();
        assert!(length > 0, E_MAILBOX_EMPTY); // This is to ensure a friendly message is given when there is no mail
        assert!(num < length, E_OUT_OF_BOUNDS);

        // This removes the item in the smart vector.
        // From a gas perspective, removing the oldest piece of mail is much more
        // expensive than the newest, but it preserves order.
        //
        // smart_vector::swap_remove can be used, if order doesn't matter
        mailbox.mail.remove(num)
    }

    #[view]
    /// Views a piece of mail in the user's mailbox
    fun view_mail(receiver: address, num: u64): Envelope acquires MailboxRouter {
        let mailbox = get_mailbox_mut(receiver);

        mailbox.mail.remove(num)
    }

    /// Retrieve the mailbox router object
    inline fun get_mailbox_router_mut(): &mut MailboxRouter {
        let mailbox_router_address = object::create_object_address(&@deploy_addr, SEED);
        &mut MailboxRouter[mailbox_router_address]
    }

    /// Retrieve the mailbox signer for moving objects around
    inline fun get_mailbox_signer(): &signer {
        let router = get_mailbox_router_mut();
        &object::generate_signer_for_extending(&router.extend_ref)
    }

    /// Retrieves the mailbox for reading for a user
    inline fun get_mailbox_mut(receiver: address): &mut Mailbox {
        let router = get_mailbox_router_mut();
        let mailbox_id = MailboxId {
            receiver
        };
        assert!(router.mailboxes.contains(mailbox_id), E_NO_MAILBOX_EXISTS);

        router.mailboxes.borrow_mut(mailbox_id)
    }

    /// Retrieves the mailbox in a non-mutable way
    inline fun get_mailbox(receiver: address): &Mailbox {
        let router = get_mailbox_router_mut();
        let mailbox_id = MailboxId {
            receiver
        };
        assert!(router.mailboxes.contains(mailbox_id), E_NO_MAILBOX_EXISTS);

        router.mailboxes.borrow(mailbox_id)
    }
}
