// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {Helper} from "../src/libraries/Helper.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract FactoryTest is Test {
    Factory public factory;
    address public constant registryAddress = address(0x1);
    address public constant poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public constant positionManager = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant router = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant owner = 0xB3FFde53f0076295f2C183f13b4A07dE288Df61D;
    address public constant nonProfitOrg = address(0x7);
    address public fundraisingTokenAddress;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public constant quoter = 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203;
    address public constant stateView = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint160 public constant sqrtPriceX96 = 79228162514264337593543950336; // 1:1 price ratio
    address treasuryWalletAddress;
    address donationWalletAddress;
    address constant admin = address(0x22);

    string tokenName = "Fundraising Token";
    string tokenSymbol = "FTN";
    uint256 taxFee = 2e16; // 2%
    uint256 maximumThreshold = 30e16; // 30%
    uint256 minimumHealthThreshhold = 5e16; // 7%
    uint256 transferInterval = 30 days;
    uint256 public minLPHealthThreshhold = 5e16; // 5%
    int24 tickSpacing = 60;

    address public nonProfitOrg2 = address(0x27);
    address treasuryWalletBeacon;
    address donationWalletBeacon;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.startPrank(owner);

        address treasuryImplementation = address(new TreasuryWallet());
        treasuryWalletBeacon = address(new UpgradeableBeacon(treasuryImplementation, msg.sender));
        // deploy donation wallet beacon
        address donationWalletImplementation = address(new DonationWallet());
        donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));

        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        factory.initialize(
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );

        factory.createFundraisingVault("FundraisingToken", "FTN", usdc, nonProfitOrg);

        factory.createFundraisingVault("FundraisingToken", "FTN", address(0), nonProfitOrg2);

        (fundraisingTokenAddress,, treasuryWalletAddress, donationWalletAddress,,,) = factory.protocols(nonProfitOrg);
        vm.stopPrank();
    }

    function testCannotInitializeImplementation() public {
        Factory factoryImplementation = new Factory();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factoryImplementation.initialize(
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroPoolManagerAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            address(0),
            positionManager,
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroPositionManagerAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            address(0),
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroTreasuryWalletBeaconAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager, positionManager, router, permit2, quoter, admin, address(0), donationWalletBeacon, stateView
        );
    }

    function testInitializeRevertsOnZeroDonationWalletBeaconAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager, positionManager, router, permit2, quoter, admin, treasuryWalletBeacon, address(0), stateView
        );
    }

    function testInitializeRevertsOnZeroRouterAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            positionManager,
            address(0),
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitialzeRevertsOnZeroPermit2Address() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            positionManager,
            router,
            address(0),
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroQuoterAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            positionManager,
            router,
            permit2,
            address(0),
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroAdminAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            address(0),
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
    }

    function testInitializeRevertsOnZeroStateViewAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            address(0)
        );
    }

    function testInitializeSetsStateVariables() public view {
        assertEq(factory.poolManager(), poolManager);
        assertEq(factory.positionManager(), positionManager);
        assertEq(factory.router(), router);
        assertEq(factory.permit2(), permit2);
    }

    function testOwnerIsSetCorrectly() public view {
        assertEq(factory.owner(), owner);
    }

    function testOnlyOwnerModifier() public {
        vm.startPrank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.transferOwnership(address(0x20));
        vm.stopPrank();

        vm.startPrank(owner);
        console.log(factory.owner(), "owner");
        factory.transferOwnership(address(0x20));
        vm.stopPrank();
        vm.startPrank(address(0x20));
        // two step ownership transfer
        factory.acceptOwnership();
        assertEq(factory.owner(), address(0x20));
    }

    function testCreateFundraisingVaultRevertsIfNotOwner() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createFundraisingVault("TokenName", "TKN", usdc, nonProfitOrg);
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsOnZeroOwnerAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createFundraisingVault("TokenName", "TKN", usdc, address(0));
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsIfVaultAlreadyExists() public {
        vm.prank(owner);
        vm.expectRevert(Factory.VaultAlreadyExists.selector);
        factory.createFundraisingVault("TokenName", "TKN", usdc, nonProfitOrg);
        vm.stopPrank();
    }

    function testCreateFundraisingVaultAndEmitFundraisingVaultCreatedEvent() public {
        vm.prank(owner);
        factory.createFundraisingVault("TokenName", "TKN", usdc, address(30));
        (address fundraisingToken,, address treasuryWallet, address donationWallet,,,) = factory.protocols(address(30));
        assert(fundraisingToken != address(0));
        assert(donationWallet != address(0));
        assert(treasuryWallet != address(0));

        FundRaisingToken token = FundRaisingToken(fundraisingToken);
        assertEq(token.name(), "TokenName");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), IERC20Metadata(usdc).decimals());
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** token.decimals());
        assertEq(token.balanceOf(treasuryWallet), 250_000_000 * 10 ** token.decimals());
        assertEq(token.balanceOf(donationWallet), 0);
        assertEq(token.balanceOf(owner), 750_000_000 * 10 ** token.decimals());
        assertEq(token.lpManager(), factory.owner());
        assertEq(token.treasuryAddress(), treasuryWallet);

        DonationWallet dw = DonationWallet(payable(donationWallet));
        assertEq(dw.owner(), address(30));
        assertEq(dw.factoryAddress(), address(factory));
        assertEq(address(dw.router()), router);
        assertEq(address(dw.poolManager()), poolManager);
        assertEq(address(dw.permit2()), permit2);
        assertEq(address(dw.positionManager()), positionManager);

        TreasuryWallet tw = TreasuryWallet(payable(treasuryWallet));
        assertEq(tw.donationAddress(), donationWallet);
        assertEq(tw.factoryAddress(), address(factory));
        assertEq(address(tw.router()), router);
        assertEq(address(tw.poolManager()), poolManager);
        assertEq(address(tw.permit2()), permit2);
        assertEq(address(tw.positionManager()), positionManager);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroOwnerAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createPool(address(0), 1, 1);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroAmount0() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.createPool(nonProfitOrg, 0, 1);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroAmount1() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.createPool(nonProfitOrg, 1, 0);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreateIfEtherPassedIsNotEqualToAmount0() public {
        vm.prank(owner);
        uint256 amount0 = 7 ether; // amount of Eth
        (address fundraisingTokenAddress2,,,,,,) = factory.protocols(nonProfitOrg2);
        uint256 amount1 = IERC20Metadata(fundraisingTokenAddress2).balanceOf(owner); // amount of fundraising token

        vm.startPrank(owner);
        IERC20Metadata(fundraisingTokenAddress2).approve(address(factory), amount1);
        vm.expectRevert(Factory.InvalidAmount0.selector);
        factory.createPool(nonProfitOrg2, amount0, amount1);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreatePoolIfVaultNotCreated() public {
        vm.prank(owner);
        vm.expectRevert(Factory.FundraisingVaultNotCreated.selector);
        factory.createPool(address(0x10), 1, 1);
        vm.stopPrank();
    }

    function testCreatePoolOnlyOwnerCanCreatePool() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createPool(owner, 1, 1);
        vm.stopPrank();
    }

    function testCreatePoolSwapsCurrienciesIfCurrency0IsGreaterThanCurrency1() public {
        vm.startPrank(owner);
        address nonProfitOrg3 = address(0x100);
        factory.createFundraisingVault("FundraisingToken", "FTN", usdc, nonProfitOrg3);

        (address _fundraisingTokenAddress,,,,,,) = factory.protocols(nonProfitOrg3);

        vm.stopPrank();

        uint256 amount0 = 100_000_000_000; // amount of usdc
        uint256 amount1 = IERC20Metadata(_fundraisingTokenAddress).balanceOf(owner); // amount of fundraising token

        vm.startPrank(USDC_WHALE);

        IERC20Metadata(usdc).transfer(owner, amount0);
        vm.stopPrank();

        uint256 tolerance = 2_200; // add some tolerance due to precision

        vm.startPrank(owner);
        IERC20Metadata(usdc).approve(address(factory), amount0);
        IERC20Metadata(_fundraisingTokenAddress).approve(address(factory), amount1);
        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(usdc, _fundraisingTokenAddress, nonProfitOrg);
        factory.createPool(nonProfitOrg3, amount0, amount1);
        assertApproxEqAbs(IERC20Metadata(_fundraisingTokenAddress).balanceOf(poolManager), amount1, tolerance);
        assertEq(IERC20Metadata(usdc).balanceOf(address(factory)), 0);
        // PoolKey memory key = factory.getPoolKey(nonProfitOrg3);
        // assertEq(Currency.unwrap(key.currency0), _fundraisingTokenAddress);
        //  assertEq(Currency.unwrap(key.currency1), usdc);
        vm.stopPrank();
    }

    function testCreatePoolOwnerCanCreateAPoolOnUniswap() public {
        vm.prank(owner);
        uint256 amount0 = 30_000_000_000; // amount of usdc
        uint256 amount1 = IERC20Metadata(fundraisingTokenAddress).balanceOf(owner); // amount of fundraising token

        vm.startPrank(USDC_WHALE);

        IERC20Metadata(usdc).transfer(owner, amount0);
        vm.stopPrank();

        vm.startPrank(owner);
        IERC20Metadata(usdc).approve(address(factory), amount0);
        IERC20Metadata(fundraisingTokenAddress).approve(address(factory), amount1);
        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(usdc, fundraisingTokenAddress, nonProfitOrg);
        factory.createPool(nonProfitOrg, amount0, amount1);
        assertEq(IERC20Metadata(fundraisingTokenAddress).balanceOf(poolManager), amount1 - 1);
        assertEq(IERC20Metadata(usdc).balanceOf(address(factory)), 0);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreateSamePoolTwice() public {
        testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(owner);
        vm.expectRevert(Factory.PoolAlreadyExists.selector);
        factory.createPool(nonProfitOrg, 1, 1);
        vm.stopPrank();
    }

    function testSwapFundraisingToken() public {
        testCreatePoolOwnerCanCreateAPoolOnUniswap();

        vm.startPrank(address(factory));

        // transfer some amount to donation wallet
        vm.roll(block.number + 10);
        TreasuryWallet treasury = TreasuryWallet(payable(treasuryWalletAddress));
        treasury.setRegistry(registryAddress);
        bytes memory performData = abi.encode(true, false);
        vm.stopPrank();
        vm.startPrank(registryAddress);
        treasury.performUpkeep(performData);

        assert(IERC20Metadata(fundraisingTokenAddress).balanceOf(donationWalletAddress) > 0);

        assert(IERC20Metadata(usdc).balanceOf(donationWalletAddress) == 0);
        vm.stopPrank();

        vm.startPrank(address(factory));
        // swap fundraising token to usdc

        DonationWallet donation = DonationWallet(payable(donationWalletAddress));
        donation.setRegistry(registryAddress);
        vm.stopPrank();
        vm.startPrank(registryAddress);
        donation.performUpkeep(bytes(""));

        assert(IERC20Metadata(usdc).balanceOf(nonProfitOrg) > 0);
    }

    function testCreatePoolOwnerCanCreatePoolUsingEtherAsUnderlyingToken() public {
        vm.prank(owner);
        uint256 amount0 = 7 ether; // amount of Eth
        (address fundraisingTokenAddress2,,,,,,) = factory.protocols(nonProfitOrg2);
        uint256 amount1 = IERC20Metadata(fundraisingTokenAddress2).balanceOf(owner); // amount of fundraising token

        vm.deal(owner, amount0);

        uint256 tolerance = 2_200; // add some tolerance due to precision

        vm.startPrank(owner);
        IERC20Metadata(fundraisingTokenAddress2).approve(address(factory), amount1);
        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(address(0), fundraisingTokenAddress, nonProfitOrg);
        factory.createPool{value: amount0}(nonProfitOrg2, amount0, amount1);
        // amount should be added as a liquidity
        assertEq(address(factory).balance, 0);
        assertApproxEqAbs(IERC20Metadata(fundraisingTokenAddress2).balanceOf(address(poolManager)), amount1, tolerance);
        vm.stopPrank();
    }

    function testSetTreasuryEmergencyPauseRevertsIfNonProfitOrgAddressIsZeroAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setTreasuryPaused(address(0), true);
    }

    function testsetTreasuryPausedRevertsIfNotCalledByNonProfitOrg() public {
        vm.expectRevert(Factory.OnlyCalledByNonProfitOrg.selector);
        factory.setTreasuryPaused(nonProfitOrg, true);
    }

    function testsetTreasuryPausedEmitsTreasuryEmergencyPauseSetEvent() public {
        vm.startPrank(nonProfitOrg);
        vm.expectEmit(true, true, false, false);

        emit Factory.TreasuryEmergencyPauseSet(nonProfitOrg, treasuryWalletAddress, true);
        factory.setTreasuryPaused(nonProfitOrg, true);
    }

    function testSetAllTreasuriesPausedRevertsIfNotCalledByAdmin() public {
        vm.prank(address(0x10));
        vm.expectRevert(Factory.NotAdmin.selector);
        factory.setAllTreasuriesPaused(true);
    }

    function testSetAllTreasuriesPausedRevertsIfPauseAlreadySet() public {
        vm.prank(admin);
        factory.setAllTreasuriesPaused(true);

        vm.prank(admin);
        vm.expectRevert(Factory.EmergencyPauseAlreadySet.selector);
        factory.setAllTreasuriesPaused(true);
    }

    function testSetAllTreasuriesPausedEmitsAllTreasuriesEmergencyPauseSetEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);

        emit Factory.AllTreasuriesPaused(true);
        factory.setAllTreasuriesPaused(true);
    }

    function testEmergencyWithdrawRevertsIfCalledByNonTreasuryWallet() public {
        vm.prank(address(0x10));
        vm.expectRevert(Factory.OnlyCalledByNonProfitOrg.selector);
        factory.emergencyWithdraw();
    }

    function testEmergencyWithdrawEmitsEmergencyWithdrawnEvent() public {
        vm.startPrank(admin);
        factory.setAllTreasuriesPaused(true);
        vm.stopPrank();
        vm.startPrank(nonProfitOrg);
        uint256 treasuryBalanceBeforeWithdraw = IERC20Metadata(fundraisingTokenAddress).balanceOf(treasuryWalletAddress);
        assert(treasuryBalanceBeforeWithdraw > 0);
        vm.expectEmit(true, true, false, false);
        emit Factory.EmergencyWithdrawn(treasuryWalletAddress, nonProfitOrg, treasuryBalanceBeforeWithdraw);
        factory.emergencyWithdraw();

        assertEq(
            IERC20Metadata(fundraisingTokenAddress).balanceOf(treasuryWalletAddress),
            0,
            "Treasury wallet balance should be zero after emergency withdraw"
        );
        assertEq(
            IERC20Metadata(fundraisingTokenAddress).balanceOf(nonProfitOrg),
            treasuryBalanceBeforeWithdraw,
            "Non profit org should receive the withdrawn amount"
        );
    }

    function testSetRegistryAddressForTreasuryRevertsOnZeroNonProfitOrgAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setRegistryForTreasuryWallet(address(0), registryAddress);
    }

    function testSetRegistryAddressForTreasuryRevertsOnZeroRegistryAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setRegistryForTreasuryWallet(address(20), address(0));
    }

    function testSetRegistryAddressForTreasuryRevertsIfNotCalledbyOwner() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.setRegistryForTreasuryWallet(address(20), registryAddress);
    }

    function testSetRegistryAddressForTreasuryRevertsIfVaultIsNotCreated() public {
        vm.startPrank(owner);
        vm.expectRevert(Factory.ProtocolNotAvailable.selector);
        factory.setRegistryForTreasuryWallet(address(20), registryAddress);
    }

    function testSetRegistryAddressForTreasuryRevertsIfAlreadySet() public {
        vm.startPrank(owner);
        factory.setRegistryForTreasuryWallet(nonProfitOrg, registryAddress);
        vm.expectRevert(Factory.RegistryAlreadySet.selector);
        factory.setRegistryForTreasuryWallet(nonProfitOrg, registryAddress);
    }

    function testSetRegistryAddressForTreasurySetRegistryAddressForTheGivenTreasuryAndEmitsEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit Factory.RegistryAddressForTreasurySet(treasuryWalletAddress, registryAddress);
        factory.setRegistryForTreasuryWallet(nonProfitOrg, registryAddress);
        assertEq(TreasuryWallet(payable(treasuryWalletAddress)).registryAddress(), registryAddress);
    }

    function testSetRegistryAddressForDonationRevertsOnZeroNonProfitOrgAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setRegistryForDonationWallet(address(0), registryAddress);
    }

    function testSetRegistryAddressForDonationRevertsOnZeroRegistryAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setRegistryForDonationWallet(address(20), address(0));
    }

    function testSetRegistryAddressForDonationRevertsIfNotCalledbyOwner() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.setRegistryForDonationWallet(address(20), registryAddress);
    }

    function testSetRegistryAddressForDonationRevertsIfVaultIsNotCreated() public {
        vm.startPrank(owner);
        vm.expectRevert(Factory.ProtocolNotAvailable.selector);
        factory.setRegistryForDonationWallet(address(20), registryAddress);
    }

    function testSetRegistryAddressForDonationRevertsIfAlreadySet() public {
        vm.startPrank(owner);
        factory.setRegistryForDonationWallet(nonProfitOrg, registryAddress);
        vm.expectRevert(Factory.RegistryAlreadySet.selector);
        factory.setRegistryForDonationWallet(nonProfitOrg, registryAddress);
    }

    function testSetRegistryAddressForDonationSetRegistryAddressForTheGivenTreasuryAndEmitsEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit Factory.RegistryAddressForDonationSet(donationWalletAddress, registryAddress);
        factory.setRegistryForDonationWallet(nonProfitOrg, registryAddress);
        assertEq(DonationWallet(payable(donationWalletAddress)).registryAddress(), registryAddress);
    }
}
