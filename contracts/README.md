## FeemakerHolders

An ERC20-like token where each token represents a share of ETH income received by the contract. Incoming ETH is accounted for and made withdrawable by current token holders proportionally to their balances at the time each distribution occurs.

Contract source: `contracts/src/FeemakerHolders.sol`

### Key features
- Proportional ETH income distribution to token holders
- Pull-based withdrawals via `withdrawDividend()` to avoid forced transfers
- Accurate accounting across transfers before/after distributions
- Minimal ERC20 interface: `transfer`, `approve`, `transferFrom`, `balanceOf`, `allowance`, `totalSupply`

### Public interface
- `name() -> string`
- `symbol() -> string`
- `decimals() -> uint8`
- `totalSupply() -> uint256`
- `balanceOf(address) -> uint256`
- `allowance(address,address) -> uint256`
- `approve(address,uint256) -> bool`
- `transfer(address,uint256) -> bool`
- `transferFrom(address,address,uint256) -> bool`
- `withdrawableDividendOf(address) -> uint256` — current claimable ETH
- `accumulativeDividendOf(address) -> uint256` — total accrued ETH (claimed + unclaimed)
- `withdrawDividend()` — withdraws caller’s claimable ETH
- `receive()` — sending ETH to the contract triggers distribution

Events:
- `Transfer(address from, address to, uint256 value)`
- `Approval(address owner, address spender, uint256 value)`
- `DividendsDistributed(address from, uint256 weiAmount)`
- `DividendWithdrawn(address to, uint256 weiAmount)`

### How distributions work
- Any ETH sent to the contract (direct transfer or via `distributeDividends()`) is recorded and increases a global per-share accumulator.
- A holder’s withdrawable amount is computed from their token balance history and the accumulator, minus what they have already withdrawn.
- Transfers do not move ETH; they only adjust accounting so past distributions stay with previous holders, and future distributions follow current balances.

## Getting started

Prerequisites:
- Foundry installed (`forge`, `cast`, `anvil`). See `https://book.getfoundry.sh/`.

Install dependencies and build:
```shell
forge build
```

Run tests:
```shell
forge test
```

The reference tests live in `contracts/test/FeemakerHolders.t.sol` and cover single/multi-holder splits, transfers before/after distributions, and partial withdrawals.

## Local workflow

Start a local node:
```shell
anvil
```

In another terminal, run tests or scripts against the local RPC (`--rpc-url http://127.0.0.1:8545`).

## Deploy

Deployment script: `contracts/script/FeemakerHolders.s.sol` (entry: `CounterScript`). It deploys `FeemakerHolders` with an initial supply of `100 ether` (100 tokens with 18 decimals).

Example (replace placeholders):
```shell
forge script contracts/script/FeemakerHolders.s.sol:CounterScript \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

On Anvil (no broadcast, dry-run):
```shell
forge script contracts/script/FeemakerHolders.s.sol:CounterScript \
  --rpc-url http://127.0.0.1:8545
```

## Interact (cast)

Assuming the contract is deployed at `$ADDR` and you control `$PK`.

Check token metadata and balances:
```shell
cast call $ADDR "name()(string)"
cast call $ADDR "symbol()(string)"
cast call $ADDR "decimals()(uint8)"
cast call $ADDR "totalSupply()(uint256)"
cast call $ADDR "balanceOf(address)(uint256)" <holder>
```

Transfer tokens:
```shell
cast send $ADDR "transfer(address,uint256)" <to> <amount> --private-key $PK
```

Send ETH to distribute income:
```shell
cast send $ADDR --value <wei> --private-key $PK
```

Query and withdraw dividends:
```shell
cast call $ADDR "withdrawableDividendOf(address)(uint256)" <holder>
cast send $ADDR "withdrawDividend()" --private-key $PK
```

## Artifacts / ABI

ABI and bytecode are generated in:
- `contracts/out/FeemakerHolders.sol/FeemakerHolders.json`

## Notes and caveats
- The token uses 18 decimals; initial supply is specified in wei-like units (e.g., `100 ether`).
- ETH transfers may fail if the recipient is a contract without a payable fallback; this implementation uses a low-level call and reverts on failure.
- There is no mint/burn after construction; supply is fixed to simplify accounting.

## License

MIT
