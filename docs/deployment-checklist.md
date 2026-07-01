# AccessControls.sol

Address: [`0x791D2a017532CfAD881c446e6bF93BbC3c0778b2`](https://etherscan.io/address/0x791D2a017532CfAD881c446e6bF93BbC3c0778b2)

Deployment tx: [`0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640`](https://etherscan.io/tx/0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Scope checked here is Ethereum mainnet only.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.
  - Deployment used Ledger (`--ledger`). `.env` contains `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY`; no private-key-like env variable was found by variable name.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.7.1`; latest Foundry GitHub release checked as `v1.7.1`, published `2026-05-08`.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, build timestamp `2026-05-08T07:50:55.527285345Z`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/diamond-pau/commit/5c5ad6ae174bf467081ca82342ced2bd42a5c732
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/diamond-pau` is checked out at `5c5ad6ae174bf467081ca82342ced2bd42a5c732`.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No root package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Ledger sender: [`0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`](https://etherscan.io/address/0xa71657b776d01A35dEbe9D64d9fa23dBC5676696). Etherscan history inspected.
- [x] Ensure the deployer has enough gas tokens.
  - Mainnet deployment succeeded; tx gas used `5,606,309`.
- [x] Document the command planned to be used to perform the deployment.

```bash
forge script script/Deploy.s.sol \
  --rpc-url "$MAINNET_RPC_URL" \
  --ledger \
  --sender 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696 \
  --verify \
  --broadcast \
  --hd-paths "<redacted-ledger-hd-path>"
```

- [x] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.

### Deployment

- [x] Set production RPC URL.
  - `MAINNET_RPC_URL` configured; value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - `ETHERSCAN_API_KEY` configured; value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Deployment transaction succeeded and `AccessControls` is verified on Etherscan.
- [x] Inspect the transaction history of the deployer.
  - Inspected on Etherscan.
- [x] Perform all relevant checks documented in the technical doc.
  - Etherscan verified with `v0.8.34+commit.80d5c536`, optimizer enabled, `200` runs, EVM `cancun`.
  - Runtime bytecode matches the local artifact after stripping solc CBOR metadata.
  - `OSERO_PROXY` has `DEFAULT_ADMIN_ROLE`; allocator agent has `ALLOCATOR_ROLE`.
- [x] Independently verify the deployment by another member of the team.

# ALMProxy.sol

Address: [`0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884`](https://etherscan.io/address/0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884)

Deployment tx: [`0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640`](https://etherscan.io/tx/0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Scope checked here is Ethereum mainnet only.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.
  - Deployment used Ledger (`--ledger`). `.env` contains `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY`; no private-key-like env variable was found by variable name.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.7.1`; latest Foundry GitHub release checked as `v1.7.1`, published `2026-05-08`.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, build timestamp `2026-05-08T07:50:55.527285345Z`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/diamond-pau/commit/5c5ad6ae174bf467081ca82342ced2bd42a5c732
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/diamond-pau` is checked out at `5c5ad6ae174bf467081ca82342ced2bd42a5c732`.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No root package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Ledger sender: [`0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`](https://etherscan.io/address/0xa71657b776d01A35dEbe9D64d9fa23dBC5676696). Etherscan history inspected.
- [x] Ensure the deployer has enough gas tokens.
  - Mainnet deployment succeeded; tx gas used `5,606,309`.
- [x] Document the command planned to be used to perform the deployment.

```bash
forge script script/Deploy.s.sol \
  --rpc-url "$MAINNET_RPC_URL" \
  --ledger \
  --sender 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696 \
  --verify \
  --broadcast \
  --hd-paths "<redacted-ledger-hd-path>"
```

- [x] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.

### Deployment

- [x] Set production RPC URL.
  - `MAINNET_RPC_URL` configured; value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - `ETHERSCAN_API_KEY` configured; value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Deployment transaction succeeded and `ALMProxy` is verified on Etherscan.
- [x] Inspect the transaction history of the deployer.
  - Inspected on Etherscan.
- [x] Perform all relevant checks documented in the technical doc.
  - Etherscan verified with `v0.8.34+commit.80d5c536`, optimizer enabled, `200` runs, EVM `cancun`.
  - Runtime bytecode matches the local artifact after stripping solc CBOR metadata.
  - `OSERO_PROXY` has `DEFAULT_ADMIN_ROLE`; `Controller` has proxy `CONTROLLER` role.
- [x] Independently verify the deployment by another member of the team.

# RateLimits.sol

Address: [`0xe9a78f34fe497e2186f81b8c014cd93b308bc62a`](https://etherscan.io/address/0xe9a78f34fe497e2186f81b8c014cd93b308bc62a)

Deployment tx: [`0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640`](https://etherscan.io/tx/0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Scope checked here is Ethereum mainnet only.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.
  - Deployment used Ledger (`--ledger`). `.env` contains `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY`; no private-key-like env variable was found by variable name.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.7.1`; latest Foundry GitHub release checked as `v1.7.1`, published `2026-05-08`.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, build timestamp `2026-05-08T07:50:55.527285345Z`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/diamond-pau/commit/5c5ad6ae174bf467081ca82342ced2bd42a5c732
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/diamond-pau` is checked out at `5c5ad6ae174bf467081ca82342ced2bd42a5c732`.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No root package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Ledger sender: [`0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`](https://etherscan.io/address/0xa71657b776d01A35dEbe9D64d9fa23dBC5676696). Etherscan history inspected.
- [x] Ensure the deployer has enough gas tokens.
  - Mainnet deployment succeeded; tx gas used `5,606,309`.
- [x] Document the command planned to be used to perform the deployment.

```bash
forge script script/Deploy.s.sol \
  --rpc-url "$MAINNET_RPC_URL" \
  --ledger \
  --sender 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696 \
  --verify \
  --broadcast \
  --hd-paths "<redacted-ledger-hd-path>"
```

- [x] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.

### Deployment

- [x] Set production RPC URL.
  - `MAINNET_RPC_URL` configured; value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - `ETHERSCAN_API_KEY` configured; value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Deployment transaction succeeded and `RateLimits` is verified on Etherscan.
- [x] Inspect the transaction history of the deployer.
  - Inspected on Etherscan.
- [x] Perform all relevant checks documented in the technical doc.
  - Etherscan verified with `v0.8.34+commit.80d5c536`, optimizer enabled, `200` runs, EVM `cancun`.
  - Runtime bytecode matches the local artifact after stripping solc CBOR metadata.
  - `OSERO_PROXY` has `DEFAULT_ADMIN_ROLE`; `Controller` has rate-limits `CONTROLLER` role.
- [x] Independently verify the deployment by another member of the team.

# Controller.sol

Address: [`0x24169Afb34fAe4D4356BC54Bd80319131e35ca38`](https://etherscan.io/address/0x24169Afb34fAe4D4356BC54Bd80319131e35ca38)

Deployment tx: [`0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640`](https://etherscan.io/tx/0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Scope checked here is Ethereum mainnet only.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.
  - Deployment used Ledger (`--ledger`). `.env` contains `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY`; no private-key-like env variable was found by variable name.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.7.1`; latest Foundry GitHub release checked as `v1.7.1`, published `2026-05-08`.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, build timestamp `2026-05-08T07:50:55.527285345Z`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/diamond-pau/commit/5c5ad6ae174bf467081ca82342ced2bd42a5c732
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/diamond-pau` is checked out at `5c5ad6ae174bf467081ca82342ced2bd42a5c732`.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No root package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Ledger sender: [`0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`](https://etherscan.io/address/0xa71657b776d01A35dEbe9D64d9fa23dBC5676696). Etherscan history inspected.
- [x] Ensure the deployer has enough gas tokens.
  - Mainnet deployment succeeded; tx gas used `5,606,309`.
- [x] Document the command planned to be used to perform the deployment.

```bash
forge script script/Deploy.s.sol \
  --rpc-url "$MAINNET_RPC_URL" \
  --ledger \
  --sender 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696 \
  --verify \
  --broadcast \
  --hd-paths "<redacted-ledger-hd-path>"
```

- [x] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.

### Deployment

- [x] Set production RPC URL.
  - `MAINNET_RPC_URL` configured; value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - `ETHERSCAN_API_KEY` configured; value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Deployment transaction succeeded and `Controller` is verified on Etherscan.
- [x] Inspect the transaction history of the deployer.
  - Inspected on Etherscan.
- [x] Perform all relevant checks documented in the technical doc.
  - Etherscan verified with `v0.8.34+commit.80d5c536`, optimizer enabled, `200` runs, EVM `cancun`.
  - Runtime bytecode matches the local artifact after stripping solc CBOR metadata and masking `beacon` immutable byte ranges.
  - Constructor/state wiring verified: `accessControls()`, `proxy()`, `rateLimits()`, and `beacon()` point to the expected contracts.
  - Integrations verified: `AAVE_FACET` then `USDS_FACET`.
- [x] Independently verify the deployment by another member of the team.

# AdministeredAgent.sol

Address: [`0x1837505d104f7a6d8b7e19452610b0a3d652ef12`](https://etherscan.io/address/0x1837505d104f7a6d8b7e19452610b0a3d652ef12)

Deployment tx: [`0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640`](https://etherscan.io/tx/0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Scope checked here is Ethereum mainnet only.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.
  - Deployment used Ledger (`--ledger`). `.env` contains `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY`; no private-key-like env variable was found by variable name.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.7.1`; latest Foundry GitHub release checked as `v1.7.1`, published `2026-05-08`.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.7.1`, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, build timestamp `2026-05-08T07:50:55.527285345Z`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/pau-administered-agent/commit/bfaaf709a8664d74d12604455f0365a0a12439cf
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/pau-administered-agent` is checked out at `bfaaf709a8664d74d12604455f0365a0a12439cf`.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No root package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Ledger sender: [`0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`](https://etherscan.io/address/0xa71657b776d01A35dEbe9D64d9fa23dBC5676696). Etherscan history inspected.
- [x] Ensure the deployer has enough gas tokens.
  - Mainnet deployment succeeded; tx gas used `5,606,309`.
- [x] Document the command planned to be used to perform the deployment.

```bash
forge script script/Deploy.s.sol \
  --rpc-url "$MAINNET_RPC_URL" \
  --ledger \
  --sender 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696 \
  --verify \
  --broadcast \
  --hd-paths "<redacted-ledger-hd-path>"
```

- [x] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.

### Deployment

- [x] Set production RPC URL.
  - `MAINNET_RPC_URL` configured; value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - `ETHERSCAN_API_KEY` configured; value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Deployment transaction succeeded and `AdministeredAgent` is verified on Etherscan.
- [x] Inspect the transaction history of the deployer.
  - Inspected on Etherscan.
- [x] Perform all relevant checks documented in the technical doc.
  - Etherscan verified with `v0.8.34+commit.80d5c536`, optimizer enabled, `200` runs, EVM `cancun`.
  - Runtime bytecode matches the local artifact after stripping solc CBOR metadata.
  - Agent permissions verified: one admin (`OSERO_PROXY`), two actors (`SOTER_OPERATOR`, `OSERO_OPERATOR`), zero grantors, one revoker (`SOTER_FREEZER`).
- [x] Independently verify the deployment by another member of the team.

# Reproduction commands

```bash
git submodule update --init --recursive
devenv shell forge --version
devenv shell forge build
devenv shell forge test --match-path test/OseroPAUDeployment.t.sol
devenv shell cast receipt --rpc-url mainnet 0xff3acce7d732e47730320fa202a8553626fc14286048be4c3c1a5fb173e43640 --json
```
