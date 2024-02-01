/// Simple object design to show how objects can be used in replacing standard resources
///
/// The initial implementation is built to be extendable, and made to show first the differences between
/// resources and objects.  The next tutorial will extend upon this, showing how objects can be extended.
module 0x1::sticky_note {

    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_framework::object::{Self, Object, ExtendRef, DeleteRef, TransferRef, ConstructorRef};

    /// Please call initialize on this account
    const E_NO_BOARD_CREATED: u64 = 1;
    /// Please call initialize on the destination address
    const E_NO_BOARD_CREATED_ON_DESTINATION: u64 = 2;
    /// Caller doesn't own sticky note
    const E_NOT_OWNER: u64 = 3;
    /// Num is too high for number of sticky notes
    const E_OUT_OF_BOUNDS: u64 = 4;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A sticky note with a message for others to read
    struct StickyNote has key, store {
        message: String,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A board keeping track of sticky note resources
    struct StickyNoteBoard has key {
        /// Note we use vector here for this demo, but a more scalable version would use SmartVector
        board: vector<StickyNote>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A board keeping track of object addresses, this is one way of keeping track of Objects, but a more parallel
    /// scalable way would be with an indexer
    struct StickyNoteObjectBoard has key {
        /// Note we use vector here for this demo, but a more scalable version would use SmartVector
        board: vector<Object<StickyNote>>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A collection of references to control an Object
    struct ObjectController has key {
        extend_ref: ExtendRef,
        transfer_ref: Option<TransferRef>,
        delete_ref: Option<DeleteRef>,
    }

    /// Initializes boards for an account
    entry fun initialize_account(caller: &signer) {
        move_to(caller, StickyNoteBoard { board: vector[] });
        move_to(caller, StickyNoteObjectBoard { board: vector[] });
    }

    /// Creates a standard note, not an object
    entry fun create_note(caller: &signer, message: String) acquires StickyNoteBoard {
        let board = fetch_board(caller);

        // Attach a note
        vector::push_back(&mut board.board, StickyNote {
            message,
        })
    }

    /// Creates an object note
    entry fun create_object_note(caller: &signer, message: String) acquires StickyNoteObjectBoard {
        let board = fetch_object_board(caller);

        // Attach a note
        let constructor_ref = create_object_from_account(caller);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, StickyNote { message });

        let object = object::object_from_constructor_ref<StickyNote>(&constructor_ref);
        vector::push_back(&mut board.board, object);
    }

    /// Move sticky note
    entry fun transfer_note(caller: &signer, destination: address, num: u64) acquires StickyNoteBoard {
        // Retrieve the board
        let board = fetch_board(caller);

        // Remove the note from the board
        assert!(num < vector::length(&board.board), E_OUT_OF_BOUNDS);
        let note = vector::remove(&mut board.board, num);

        // The user must have created a board already
        assert!(exists<StickyNoteBoard>(destination), E_NO_BOARD_CREATED_ON_DESTINATION);

        // Transfer note
        let destination_board = borrow_global_mut<StickyNoteBoard>(destination);
        vector::push_back(&mut destination_board.board, note);
    }

    /// Move object sticky note
    entry fun transfer_note_object(caller: &signer, destination: address, num: u64) acquires StickyNoteObjectBoard {
        // Retrieve the board
        let board = fetch_object_board(caller);

        // Remove the note from the board
        assert!(num < vector::length(&board.board), E_OUT_OF_BOUNDS);
        let note = vector::remove(&mut board.board, num);

        // Sanity check, the object must be owned by the holder
        assert!(object::is_owner(note, signer::address_of(caller)), E_NOT_OWNER);

        // The user must have created a board already
        assert!(exists<StickyNoteBoard>(destination), E_NO_BOARD_CREATED_ON_DESTINATION);
        let destination_board = borrow_global_mut<StickyNoteObjectBoard>(destination);
        vector::push_back(&mut destination_board.board, note);

        // Now actually transfer the object, this overall should be cheaper than the note if the note was long enough
        object::transfer(caller, note, destination)
    }

    /// Creates an object from an account
    fun create_object_from_account(caller: &signer): ConstructorRef {
        // This actually creates the object.  It will create an ObjectCore resource at the address
        let constructor_ref = object::create_object_from_account(caller);
        setup_object(&constructor_ref, true);
        constructor_ref
    }

    /// Sets up the object, and returns the signer for simplicity
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

        move_to(&object_signer, ObjectController {
            extend_ref,
            transfer_ref,
            delete_ref,
        });
    }

    inline fun fetch_board(caller: &signer): &mut StickyNoteBoard {
        let caller_address = signer::address_of(caller);
        assert!(exists<StickyNoteBoard>(caller_address), E_NO_BOARD_CREATED);
        borrow_global_mut<StickyNoteBoard>(caller_address)
    }

    inline fun fetch_object_board(caller: &signer): &mut StickyNoteObjectBoard {
        let caller_address = signer::address_of(caller);
        assert!(exists<StickyNoteBoard>(caller_address), E_NO_BOARD_CREATED);
        borrow_global_mut<StickyNoteObjectBoard>(caller_address)
    }
}

