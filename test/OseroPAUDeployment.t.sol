// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {DefaultPAUAssembler, IDefaultPAUAssembler} from "pau-assemblers/DefaultPAUAssembler.sol";

import {OseroPAUDeployment} from "../src/OseroPAUDeployment.sol";

interface IAdministeredAgentLike {
    error NotActor();

    function actorCount() external view returns (uint256);
    function adminCount() external view returns (uint256);
    function call(address target, bytes memory data) external payable returns (bytes memory result);
    function getIsActor(address account) external view returns (bool);
    function getIsAdmin(address account) external view returns (bool);
    function getIsGrantor(address account) external view returns (bool);
    function getIsRevoker(address account) external view returns (bool);
    function grantorCount() external view returns (uint256);
    function revokerCount() external view returns (uint256);
}

interface IAccessControlLike {
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IALMProxyLike {
    function CONTROLLER() external view returns (bytes32);
}

interface IControllerLike {
    struct Config {
        address facet;
        Wire[] wires;
    }

    struct Integration {
        bytes32 id;
        Config config;
    }

    struct Wire {
        bytes4 callSelector;
        bytes4 delegateSelector;
    }

    function accessControls() external view returns (address);
    function beacon() external view returns (address);
    function integrations() external view returns (Integration[] memory);
    function proxy() external view returns (address);
    function rateLimits() external view returns (address);
}

interface IPAUFactoryLike {
    function beacon() external view returns (address);
}

interface IRateLimitsLike {
    function CONTROLLER() external view returns (bytes32);
}

contract CallTarget {
    address public lastSender;
    uint256 public callCount;

    function record() external returns (address caller) {
        lastSender = msg.sender;
        callCount++;
        return msg.sender;
    }
}

contract OseroPAUDeployment_Fork_Tests is Test {
    uint256 internal constant MAINNET_FORK_BLOCK = 25_374_589;

    address internal constant AAVE_FACET = 0x8CE890A96a193ff2DD4B2eA3C682326F655f6b62;
    address internal constant USDS_FACET = 0x1221CC4B85Ab260660aD21C2829e0EB516dffBc7;

    bytes32 internal constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 internal constant AAVE_FACET_INTEGRATION_ID = "AAVE_FACET";
    bytes32 internal constant USDS_FACET_INTEGRATION_ID = "USDS_FACET";

    DefaultPAUAssembler internal assembler;
    OseroPAUDeployment.Deployment internal deployment;

    address internal expectedAccessControls;
    address internal expectedAllocatorAgent;
    address internal expectedController;
    address internal expectedProxy;
    address internal expectedRateLimits;
    address internal pauFactory;

    function setUp() external {
        vm.createSelectFork("mainnet", MAINNET_FORK_BLOCK);

        assembler = OseroPAUDeployment.defaultPAUAssembler();
        pauFactory = assembler.pauFactory();

        address administeredAgentFactory = assembler.administeredAgentFactory();

        expectedAllocatorAgent =
            vm.computeCreateAddress(administeredAgentFactory, vm.getNonce(administeredAgentFactory));
        expectedAccessControls = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory));
        expectedProxy = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 1);
        expectedRateLimits = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 2);
        expectedController = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 3);

        deployment = OseroPAUDeployment.deploy();
    }

    function test_configurationLibraryBuildsExpectedInputs() external pure {
        bytes32[] memory integrationIds = OseroPAUDeployment.integrationIds();
        assertEq(integrationIds.length, 2);
        assertEq(integrationIds[0], AAVE_FACET_INTEGRATION_ID);
        assertEq(integrationIds[1], USDS_FACET_INTEGRATION_ID);

        IDefaultPAUAssembler.AdminConfig memory adminConfig = OseroPAUDeployment.adminConfig();
        assertEq(adminConfig.accessControlAdmins.length, 1);
        assertEq(adminConfig.proxyAdmins.length, 1);
        assertEq(adminConfig.rateLimitsAdmins.length, 1);
        assertEq(adminConfig.accessControlAdmins[0], OseroPAUDeployment.oseroSubProxy());
        assertEq(adminConfig.proxyAdmins[0], OseroPAUDeployment.oseroSubProxy());
        assertEq(adminConfig.rateLimitsAdmins[0], OseroPAUDeployment.oseroSubProxy());

        IDefaultPAUAssembler.AdministeredAgentConfig[] memory allocatorAgentConfigs =
            OseroPAUDeployment.allocatorAgentConfigs();
        assertEq(allocatorAgentConfigs.length, 1);
        assertEq(allocatorAgentConfigs[0].admins.length, 1);
        assertEq(allocatorAgentConfigs[0].actors.length, 2);
        assertEq(allocatorAgentConfigs[0].grantors.length, 0);
        assertEq(allocatorAgentConfigs[0].revokers.length, 1);
        assertEq(allocatorAgentConfigs[0].admins[0], OseroPAUDeployment.oseroSubProxy());
        assertEq(allocatorAgentConfigs[0].actors[0], OseroPAUDeployment.soterRelayer());
        assertEq(allocatorAgentConfigs[0].actors[1], OseroPAUDeployment.oseroOperator());
        assertEq(allocatorAgentConfigs[0].revokers[0], OseroPAUDeployment.soterFreezer());
    }

    function test_deploysExpectedAddressesAndCode() external view {
        assertEq(deployment.accessControls, expectedAccessControls);
        assertEq(deployment.proxy, expectedProxy);
        assertEq(deployment.rateLimits, expectedRateLimits);
        assertEq(deployment.controller, expectedController);

        assertEq(deployment.allocatorAgents.length, 1);
        assertEq(deployment.allocatorAgents[0], expectedAllocatorAgent);

        assertGt(deployment.accessControls.code.length, 0);
        assertGt(deployment.proxy.code.length, 0);
        assertGt(deployment.rateLimits.code.length, 0);
        assertGt(deployment.controller.code.length, 0);
        assertGt(deployment.allocatorAgents[0].code.length, 0);
    }

    function test_deploymentEventMatchesLibraryConfiguration() external {
        assembler = OseroPAUDeployment.defaultPAUAssembler();
        pauFactory = assembler.pauFactory();

        address administeredAgentFactory = assembler.administeredAgentFactory();
        address[] memory expectedAllocatorAgents = new address[](1);
        expectedAllocatorAgents[0] =
            vm.computeCreateAddress(administeredAgentFactory, vm.getNonce(administeredAgentFactory));

        address accessControls = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory));
        address proxy = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 1);
        address rateLimits = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 2);
        address controller = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 3);

        bytes32[] memory integrationIds = OseroPAUDeployment.integrationIds();
        IDefaultPAUAssembler.AdminConfig memory adminConfig = OseroPAUDeployment.adminConfig();
        IDefaultPAUAssembler.AdministeredAgentConfig[] memory allocatorAgentConfigs =
            OseroPAUDeployment.allocatorAgentConfigs();

        vm.expectEmit(address(assembler));
        emit IDefaultPAUAssembler.Deployment(
            proxy,
            controller,
            accessControls,
            rateLimits,
            expectedAllocatorAgents,
            integrationIds,
            adminConfig,
            allocatorAgentConfigs
        );

        OseroPAUDeployment.deploy();
    }

    function test_adminRolesAndRoleBoundaries() external view {
        address oseroSubProxy = OseroPAUDeployment.oseroSubProxy();
        address oseroOperator = OseroPAUDeployment.oseroOperator();
        address soterFreezer = OseroPAUDeployment.soterFreezer();
        address soterRelayer = OseroPAUDeployment.soterRelayer();

        IAccessControlLike accessControls = IAccessControlLike(deployment.accessControls);
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(accessControls.getRoleMemberCount(ALLOCATOR_ROLE), 1);
        assertEq(accessControls.getRoleAdmin(ALLOCATOR_ROLE), DEFAULT_ADMIN_ROLE);
        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, oseroSubProxy));
        assertTrue(accessControls.hasRole(ALLOCATOR_ROLE, deployment.allocatorAgents[0]));
        assertFalse(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)));
        assertFalse(accessControls.hasRole(ALLOCATOR_ROLE, oseroOperator));
        assertFalse(accessControls.hasRole(ALLOCATOR_ROLE, soterRelayer));
        assertFalse(accessControls.hasRole(ALLOCATOR_ROLE, soterFreezer));

        IAccessControlLike proxy = IAccessControlLike(deployment.proxy);
        assertTrue(proxy.hasRole(DEFAULT_ADMIN_ROLE, oseroSubProxy));
        assertTrue(proxy.hasRole(IALMProxyLike(deployment.proxy).CONTROLLER(), deployment.controller));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, oseroOperator));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, soterRelayer));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, soterFreezer));

        IAccessControlLike rateLimits = IAccessControlLike(deployment.rateLimits);
        assertTrue(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, oseroSubProxy));
        assertTrue(rateLimits.hasRole(IRateLimitsLike(deployment.rateLimits).CONTROLLER(), deployment.controller));
        assertFalse(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)));
        assertFalse(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, oseroOperator));
        assertFalse(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, soterRelayer));
        assertFalse(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, soterFreezer));
    }

    function test_allocatorAgentPermissionsAndBoundaries() external view {
        address allocatorAgentAddress = deployment.allocatorAgents[0];
        IAdministeredAgentLike allocatorAgent = IAdministeredAgentLike(allocatorAgentAddress);

        address oseroSubProxy = OseroPAUDeployment.oseroSubProxy();
        address oseroOperator = OseroPAUDeployment.oseroOperator();
        address soterFreezer = OseroPAUDeployment.soterFreezer();
        address soterRelayer = OseroPAUDeployment.soterRelayer();

        assertEq(allocatorAgent.adminCount(), 1);
        assertEq(allocatorAgent.actorCount(), 2);
        assertEq(allocatorAgent.grantorCount(), 0);
        assertEq(allocatorAgent.revokerCount(), 1);

        assertTrue(allocatorAgent.getIsAdmin(oseroSubProxy));
        assertTrue(allocatorAgent.getIsActor(soterRelayer));
        assertTrue(allocatorAgent.getIsActor(oseroOperator));
        assertTrue(allocatorAgent.getIsRevoker(soterFreezer));

        assertFalse(allocatorAgent.getIsAdmin(address(assembler)));
        assertFalse(allocatorAgent.getIsAdmin(soterRelayer));
        assertFalse(allocatorAgent.getIsAdmin(oseroOperator));
        assertFalse(allocatorAgent.getIsAdmin(soterFreezer));
        assertFalse(allocatorAgent.getIsActor(oseroSubProxy));
        assertFalse(allocatorAgent.getIsActor(soterFreezer));
        assertFalse(allocatorAgent.getIsGrantor(oseroSubProxy));
        assertFalse(allocatorAgent.getIsGrantor(soterRelayer));
        assertFalse(allocatorAgent.getIsGrantor(oseroOperator));
        assertFalse(allocatorAgent.getIsGrantor(soterFreezer));
        assertFalse(allocatorAgent.getIsRevoker(oseroSubProxy));
        assertFalse(allocatorAgent.getIsRevoker(soterRelayer));
        assertFalse(allocatorAgent.getIsRevoker(oseroOperator));
    }

    function test_allocatorActorsCanExecuteButNonActorsCannot() external {
        IAdministeredAgentLike allocatorAgent = IAdministeredAgentLike(deployment.allocatorAgents[0]);
        CallTarget target = new CallTarget();

        vm.prank(OseroPAUDeployment.soterRelayer());
        bytes memory relayerResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(abi.decode(relayerResult, (address)), deployment.allocatorAgents[0]);
        assertEq(target.lastSender(), deployment.allocatorAgents[0]);
        assertEq(target.callCount(), 1);

        vm.prank(OseroPAUDeployment.oseroOperator());
        bytes memory operatorResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(abi.decode(operatorResult, (address)), deployment.allocatorAgents[0]);
        assertEq(target.lastSender(), deployment.allocatorAgents[0]);
        assertEq(target.callCount(), 2);

        vm.prank(makeAddr("non-actor"));
        vm.expectRevert(IAdministeredAgentLike.NotActor.selector);
        bytes memory nonActorResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(nonActorResult.length, 0);
    }

    function test_controllerWiringAndIntegrations() external view {
        IControllerLike controller = IControllerLike(deployment.controller);

        assertEq(controller.accessControls(), deployment.accessControls);
        assertEq(controller.proxy(), deployment.proxy);
        assertEq(controller.rateLimits(), deployment.rateLimits);
        assertEq(controller.beacon(), IPAUFactoryLike(pauFactory).beacon());

        bytes32[] memory expectedIntegrationIds = OseroPAUDeployment.integrationIds();
        IControllerLike.Integration[] memory integrations = controller.integrations();
        assertEq(integrations.length, expectedIntegrationIds.length);

        assertEq(integrations[0].id, expectedIntegrationIds[0]);
        assertEq(integrations[0].config.facet, AAVE_FACET);
        assertEq(integrations[0].config.wires.length, 7);
        _assertWiresConfigured(integrations[0].config.wires);

        assertEq(integrations[1].id, expectedIntegrationIds[1]);
        assertEq(integrations[1].config.facet, USDS_FACET);
        assertEq(integrations[1].config.wires.length, 8);
        _assertWiresConfigured(integrations[1].config.wires);
    }

    function _assertWiresConfigured(IControllerLike.Wire[] memory wires) internal pure {
        for (uint256 i; i < wires.length; ++i) {
            assertTrue(wires[i].callSelector != bytes4(0));
            assertTrue(wires[i].delegateSelector != bytes4(0));
        }
    }
}
