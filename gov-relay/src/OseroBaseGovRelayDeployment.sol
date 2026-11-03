// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Executor} from "spark-gov-relay/Executor.sol";
import {OptimismReceiver} from "xchain-helpers/receivers/OptimismReceiver.sol";
import {Ethereum as OseroEthereumRegistry} from "@osero/address-registry/Ethereum.sol";

/// @title Osero Base Governance Relay Deployment Library
/// @notice Deploys and configures the Osero governance relay on Base: a spark-gov-relay `Executor`
///         and an xchain-helpers `OptimismReceiver` that forwards messages from the Osero SubProxy on
///         Ethereum mainnet to that Executor.
/// @dev Shared by the deployment script and the fork tests so both paths use the exact same
///      parameters and permission sequence. Mirrors Grove's Base relay
///      (Executor `0x491EDFB0B8b608044e227225C715981a30F3A44E`, Receiver
///      `0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a`). spark-gov-relay v1.0.1 ships no `deploy/`
///      library, so the permission calls match the later `Deploy.setUpExecutorPermissions` without
///      a guardian.
library OseroBaseGovRelayDeployment {
    /// @notice Thrown when `deployer` is not the account the Executor constructor made admin.
    error DeployerNotExecutorAdmin(address deployer);

    /// @notice Base mainnet chain ID.
    uint256 internal constant CHAIN_ID = 8453;

    /// @notice Executor timelock between queueing and execution. Matches the Grove and Spark
    ///         Executors on Base, which both read `delay() == 0`.
    uint256 internal constant DELAY = 0;

    /// @notice Window after the delay during which a queued actions set can be executed. Matches
    ///         the Grove and Spark Executors on Base, which both read `gracePeriod() == 604800`.
    uint256 internal constant GRACE_PERIOD = 7 days;

    /// @notice Only L1 sender the Receiver accepts: the Osero SubProxy on Ethereum mainnet
    ///         (chainlog key `OSERO_SUBPROXY`).
    address internal constant L1_AUTHORITY = OseroEthereumRegistry.OSERO_PROXY;

    /// @notice Deploys the Executor and Receiver and hands control of the Executor to the Receiver.
    /// @dev    Executes, in order:
    ///         1. `new Executor(DELAY, GRACE_PERIOD)`, whose constructor grants `DEFAULT_ADMIN_ROLE`
    ///            to `msg.sender` and to the Executor itself;
    ///         2. `new OptimismReceiver(L1_AUTHORITY, executor)`;
    ///         3. `executor.grantRole(SUBMISSION_ROLE, receiver)`;
    ///         4. `executor.revokeRole(DEFAULT_ADMIN_ROLE, deployer)`.
    ///         No `GUARDIAN_ROLE` is granted. The Executor keeps its own `DEFAULT_ADMIN_ROLE`, which
    ///         it needs for delegatecall execution and self-reconfiguration through governance.
    /// @param  deployer The account that sends the deployment transactions, i.e. `msg.sender` of the
    ///         Executor constructor. Its constructor-granted admin role is revoked.
    /// @return executor The deployed Executor.
    /// @return receiver The deployed OptimismReceiver.
    function deploy(address deployer) internal returns (address executor, address receiver) {
        Executor executor_ = new Executor(DELAY, GRACE_PERIOD);
        executor = address(executor_);

        receiver = address(new OptimismReceiver(L1_AUTHORITY, executor));

        executor_.grantRole(executor_.SUBMISSION_ROLE(), receiver);

        // Revoking from an account that does not hold the role is a silent no-op, which would leave
        // the real deployer as admin. Fail loudly instead.
        bytes32 defaultAdminRole = executor_.DEFAULT_ADMIN_ROLE();
        if (!executor_.hasRole(defaultAdminRole, deployer)) revert DeployerNotExecutorAdmin(deployer);
        executor_.revokeRole(defaultAdminRole, deployer);
    }
}
