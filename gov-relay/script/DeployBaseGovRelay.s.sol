// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {Executor} from "spark-gov-relay/Executor.sol";
import {OptimismReceiver} from "xchain-helpers/receivers/OptimismReceiver.sol";

import {OseroBaseGovRelayDeployment} from "../src/OseroBaseGovRelayDeployment.sol";

/// @title Osero Base Governance Relay Deployment Script
/// @notice Broadcasts the Osero governance relay deployment on Base, checks the resulting state,
///         logs the addresses and writes them to `gov-relay/output/8453/`.
contract DeployBaseGovRelayScript is Script {
    /// @notice Ethereum mainnet PAU deployer. Each chain needs its own deployer EOA, so it must not
    ///         be used here.
    address internal constant MAINNET_PAU_DEPLOYER = 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696;

    /// @notice Output directory for this chain.
    string internal constant OUTPUT_DIR = "gov-relay/output/8453";

    /// @notice Output file name. Broadcasts write `OUTPUT_DIR/<name>`; dry runs write
    ///         `OUTPUT_DIR/dry-run/<name>` so they never overwrite a real deployment record.
    string internal constant OUTPUT_FILE = "base-gov-relay-latest.json";

    /// @notice Deploys the relay from the broadcasting account.
    /// @dev Deployment configuration lives in {OseroBaseGovRelayDeployment}. This script handles
    ///      broadcasting, post-deployment checks, operator-facing output and the output file.
    /// @return executor The deployed Executor.
    /// @return receiver The deployed OptimismReceiver.
    function run() external returns (address executor, address receiver) {
        require(block.chainid == OseroBaseGovRelayDeployment.CHAIN_ID, "DeployBaseGovRelay/not-base");

        uint256 deployBlock = block.number;

        vm.startBroadcast();

        (, address deployer,) = vm.readCallers();
        _checkDeployer(deployer);
        uint64 deployerNonce = vm.getNonce(deployer);

        (executor, receiver) = OseroBaseGovRelayDeployment.deploy(deployer);

        vm.stopBroadcast();

        // CREATE addresses depend only on the deployer and its nonce, so the would-be addresses printed
        // by a dry run are final as long as the deployer sends nothing else before broadcasting.
        require(executor == vm.computeCreateAddress(deployer, deployerNonce), "DeployBaseGovRelay/executor-address");
        require(receiver == vm.computeCreateAddress(deployer, deployerNonce + 1), "DeployBaseGovRelay/receiver-address");

        _checkDeployment(executor, receiver, deployer);

        string memory outputPath = _writeOutput(executor, receiver, deployer, deployBlock);

        console.log("Deployer:", deployer);
        console.log("Deployer nonce before deployment:", deployerNonce);
        console.log("Executor deployed at:", executor);
        console.log("Receiver deployed at:", receiver);
        console.log("L1 authority (Osero SubProxy):", OseroBaseGovRelayDeployment.L1_AUTHORITY);
        console.log("Executor delay:", OseroBaseGovRelayDeployment.DELAY);
        console.log("Executor grace period:", OseroBaseGovRelayDeployment.GRACE_PERIOD);
        console.log("Deploy block (lower bound):", deployBlock);
        console.log("Output written to:", outputPath);
    }

    /// @notice Rejects senders that cannot or must not perform this deployment.
    /// @param  deployer The broadcasting account.
    function _checkDeployer(address deployer) internal view {
        require(deployer != DEFAULT_SENDER, "DeployBaseGovRelay/sender-not-set");
        require(deployer != MAINNET_PAU_DEPLOYER, "DeployBaseGovRelay/mainnet-deployer");
        require(deployer.code.length == 0, "DeployBaseGovRelay/deployer-not-eoa");
    }

    /// @notice Asserts the final relay configuration and permissions.
    /// @param  executor The deployed Executor.
    /// @param  receiver The deployed OptimismReceiver.
    /// @param  deployer The broadcasting account.
    function _checkDeployment(address executor, address receiver, address deployer) internal view {
        Executor executor_ = Executor(executor);
        OptimismReceiver receiver_ = OptimismReceiver(receiver);

        bytes32 defaultAdminRole = executor_.DEFAULT_ADMIN_ROLE();
        bytes32 submissionRole = executor_.SUBMISSION_ROLE();
        bytes32 guardianRole = executor_.GUARDIAN_ROLE();

        require(executor_.delay() == OseroBaseGovRelayDeployment.DELAY, "DeployBaseGovRelay/delay");
        require(executor_.gracePeriod() == OseroBaseGovRelayDeployment.GRACE_PERIOD, "DeployBaseGovRelay/grace-period");
        require(executor_.actionsSetCount() == 0, "DeployBaseGovRelay/actions-set-count");

        require(executor_.hasRole(defaultAdminRole, executor), "DeployBaseGovRelay/executor-not-self-admin");
        require(!executor_.hasRole(defaultAdminRole, deployer), "DeployBaseGovRelay/deployer-still-admin");
        require(!executor_.hasRole(defaultAdminRole, receiver), "DeployBaseGovRelay/receiver-admin");

        require(executor_.hasRole(submissionRole, receiver), "DeployBaseGovRelay/receiver-not-submitter");
        require(!executor_.hasRole(submissionRole, deployer), "DeployBaseGovRelay/deployer-submitter");

        require(!executor_.hasRole(guardianRole, deployer), "DeployBaseGovRelay/deployer-guardian");
        require(!executor_.hasRole(guardianRole, receiver), "DeployBaseGovRelay/receiver-guardian");

        require(receiver_.l1Authority() == OseroBaseGovRelayDeployment.L1_AUTHORITY, "DeployBaseGovRelay/l1-authority");
        require(receiver_.target() == executor, "DeployBaseGovRelay/target");
        require(
            address(receiver_.l2CrossDomain()) == 0x4200000000000000000000000000000000000007,
            "DeployBaseGovRelay/l2-cross-domain"
        );
    }

    /// @notice Writes the deployment record consumed by the post-deploy verification tests.
    /// @param  executor    The deployed Executor.
    /// @param  receiver    The deployed OptimismReceiver.
    /// @param  deployer    The broadcasting account.
    /// @param  deployBlock The block the script simulated against. The deployment transactions land
    ///                     in this block or a later one, so log scans may start here.
    /// @return outputPath  The path of the written file.
    function _writeOutput(address executor, address receiver, address deployer, uint256 deployBlock)
        internal
        returns (string memory outputPath)
    {
        bool broadcasting =
            vm.isContext(VmSafe.ForgeContext.ScriptBroadcast) || vm.isContext(VmSafe.ForgeContext.ScriptResume);
        string memory dir = broadcasting ? OUTPUT_DIR : string.concat(OUTPUT_DIR, "/dry-run");
        outputPath = string.concat(dir, "/", OUTPUT_FILE);

        string memory key = "base-gov-relay";
        vm.serializeAddress(key, "executor", executor);
        vm.serializeAddress(key, "receiver", receiver);
        vm.serializeAddress(key, "deployer", deployer);
        vm.serializeAddress(key, "l1Authority", OseroBaseGovRelayDeployment.L1_AUTHORITY);
        vm.serializeUint(key, "delay", OseroBaseGovRelayDeployment.DELAY);
        vm.serializeUint(key, "gracePeriod", OseroBaseGovRelayDeployment.GRACE_PERIOD);
        string memory json = vm.serializeUint(key, "deployBlock", deployBlock);

        vm.createDir(dir, true);
        vm.writeJson(json, outputPath);
    }
}
