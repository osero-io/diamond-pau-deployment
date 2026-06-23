// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {AllocatorIlkConfig, AllocatorInit} from "dss-allocator/deploy/AllocatorInit.sol";
import {AllocatorIlkInstance, AllocatorSharedInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {AllocatorBuffer} from "dss-allocator/src/AllocatorBuffer.sol";
import {AllocatorOracle} from "dss-allocator/src/AllocatorOracle.sol";
import {AllocatorRegistry} from "dss-allocator/src/AllocatorRegistry.sol";
import {AllocatorRoles} from "dss-allocator/src/AllocatorRoles.sol";
import {AllocatorVault} from "dss-allocator/src/AllocatorVault.sol";
import {DssInstance, MCD} from "dss-test/MCD.sol";

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
    struct RateLimitData {
        uint256 maxAmount;
        uint256 slope;
        uint256 lastAmount;
        uint256 lastUpdated;
    }

    function CONTROLLER() external view returns (bytes32);
    function getCurrentRateLimit(bytes32 key) external view returns (uint256);
    function getRateLimitData(bytes32 key) external view returns (RateLimitData memory);
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
}

interface IControllerFacetLike {
    function aave_deposit(address aToken, uint256 amount) external;
    function aave_getDepositRateLimitKey(address aToken, address pool, address underlyingAsset)
        external
        pure
        returns (bytes32);
    function aave_getMaxSlippage(address aToken) external view returns (uint256);
    function aave_getWithdrawRateLimitKey(address aToken, address pool) external pure returns (bytes32);
    function aave_setMaxSlippage(address aToken, uint256 maxSlippage) external;
    function aave_withdraw(address aToken, uint256 amount) external returns (uint256 amountWithdrawn);
    function usds_burn(uint256 usdsAmount) external;
    function usds_burnRateLimitKey() external pure returns (bytes32);
    function usds_mint(uint256 usdsAmount) external;
    function usds_mintRateLimitKey() external pure returns (bytes32);
    function usds_setVault(address vault) external;
    function usds_vault() external view returns (address);
}

interface IChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface IAuthLike {
    function deny(address usr) external;
    function rely(address usr) external;
}

interface IAllocatorBufferLike {
    function approve(address asset, address spender, uint256 amount) external;
}

interface IAllocatorVaultLike {
    function rely(address usr) external;
    function wards(address usr) external view returns (uint256);
}

