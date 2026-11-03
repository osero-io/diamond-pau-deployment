// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

import {IExecutor} from "spark-gov-relay/interfaces/IExecutor.sol";
import {OptimismReceiver} from "xchain-helpers/receivers/OptimismReceiver.sol";
import {OptimismForwarder} from "xchain-helpers/forwarders/OptimismForwarder.sol";
import {Bridge} from "xchain-helpers/testing/Bridge.sol";
import {Domain, DomainHelpers} from "xchain-helpers/testing/Domain.sol";
import {OptimismBridgeTesting} from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import {RecordedLogs} from "xchain-helpers/testing/utils/RecordedLogs.sol";

import {OseroBaseGovRelayDeployment} from "../src/OseroBaseGovRelayDeployment.sol";

import {GovRelayMessages} from "./utils/GovRelayMessages.sol";
import {GovRelayTestBase} from "./utils/GovRelayTestBase.sol";
import {GovRelayTestPayload} from "./utils/GovRelayTestPayload.sol";

interface ISubProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

/// @title Osero Base Relay Spell
/// @notice Mainnet spell-side payload, delegatecalled by the Osero SubProxy, that relays a queue
///         message to the Base Receiver. Uses immutables only, since it runs in the SubProxy's storage.
contract OseroBaseRelaySpell {
    address internal immutable receiver;
    address internal immutable payload;

    constructor(address receiver_, address payload_) {
        receiver = receiver_;
        payload = payload_;
    }

    function execute() external {
        OptimismForwarder.sendMessageL1toL2(
            OptimismForwarder.L1_CROSS_DOMAIN_BASE, receiver, GovRelayMessages.queueMessage(payload), 1_000_000
        );
    }
}

