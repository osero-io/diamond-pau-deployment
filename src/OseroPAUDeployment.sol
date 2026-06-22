// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {DefaultPAUAssembler, IDefaultPAUAssembler} from "pau-assemblers/DefaultPAUAssembler.sol";
import {Ethereum} from "sky-pau-registry/Ethereum.sol";
import {Ethereum as OseroEthereumRegistry} from "@osero/address-registry/Ethereum.sol";

/// @title Osero PAU Deployment Library
/// @notice Builds and executes the canonical Osero PAU deployment configuration.
/// @dev The library is shared by the deployment script and fork tests so both paths use the exact
///      same assembler address, admins, allocator-agent permissions, and integration IDs.
library OseroPAUDeployment {
    /// @notice Mainnet DefaultPAUAssembler used to deploy and wire the PAU contracts.
    DefaultPAUAssembler internal constant DEFAULT_PAU_ASSEMBLER = DefaultPAUAssembler(Ethereum.DEFAULT_PAU_ASSEMBLER);

    /// @notice Soter Labs relayer multisig authorized as an allocator-agent actor.
    address internal constant SOTER_RELAYER = 0x3dE688267Cf099307aBdd85F64D8efe03D0b2b26;

    /// @notice Soter Labs freezer multisig authorized to revoke allocator-agent permissions.
    address internal constant SOTER_FREEZER = 0xF61F90907551a8A23f0f8EEE9658Fa53326de603;

    /// @notice Controller integration ID for the Aave facet.
    bytes32 internal constant AAVE_FACET_INTEGRATION_ID = "AAVE_FACET";

    /// @notice Controller integration ID for the PSM facet.
    bytes32 internal constant PSM_FACET_INTEGRATION_ID = "PSM_FACET";

    /// @notice Addresses returned by the assembler deployment.
    /// @param  proxy           The deployed ALMProxy contract.
    /// @param  controller      The deployed Controller contract.
    /// @param  accessControls  The deployed AccessControls contract.
    /// @param  rateLimits      The deployed RateLimits contract.
    /// @param  allocatorAgents The deployed allocator AdministeredAgent contracts.
    struct Deployment {
        address proxy;
        address controller;
        address accessControls;
        address rateLimits;
        address[] allocatorAgents;
    }

    /// @notice Returns the assembler used by the canonical deployment.
    /// @return The DefaultPAUAssembler deployed on mainnet.
    function defaultPAUAssembler() internal pure returns (DefaultPAUAssembler) {
        return DEFAULT_PAU_ASSEMBLER;
    }

    /// @notice Returns the Osero subproxy address.
    /// @return The address configured as component admin and allocator-agent admin.
    function oseroSubProxy() internal pure returns (address) {
        return OseroEthereumRegistry.OSERO_PROXY;
    }

    /// @notice Returns the Osero operator multisig address.
    /// @return The address configured as an allocator-agent actor.
    function oseroOperator() internal pure returns (address) {
        return OseroEthereumRegistry.OSERO_OPERATOR;
    }

    /// @notice Returns the Soter Labs relayer multisig address.
    /// @return The address configured as an allocator-agent actor.
    function soterRelayer() internal pure returns (address) {
        return SOTER_RELAYER;
    }

    /// @notice Returns the Soter Labs freezer multisig address.
    /// @return The address configured as an allocator-agent revoker.
    function soterFreezer() internal pure returns (address) {
        return SOTER_FREEZER;
    }

    /// @notice Returns the configured controller integration IDs in deployment order.
    /// @return ids The Aave and PSM facet integration IDs.
    function integrationIds() internal pure returns (bytes32[] memory ids) {
        ids = new bytes32[](2);
        ids[0] = AAVE_FACET_INTEGRATION_ID;
        ids[1] = PSM_FACET_INTEGRATION_ID;
    }

    /// @notice Returns the component default-admin configuration.
    /// @return config Osero subproxy as admin for AccessControls, ALMProxy, and RateLimits.
    function adminConfig() internal pure returns (IDefaultPAUAssembler.AdminConfig memory config) {
        address[] memory componentAdmins = _componentAdmins();

        config = IDefaultPAUAssembler.AdminConfig({
            accessControlAdmins: componentAdmins, proxyAdmins: componentAdmins, rateLimitsAdmins: componentAdmins
        });
    }

    /// @notice Returns the allocator-agent configuration.
    /// @return configs One allocator agent administered by Osero and operated by Soter relayer plus
    ///         Osero operator, with Soter freezer as revoker and no grantors.
    function allocatorAgentConfigs()
        internal
        pure
        returns (IDefaultPAUAssembler.AdministeredAgentConfig[] memory configs)
    {
        address[] memory allocatorActors = new address[](2);
        allocatorActors[0] = SOTER_RELAYER;
        allocatorActors[1] = OseroEthereumRegistry.OSERO_OPERATOR;

        address[] memory allocatorRevokers = new address[](1);
        allocatorRevokers[0] = SOTER_FREEZER;

        configs = new IDefaultPAUAssembler.AdministeredAgentConfig[](1);
        configs[0] = IDefaultPAUAssembler.AdministeredAgentConfig({
            admins: _componentAdmins(), actors: allocatorActors, grantors: new address[](0), revokers: allocatorRevokers
        });
    }

    /// @notice Deploys and configures the Osero PAU stack.
    /// @return deployment The deployed component and allocator-agent addresses.
    function deploy() internal returns (Deployment memory deployment) {
        (
            deployment.proxy,
            deployment.controller,
            deployment.accessControls,
            deployment.rateLimits,
            deployment.allocatorAgents
        ) = DEFAULT_PAU_ASSEMBLER.deploy(integrationIds(), adminConfig(), allocatorAgentConfigs());
    }

    /// @notice Builds the singleton component-admin list used across the deployment.
    /// @return componentAdmins A one-element array containing the Osero subproxy.
    function _componentAdmins() private pure returns (address[] memory componentAdmins) {
        componentAdmins = new address[](1);
        componentAdmins[0] = OseroEthereumRegistry.OSERO_PROXY;
    }
}
