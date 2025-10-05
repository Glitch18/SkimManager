## Skim Manager

**The SkimManager is a contract that can skim adapters and reinvest rewards into vaults**

## Notes

In order to use this contract to skim rewards from an adapter, 
the adapter first needs to set this contract as the skim recipient.

### Set Up

In order to run the unit tests against a forked environment, we need an Alchemy API key.
Please create a `.env` file with the API key. See `example.env` for reference.

Run the following commands to test:

```
forge install
forge build
forge test -vv
```

### Deployment 

A deployment script is provided to deploy the SkimManager, it can be run as follows:

Dry run:
```
forge script script/DeploySkimManager.s.sol --rpc-url mainnet --private-key $PRIVATE_KEY
```

Deployment:
```
forge script script/DeploySkimManager.s.sol --rpc-url mainnet --private-key $PRIVATE_KEY --broadcast
```

### Tests

In order to run the unit tests, run `forge test`.
This will run the tests against a mainnet fork.