/// @title Osero Base Governance Relay Cross-chain Tests
/// @notice Sends messages from an Ethereum mainnet fork through the native OP Stack bridge to the
///         relay deployed on a Base fork, then executes the queued payload.
contract OseroBaseGovRelayCrosschainTest is GovRelayTestBase {
    using DomainHelpers for *;
    using OptimismBridgeTesting for *;

    /// @notice Sky `MCD_PAUSE_PROXY`, a ward of the Osero SubProxy. Executes Osero spells through
    ///         `SubProxy.exec`.
    address internal constant SKY_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    uint32 internal constant L2_GAS_LIMIT = 1_000_000;

    bytes32 internal constant RELAYED_MESSAGE = keccak256("RelayedMessage(bytes32)");
    bytes32 internal constant FAILED_RELAYED_MESSAGE = keccak256("FailedRelayedMessage(bytes32)");

    Domain internal mainnet;
    Domain internal base;
    Bridge internal bridge;

    address internal deployer;
    address internal executor;
    address internal receiver;
    GovRelayTestPayload internal payload;

    function setUp() public {
        mainnet = getChain("mainnet").createFork(MAINNET_FORK_BLOCK);
        base = getChain("base").createFork(BASE_FORK_BLOCK);
        bridge = OptimismBridgeTesting.createNativeBridge(mainnet, base);

        base.selectFork();

        deployer = makeAddr("osero-base-deployer");
        vm.startBroadcast(deployer);
        (executor, receiver) = OseroBaseGovRelayDeployment.deploy(deployer);
        vm.stopBroadcast();

        payload = new GovRelayTestPayload();
    }

    function test_endToEnd_subProxyMessageIsQueuedAndExecuted() public {
        _sendFromL1(OSERO_SUBPROXY, GovRelayMessages.queueMessage(address(payload)));
        _relayAndExpectQueued();
        _executeAndExpectPayloadRan(0);
    }

    function test_endToEnd_spellThroughSubProxyExecIsQueuedAndExecuted() public {
        mainnet.selectFork();
        OseroBaseRelaySpell spell = new OseroBaseRelaySpell(receiver, address(payload));

        vm.prank(SKY_PAUSE_PROXY);
        ISubProxyLike(OSERO_SUBPROXY).exec(address(spell), abi.encodeCall(OseroBaseRelaySpell.execute, ()));

        _relayAndExpectQueued();
        _executeAndExpectPayloadRan(0);
    }

    function test_endToEnd_queuedActionsSetExpiresAfterGracePeriod() public {
        _sendFromL1(OSERO_SUBPROXY, GovRelayMessages.queueMessage(address(payload)));
        _relayAndExpectQueued();

        skip(EXPECTED_GRACE_PERIOD + 1);

        assertEq(uint256(IExecutor(executor).getCurrentState(0)), uint256(IExecutor.ActionsSetState.Expired));
        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        IExecutor(executor).execute(0);
    }

    /// @notice Messages from any L1 sender other than the Osero SubProxy reach the Receiver through the
    ///         real messenger, revert with `OptimismReceiver/invalid-l1Authority` there, and are
    ///         recorded by the messenger as failed. Nothing is queued. The revert reason itself is
    ///         asserted in `OseroBaseGovRelayDeploymentTest`, since the messenger swallows it.
    function test_endToEnd_messagesFromOtherL1SendersFail() public {
        base.selectFork();
        address groveSubProxy = OptimismReceiver(GROVE_RECEIVER).l1Authority();

        address[3] memory senders = [makeAddr("l1-attacker"), groveSubProxy, SKY_PAUSE_PROXY];
        for (uint256 i; i < senders.length; ++i) {
            _sendFromL1(senders[i], GovRelayMessages.queueMessage(address(payload)));
            bridge.relayMessagesToDestination(true);

            Vm.Log[] memory logs = RecordedLogs.getLogs();
            Vm.Log memory last = logs[logs.length - 1];
            assertEq(last.emitter, L2_CROSS_DOMAIN, "last log must come from the L2 messenger");
            assertEq(last.topics[0], FAILED_RELAYED_MESSAGE, "message must fail on L2");
            assertEq(IExecutor(executor).actionsSetCount(), 0, "nothing queued");
        }
    }

    /**
     * Helpers
     */

    function _sendFromL1(address l1Sender, bytes memory message) internal {
        mainnet.selectFork();
        vm.prank(l1Sender);
        OptimismForwarder.sendMessageL1toL2(OptimismForwarder.L1_CROSS_DOMAIN_BASE, receiver, message, L2_GAS_LIMIT);
    }

    /// @dev Relays pending L1 messages to Base and asserts that exactly one relayed successfully and
    ///      emitted `ActionsSetQueued(0, ...)` with `executionTime == block.timestamp`.
    function _relayAndExpectQueued() internal {
        bridge.relayMessagesToDestination(true);

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        uint256 queued;
        uint256 relayed;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            if (logs[i].emitter == L2_CROSS_DOMAIN) {
                assertTrue(logs[i].topics[0] != FAILED_RELAYED_MESSAGE, "message failed on L2");
                if (logs[i].topics[0] == RELAYED_MESSAGE) ++relayed;
            }
            if (logs[i].emitter != executor || logs[i].topics[0] != IExecutor.ActionsSetQueued.selector) continue;

            ++queued;
            assertEq(uint256(logs[i].topics[1]), 0, "actions set id");
            (
                address[] memory targets,
                uint256[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas,
                bool[] memory withDelegatecalls,
                uint256 executionTime
            ) = abi.decode(logs[i].data, (address[], uint256[], string[], bytes[], bool[], uint256));

            assertEq(targets.length, 1, "targets length");
            assertEq(targets[0], address(payload), "target");
            assertEq(values[0], 0, "value");
            assertEq(signatures[0], "execute()", "signature");
            assertEq(calldatas[0].length, 0, "calldata");
            assertTrue(withDelegatecalls[0], "delegatecall");
            assertEq(executionTime, block.timestamp, "executionTime");
        }
        assertEq(relayed, 1, "exactly one message relayed");
        assertEq(queued, 1, "exactly one ActionsSetQueued");

        assertEq(IExecutor(executor).actionsSetCount(), 1, "actionsSetCount");
        assertEq(uint256(IExecutor(executor).getCurrentState(0)), uint256(IExecutor.ActionsSetState.Queued));
    }

    function _executeAndExpectPayloadRan(uint256 id) internal {
        bytes32 slot = payload.MARKER_SLOT();
        assertEq(vm.load(executor, slot), bytes32(0), "marker unset before execution");

        vm.expectEmit(executor);
        emit GovRelayTestPayload.PayloadExecuted(executor);
        IExecutor(executor).execute(id);

        // The payload wrote to the Executor's storage, not its own: it ran via delegatecall in the
        // Executor's context.
        assertEq(vm.load(executor, slot), payload.MARKER(), "marker set in executor storage");
        assertEq(vm.load(address(payload), slot), bytes32(0), "payload storage untouched");
        assertTrue(IExecutor(executor).getActionsSetById(id).executed, "executed flag");
        assertEq(uint256(IExecutor(executor).getCurrentState(id)), uint256(IExecutor.ActionsSetState.Executed));
    }
}