interface IATokenLike {
    function POOL() external view returns (address);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface IERC20Like {
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
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

    address internal constant DSS_CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address internal constant MCD_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address internal constant SPARK_USDS_SPTOKEN = 0xC02aB1A5eaA8d1B114EF786D9bde108cD4364359;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

    bytes32 internal constant OSERO_ALLOCATOR_ILK = "OSERO-A";

    uint256 internal constant RAD = 10 ** 45;
    uint256 internal constant EIGHT_PCT_APY = 1.00000000244041860825840003e27;

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
    address internal oseroAllocatorBuffer;
    address internal oseroAllocatorVault;

    function setUp() external {
        // Pin the fork so deterministic addresses and live protocol state stay stable.
        vm.createSelectFork("mainnet", MAINNET_FORK_BLOCK);

        assembler = OseroPAUDeployment.defaultPAUAssembler();
        pauFactory = assembler.pauFactory();

        // Pre-compute CREATE addresses before deploy() consumes the factory nonces.
        address administeredAgentFactory = assembler.administeredAgentFactory();

        expectedAllocatorAgent =
            vm.computeCreateAddress(administeredAgentFactory, vm.getNonce(administeredAgentFactory));
        expectedAccessControls = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory));
        expectedProxy = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 1);
        expectedRateLimits = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 2);
        expectedController = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 3);

        // Deploy the PAU stack, then build the local allocator used by end-to-end tests.
        deployment = OseroPAUDeployment.deploy();
        _deployOseroAllocator();
    }

    function test_configurationLibraryBuildsExpectedInputs() external pure {
        // Integration IDs define the controller facet order.
        bytes32[] memory integrationIds = OseroPAUDeployment.integrationIds();
        assertEq(integrationIds.length, 2);
        assertEq(integrationIds[0], AAVE_FACET_INTEGRATION_ID);
        assertEq(integrationIds[1], USDS_FACET_INTEGRATION_ID);

        // Component admins should all resolve to the Osero subproxy.
        IDefaultPAUAssembler.AdminConfig memory adminConfig = OseroPAUDeployment.adminConfig();
        assertEq(adminConfig.accessControlAdmins.length, 1);
        assertEq(adminConfig.proxyAdmins.length, 1);
        assertEq(adminConfig.rateLimitsAdmins.length, 1);
        assertEq(adminConfig.accessControlAdmins[0], OseroPAUDeployment.oseroSubProxy());
        assertEq(adminConfig.proxyAdmins[0], OseroPAUDeployment.oseroSubProxy());
        assertEq(adminConfig.rateLimitsAdmins[0], OseroPAUDeployment.oseroSubProxy());

        // The allocator agent config should expose only the intended operators and freezer.
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
        // The deployment should consume the exact factory nonces predicted in setUp().
        assertEq(deployment.accessControls, expectedAccessControls);
        assertEq(deployment.proxy, expectedProxy);
        assertEq(deployment.rateLimits, expectedRateLimits);
        assertEq(deployment.controller, expectedController);

        assertEq(deployment.allocatorAgents.length, 1);
        assertEq(deployment.allocatorAgents[0], expectedAllocatorAgent);

        // Address checks are not enough; each deployed component must contain bytecode.
        assertGt(deployment.accessControls.code.length, 0);
        assertGt(deployment.proxy.code.length, 0);
        assertGt(deployment.rateLimits.code.length, 0);
        assertGt(deployment.controller.code.length, 0);
        assertGt(deployment.allocatorAgents[0].code.length, 0);
    }

    function test_deploymentEventMatchesLibraryConfiguration() external {
        assembler = OseroPAUDeployment.defaultPAUAssembler();
        pauFactory = assembler.pauFactory();

        // Recompute expected addresses against the current factory nonces for this deploy.
        address administeredAgentFactory = assembler.administeredAgentFactory();
        address[] memory expectedAllocatorAgents = new address[](1);
        expectedAllocatorAgents[0] =
            vm.computeCreateAddress(administeredAgentFactory, vm.getNonce(administeredAgentFactory));

        address accessControls = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory));
        address proxy = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 1);
        address rateLimits = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 2);
        address controller = vm.computeCreateAddress(pauFactory, vm.getNonce(pauFactory) + 3);

        // The emitted deployment payload should mirror the library-generated config.
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

        // AccessControls owns PAU-wide roles; only the allocator agent gets ALLOCATOR_ROLE.
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

        // The proxy accepts controller calls but does not grant admin rights to operators.
        IAccessControlLike proxy = IAccessControlLike(deployment.proxy);
        assertTrue(proxy.hasRole(DEFAULT_ADMIN_ROLE, oseroSubProxy));
        assertTrue(proxy.hasRole(IALMProxyLike(deployment.proxy).CONTROLLER(), deployment.controller));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, address(assembler)));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, oseroOperator));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, soterRelayer));
        assertFalse(proxy.hasRole(DEFAULT_ADMIN_ROLE, soterFreezer));

        // RateLimits follows the same admin boundary and controller-only mutation path.
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

        // Agent membership counts lock down the intended role surface.
        assertEq(allocatorAgent.adminCount(), 1);
        assertEq(allocatorAgent.actorCount(), 2);
        assertEq(allocatorAgent.grantorCount(), 0);
        assertEq(allocatorAgent.revokerCount(), 1);

        // Positive membership checks cover each configured agent role.
        assertTrue(allocatorAgent.getIsAdmin(oseroSubProxy));
        assertTrue(allocatorAgent.getIsActor(soterRelayer));
        assertTrue(allocatorAgent.getIsActor(oseroOperator));
        assertTrue(allocatorAgent.getIsRevoker(soterFreezer));

        // Negative checks prevent admins, actors, grantors, and revokers from overlapping.
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

        // Soter relayer can execute through the agent, and the target sees the agent as msg.sender.
        vm.prank(OseroPAUDeployment.soterRelayer());
        bytes memory relayerResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(abi.decode(relayerResult, (address)), deployment.allocatorAgents[0]);
        assertEq(target.lastSender(), deployment.allocatorAgents[0]);
        assertEq(target.callCount(), 1);

        // Osero operator has the same actor path and increments the target call count.
        vm.prank(OseroPAUDeployment.oseroOperator());
        bytes memory operatorResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(abi.decode(operatorResult, (address)), deployment.allocatorAgents[0]);
        assertEq(target.lastSender(), deployment.allocatorAgents[0]);
        assertEq(target.callCount(), 2);

        // A random non-actor must fail before the target call executes.
        vm.prank(makeAddr("non-actor"));
        vm.expectRevert(IAdministeredAgentLike.NotActor.selector);
        bytes memory nonActorResult = allocatorAgent.call(address(target), abi.encodeCall(CallTarget.record, ()));
        assertEq(nonActorResult.length, 0);
    }

    function test_controllerWiringAndIntegrations() external view {
        IControllerLike controller = IControllerLike(deployment.controller);

        // Core controller pointers should match the deployed PAU components.
        assertEq(controller.accessControls(), deployment.accessControls);
        assertEq(controller.proxy(), deployment.proxy);
        assertEq(controller.rateLimits(), deployment.rateLimits);
        assertEq(controller.beacon(), IPAUFactoryLike(pauFactory).beacon());

        // Controller integrations should preserve the library order and expected facet wiring.
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

    function test_endToEnd_usdsFacetMintsThenBurnsThroughSkyAllocatorVault() external {
        uint256 usdsAmount = 100e18;

        IControllerFacetLike controller = IControllerFacetLike(deployment.controller);
        IRateLimitsLike rateLimits = IRateLimitsLike(deployment.rateLimits);

        // Give the PAU proxy permission to use the local allocator vault and buffer.
        _authorizeProxyOnOseroAllocator();

        // Configure the USDS facet to mint from and burn back into the Osero allocator vault.
        vm.prank(OseroPAUDeployment.oseroSubProxy());
        controller.usds_setVault(oseroAllocatorVault);
        assertEq(controller.usds_vault(), oseroAllocatorVault);

        bytes32 mintKey = controller.usds_mintRateLimitKey();
        bytes32 burnKey = controller.usds_burnRateLimitKey();

        // Seed one-shot mint and burn limits so each operation must consume its own key.
        vm.startPrank(OseroPAUDeployment.oseroSubProxy());
        rateLimits.setRateLimitData(mintKey, usdsAmount, 0);
        rateLimits.setRateLimitData(burnKey, usdsAmount, 0);
        vm.stopPrank();

        assertEq(rateLimits.getCurrentRateLimit(mintKey), usdsAmount);
        assertEq(rateLimits.getCurrentRateLimit(burnKey), usdsAmount);
        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), 0);

        // Mint through the allocator agent; the proxy receives USDS and spends the mint limit.
        _operateDiamond(abi.encodeCall(IControllerFacetLike.usds_mint, (usdsAmount)));

        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), usdsAmount);
        assertEq(rateLimits.getCurrentRateLimit(mintKey), 0);

        // Burn through the same path; USDS returns to zero and the burn limit is consumed.
        _operateDiamond(abi.encodeCall(IControllerFacetLike.usds_burn, (usdsAmount)));

        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), 0);
        assertEq(rateLimits.getCurrentRateLimit(burnKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(mintKey), usdsAmount);
    }

    function test_endToEnd_usdsFacetFundsSparkLendAaveFacet() external {
        uint256 usdsAmount = 100e18;
        // Configure USDS, Aave, and rate-limit state shared by the Spark Lend flow.
        (bytes32 depositKey, bytes32 withdrawKey) = _configureSparkLendFacetTest(usdsAmount);

        // Start with freshly minted USDS held by the PAU proxy.
        _operateDiamond(abi.encodeCall(IControllerFacetLike.usds_mint, (usdsAmount)));
        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), usdsAmount);
        assertEq(IERC20Like(SPARK_USDS_SPTOKEN).balanceOf(deployment.proxy), 0);

        // Deposit USDS into Spark Lend; the proxy should receive spTokens and spend deposit capacity.
        _operateDiamond(abi.encodeCall(IControllerFacetLike.aave_deposit, (SPARK_USDS_SPTOKEN, usdsAmount)));
        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), 0);
        assertGe(IERC20Like(SPARK_USDS_SPTOKEN).balanceOf(deployment.proxy), usdsAmount);
        assertEq(IRateLimitsLike(deployment.rateLimits).getCurrentRateLimit(depositKey), 0);

        // Withdraw back to USDS and verify the facet returns the withdrawn amount.
        bytes memory withdrawResult =
            _operateDiamond(abi.encodeCall(IControllerFacetLike.aave_withdraw, (SPARK_USDS_SPTOKEN, usdsAmount)));

        assertEq(abi.decode(withdrawResult, (uint256)), usdsAmount);
        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), usdsAmount);
        assertEq(IERC20Like(SPARK_USDS_SPTOKEN).balanceOf(deployment.proxy), 0);
        assertEq(IRateLimitsLike(deployment.rateLimits).getCurrentRateLimit(withdrawKey), 0);
        assertEq(IRateLimitsLike(deployment.rateLimits).getCurrentRateLimit(depositKey), usdsAmount);

        // Burn the withdrawn USDS so the end-to-end flow exits with no proxy balance.
        _operateDiamond(abi.encodeCall(IControllerFacetLike.usds_burn, (usdsAmount)));
        assertEq(IERC20Like(USDS).balanceOf(deployment.proxy), 0);
    }

    function test_endToEnd_operatorCannotBypassAllocatorAgent() external {
        // Operators must route through the allocator agent; direct controller calls lack ALLOCATOR_ROLE.
        vm.prank(OseroPAUDeployment.oseroOperator());
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", OseroPAUDeployment.oseroOperator(), ALLOCATOR_ROLE
            )
        );
        IControllerFacetLike(deployment.controller).usds_mint(1);
    }

    function _operateDiamond(bytes memory data) internal returns (bytes memory result) {
        // All mutating controller calls in these tests execute via the configured operator path.
        vm.prank(OseroPAUDeployment.oseroOperator());
        result = IAdministeredAgentLike(deployment.allocatorAgents[0]).call(deployment.controller, data);
    }

    function _configureSparkLendFacetTest(uint256 usdsAmount)
        internal
        returns (bytes32 depositKey, bytes32 withdrawKey)
    {
        IControllerFacetLike controller = IControllerFacetLike(deployment.controller);
        IRateLimitsLike rateLimits = IRateLimitsLike(deployment.rateLimits);
        address sparkPool = IATokenLike(SPARK_USDS_SPTOKEN).POOL();

        // Sanity-check that the Spark market under test is the USDS market.
        assertEq(IATokenLike(SPARK_USDS_SPTOKEN).UNDERLYING_ASSET_ADDRESS(), USDS);

        // Wire allocator permissions before facets attempt to move USDS through the proxy.
        _authorizeProxyOnOseroAllocator();

        // Configure facet state and per-operation rate limits as the Osero subproxy admin.
        vm.startPrank(OseroPAUDeployment.oseroSubProxy());
        controller.usds_setVault(oseroAllocatorVault);
        controller.aave_setMaxSlippage(SPARK_USDS_SPTOKEN, 1e18);

        depositKey = controller.aave_getDepositRateLimitKey(SPARK_USDS_SPTOKEN, sparkPool, USDS);
        withdrawKey = controller.aave_getWithdrawRateLimitKey(SPARK_USDS_SPTOKEN, sparkPool);

        rateLimits.setRateLimitData(controller.usds_mintRateLimitKey(), usdsAmount, 0);
        rateLimits.setRateLimitData(controller.usds_burnRateLimitKey(), usdsAmount, 0);
        rateLimits.setRateLimitData(depositKey, usdsAmount, 0);
        rateLimits.setRateLimitData(withdrawKey, usdsAmount, 0);
        vm.stopPrank();

        // Confirm setup took effect before the caller exercises deposit or withdrawal paths.
        assertEq(controller.aave_getMaxSlippage(SPARK_USDS_SPTOKEN), 1e18);
        assertEq(rateLimits.getCurrentRateLimit(depositKey), usdsAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), usdsAmount);
    }

    function _deployOseroAllocator() internal {
        // Build a minimal Maker allocator instance on the fork for PAU integration tests.
        DssInstance memory dss = MCD.loadFromChainlog(DSS_CHAINLOG);
        address usdsJoin = IChainlogLike(DSS_CHAINLOG).getAddress("USDS_JOIN");

        AllocatorSharedInstance memory sharedInstance;
        sharedInstance.oracle = address(new AllocatorOracle());
        sharedInstance.roles = address(new AllocatorRoles());
        sharedInstance.registry = address(new AllocatorRegistry());

        // Hand ownership to the pause proxy so AllocatorInit can initialize shared contracts.
        _switchOwner(sharedInstance.roles, MCD_PAUSE_PROXY);
        _switchOwner(sharedInstance.registry, MCD_PAUSE_PROXY);

        AllocatorIlkInstance memory ilkInstance;
        ilkInstance.buffer = address(new AllocatorBuffer());
        ilkInstance.vault =
            address(new AllocatorVault(sharedInstance.roles, ilkInstance.buffer, OSERO_ALLOCATOR_ILK, usdsJoin));
        ilkInstance.owner = MCD_PAUSE_PROXY;

        // The ilk-level buffer and vault are also initialized under pause-proxy authority.
        _switchOwner(ilkInstance.buffer, MCD_PAUSE_PROXY);
        _switchOwner(ilkInstance.vault, MCD_PAUSE_PROXY);

        AllocatorIlkConfig memory ilkConfig = AllocatorIlkConfig({
            ilk: OSERO_ALLOCATOR_ILK,
            duty: EIGHT_PCT_APY,
            maxLine: 100_000_000 * RAD,
            gap: 10_000_000 * RAD,
            ttl: 6 hours,
            allocatorProxy: OseroPAUDeployment.oseroSubProxy(),
            ilkRegistry: IChainlogLike(DSS_CHAINLOG).getAddress("ILK_REGISTRY")
        });

        // Initialize the allocator ilk as Maker governance would on mainnet.
        vm.startPrank(MCD_PAUSE_PROXY);
        AllocatorInit.initShared(dss, sharedInstance);
        AllocatorInit.initIlk(dss, sharedInstance, ilkInstance, ilkConfig);
        vm.stopPrank();

        oseroAllocatorBuffer = ilkInstance.buffer;
        oseroAllocatorVault = ilkInstance.vault;
    }

    function _switchOwner(address target, address newOwner) internal {
        IAuthLike(target).rely(newOwner);
        IAuthLike(target).deny(address(this));
    }

    function _authorizeProxyOnOseroAllocator() internal {
        // Osero subproxy grants PAU vault authority and buffer allowance for USDS movements.
        vm.startPrank(OseroPAUDeployment.oseroSubProxy());
        IAllocatorVaultLike(oseroAllocatorVault).rely(deployment.proxy);
        IAllocatorBufferLike(oseroAllocatorBuffer).approve(USDS, deployment.proxy, type(uint256).max);
        vm.stopPrank();

        // Assert both auth and token allowances before an end-to-end test depends on them.
        assertEq(IAllocatorVaultLike(oseroAllocatorVault).wards(deployment.proxy), 1);
        assertEq(IERC20Like(USDS).allowance(oseroAllocatorBuffer, deployment.proxy), type(uint256).max);
        assertEq(IERC20Like(USDS).allowance(oseroAllocatorBuffer, oseroAllocatorVault), type(uint256).max);
    }

    function _assertWiresConfigured(IControllerLike.Wire[] memory wires) internal pure {
        // Every configured wire must map a public selector to a delegate selector.
        for (uint256 i; i < wires.length; ++i) {
            assertTrue(wires[i].callSelector != bytes4(0));
            assertTrue(wires[i].delegateSelector != bytes4(0));
        }
    }
}
