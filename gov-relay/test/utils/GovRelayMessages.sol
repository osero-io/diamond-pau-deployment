// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import {IExecutor} from "spark-gov-relay/interfaces/IExecutor.sol";

/// @title Governance Relay Messages
/// @notice Encodes the `Executor.queue` message that an Osero spell relays to Base.
library GovRelayMessages {
    /// @notice Encodes one delegatecall action that runs `payload.execute()` with no value.
    function queueMessage(address payload) internal pure returns (bytes memory) {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            bool[] memory withDelegatecalls
        ) = queueArgs(payload);
        return abi.encodeCall(IExecutor.queue, (targets, values, signatures, calldatas, withDelegatecalls));
    }

    /// @notice Returns the `Executor.queue` arguments of {queueMessage}.
    function queueArgs(address payload)
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            bool[] memory withDelegatecalls
        )
    {
        targets = new address[](1);
        targets[0] = payload;
        values = new uint256[](1);
        signatures = new string[](1);
        signatures[0] = "execute()";
        calldatas = new bytes[](1);
        withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;
    }
}
