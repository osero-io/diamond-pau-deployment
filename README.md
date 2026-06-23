# Osero PAU Deployment

This repository contains the canonical Foundry deployment package for the Osero PAU stack on Ethereum mainnet.

The code does not implement new PAU facets. It composes existing Sky PAU contracts and Osero registry addresses into one deployment configuration:

- deploy a PAU proxy, controller, access-control contract, and rate-limit contract through Sky's `DefaultPAUAssembler`;
- enable the `AAVE_FACET` and `USDS_FACET` controller integrations in a fixed order;
- configure Osero's proxy as the component administrator;
- configure one allocator `AdministeredAgent` administered by Osero, operated by the Soter relayer and Osero operator, and revocable by the Soter freezer.

## Repository layout

```text
src/OseroPAUDeployment.sol      Shared deployment library and configuration.
script/Deploy.s.sol            Broadcast script that calls the deployment library and logs addresses.
test/OseroPAUDeployment.t.sol   Mainnet-fork tests covering deployment config, permissions, wiring, and USDS/Aave flows.
foundry.toml                   Foundry compiler, remapping, RPC, and Etherscan settings.
lib/                           Git submodules for PAU assemblers, registries, and forge-std.
```

## External dependencies

The deployment imports addresses and contracts from submodules:

- `sky-pau-registry`: Sky PAU mainnet contract addresses, including `DEFAULT_PAU_ASSEMBLER`, `AAVE_FACET`, and `USDS_FACET`.
- `pau-assemblers`: `DefaultPAUAssembler` and assembler interfaces.
- `osero-address-registry`: Osero operational addresses, allocator vault/buffer addresses, and ilk constants.
- `forge-std`: Foundry test and script utilities.

After cloning, install dependencies before building:

```shell
forge install
```

## Environment

The test suite forks Ethereum mainnet and `foundry.toml` resolves the `mainnet` RPC endpoint from `MAINNET_RPC_URL`.

```shell
export MAINNET_RPC_URL=<ethereum-mainnet-rpc-url>
export ETHERSCAN_API_KEY=<etherscan-api-key> # only needed for verification
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

## License

AGPL-3.0-or-later. The Solidity sources use `SPDX-License-Identifier: AGPL-3.0-or-later`.
