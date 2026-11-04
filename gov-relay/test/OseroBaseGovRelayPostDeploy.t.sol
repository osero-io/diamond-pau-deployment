// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

import {GovRelayTestBase} from "./utils/GovRelayTestBase.sol";

/// @title Osero Base Governance Relay Post-deploy Verification
/// @notice Verifies a real deployment from its output record. Runs only when `POSTDEPLOY_OUTPUT`
///         points at the JSON written by `DeployBaseGovRelay.s.sol`; every test is skipped otherwise.
///         Forks Base at the latest block and reads the full Executor log history with `eth_getLogs`.
/// @dev    `POSTDEPLOY_OUTPUT` must be inside `gov-relay/output` (the profile's `fs_permissions`).
///         `POSTDEPLOY_LOGS_BLOCK_RANGE` (default 10000) sets the `eth_getLogs` window size for RPCs
///         that cap the block range.
contract OseroBaseGovRelayPostDeployTest is GovRelayTestBase {
    /// @notice Ethereum mainnet PAU deployer, which must not be reused on Base.
    address internal constant MAINNET_PAU_DEPLOYER = 0xa71657b776d01A35dEbe9D64d9fa23dBC5676696;

    uint256 internal constant DEFAULT_LOGS_BLOCK_RANGE = 10_000;
    uint64 internal constant MAX_DEPLOYER_NONCE = 10_000;

    bool internal enabled;
    string internal outputPath;

    address internal executor;
    address internal receiver;
    address internal deployer;
    address internal l1Authority;
    uint256 internal delay;
    uint256 internal gracePeriod;
    uint256 internal deployBlock;

    uint256 internal latestBlock;

    modifier postDeployOnly() {
        vm.skip(!enabled, "POSTDEPLOY_OUTPUT not set");
        _;
    }

    function setUp() public {
        outputPath = vm.envOr("POSTDEPLOY_OUTPUT", string(""));
        if (bytes(outputPath).length == 0) return;
        enabled = true;

        string memory json = vm.readFile(outputPath);
        executor = vm.parseJsonAddress(json, ".executor");
        receiver = vm.parseJsonAddress(json, ".receiver");
        deployer = vm.parseJsonAddress(json, ".deployer");
        l1Authority = vm.parseJsonAddress(json, ".l1Authority");
        delay = vm.parseJsonUint(json, ".delay");
        gracePeriod = vm.parseJsonUint(json, ".gracePeriod");
        deployBlock = vm.parseJsonUint(json, ".deployBlock");

        vm.createSelectFork("base");
        latestBlock = block.number;
    }

    function test_postDeploy_outputRecord() public postDeployOnly {
        assertEq(block.chainid, 8453, "fork must be Base");
        assertEq(l1Authority, OSERO_SUBPROXY, "recorded l1Authority");
        assertEq(delay, EXPECTED_DELAY, "recorded delay");
        assertEq(gracePeriod, EXPECTED_GRACE_PERIOD, "recorded gracePeriod");
        assertGt(deployBlock, 0, "recorded deployBlock");
        assertLe(deployBlock, latestBlock, "deployBlock in the future");
        assertTrue(deployer != address(0), "recorded deployer");
        assertTrue(deployer != MAINNET_PAU_DEPLOYER, "mainnet deployer reused on Base");
    }

    /// @notice 5a against the live contracts.
    function test_postDeploy_configuration() public postDeployOnly {
        _assertConfiguration(executor, receiver, deployer);
    }

    /// @notice 5c against the live contracts.
    function test_postDeploy_bytecodeParity() public postDeployOnly {
        _assertBytecodeParity(executor, receiver);
    }

    /// @notice 5b rebuilt from the chain: every role event the Executor ever emitted, from
    ///         `deployBlock` to the latest block.
    function test_postDeploy_roleHistory() public postDeployOnly {
        Vm.EthGetLogs[] memory logs = _executorLogs();
        _assertRoleHistory(_roleEvents(logs, executor), executor, receiver, deployer);

        // Both constructor grants come from the creation transaction; the grant and the revoke are
        // separate later transactions.
        Vm.EthGetLogs[] memory roleLogs = _roleLogs(logs);
        assertEq(roleLogs[0].transactionHash, roleLogs[1].transactionHash, "constructor grants share a tx");
        assertTrue(roleLogs[2].transactionHash != roleLogs[0].transactionHash, "grant is a separate tx");
        assertTrue(roleLogs[3].transactionHash != roleLogs[2].transactionHash, "revoke is a separate tx");
        for (uint256 i = 1; i < roleLogs.length; ++i) {
            assertTrue(_isAfter(roleLogs[i], roleLogs[i - 1]), "role events out of order");
        }
    }

    /// @notice Both contracts were created by transactions from the recorded deployer, the Receiver
    ///         after the Executor.
    function test_postDeploy_creationTransactions() public postDeployOnly {
        assertEq(deployer.code.length, 0, "deployer must be an EOA without delegated code");

        // CREATE addresses of consecutive deployer nonces n and n + 1.
        uint64 nonce = _assertCreatedInOrderBy(deployer, executor, receiver, MAX_DEPLOYER_NONCE);

        // The creation transaction is the one that emitted the constructor's first role event.
        Vm.EthGetLogs[] memory roleLogs = _roleLogs(_executorLogs());
        uint256 creationBlock = roleLogs[0].blockNumber;
        assertGe(creationBlock, deployBlock, "executor created before the recorded deployBlock");

        // Just before that block, neither contract existed and the deployer had not yet used nonce n.
        vm.createSelectFork("base", creationBlock - 1);
        assertEq(executor.code.length, 0, "executor existed before its creation block");
        assertEq(receiver.code.length, 0, "receiver existed before the executor");
        assertEq(deployer.code.length, 0, "deployer had code before deployment");
        assertEq(vm.getNonce(deployer), nonce, "deployer nonce before the executor creation");

        // In that block the deployer's nonce-n transaction created the Executor.
        vm.createSelectFork("base", creationBlock);
        assertGt(executor.code.length, 0, "executor missing at its creation block");
        assertGt(vm.getNonce(deployer), nonce, "deployer nonce n unused at the creation block");
    }

    /**
     * Helpers
     */

    /// @dev Fetches every log the Executor emitted in `[deployBlock, latestBlock]`.
    function _executorLogs() internal view returns (Vm.EthGetLogs[] memory all) {
        uint256 range = vm.envOr("POSTDEPLOY_LOGS_BLOCK_RANGE", DEFAULT_LOGS_BLOCK_RANGE);
        require(range > 0, "POSTDEPLOY_LOGS_BLOCK_RANGE must be positive");

        bytes32[] memory anyTopics = new bytes32[](0);
        for (uint256 from = deployBlock; from <= latestBlock; from += range) {
            uint256 to = from + range - 1;
            if (to > latestBlock) to = latestBlock;
            all = _concat(all, vm.eth_getLogs(from, to, executor, anyTopics));
        }

        for (uint256 i; i < all.length; ++i) {
            assertFalse(all[i].removed, "removed log");
            assertEq(all[i].emitter, executor, "log from another emitter");
        }
    }

    function _roleLogs(Vm.EthGetLogs[] memory logs) internal pure returns (Vm.EthGetLogs[] memory roleLogs) {
        roleLogs = new Vm.EthGetLogs[](logs.length);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length > 0 && _isRoleEvent(logs[i].topics[0])) roleLogs[count++] = logs[i];
        }
        assembly ("memory-safe") {
            mstore(roleLogs, count)
        }
        require(count == 4, "expected exactly four role events");
    }

    function _isAfter(Vm.EthGetLogs memory a, Vm.EthGetLogs memory b) internal pure returns (bool) {
        return a.blockNumber > b.blockNumber || (a.blockNumber == b.blockNumber && a.logIndex > b.logIndex);
    }

    function _concat(Vm.EthGetLogs[] memory a, Vm.EthGetLogs[] memory b)
        internal
        pure
        returns (Vm.EthGetLogs[] memory c)
    {
        c = new Vm.EthGetLogs[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            c[i] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            c[a.length + i] = b[i];
        }
    }
}
