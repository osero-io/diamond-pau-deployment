// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {DefaultPAUAssembler, IDefaultPAUAssembler} from "pau-assemblers/DefaultPAUAssembler.sol";

contract DeployScript is Script {
    DefaultPAUAssembler public constant ASSEMBLER = DefaultPAUAssembler(0xc812aAD3FaE2D3511C664374B601a9BeBFeCCa2E);

    function run() external {
        // Osero subproxy
        address OSERO_SUBPROXY = 0x24fdcd3bFA5C2553e05B2f9AD0365EBC296278D3;

        // Osero operator multisig
        address OSERO_OPERATOR = 0x29c5A20A49A0D522A3714af97C517a908946b6A8;

        // Soter labs realayer multisig
        address SOTER_RELAYER = 0x3dE688267Cf099307aBdd85F64D8efe03D0b2b26;

        // Soter labs freezer multisig
        address SOTER_FREEZER = 0xF61F90907551a8A23f0f8EEE9658Fa53326de603;

        address[] memory admins = new address[](1);
        address[] memory actors = new address[](2);
        address[] memory revokers = new address[](1);

        admins[0] = OSERO_SUBPROXY;

        actors[0] = SOTER_RELAYER;
        actors[1] = OSERO_OPERATOR;

        revokers[0] = SOTER_FREEZER;

        IDefaultPAUAssembler.AdminConfig memory adminConfig = IDefaultPAUAssembler.AdminConfig({
            accessControlAdmins: admins, proxyAdmins: admins, rateLimitsAdmins: admins
        });

        IDefaultPAUAssembler.AdministeredAgentConfig[] memory administeredAgentConfig =
            new IDefaultPAUAssembler.AdministeredAgentConfig[](1);

        administeredAgentConfig[0] = IDefaultPAUAssembler.AdministeredAgentConfig({
            admins: admins, actors: actors, grantors: new address[](0), revokers: revokers
        });

        bytes32[] memory integrationIds = new bytes32[](2);

        integrationIds[0] = bytes32("AAVE_FACET");
        integrationIds[1] = bytes32("PSM_FACET");

        vm.startBroadcast();

        (
            address proxy,
            address controller,
            address accessControls,
            address rateLimits,
            address[] memory allocatorAgents
        ) = ASSEMBLER.deploy(integrationIds, adminConfig, administeredAgentConfig);

        vm.stopBroadcast();

        console.log("ALM Proxy deployed at:", proxy);
        console.log("ALM Controller deployed at:", controller);
        console.log("Access controls deployed at:", accessControls);
        console.log("Rate limits deployed at:", rateLimits);

        for (uint256 i; i < allocatorAgents.length; i++) {
            console.log("Allocator agent deployed at:", i, allocatorAgents[i]);
        }
    }
}
