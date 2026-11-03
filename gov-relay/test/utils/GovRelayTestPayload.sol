// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

/// @title Governance Relay Test Payload
/// @notice Spell-style payload for the Executor. `execute()` only succeeds through `delegatecall`,
///         and it records the execution context in the caller's storage and logs.
contract GovRelayTestPayload {
    /// @notice Emitted from the delegating contract when the payload runs.
    /// @param  context `address(this)` during execution, i.e. the delegating contract.
    event PayloadExecuted(address indexed context);

    /// @notice Storage slot written in the delegating contract's storage.
    bytes32 public constant MARKER_SLOT = keccak256("osero.gov-relay.test-payload.marker");

    /// @notice Value written to `MARKER_SLOT`.
    bytes32 public constant MARKER = keccak256("osero.gov-relay.test-payload.executed");

    address private immutable self;

    constructor() {
        self = address(this);
    }

    /// @notice Writes `MARKER` to `MARKER_SLOT` and emits {PayloadExecuted}. Reverts on direct calls.
    function execute() external {
        require(address(this) != self, "GovRelayTestPayload/not-delegatecall");

        bytes32 slot = MARKER_SLOT;
        bytes32 marker = MARKER;
        assembly ("memory-safe") {
            sstore(slot, marker)
        }

        emit PayloadExecuted(address(this));
    }
}
