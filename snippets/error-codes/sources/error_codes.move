/// 19th January 2024
///
/// This snippet teaches us about error codes
///
/// * Two slashes `//` only represent a comment, while 3 slashes `///` represent a doc comment
/// * Doc comments are used to provide useful error messages when put above error codes
///
/// Feel free to deploy this on your own using the aptos CLI with the instructions below
///
/// ```
/// MY_ADDR=0x12345
/// aptos move publish --named-addresses deploy_addr=$MY_ADDR
/// ```
///
/// or if you've set up a profile in the Aptos CLI, you can simply use that instead
///
/// ```
/// aptos init --profile my-profile
/// aptos move publish --profile my-profile --named-addresses deploy_addr=my-profile
/// ```
///
/// Similarly, if the default profile is set, then it will also work.
///
/// ```
/// aptos init
/// aptos move publish --named-addresses deploy_addr=default
/// ```
///
/// You can then test it directly with a wallet on
/// https://explorer.aptoslabs.com/account/<ADDRESS>/modules/run/error_codes?network=devnet
module deploy_addr::error_codes {
    // For best practice, place your constants near the top of the function, but for purposes of this tutorial we'll
    // put them next to their usage.
    //
    // By convention, error code constants should start with E.
    // If it starts with E, then it's very clearly an error and will show up in the error.
    //
    // Error codes are always constants.  The error messages are always u64 types, and by convention
    // skip 0, and start with 1.  Keep in mind that all errors should be different numbers.  If they're the same
    // then the error messages may get mixed.

    // Two slash comments, do not count towards error messages.  Ensure they are 3 slashes (doc comments)
    const E_ERROR_WITHOUT_MESSAGE: u64 = 1;

    /// This function will error without a useful error message
    entry fun throw_error_code_only() {
        abort E_ERROR_WITHOUT_MESSAGE
    }

    /// This error message will appear in the error message
    const E_USEFUL_ERROR: u64 = 2;

    /// This function will error with a useful error message defined above
    entry fun throw_useful_error() {
        abort E_USEFUL_ERROR
    }

    // This error uses the error type to provide grouping of errors, notice that the error code will be 0xc0003
    const E_ERROR_WITH_CLASSIFICATION: u64 = 3;

    /// This error will throw an error, but with a higher error code, for the classification
    entry fun throw_classified_error() {
        abort std::error::not_implemented(E_ERROR_WITH_CLASSIFICATION)
    }

    /// Value is not true, so we're failing the function
    const E_VALUE_NOT_TRUE: u64 = 4;

    /// This function will fail, if false with a useful error message.  This is how most errors will be
    entry fun throw_if_false(input: bool) {
        assert!(input == true, E_VALUE_NOT_TRUE)
    }

    // ---- Tests ----

    #[test]
    /// Verifies that throw_if_false succeeds when given true
    fun test_throw_if_false_with_true() {
        throw_if_false(true);
    }

    #[test]
    #[expected_failure(abort_code = E_VALUE_NOT_TRUE)]
    /// Verifies that throw_if_false aborts with E_VALUE_NOT_TRUE when given false
    fun test_throw_if_false_with_false() {
        throw_if_false(false);
    }

    #[test]
    #[expected_failure(abort_code = E_ERROR_WITHOUT_MESSAGE)]
    /// Verifies that throw_error_code_only aborts with E_ERROR_WITHOUT_MESSAGE
    fun test_throw_error_code_only() {
        throw_error_code_only();
    }

    #[test]
    #[expected_failure(abort_code = E_USEFUL_ERROR)]
    /// Verifies that throw_useful_error aborts with E_USEFUL_ERROR
    fun test_throw_useful_error() {
        throw_useful_error();
    }

    #[test]
    #[expected_failure]
    /// Verifies that throw_classified_error aborts with a classified error code
    fun test_throw_classified_error() {
        throw_classified_error();
    }
}
