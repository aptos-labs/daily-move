# daily-move

Daily Move Snippets

This is part of a series written from @gregnazario, on a series of tweets on how to learn Move piece by piece.

It helps learn best practices and how to do things in Move.

Feel free to deploy this on your own using the aptos CLI with the instructions below

```bash
MY_ADDR=0x12345
aptos move publish --named-addresses deploy_addr=$MY_ADDR --package-dir snippets/19-01-2024
```

or if you've set up a profile in the Aptos CLI, you can simply use that instead

```bash
aptos init --profile my-profile
aptos move publish --profile my-profile --named-addresses deploy_addr=my-profile snippets/19-01-2024
```

Similarly, if the default profile is set, then it will also work.

```bash
aptos init
aptos move publish --named-addresses deploy_addr=default
```

You can then test it directly with a wallet on
https://explorer.aptoslabs.com/account/<ADDRESS>/modules/run?network=devnet