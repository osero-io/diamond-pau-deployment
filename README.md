# Osero PAU Deployment

This repository contains Osero's canonical Foundry deployment packages:

- the Osero PAU stack on Ethereum mainnet, covered by the sections below up to [Base governance relay](#base-governance-relay);
- the Osero governance relay on Base, which lets Osero spells on Ethereum mainnet relay payloads to Base, covered by [Base governance relay](#base-governance-relay).

The PAU code does not implement new PAU facets. It composes existing Sky PAU contracts and Osero registry addresses into one deployment configuration:

- deploy a PAU proxy, controller, access-control contract, and rate-limit contract through Sky's `DefaultPAUAssembler`;
- enable the `AAVE_FACET` and `USDS_FACET` controller integrations in a fixed order;
- configure Osero's proxy as the component administrator;
- configure one allocator `AdministeredAgent` administered by Osero, operated by the Soter relayer and Osero operator, and revocable by the Soter freezer.

## Repository layout

```text
src/OseroPAUDeployment.sol      Shared deployment library and configuration.
script/Deploy.s.sol            Broadcast script that calls the deployment library and logs addresses.
test/OseroPAUDeployment.t.sol   Mainnet-fork tests covering deployment config, permissions, wiring, and USDS/Aave flows.
foundry.toml                   Foundry compiler, remapping, RPC, and Etherscan settings (default and `gov-relay` profiles).
lib/                           Git submodules for PAU assemblers, registries, spark-gov-relay, and forge-std.
gov-relay/                     Base governance relay package, built with `FOUNDRY_PROFILE=gov-relay` (see below).
```

## External dependencies

The deployment imports addresses and contracts from submodules:

- `sky-pau-registry`: Sky PAU mainnet contract addresses, including `DEFAULT_PAU_ASSEMBLER`, `AAVE_FACET`, and `USDS_FACET`.
- `pau-assemblers`: `DefaultPAUAssembler` and assembler interfaces.
- `osero-address-registry`: Osero operational addresses, allocator vault/buffer addresses, and ilk constants.
- `spark-gov-relay` (`v1.0.1`): the `Executor` and, through its pinned `xchain-helpers` and OpenZeppelin submodules, the `OptimismReceiver` of the Base governance relay.
- `forge-std`: Foundry test and script utilities.

After cloning, install dependencies before building:

```shell
forge install
```

or, equivalently, `git submodule update --init --recursive` (spark-gov-relay has nested submodules).

## Environment

The test suite forks Ethereum mainnet and `foundry.toml` resolves the `mainnet` RPC endpoint from `MAINNET_RPC_URL`. The Base governance relay additionally resolves the `base` endpoint from `BASE_RPC_URL`. Both must be archive nodes, since the tests fork pinned blocks.

```shell
export MAINNET_RPC_URL=<ethereum-mainnet-rpc-url>
export BASE_RPC_URL=<base-rpc-url>           # only needed for the Base governance relay
export ETHERSCAN_API_KEY=<etherscan-api-key> # only needed for verification (Etherscan API v2 covers Base)
```

## Build and test

```shell
forge build
forge test
```

Run the deployment test suite only:

```shell
forge test --match-path test/OseroPAUDeployment.t.sol
```

Format Solidity before committing:

```shell
forge fmt
```

## Deployment

The deploy script broadcasts `OseroPAUDeployment.deploy()` and prints the deployed PAU component addresses.

```shell
forge script script/Deploy.s.sol:DeployOseroPAUScript \
  --rpc-url mainnet \
  --private-key <deployer-private-key> \
  --broadcast
```

Add `--verify` when contract verification is required and `ETHERSCAN_API_KEY` is set.

## Bytecode Verification

The deployment creates five contracts through internal `CREATE` calls inside Sky's `DefaultPAUAssembler` (`Ethereum.DEFAULT_PAU_ASSEMBLER`), all within a single `deploy(...)` transaction:

| Address | Contract | Source |
| --- | --- | --- |
| `0x791D2a017532CfAD881c446e6bF93BbC3c0778b2` | `AccessControls` | `lib/diamond-pau/src/AccessControls.sol` |
| `0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884` | `ALMProxy` | `lib/diamond-pau/src/ALMProxy.sol` |
| `0xe9a78f34fe497e2186f81b8c014cd93b308bc62a` | `RateLimits` | `lib/diamond-pau/src/RateLimits.sol` |
| `0x24169Afb34fAe4D4356BC54Bd80319131e35ca38` | `Controller` | `lib/diamond-pau/src/Controller.sol` |
| `0x1837505d104f7a6d8b7e19452610b0a3d652ef12` | `AdministeredAgent` (allocator agent) | `lib/pau-administered-agent/src/AdministeredAgent.sol` |

Because the contracts are created by the assembler rather than by standalone transactions, their creation (init) code never appears as transaction calldata; it exists only in the assembler's memory at the `CREATE` opcode. `forge verify-bytecode` reconstructs the on-chain creation code from the creation transaction, so it fails with `Could not extract the creation code` for every address. `--ignore creation` does not change this: it suppresses a creation-code *mismatch*, not the extraction step itself. Verify the **runtime (deployed) bytecode** and confirm the constructor wiring from on-chain state instead.

### Runtime bytecode

Install dependencies and build with the settings pinned in `foundry.toml` (`solc 0.8.34`, optimizer enabled, `200` runs, `cancun`). The five contracts are compiled as part of the build, producing `out/<File>.sol/<Contract>.json`:

```shell
forge install
forge build
```

Compare each on-chain runtime bytecode against its artifact, excluding the trailing metadata (see below). The artifact field is `deployedBytecode.object`:

```shell
strip() {                       # read hex on stdin, drop the trailing CBOR metadata
  local b; b=$(tr -d '\n' | sed 's/^0x//')
  local n=$(( 16#${b: -4} ))    # last two bytes hold the metadata length
  printf '%s' "${b:0:$(( ${#b} - (n + 2) * 2 ))}"
}

addr=0x791D2a017532CfAD881c446e6bF93BbC3c0778b2
artifact=out/AccessControls.sol/AccessControls.json

onchain=$(cast code --rpc-url mainnet "$addr" | strip)
local=$(jq -r .deployedBytecode.object "$artifact" | strip)
[ "$onchain" = "$local" ] && echo match
```

For `AccessControls`, `ALMProxy`, `RateLimits`, and `AdministeredAgent` this comparison is exact. `Controller` additionally carries an immutable (see below).

### CBOR metadata trailer

solc appends a CBOR-encoded metadata blob to the runtime bytecode; its last two bytes are the big-endian length of the blob, and it embeds an IPFS hash of the compilation metadata (the source-file set, their paths, and the compiler settings). Recompiling identical logic from this repository's layout yields a different IPFS hash than the original compilation, so the trailing bytes differ while the executable code is byte-identical. The comparison above removes the trailer from both sides; everything that remains must match exactly. The compiler-version bytes inside the trailer (immediately after `64736f6c6343`, the CBOR `solc` key) decode to `0.8.34` (`000822`).

### Immutables

`Controller` stores `beacon` as an `immutable`, so its value is embedded in the runtime bytecode while the artifact leaves those positions zeroed and lists them under `deployedBytecode.immutableReferences`. Before comparing, mask those byte ranges on both sides, or substitute `Ethereum.BEACON` (left-padded to 32 bytes) into the artifact. The other three `Controller` constructor arguments are kept in storage and do not appear in the runtime bytecode.

### Constructor arguments

Runtime bytecode does not bind constructor arguments other than immutables, so confirm them from on-chain state. `Controller` exposes its arguments directly:

```shell
ctrl=0x24169Afb34fAe4D4356BC54Bd80319131e35ca38
cast call --rpc-url mainnet "$ctrl" "accessControls()(address)"
cast call --rpc-url mainnet "$ctrl" "proxy()(address)"
cast call --rpc-url mainnet "$ctrl" "rateLimits()(address)"
cast call --rpc-url mainnet "$ctrl" "beacon()(address)"
```

These must equal the `AccessControls`, `ALMProxy`, and `RateLimits` addresses above and `Ethereum.BEACON`. For the remaining contracts the constructor argument only seeds initial access control; check the current role holders with `hasRole(bytes32,address)` against the administrator configuration in `src/OseroPAUDeployment.sol`. The fork tests in `test/OseroPAUDeployment.t.sol` assert this wiring and the role boundaries end to end.

## Working on deployment configuration

Most changes should be made in `src/OseroPAUDeployment.sol`:

- integration IDs belong in `integrationIds()`;
- component administrators belong in `adminConfig()` / `_componentAdmins()`;
- allocator agent admins, actors, grantors, and revokers belong in `allocatorAgentConfigs()`;
- deployment execution belongs in `deploy()`.

Keep registry-owned addresses in their registries. Import constants from `sky-pau-registry` or `osero-address-registry` instead of copying literal addresses into this repository.

The fork tests intentionally assert both configuration and live behavior:

- deterministic CREATE addresses from the assembler factories;
- deployed bytecode presence;
- admin and allocator-agent role boundaries;
- controller integration order and facet wiring;
- USDS mint/burn through the Osero allocator vault;
- USDS deposit/withdraw through Spark Lend via the Aave facet;
- prevention of direct operator calls that bypass the allocator agent.

Update tests with any deployment configuration change. A passing build alone is not enough for this repository because the deployment depends on live mainnet state.

## Base governance relay

The relay lets Osero governance on Ethereum mainnet execute payloads on Base. An Osero spell, executed by the Osero SubProxy, sends `Executor.queue(...)` through the OP Stack messenger (`OptimismForwarder.sendMessageL1toL2` with `L1_CROSS_DOMAIN_BASE`). On Base the `OptimismReceiver` accepts the message only from the L2 messenger `0x4200000000000000000000000000000000000007` and only if the L1 sender is the Osero SubProxy, then forwards it to the `Executor`. The `Executor` queues the actions set, and anyone can then call `execute(id)`, which delegatecalls the payload in the `Executor`'s context.

The deployment copies Grove's Base relay: Executor [`0x491EDFB0B8b608044e227225C715981a30F3A44E`](https://basescan.org/address/0x491EDFB0B8b608044e227225C715981a30F3A44E) and Receiver [`0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a`](https://basescan.org/address/0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a), both Sourcify `exact_match`.

```text
gov-relay/src/OseroBaseGovRelayDeployment.sol   Deployment library: parameters and the deploy/permission sequence.
gov-relay/script/DeployBaseGovRelay.s.sol       Broadcast script: deploys, checks the final state, writes gov-relay/output/8453/.
gov-relay/test/                                 Base-fork, cross-chain, and post-deploy verification tests.
gov-relay/output/8453/                          Deployment record (base-gov-relay-latest.json) consumed by the post-deploy tests.
```

### Parameters

| Parameter | Value | Source |
| --- | --- | --- |
| `Executor` source | sparkdotfi/spark-gov-relay `v1.0.1`, commit `5c166763464802a9f985fa50560c9e9fb0cf6c2b` | Final audited commit; `lib/spark-gov-relay`. |
| `OptimismReceiver` source | `lib/spark-gov-relay/lib/xchain-helpers`, commit `6be2397aa4f6e9465a763f609e25a9111ffff200` | Submodule pinned by spark-gov-relay `v1.0.1`; `OptimismReceiver.sol` is identical to sky-ecosystem/xchain-helpers `v1.2.0`. |
| OpenZeppelin | `lib/spark-gov-relay/lib/openzeppelin-contracts` (`v5.0.2`, commit `dbb6104c`) | Submodule pinned by spark-gov-relay `v1.0.1`. |
| Compiler | solc `0.8.25`, optimizer enabled, `200` runs, `evm_version = cancun`, no via-IR | spark-gov-relay `v1.0.1` and Grove's deployed relay. The repository default (`0.8.34`) must not be used. |
| Chain | Base (`8453`) | |
| `Executor` `delay` | `0` | Grove's and Spark's Base Executors both read `delay() == 0`. |
| `Executor` `gracePeriod` | `7 days` (`604800`) | Grove's and Spark's Base Executors both read `gracePeriod() == 604800`. |
| `OptimismReceiver` `_l1Authority` | Osero SubProxy `0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3` | `osero-address-registry` `Ethereum.OSERO_PROXY`; chainlog key `OSERO_SUBPROXY`. |
| `OptimismReceiver` `_target` | the new `Executor` | |
| Permissions | 1. `executor.grantRole(SUBMISSION_ROLE, receiver)`<br>2. `executor.revokeRole(DEFAULT_ADMIN_ROLE, deployer)` | Matches the later spark-gov-relay `Deploy.setUpExecutorPermissions` (absent from `v1.0.1`), without a guardian. |
| `GUARDIAN_ROLE` | nobody | |
| Deployer | a fresh EOA used only for Osero's Base deployments (Ledger or keystore) | The deployment checklist requires a different deployer per chain. The script rejects the Ethereum mainnet deployer `0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`. |

After deployment the `Executor` keeps the `DEFAULT_ADMIN_ROLE` its constructor grants to itself: governance reconfigures it through queued payloads that run in its own context. The deployer holds no role.

### Build and test

The relay uses its own Foundry profile, `gov-relay`, which compiles only `gov-relay/` and its imports with the settings above. It writes to `gov-relay/out` and `gov-relay/cache`, so it never touches the PAU artifacts in `out/`.

```shell
FOUNDRY_PROFILE=gov-relay forge build
FOUNDRY_PROFILE=gov-relay forge test            # needs BASE_RPC_URL and MAINNET_RPC_URL
FOUNDRY_PROFILE=gov-relay forge fmt --check     # the default profile's fmt check does not cover gov-relay/
```

- `OseroBaseGovRelayDeployment.t.sol` (Base fork) deploys the relay through the library as the deployer and checks the configuration, the complete role-event history, bytecode parity with Grove's relay, and the permission boundaries of the `Receiver` and `Executor`.
- `OseroBaseGovRelayCrosschain.t.sol` (Ethereum mainnet + Base forks) relays `queue` messages from the Osero SubProxy, both directly and through `SubProxy.exec` of a spell, executes the payload, and checks that messages from other L1 senders fail on L2.
- `OseroBaseGovRelayPostDeploy.t.sol` verifies a real deployment and is skipped unless `POSTDEPLOY_OUTPUT` is set (see below).

### Dry run

Simulate the deployment on a Base fork without broadcasting. The script requires chain ID `8453`, rejects the default sender and the mainnet deployer, deploys, asserts the final state, and prints the would-be addresses:

```shell
FOUNDRY_PROFILE=gov-relay forge script gov-relay/script/DeployBaseGovRelay.s.sol \
  --rpc-url base \
  --sender <base deployer>
```

CREATE addresses depend only on the deployer and its nonce, so the printed addresses are final as long as the deployer sends no other transaction before the broadcast. Foundry checks during simulation that the sender can pay for gas, so the deployer must already hold ETH on Base. A dry run writes its record to `gov-relay/output/8453/dry-run/` (git-ignored), never over the real record.

### Deployment

```shell
FOUNDRY_PROFILE=gov-relay forge script gov-relay/script/DeployBaseGovRelay.s.sol \
  --rpc-url base \
  --ledger --hd-paths "<base-deployer-hd-path>" \
  --sender <base deployer> \
  --slow \
  --broadcast \
  --verify
```

Use `--account <keystore-name>` instead of `--ledger --hd-paths ...` for an encrypted keystore. Never put a private key in an env file or on the command line. `--slow` waits for each transaction to be included before sending the next. `--verify` uses the `base` entry in `[etherscan]` (Etherscan API v2, chain `8453`) with `ETHERSCAN_API_KEY`, and submits the `gov-relay` compiler settings.

The script sends exactly four transactions from the deployer: create `Executor`, create `OptimismReceiver`, `grantRole(SUBMISSION_ROLE, receiver)`, `revokeRole(DEFAULT_ADMIN_ROLE, deployer)`. It then writes `gov-relay/output/8453/base-gov-relay-latest.json` with `executor`, `receiver`, `deployer`, `l1Authority`, `delay`, `gracePeriod` and `deployBlock`. `deployBlock` is the block the script simulated against, a lower bound for the creation block. Commit this file together with `broadcast/DeployBaseGovRelay.s.sol/8453/`.

### Post-deploy verification

```shell
POSTDEPLOY_OUTPUT=gov-relay/output/8453/base-gov-relay-latest.json \
FOUNDRY_PROFILE=gov-relay forge test --match-path gov-relay/test/OseroBaseGovRelayPostDeploy.t.sol -vvv
```

With `POSTDEPLOY_OUTPUT` set (it must point inside `gov-relay/output`), the tests fork Base at the latest block and check the deployed addresses:

- the recorded parameters, the configuration, and bytecode parity with Grove's relay and the local artifacts;
- the `Executor`'s complete `RoleGranted` / `RoleRevoked` / `RoleAdminChanged` history, rebuilt with `eth_getLogs` from `deployBlock`. It must be exactly `RoleGranted(0x00, deployer)`, `RoleGranted(0x00, executor)`, `RoleGranted(SUBMISSION_ROLE, receiver)`, `RoleRevoked(0x00, deployer)`, all sent by the deployer. `AccessControl` is not enumerable, so this history is the only proof that no one else holds a role;
- that both creation transactions were sent by the recorded deployer, the `Receiver` after the `Executor`. The `Executor` and `Receiver` must be the CREATE addresses of consecutive deployer nonces `n` and `n + 1`, and the deployer must be an EOA whose nonce was `n` in the block before the `Executor`'s creation.

Set `POSTDEPLOY_LOGS_BLOCK_RANGE` (default `10000`) if the RPC limits the `eth_getLogs` block range. Run the check right after deployment: later governance role changes are legitimate but fail the history assertion.

### Bytecode verification

Unlike the PAU contracts, the `Executor` and the `OptimismReceiver` are created by standalone CREATE transactions from the deployer EOA. Their runtime code can be checked directly against the `gov-relay` artifacts and against Grove's relay. Build with the profile, which pins solc `0.8.25`, optimizer `200` runs, `cancun`, no via-IR, and the OpenZeppelin copy inside spark-gov-relay:

```shell
FOUNDRY_PROFILE=gov-relay forge build
```

The artifacts are `gov-relay/out/Executor.sol/Executor.json` and `gov-relay/out/OptimismReceiver.sol/OptimismReceiver.json`. Compare `deployedBytecode.object` with the on-chain code after removing the CBOR metadata trailer (see [CBOR metadata trailer](#cbor-metadata-trailer); here the compiler-version bytes decode to `0.8.25`, i.e. `000819`). The `OptimismReceiver` stores `l1Authority` and `target` as immutables, so their byte ranges, listed under `deployedBytecode.immutableReferences`, must be masked on both sides. The `Executor` has no immutables.

```shell
strip() {                       # read hex on stdin, drop the trailing CBOR metadata
  local b; b=$(tr -d '\n' | sed 's/^0x//')
  local n=$(( 16#${b: -4} ))    # last two bytes hold the metadata length
  printf '%s' "${b:0:$(( ${#b} - (n + 2) * 2 ))}"
}

mask() {                        # read hex on stdin, zero the immutable ranges listed in artifact $1
  local b; b=$(tr -d '\n' | sed 's/^0x//')
  local s l
  for r in $(jq -r '.deployedBytecode.immutableReferences[][] | "\(.start):\(.length)"' "$1"); do
    s=${r%:*}; l=${r#*:}
    b="${b:0:$(( s * 2 ))}$(printf '%0*d' $(( l * 2 )) 0)${b:$(( (s + l) * 2 ))}"
  done
  printf '%s' "$b"
}

executor=<deployed executor>
receiver=<deployed receiver>

artifact=gov-relay/out/Executor.sol/Executor.json
expected=$(jq -r .deployedBytecode.object "$artifact" | strip)
[ "$(cast code --rpc-url base "$executor" | strip)" = "$expected" ] && echo "executor matches artifact"
[ "$(cast code --rpc-url base 0x491EDFB0B8b608044e227225C715981a30F3A44E | strip)" = "$expected" ] && echo "artifact matches Grove executor"

artifact=gov-relay/out/OptimismReceiver.sol/OptimismReceiver.json
expected=$(jq -r .deployedBytecode.object "$artifact" | mask "$artifact" | strip)
[ "$(cast code --rpc-url base "$receiver" | mask "$artifact" | strip)" = "$expected" ] && echo "receiver matches artifact"
[ "$(cast code --rpc-url base 0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a | mask "$artifact" | strip)" = "$expected" ] && echo "artifact matches Grove receiver"
```

Then confirm the masked immutables and the constructor arguments from on-chain state: `l1Authority()` must be the Osero SubProxy, `target()` the `Executor`, `delay()` `0` and `gracePeriod()` `604800`. The fork and post-deploy tests assert all of this, including that each immutable occupies the same positions in Grove's `Receiver`, holding Grove's own values there.

Do not compile these two contracts with the default profile. Any other solc version, optimizer setting or EVM version gives different runtime code (the parity test fails, for example, with solc `0.8.34`, `10000` runs, or `shanghai`).

## License

AGPL-3.0-or-later. The Solidity sources use `SPDX-License-Identifier: AGPL-3.0-or-later`.
