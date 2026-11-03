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

# Executor.sol (Osero Executor on Base)

Address: [`0x5528A5A043F74C2250c0d0983E4633F38395e19F`](https://basescan.org/address/0x5528A5A043F74C2250c0d0983E4633F38395e19F)

Deployment tx: [`0x576ecf4a8b1a375db0b5de1a66fd355c149fb0ec22e17ed4d3eb23049ef214fe`](https://basescan.org/tx/0x576ecf4a8b1a375db0b5de1a66fd355c149fb0ec22e17ed4d3eb23049ef214fe)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Base deployer [`0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C`](https://basescan.org/address/0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C) is a fresh EOA created for Osero's Base deployments. It is not the Ethereum mainnet deployer `0xa71657b776d01A35dEbe9D64d9fa23dBC5676696` (which `DeployBaseGovRelay.s.sol` rejects), and it has sent no transaction on Ethereum mainnet (nonce `0`).
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
  - Base nonce is `4`: the deployer sent only the four transactions of `DeployBaseGovRelay.s.sol` (two creations, one `grantRole`, one `revokeRole`).
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - `forge Version: 1.8.6`, published `2026-10-21`: the newest stable Foundry release at least one week old at the broadcast on `2026-11-03` (`v1.8.7`, published `2026-10-29`, and `v1.9.0`, published `2026-11-02`, were younger).
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.8.6`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sparkdotfi/spark-gov-relay/commit/5c166763464802a9f985fa50560c9e9fb0cf6c2b (tag `v1.0.1`, final audited commit; reports in `lib/spark-gov-relay/audits/`).
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/spark-gov-relay` is checked out at `5c166763464802a9f985fa50560c9e9fb0cf6c2b` (`v1.0.1`), with `lib/spark-gov-relay/lib/openzeppelin-contracts` at `dbb6104ce834628e473d2173bbc9d47f81a9eec3`. The broadcast commit `664d6db` pins the same revisions.
  - The Standard JSON input built from these sources recompiled to the on-chain runtime bytecode, metadata hash included.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Sender: [`0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C`](https://basescan.org/address/0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C), the `from` of all four transactions. Its nonce was `0` on Base and on Ethereum mainnet before the deployment.
- [x] Ensure the deployer has enough gas tokens.
  - Funded with `0.004194` ETH on Base. The four transactions used `2,254,474` gas (fork dry-run estimate `2,937,209`) and cost about `0.0000116` ETH including L1 data fees; `0.004182` ETH remains.
- [x] Document the command planned to be used to perform the deployment.

```bash
FOUNDRY_PROFILE=gov-relay forge script gov-relay/script/DeployBaseGovRelay.s.sol \
  --rpc-url base \
  --ledger \
  --sender 0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C \
  --hd-paths "<redacted-ledger-hd-path>" \
  --slow \
  --broadcast \
  --verify
```

- [ ] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - No Tenderly testnet was used: the project rule was fork dry-runs only.
  - Instead, the script was dry-run on a local anvil fork of Base, including once with the real deployer `0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C` as `--sender`. That run predicted exactly the deployed addresses and the same four transactions (create `Executor(0, 604800)`, create `OptimismReceiver(0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3, executor)`, `grantRole(SUBMISSION_ROLE, receiver)`, `revokeRole(DEFAULT_ADMIN_ROLE, deployer)`), with an estimated `2,937,209` gas.

### Deployment

- [x] Set production RPC URL.
  - A Base mainnet RPC was set: the broadcast landed on chain `8453`. Value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - An Etherscan API v2 key was set: Basescan accepted the `--verify` submissions into its queue. Value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Broadcast with `--verify` from repo commit `664d6db` on 2026-11-03 (blocks `53470347` to `53470367`); all four transactions succeeded. The broadcast files and the deployment record `gov-relay/output/8453/base-gov-relay-latest.json` (`deployBlock` `53470334`, the script's lower bound) were committed in `12dc417`.
  - `--verify` produced a Sourcify exact match (creation and runtime) at 2026-11-03 18:21 UTC. The Basescan API submission stayed "Pending in queue" and timed out, so the Executor was then verified on Basescan with its Standard-Json-Input (`forge verify-contract --show-standard-json-input`).
- [x] Inspect the transaction history of the deployer.
  - Checked over Base RPC (nonce, receipts, balance history): exactly four outgoing transactions, all status `1`, nonces `0` to `3` in this order:
    - [`0x576ecf4a8b1a375db0b5de1a66fd355c149fb0ec22e17ed4d3eb23049ef214fe`](https://basescan.org/tx/0x576ecf4a8b1a375db0b5de1a66fd355c149fb0ec22e17ed4d3eb23049ef214fe): create Executor, block `53470347`, `1,891,500` gas.
    - [`0x5aa8789aa53241e4cb71283626f5bd56dbbe5279120740ca00517909ab15c65c`](https://basescan.org/tx/0x5aa8789aa53241e4cb71283626f5bd56dbbe5279120740ca00517909ab15c65c): create OptimismReceiver, block `53470353`, `284,263` gas.
    - [`0xb33e345fa9b502558f9035d925312ec4639d5ef4ab7a5cb1ee49d41fe59ad3e7`](https://basescan.org/tx/0xb33e345fa9b502558f9035d925312ec4639d5ef4ab7a5cb1ee49d41fe59ad3e7): `grantRole(SUBMISSION_ROLE, receiver)`, block `53470359`, `51,552` gas.
    - [`0xd4b23ae93b3b92cc84ec925272e28c5478321acd1994434bd2b96b679fff970c`](https://basescan.org/tx/0xd4b23ae93b3b92cc84ec925272e28c5478321acd1994434bd2b96b679fff970c): `revokeRole(DEFAULT_ADMIN_ROLE, deployer)`, block `53470367`, `27,159` gas.
  - The only incoming transfer on Base was the funding of `0.004194` ETH from `0xa71657b776d01A35dEbe9D64d9fa23dBC5676696` in [`0xb39c9e4f5e6d82acc4568329f2f73ede8c10d5da449e8f9674ee9c64dd002472`](https://basescan.org/tx/0xb39c9e4f5e6d82acc4568329f2f73ede8c10d5da449e8f9674ee9c64dd002472) (block `53470301`). On Ethereum mainnet the deployer only received `0.004245` ETH from the same address in [`0x42b6af4697ddf283f17b964ae326c6bb116f99919dd261c93339effc34e42e66`](https://etherscan.io/tx/0x42b6af4697ddf283f17b964ae326c6bb116f99919dd261c93339effc34e42e66), still unspent.
- [x] Perform all relevant checks documented in the technical doc.
  - Basescan verified with `v0.8.25+commit.b61c2a91`, optimizer enabled, `200` runs, EVM `cancun`, no via-IR, license GNU AGPLv3; constructor arguments `(0, 604800)`.
  - Before submission, the Standard JSON input was compiled with solc `0.8.25`; its runtime bytecode was identical to on-chain, metadata hash included.
  - Runtime bytecode matches `gov-relay/out/Executor.sol/Executor.json` and Grove's Executor `0x491EDFB0B8b608044e227225C715981a30F3A44E` after stripping the solc CBOR metadata (`test_postDeploy_bytecodeParity`).
  - `delay() == 0`, `gracePeriod() == 604800`; `DEFAULT_ADMIN_ROLE` is held by the Executor itself and not the deployer; `SUBMISSION_ROLE` is held by the Receiver; no `GUARDIAN_ROLE` holder; the role-event history matches the four transactions above.
  - Post-deploy tests passed against the live deployment on 2026-11-03, 5/5 (`test_postDeploy_bytecodeParity`, `_configuration`, `_creationTransactions`, `_outputRecord`, `_roleHistory`): `POSTDEPLOY_OUTPUT=gov-relay/output/8453/base-gov-relay-latest.json FOUNDRY_PROFILE=gov-relay forge test --match-path gov-relay/test/OseroBaseGovRelayPostDeploy.t.sol -vvv`.
- [ ] Independently verify the deployment by another member of the team.
  - TODO: another team member must independently check the deployment (for example, rerun the reproduction commands below and review both contracts on Basescan).

# OptimismReceiver.sol (Osero Receiver on Base)

Address: [`0x63B4A33770F58205F3D646C5A635fF417a3819C3`](https://basescan.org/address/0x63B4A33770F58205F3D646C5A635fF417a3819C3)

Deployment tx: [`0x5aa8789aa53241e4cb71283626f5bd56dbbe5279120740ca00517909ab15c65c`](https://basescan.org/tx/0x5aa8789aa53241e4cb71283626f5bd56dbbe5279120740ca00517909ab15c65c)

## Deployment Checklist

### General rules

- [x] A different deployer EOA shall be used across different chains.
  - Same Base-only deployer as the Executor, [`0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C`](https://basescan.org/address/0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C); not the Ethereum mainnet deployer `0xa71657b776d01A35dEbe9D64d9fa23dBC5676696`.
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
  - Base nonce is `4`, only the four script transactions (see the Executor entry); Ethereum mainnet nonce is `0`.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.

### Deployment preparation

- [x] Update your Foundry to the latest stable version, and ensure that the updated version is at least one week old.
  - Same as the Executor entry: `forge Version: 1.8.6`, the newest stable release at least one week old at the broadcast.
- [x] Note down your Foundry version used for the deployments.
  - `forge Version: 1.8.6`.
- [x] Find the latest audits for the contract to be deployed.
  - Commit URL: https://github.com/sky-ecosystem/xchain-helpers/commit/6be2397aa4f6e9465a763f609e25a9111ffff200 (pinned by spark-gov-relay `v1.0.1` as `lib/xchain-helpers`, submodule URL `marsfoundation/xchain-helpers`; `OptimismReceiver.sol` is identical to xchain-helpers `v1.2.0`).
- [x] Freshly clone the repository with the contract at the commit determined above.
  - `lib/spark-gov-relay/lib/xchain-helpers` is checked out at `6be2397aa4f6e9465a763f609e25a9111ffff200`, and `OptimismReceiver` was compiled against `lib/spark-gov-relay/lib/openzeppelin-contracts` (`dbb6104ce834628e473d2173bbc9d47f81a9eec3`), as pinned by the broadcast commit `664d6db`.
  - The Standard JSON input built from these sources recompiled to the on-chain runtime bytecode (immutables masked), metadata hash included.
- [x] Init submodules and install npm packages using the appropriate package manager.
  - Reproducible setup: `git submodule update --init --recursive`. No package-manager install is required.
- [x] Check the deployer address to match the expected value and expected transaction history.
  - Sender: [`0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C`](https://basescan.org/address/0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C). The Receiver creation is its nonce `1` transaction, right after the Executor creation (nonce `0`).
- [x] Ensure the deployer has enough gas tokens.
  - Covered by the single script run (see the Executor entry); the Receiver creation used `284,263` gas.
- [x] Document the command planned to be used to perform the deployment.

```bash
FOUNDRY_PROFILE=gov-relay forge script gov-relay/script/DeployBaseGovRelay.s.sol \
  --rpc-url base \
  --ledger \
  --sender 0x3841ec3CB6aEE239ecD43d49755F6f25aDcA9D5C \
  --hd-paths "<redacted-ledger-hd-path>" \
  --slow \
  --broadcast \
  --verify
```

- [ ] Perform a test deployment using a fresh private Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - No Tenderly testnet was used: the project rule was fork dry-runs only.
  - The anvil fork dry-run with the real deployer as `--sender` (see the Executor entry) predicted exactly this Receiver address and its creation as the second transaction, with constructor arguments `(0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3, executor)`.

### Deployment

- [x] Set production RPC URL.
  - A Base mainnet RPC was set: the broadcast landed on chain `8453`. Value intentionally not documented.
- [x] Set API key for the verification provider compatible with the target chain.
  - An Etherscan API v2 key was set: Basescan accepted the `--verify` submissions into its queue. Value intentionally not documented.
- [x] Execute the production deployment command with verification enabled.
  - Same broadcast as the Executor (repo commit `664d6db`); the Receiver creation succeeded in block `53470353`.
  - `--verify` produced a Sourcify exact match (creation and runtime) at 2026-11-03 18:21 UTC. The Basescan API submission stayed "Pending in queue" and timed out, so the Receiver was then verified on Basescan with its Standard-Json-Input (`forge verify-contract --show-standard-json-input`).
- [x] Inspect the transaction history of the deployer.
  - Exactly the four script transactions, the Receiver creation second (nonce `1`); see the Executor entry for the full list and the funding transfers.
- [x] Perform all relevant checks documented in the technical doc.
  - Basescan verified with `v0.8.25+commit.b61c2a91`, optimizer enabled, `200` runs, EVM `cancun`, no via-IR, license GNU AGPLv3; constructor arguments `(0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3, 0x5528A5A043F74C2250c0d0983E4633F38395e19F)`.
  - Before submission, the Standard JSON input was compiled with solc `0.8.25`; its runtime bytecode was identical to on-chain with the 4 immutable ranges masked, metadata hash included.
  - Runtime bytecode matches `gov-relay/out/OptimismReceiver.sol/OptimismReceiver.json` and Grove's Receiver `0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a` after stripping the solc CBOR metadata and masking the `l1Authority` and `target` immutables (`test_postDeploy_bytecodeParity`).
  - `l1Authority() == 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3` (Osero SubProxy, chainlog `OSERO_SUBPROXY`), `target() == 0x5528A5A043F74C2250c0d0983E4633F38395e19F` (the Executor), `l2CrossDomain() == 0x4200000000000000000000000000000000000007`.
  - Post-deploy tests passed on 2026-11-03 (see the Executor entry), including `test_postDeploy_creationTransactions`: the Receiver was created by the deployer at the nonce right after the Executor.
- [ ] Independently verify the deployment by another member of the team.
  - TODO: another team member must independently check the deployment (for example, rerun the reproduction commands below and review both contracts on Basescan).

# Reproduction commands (Base governance relay)

```bash
git submodule update --init --recursive
forge --version
FOUNDRY_PROFILE=gov-relay forge build
FOUNDRY_PROFILE=gov-relay forge test
POSTDEPLOY_OUTPUT=gov-relay/output/8453/base-gov-relay-latest.json \
  FOUNDRY_PROFILE=gov-relay forge test --match-path gov-relay/test/OseroBaseGovRelayPostDeploy.t.sol -vvv
cast receipt --rpc-url base 0x576ecf4a8b1a375db0b5de1a66fd355c149fb0ec22e17ed4d3eb23049ef214fe --json
cast receipt --rpc-url base 0x5aa8789aa53241e4cb71283626f5bd56dbbe5279120740ca00517909ab15c65c --json
```
