/// 22th January 2024
///
/// This snippet teaches us about private vs public function types, through a game of a dice roll.
///
/// This application rolls a dice 1-6, and when you roll a 1, you win!  Each roll has a fee and the wins are counted
/// locally in a resource. The example shows you why you need to take into account private vs public entry functions.
///
/// This is especially important because of compatibility rules a private function can become a public function.  But,
/// once a function is public, it cannot become private.  This applies to both entry and non-entry functions.
///
module deploy_addr::dice_roll {

    use std::bcs;
    use aptos_framework::aptos_account;

    /// Struct to keep track of all the wins
    struct Wins has key {
        num_wins: u64
    }

    /// Let's start with the game
    ///
    /// This is a private function and can only be called within this module.  It cannot be called as a transaction on
    /// its own.
    ///
    /// It's not much fun, because a transaction can't be submitted directly to play this game.  But, it has the logic
    /// for being able to roll dice, and take a fee on every dice roll.
    fun play_game_internal(caller: &signer): bool acquires Wins {
        // Take a fee for this dice roll
        aptos_account::transfer(caller, @deploy_addr, 100000000);

        // Check if they won
        let caller_address = std::signer::address_of(caller);
        let random_value = roll_dice(caller_address);

        // If the caller didn't roll 1, they lost!
        if (random_value != 1) {
            return false
        };

        // If we win, let's increment wins
        add_win(caller);

        // Return that the win was successful
        true
    }

    /// Public entry function
    ///
    /// These functions can be submitted as a transaction on their own, or called in any module or script.
    ///
    /// Now we can submit a transaction for the game, and it can take a fee for every dice roll.  If the roller, wins or
    /// loses, the fee is taken.  But, wait... there are ways around paying the fee if the roller loses.  The user can
    /// wrap this function and make it fail in the event.  See `cheater.move`
    public entry fun play_game_public(caller: &signer) acquires Wins {
        play_game_internal(caller);
    }

    /// Public function
    ///
    /// These functions cannot be called as a transaction on their own, but can be called in any module or script.
    ///
    /// Similarly, if the `play_game_internal` was public, it can be called in any script or module.  The same abilities
    /// in `play_game_public` apply as well.  See `cheater.move` for more details
    public fun play_game_internal_public(caller: &signer): bool acquires Wins {
        play_game_internal(caller)
    }

    /// Private entry function
    ///
    /// This function can be called alone in a transaction.  It can be called within this module, but *not* outside of
    /// this module.
    ///
    /// Why does this matter?  The action taken in `cheater.move`, cannot be taken.
    entry fun private_entry_fun(caller: &signer) acquires Wins {
        play_game_internal(caller);
    }

    /// Allows other programs to know how many wins the user has
    public fun num_wins(player: address): u64 acquires Wins {
        if (exists<Wins>(player)) {
            Wins[player].num_wins
        } else {
            0
        }
    }

    /// Adds a win to their win counter, for a normal game this might provide some other reward
    fun add_win(caller: &signer) acquires Wins {
        let caller_address = std::signer::address_of(caller);
        // If they don't have a wins resource yet, let's create it
        if (!exists<Wins>(caller_address)) {
            move_to(caller, Wins {
                num_wins: 0
            })
        };

        // And increment the wins
        Wins[caller_address].num_wins += 1;
    }

    /// For purposes of this example, this is a pseudorandom number generator.
    ///
    /// It uses the caller, a set of bytes to keep the random values separate from other hashes, and time.
    fun roll_dice(caller_address: address): u8 {
        // Use time, and caller as a seed for the hash
        let time = aptos_framework::timestamp::now_microseconds();
        let bytes_to_hash = bcs::to_bytes(&time);
        bytes_to_hash.append(bcs::to_bytes(&caller_address));
        bytes_to_hash.append(b"dice-roll");

        // Hash the input bytes to get a pseudorandom amount of data
        let hash = std::hash::sha3_256(bytes_to_hash);

        // Use the first byte, as the data for the random number
        let val = hash[0];

        (val % 6) + 1
    }
}
