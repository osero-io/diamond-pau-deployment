// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {OseroPAUDeployment} from "../src/OseroPAUDeployment.sol";

/// @title Osero PAU Deployment Script
/// @notice Broadcasts the canonical Osero PAU deployment and logs the deployed addresses.
contract DeployOseroPAUScript is Script {
    /// @notice Broadcasts the PAU deployment transaction and logs each deployed address.
    /// @dev Deployment configuration lives in {OseroPAUDeployment}; this script only handles
    ///      broadcasting and operator-facing console output.
    function run() external {
        vm.startBroadcast();

        OseroPAUDeployment.Deployment memory deployment = OseroPAUDeployment.deploy();

        vm.stopBroadcast();

        console.log("ALM Proxy deployed at:", deployment.proxy);
        console.log("ALM Controller deployed at:", deployment.controller);
        console.log("Access controls deployed at:", deployment.accessControls);
        console.log("Rate limits deployed at:", deployment.rateLimits);

        for (uint256 i; i < deployment.allocatorAgents.length; i++) {
            console.log("Allocator agent deployed at:", i, deployment.allocatorAgents[i]);
        }
    }
}
