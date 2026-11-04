// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import {Executor} from "spark-gov-relay/Executor.sol";
import {IExecutor} from "spark-gov-relay/interfaces/IExecutor.sol";
import {ICrossDomainOptimism, OptimismReceiver} from "xchain-helpers/receivers/OptimismReceiver.sol";

import {OseroBaseGovRelayDeployment} from "../src/OseroBaseGovRelayDeployment.sol";

import {GovRelayMessages} from "./utils/GovRelayMessages.sol";
import {GovRelayTestBase} from "./utils/GovRelayTestBase.sol";
import {GovRelayTestPayload} from "./utils/GovRelayTestPayload.sol";

/// @title Osero Base Governance Relay Fork Tests
/// @notice Deploys the relay on a Base fork with the deployment library, exactly as the script does,
///         and checks configuration, role history, bytecode parity with Grove's relay and the
///         permission boundaries.
contract OseroBaseGovRelayDeploymentTest is GovRelayTestBase {
    address internal deployer;
    address internal executor;
    address internal receiver;
    uint64 internal deployerNonce;

    /// @dev Topic 0 of every log the Executor emitted during deployment, in order.
    bytes32[] internal executorDeploymentSignatures;
    /// @dev Role events the Executor emitted during deployment, in order.
    RoleEvent[] internal deploymentRoleEvents;
    /// @dev Number of logs the Receiver emitted during deployment.
    uint256 internal receiverDeploymentLogCount;

    function setUp() public {
        vm.createSelectFork("base", BASE_FORK_BLOCK);

        deployer = makeAddr("osero-base-deployer");
        deployerNonce = vm.getNonce(deployer);

        vm.recordLogs();

        // Broadcasting makes each call a top-level transaction from `deployer`, as in the script, so
        // CREATE addresses derive from the deployer's nonce.
        vm.startBroadcast(deployer);
        (executor, receiver) = OseroBaseGovRelayDeployment.deploy(deployer);
        vm.stopBroadcast();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == executor) executorDeploymentSignatures.push(logs[i].topics[0]);
            if (logs[i].emitter == receiver) ++receiverDeploymentLogCount;
        }
        RoleEvent[] memory roleEvents = _roleEvents(logs, executor);
        for (uint256 i; i < roleEvents.length; ++i) {
            deploymentRoleEvents.push(roleEvents[i]);
        }
    }

    /**
     * Configuration (5a)
     */

    function test_libraryConstants() public pure {
        _assertLibraryConstants();
    }

    function test_configuration() public view {
        _assertConfiguration(executor, receiver, deployer);
        assertEq(Executor(executor).actionsSetCount(), 0, "no actions sets queued");
    }

    function test_createAddressesFollowDeployerNonce() public view {
        assertEq(executor, vm.computeCreateAddress(deployer, deployerNonce), "executor at deployer nonce n");
        assertEq(receiver, vm.computeCreateAddress(deployer, deployerNonce + 1), "receiver at deployer nonce n + 1");
        assertEq(_assertCreatedInOrderBy(deployer, executor, receiver, 1024), deployerNonce, "creation nonce");
        // Executor, Receiver, grantRole, revokeRole.
        assertEq(vm.getNonce(deployer), deployerNonce + 4, "deployer sends exactly four transactions");
    }

    /**
     * Role history (5b)
     */

    function test_roleHistory() public view {
        _assertRoleHistory(deploymentRoleEvents, executor, receiver, deployer);
    }

    function test_deploymentEmitsOnlyConstructorAndRoleEvents() public view {
        bytes32[] memory expected = new bytes32[](6);
        expected[0] = IExecutor.DelayUpdate.selector;
        expected[1] = IExecutor.GracePeriodUpdate.selector;
        expected[2] = ROLE_GRANTED;
        expected[3] = ROLE_GRANTED;
        expected[4] = ROLE_GRANTED;
        expected[5] = ROLE_REVOKED;

        assertEq(executorDeploymentSignatures, expected, "executor deployment events");
        assertEq(receiverDeploymentLogCount, 0, "receiver deployment events");
    }

    /**
     * Bytecode parity (5c)
     */

    function test_bytecodeParityWithGroveRelay() public view {
        _assertBytecodeParity(executor, receiver);
    }

    /**
     * Receiver boundaries (5e)
     */

    function testFuzz_receiverRejectsCallersOtherThanL2Messenger(address caller, bytes calldata message) public {
        vm.assume(caller != L2_CROSS_DOMAIN);

        vm.prank(caller);
        vm.expectRevert("OptimismReceiver/invalid-sender");
        _callReceiver(GovRelayMessages.queueMessage(address(0x1234)));

        vm.prank(caller);
        vm.expectRevert("OptimismReceiver/invalid-sender");
        _callReceiver(message);
    }

    function test_receiverRejectsPrivilegedCallersOtherThanL2Messenger() public {
        address[4] memory callers = [deployer, executor, OSERO_SUBPROXY, GROVE_RECEIVER];
        for (uint256 i; i < callers.length; ++i) {
            vm.prank(callers[i]);
            vm.expectRevert("OptimismReceiver/invalid-sender");
            _callReceiver(GovRelayMessages.queueMessage(address(0x1234)));
        }
    }

    function testFuzz_receiverRejectsL1SendersOtherThanOseroSubProxy(address l1Sender) public {
        vm.assume(l1Sender != OSERO_SUBPROXY);

        _mockXDomainMessageSender(l1Sender);
        vm.prank(L2_CROSS_DOMAIN);
        vm.expectRevert("OptimismReceiver/invalid-l1Authority");
        _callReceiver(GovRelayMessages.queueMessage(address(0x1234)));

        assertEq(Executor(executor).actionsSetCount(), 0, "nothing queued");
    }

    function test_receiverRejectsGroveSubProxyAsL1Sender() public {
        _mockXDomainMessageSender(OptimismReceiver(GROVE_RECEIVER).l1Authority());
        vm.prank(L2_CROSS_DOMAIN);
        vm.expectRevert("OptimismReceiver/invalid-l1Authority");
        _callReceiver(GovRelayMessages.queueMessage(address(0x1234)));
    }

    function test_receiverForwardsMessagesFromOseroSubProxy() public {
        _queueThroughReceiver();
        assertEq(Executor(executor).getActionsSetById(0).executionTime, block.timestamp, "no delay");
    }

    /**
     * Executor boundaries (5e)
     */

    function testFuzz_queueRevertsForAnyoneButReceiver(address caller) public {
        vm.assume(caller != receiver);
        _assertQueueReverts(caller);
    }

    function test_queueRevertsForPrivilegedAddresses() public {
        address[5] memory callers = [deployer, executor, OSERO_SUBPROXY, L2_CROSS_DOMAIN, GROVE_RECEIVER];
        for (uint256 i; i < callers.length; ++i) {
            _assertQueueReverts(callers[i]);
        }
    }

    function test_deployerHasNoAdminPowers() public {
        GovRelayTestPayload payload = new GovRelayTestPayload();
        bytes memory unauthorizedAdmin = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, deployer, DEFAULT_ADMIN_ROLE
        );

        vm.startPrank(deployer);

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).executeDelegateCall(address(payload), abi.encodeCall(GovRelayTestPayload.execute, ()));

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).updateDelay(1 days);

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).updateGracePeriod(1 days);

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).grantRole(SUBMISSION_ROLE, deployer);

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).grantRole(DEFAULT_ADMIN_ROLE, deployer);

        vm.expectRevert(unauthorizedAdmin);
        Executor(executor).revokeRole(SUBMISSION_ROLE, receiver);

        vm.stopPrank();

        assertEq(Executor(executor).delay(), EXPECTED_DELAY, "delay unchanged");
        assertEq(Executor(executor).gracePeriod(), EXPECTED_GRACE_PERIOD, "grace period unchanged");
    }

    function test_nobodyCanCancel() public {
        _queueThroughReceiver();

        address[4] memory callers = [deployer, receiver, OSERO_SUBPROXY, L2_CROSS_DOMAIN];
        for (uint256 i; i < callers.length; ++i) {
            vm.prank(callers[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, callers[i], GUARDIAN_ROLE
                )
            );
            Executor(executor).cancel(0);
        }
    }

    function test_deployRevertsWhenDeployerIsNotTheCreator() public {
        address notCreator = makeAddr("not-creator");
        vm.expectRevert(
            abi.encodeWithSelector(OseroBaseGovRelayDeployment.DeployerNotExecutorAdmin.selector, notCreator)
        );
        this.deployExternal(notCreator);
    }

    /// @dev External entry point so `vm.expectRevert` can observe a library revert. The Executor is
    ///      created by this test contract, so any other `deployer` argument must be rejected.
    function deployExternal(address deployer_) external returns (address, address) {
        return OseroBaseGovRelayDeployment.deploy(deployer_);
    }

    /**
     * Helpers
     */

    function _assertQueueReverts(address caller) internal {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            bool[] memory withDelegatecalls
        ) = GovRelayMessages.queueArgs(address(0x1234));

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, SUBMISSION_ROLE)
        );
        Executor(executor).queue(targets, values, signatures, calldatas, withDelegatecalls);
    }

    function _queueThroughReceiver() internal {
        bytes memory message = GovRelayMessages.queueMessage(address(new GovRelayTestPayload()));
        _mockXDomainMessageSender(OSERO_SUBPROXY);
        vm.prank(L2_CROSS_DOMAIN);
        _callReceiver(message);
        vm.clearMockedCalls();
        assertEq(Executor(executor).actionsSetCount(), 1, "queued through receiver");
    }

    function _callReceiver(bytes memory message) internal {
        (bool success, bytes memory returndata) = receiver.call(message);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }

    function _mockXDomainMessageSender(address l1Sender) internal {
        vm.mockCall(
            L2_CROSS_DOMAIN, abi.encodeCall(ICrossDomainOptimism.xDomainMessageSender, ()), abi.encode(l1Sender)
        );
    }
}
