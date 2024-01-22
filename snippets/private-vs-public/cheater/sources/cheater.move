/// This normally would be deployed to a different address, in a different package,
/// but this keeps it simple for this demo.
module deploy_addr::cheater {

    use std::signer;
    use deploy_addr::dice_roll;

    /// I didn't win, so I'm going to skip paying the fee
    const E_LOST: u64 = 1;

    /// This is an example of why a public entry function is possibly not a good choice
    ///
    /// In this case, the cheater refuses to pay the fee, and aborts after seeing the result
    entry fun cheat_game(caller: &signer) {
        let caller_address = signer::address_of(caller);

        // Let's see the number of wins prior to the game
        let original_num_wins = dice_roll::num_wins(caller_address);

        // Play the game
        dice_roll::play_game_public(caller);

        // Let's see the number of wins after the game
        let new_num_wins = dice_roll::num_wins(caller_address);

        // I don't like losing, so I will refuse to pay the fee if I lose
        assert!(original_num_wins == new_num_wins, E_LOST);
    }

    /// I can additionally cheat here with the internal function, and it's even easier because of the return value
    entry fun cheat_game_internal(caller: &signer) {
        // I don't like losing, so I will refuse to pay the fee if I lose
        assert!(dice_roll::play_game_internal_public(caller), E_LOST);
    }
}
