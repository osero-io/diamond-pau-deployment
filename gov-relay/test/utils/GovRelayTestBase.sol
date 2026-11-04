// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Executor} from "spark-gov-relay/Executor.sol";
import {OptimismReceiver} from "xchain-helpers/receivers/OptimismReceiver.sol";

import {Ethereum as OseroEthereumRegistry} from "@osero/address-registry/Ethereum.sol";

import {OseroBaseGovRelayDeployment} from "../../src/OseroBaseGovRelayDeployment.sol";

/// @title Osero Base Governance Relay Test Base
/// @notice Shared expectations and checks for the fork tests and the post-deploy verification tests.
/// @dev The expected values are written out as literals, so the checks do not trust the deployment
///      library they are verifying.
abstract contract GovRelayTestBase is Test {
    /// @notice Base fork block for deterministic fork tests. Grove's relay exists at this block.
    uint256 internal constant BASE_FORK_BLOCK = 53_460_000;

    /// @notice Ethereum mainnet fork block for the cross-chain tests.
    uint256 internal constant MAINNET_FORK_BLOCK = 26_330_000;

    /// @notice Osero SubProxy on Ethereum mainnet (chainlog `OSERO_SUBPROXY`).
    address internal constant OSERO_SUBPROXY = 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3;

    /// @notice OP Stack L2CrossDomainMessenger predeploy.
    address internal constant L2_CROSS_DOMAIN = 0x4200000000000000000000000000000000000007;

    uint256 internal constant EXPECTED_DELAY = 0;
    uint256 internal constant EXPECTED_GRACE_PERIOD = 604_800;

    /// @notice Grove's Base relay, the reference build (Sourcify `exact_match`, solc 0.8.25,
    ///         optimizer 200 runs, cancun). Reference fixtures for the bytecode-parity checks only;
    ///         the copy in grove-address-registry is reachable only through diamond-pau's
    ///         submodules, which the gov-relay build does not depend on.
    address internal constant GROVE_EXECUTOR = 0x491EDFB0B8b608044e227225C715981a30F3A44E;
    address internal constant GROVE_RECEIVER = 0x5F5cfCB8a463868E37Ab27B5eFF3ba02112dF19a;

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant SUBMISSION_ROLE = keccak256("SUBMISSION_ROLE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    bytes32 internal constant ROLE_GRANTED = keccak256("RoleGranted(bytes32,address,address)");
    bytes32 internal constant ROLE_REVOKED = keccak256("RoleRevoked(bytes32,address,address)");
    bytes32 internal constant ROLE_ADMIN_CHANGED = keccak256("RoleAdminChanged(bytes32,bytes32,bytes32)");

    /// @notice `0x64 "solc" 0x43` followed by the 3-byte compiler version, as encoded in the CBOR
    ///         metadata trailer.
    bytes6 internal constant CBOR_SOLC_KEY = 0x64736f6c6343;
    bytes3 internal constant SOLC_0_8_25 = 0x000819;

    string internal constant EXECUTOR_ARTIFACT = "gov-relay/out/Executor.sol/Executor.json";
    string internal constant RECEIVER_ARTIFACT = "gov-relay/out/OptimismReceiver.sol/OptimismReceiver.json";

    /// @notice An AccessControl role event. All three role events index three topics.
    struct RoleEvent {
        bytes32 signature;
        bytes32 topic1;
        bytes32 topic2;
        bytes32 topic3;
    }

    /// @notice One `deployedBytecode.immutableReferences` entry. Fields are in JSON key order.
    struct ImmutableReference {
        uint256 length;
        uint256 start;
    }

    /**
     * Configuration (5a)
     */

    /// @notice Asserts the Executor parameters, role holders and Receiver wiring.
    function _assertConfiguration(address executor, address receiver, address deployer) internal view {
        Executor executor_ = Executor(executor);
        OptimismReceiver receiver_ = OptimismReceiver(receiver);

        assertGt(executor.code.length, 0, "executor has no code");
        assertGt(receiver.code.length, 0, "receiver has no code");

        // Role identifiers compiled into the Executor match the ones these checks use.
        assertEq(executor_.DEFAULT_ADMIN_ROLE(), DEFAULT_ADMIN_ROLE, "DEFAULT_ADMIN_ROLE id");
        assertEq(executor_.SUBMISSION_ROLE(), SUBMISSION_ROLE, "SUBMISSION_ROLE id");
        assertEq(executor_.GUARDIAN_ROLE(), GUARDIAN_ROLE, "GUARDIAN_ROLE id");

        assertEq(executor_.delay(), EXPECTED_DELAY, "delay");
        assertEq(executor_.gracePeriod(), EXPECTED_GRACE_PERIOD, "gracePeriod");

        assertTrue(executor_.hasRole(DEFAULT_ADMIN_ROLE, executor), "executor must be its own admin");
        assertFalse(executor_.hasRole(DEFAULT_ADMIN_ROLE, deployer), "deployer must not be admin");
        assertFalse(executor_.hasRole(DEFAULT_ADMIN_ROLE, receiver), "receiver must not be admin");

        assertTrue(executor_.hasRole(SUBMISSION_ROLE, receiver), "receiver must be submitter");
        assertFalse(executor_.hasRole(SUBMISSION_ROLE, deployer), "deployer must not be submitter");
        assertFalse(executor_.hasRole(SUBMISSION_ROLE, executor), "executor must not be submitter");

        assertFalse(executor_.hasRole(GUARDIAN_ROLE, deployer), "deployer must not be guardian");
        assertFalse(executor_.hasRole(GUARDIAN_ROLE, receiver), "receiver must not be guardian");
        assertFalse(executor_.hasRole(GUARDIAN_ROLE, executor), "executor must not be guardian");

        // Role admins were never changed.
        assertEq(executor_.getRoleAdmin(DEFAULT_ADMIN_ROLE), DEFAULT_ADMIN_ROLE, "admin of DEFAULT_ADMIN_ROLE");
        assertEq(executor_.getRoleAdmin(SUBMISSION_ROLE), DEFAULT_ADMIN_ROLE, "admin of SUBMISSION_ROLE");
        assertEq(executor_.getRoleAdmin(GUARDIAN_ROLE), DEFAULT_ADMIN_ROLE, "admin of GUARDIAN_ROLE");

        assertEq(receiver_.l1Authority(), OSERO_SUBPROXY, "l1Authority literal");
        assertEq(receiver_.l1Authority(), OseroEthereumRegistry.OSERO_PROXY, "l1Authority registry");
        assertEq(receiver_.target(), executor, "receiver target");
        assertEq(address(receiver_.l2CrossDomain()), L2_CROSS_DOMAIN, "l2CrossDomain");
    }

    /// @notice Asserts the library constants against the expected literals.
    function _assertLibraryConstants() internal pure {
        assertEq(OseroBaseGovRelayDeployment.CHAIN_ID, 8453, "CHAIN_ID");
        assertEq(OseroBaseGovRelayDeployment.DELAY, EXPECTED_DELAY, "DELAY");
        assertEq(OseroBaseGovRelayDeployment.GRACE_PERIOD, EXPECTED_GRACE_PERIOD, "GRACE_PERIOD");
        assertEq(OseroBaseGovRelayDeployment.L1_AUTHORITY, OSERO_SUBPROXY, "L1_AUTHORITY literal");
        assertEq(OseroBaseGovRelayDeployment.L1_AUTHORITY, OseroEthereumRegistry.OSERO_PROXY, "L1_AUTHORITY registry");
    }

    /**
     * Role history (5b)
     */

    /// @notice Extracts the Executor's role events from logs recorded with `vm.recordLogs`.
    function _roleEvents(Vm.Log[] memory logs, address executor) internal pure returns (RoleEvent[] memory events) {
        events = new RoleEvent[](logs.length);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != executor || logs[i].topics.length == 0) continue;
            if (!_isRoleEvent(logs[i].topics[0])) continue;
            events[count++] = _toRoleEvent(logs[i].topics);
        }
        assembly ("memory-safe") {
            mstore(events, count)
        }
    }

    /// @notice Extracts the Executor's role events from `eth_getLogs` results.
    function _roleEvents(Vm.EthGetLogs[] memory logs, address executor)
        internal
        pure
        returns (RoleEvent[] memory events)
    {
        events = new RoleEvent[](logs.length);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != executor || logs[i].topics.length == 0) continue;
            if (!_isRoleEvent(logs[i].topics[0])) continue;
            events[count++] = _toRoleEvent(logs[i].topics);
        }
        assembly ("memory-safe") {
            mstore(events, count)
        }
    }

    /// @notice Asserts the Executor's complete role history. `AccessControl` is not enumerable, so
    ///         this history is the only proof that no other account ever held a role.
    function _assertRoleHistory(RoleEvent[] memory events, address executor, address receiver, address deployer)
        internal
        pure
    {
        assertEq(events.length, 4, "executor must emit exactly four role events");

        _assertRoleEvent(events[0], ROLE_GRANTED, DEFAULT_ADMIN_ROLE, deployer, deployer, "#0 grant admin to deployer");
        _assertRoleEvent(events[1], ROLE_GRANTED, DEFAULT_ADMIN_ROLE, executor, deployer, "#1 grant admin to executor");
        _assertRoleEvent(
            events[2], ROLE_GRANTED, SUBMISSION_ROLE, receiver, deployer, "#2 grant submission to receiver"
        );
        _assertRoleEvent(events[3], ROLE_REVOKED, DEFAULT_ADMIN_ROLE, deployer, deployer, "#3 revoke deployer admin");
    }

    function _assertRoleEvent(
        RoleEvent memory actual,
        bytes32 signature,
        bytes32 role,
        address account,
        address sender,
        string memory label
    ) internal pure {
        assertEq(actual.signature, signature, string.concat(label, ": event"));
        assertEq(actual.topic1, role, string.concat(label, ": role"));
        assertEq(actual.topic2, bytes32(uint256(uint160(account))), string.concat(label, ": account"));
        assertEq(actual.topic3, bytes32(uint256(uint160(sender))), string.concat(label, ": sender"));
    }

    function _isRoleEvent(bytes32 signature) internal pure returns (bool) {
        return signature == ROLE_GRANTED || signature == ROLE_REVOKED || signature == ROLE_ADMIN_CHANGED;
    }

    function _toRoleEvent(bytes32[] memory topics) internal pure returns (RoleEvent memory) {
        require(topics.length == 4, "role event must have four topics");
        return RoleEvent({signature: topics[0], topic1: topics[1], topic2: topics[2], topic3: topics[3]});
    }

    /**
     * Bytecode parity (5c)
     */

    /// @notice Asserts that the runtime code of both contracts equals Grove's relay and the local
    ///         artifacts, excluding the CBOR metadata trailer and (for the Receiver) the immutables.
    function _assertBytecodeParity(address executor, address receiver) internal view {
        _assertExecutorParity(executor);
        _assertReceiverParity(executor, receiver);
    }

    function _assertExecutorParity(address executor) internal view {
        bytes memory ours = executor.code;
        bytes memory grove = GROVE_EXECUTOR.code;
        bytes memory artifact = _artifactDeployedCode(EXECUTOR_ARTIFACT);

        assertGt(grove.length, 0, "Grove executor has no code");
        _assertSolcVersion(ours, "executor");
        _assertSolcVersion(grove, "Grove executor");
        _assertSolcVersion(artifact, "executor artifact");

        // The Executor has no immutables, so its runtime code is fully determined by the build.
        (string[] memory ids,) = _immutableReferences(EXECUTOR_ARTIFACT);
        assertEq(ids.length, 0, "executor must not have immutables");

        _assertSameCode(_stripMetadata(ours), _stripMetadata(grove), "executor runtime code != Grove executor");
        _assertSameCode(_stripMetadata(ours), _stripMetadata(artifact), "executor runtime code != local artifact");
    }

    function _assertReceiverParity(address executor, address receiver) internal view {
        bytes memory ours = receiver.code;
        bytes memory grove = GROVE_RECEIVER.code;
        bytes memory artifact = _artifactDeployedCode(RECEIVER_ARTIFACT);

        assertGt(grove.length, 0, "Grove receiver has no code");
        _assertSolcVersion(ours, "receiver");
        _assertSolcVersion(grove, "Grove receiver");
        _assertSolcVersion(artifact, "receiver artifact");
        assertEq(ours.length, grove.length, "receiver code length != Grove receiver");

        // Two immutables: `l1Authority` and `target`. Before masking, check that each occupies the
        // same positions in both contracts and holds that contract's own value.
        (string[] memory ids, ImmutableReference[][] memory refs) = _immutableReferences(RECEIVER_ARTIFACT);
        assertEq(ids.length, 2, "receiver must have exactly two immutables");

        address groveL1Authority = OptimismReceiver(GROVE_RECEIVER).l1Authority();
        address groveTarget = OptimismReceiver(GROVE_RECEIVER).target();
        assertEq(groveTarget, GROVE_EXECUTOR, "Grove receiver target");

        bool sawL1Authority;
        bool sawTarget;
        for (uint256 i; i < ids.length; ++i) {
            assertGt(refs[i].length, 0, "immutable without references");
            address oursValue = _immutableValue(ours, refs[i]);
            address groveValue = _immutableValue(grove, refs[i]);
            if (oursValue == OseroBaseGovRelayDeployment.L1_AUTHORITY) {
                assertEq(groveValue, groveL1Authority, "Grove l1Authority immutable position");
                sawL1Authority = true;
            } else {
                assertEq(oursValue, executor, "unexpected receiver immutable value");
                assertEq(groveValue, groveTarget, "Grove target immutable position");
                sawTarget = true;
            }
        }
        assertTrue(sawL1Authority && sawTarget, "receiver immutables must be l1Authority and target");

        bytes memory oursMasked = _stripMetadata(_maskImmutables(ours, refs));
        _assertSameCode(
            oursMasked, _stripMetadata(_maskImmutables(grove, refs)), "receiver runtime code != Grove receiver"
        );
        _assertSameCode(
            oursMasked, _stripMetadata(_maskImmutables(artifact, refs)), "receiver runtime code != local artifact"
        );
    }

    /// @notice Compares code by length and hash, so a mismatch does not dump kilobytes of hex.
    function _assertSameCode(bytes memory actual, bytes memory expected, string memory label) internal pure {
        assertEq(actual.length, expected.length, string.concat(label, " (length)"));
        assertEq(keccak256(actual), keccak256(expected), label);
    }

    /// @notice Removes the trailing CBOR metadata. The last two bytes hold the trailer length.
    function _stripMetadata(bytes memory code) internal pure returns (bytes memory stripped) {
        require(code.length > 2, "code too short");
        uint256 metadataLength = (uint256(uint8(code[code.length - 2])) << 8) | uint256(uint8(code[code.length - 1]));
        require(code.length >= metadataLength + 2, "invalid metadata length");

        uint256 length = code.length - metadataLength - 2;
        stripped = new bytes(length);
        for (uint256 i; i < length; ++i) {
            stripped[i] = code[i];
        }
    }

    /// @notice Asserts that the CBOR trailer ends with `solc: 0.8.25`.
    function _assertSolcVersion(bytes memory code, string memory label) internal pure {
        require(code.length > 11, "code too short");
        uint256 end = code.length - 2; // exclude the 2-byte trailer length
        bytes6 key;
        bytes3 version;
        for (uint256 i; i < 6; ++i) {
            key |= bytes6(code[end - 9 + i]) >> (8 * i);
        }
        for (uint256 i; i < 3; ++i) {
            version |= bytes3(code[end - 3 + i]) >> (8 * i);
        }
        assertEq(bytes32(key), bytes32(CBOR_SOLC_KEY), string.concat(label, ": CBOR solc key"));
        assertEq(bytes32(version), bytes32(SOLC_0_8_25), string.concat(label, ": solc version"));
    }

    function _maskImmutables(bytes memory code, ImmutableReference[][] memory refs)
        internal
        pure
        returns (bytes memory masked)
    {
        masked = bytes.concat(code);
        for (uint256 i; i < refs.length; ++i) {
            for (uint256 j; j < refs[i].length; ++j) {
                uint256 end = refs[i][j].start + refs[i][j].length;
                require(end <= masked.length, "immutable reference out of range");
                for (uint256 k = refs[i][j].start; k < end; ++k) {
                    masked[k] = 0;
                }
            }
        }
    }

    /// @notice Reads an address immutable and checks that all its references hold the same value.
    function _immutableValue(bytes memory code, ImmutableReference[] memory refs)
        internal
        pure
        returns (address value)
    {
        for (uint256 j; j < refs.length; ++j) {
            assertEq(refs[j].length, 32, "immutable reference length");
            require(refs[j].start + 32 <= code.length, "immutable reference out of range");
            bytes32 word;
            uint256 start = refs[j].start;
            assembly ("memory-safe") {
                word := mload(add(add(code, 0x20), start))
            }
            assertEq(uint256(word) >> 160, 0, "immutable is not an address");
            if (j == 0) value = address(uint160(uint256(word)));
            else assertEq(address(uint160(uint256(word))), value, "immutable references disagree");
        }
    }

    function _artifactDeployedCode(string memory artifact) internal view returns (bytes memory) {
        return vm.parseJsonBytes(_readArtifact(artifact), ".deployedBytecode.object");
    }

    function _immutableReferences(string memory artifact)
        internal
        view
        returns (string[] memory ids, ImmutableReference[][] memory refs)
    {
        string memory json = _readArtifact(artifact);
        string memory path = ".deployedBytecode.immutableReferences";
        if (!vm.keyExistsJson(json, path)) return (new string[](0), new ImmutableReference[][](0));

        ids = vm.parseJsonKeys(json, path);
        refs = new ImmutableReference[][](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            refs[i] = abi.decode(vm.parseJson(json, string.concat(path, ".", ids[i])), (ImmutableReference[]));
        }
    }

    function _readArtifact(string memory artifact) internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/", artifact));
    }

    /**
     * Creation order
     */

    /// @notice Asserts that `executor` and `receiver` are the CREATE addresses of `deployer`'s
    ///         consecutive nonces `n` and `n + 1`. Only transactions sent by that EOA can create
    ///         contracts at those addresses, and nonce order means the Receiver came after the Executor.
    /// @return nonce The deployer nonce that created the Executor.
    function _assertCreatedInOrderBy(address deployer, address executor, address receiver, uint64 maxNonce)
        internal
        pure
        returns (uint64 nonce)
    {
        for (uint64 n; n <= maxNonce; ++n) {
            if (vm.computeCreateAddress(deployer, n) == executor) {
                assertEq(receiver, vm.computeCreateAddress(deployer, n + 1), "receiver must be deployer nonce n + 1");
                return n;
            }
        }
        revert("executor is not a CREATE address of the deployer");
    }
}
