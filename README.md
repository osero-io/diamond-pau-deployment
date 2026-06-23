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

After cloning, initialize submodules before building:

```shell
git submodule update --init --recursive
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
