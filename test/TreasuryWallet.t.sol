// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IV4Quoter} from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import {CustomRevert} from "@uniswap/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Factory} from "../src/Factory.sol";
import {FactoryTest} from "./Factory.t.sol";
import {BuyFundraisingTokens} from "./BuyTokens.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TreasuryWalletTest is Test, BuyFundraisingTokens {
    TreasuryWallet public treasuryWallet;
    FundRaisingToken public fundRaisingToken;

    address constant DONATION = address(0x1111);
    address constant FACTORY = address(0x2222);
    address constant REGISTRY = address(0x3333);
    address constant ROUTER = address(0x4444);
    address constant POOL_MANAGER = address(0x5555);
    address constant PERMIT2 = address(0x6666);
    address constant POSITION_MANAGER = address(0x7777);
    address constant QUOTER = address(0x8888);
    address constant LP_MANAGER = address(0x11);
    address constant STATE_VIEW = address(0x12);
    uint256 constant MIN_HEALTH = 7e16; // 7%
    uint256 constant TRANSFER_INTERVAL = 30 days;
    uint256 constant MIN_LP_HEALTH = 5e16;
    int24 constant DEFAULT_TICK = 60;

    uint256 internal constant MULTIPLIER = 1e18;

    address treasuryBeacon;
    address factoryProxy;

    function setUp() public {
        address treasuryImplementation = address(new TreasuryWallet());
        treasuryBeacon = address(new UpgradeableBeacon(treasuryImplementation, msg.sender));
        treasuryWallet = TreasuryWallet(payable(payable(address(new BeaconProxy(treasuryBeacon, "")))));
        address factoryImplementation = address(new Factory());
        factoryProxy = address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes("")));
        fundRaisingToken = new FundRaisingToken("FundRaisingToken", "FRT", 6, LP_MANAGER, address(treasuryWallet), 1e27);

        treasuryWallet.initialize(
            DONATION,
            factoryProxy,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroDonationAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            address(0),
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroFactoryAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            address(0),
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroRouterAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            address(0),
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroPoolManagerAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            address(0),
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroPermit2Address() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            address(0),
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroPositionManagerAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            address(0),
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroQuoterAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            address(0),
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testRevertOnZeroFundraisingTokenAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(0),
            STATE_VIEW
        );
    }

    function testCannotInitializeTwice() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector); // expected since initialize should only be callable once
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );
    }

    function testInitializeSetsValuesCorrectly() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            DEFAULT_TICK,
            address(fundRaisingToken),
            STATE_VIEW
        );

        assertEq(treasuryWallet.donationAddress(), DONATION);
        assertEq(treasuryWallet.factoryAddress(), FACTORY);
        assertEq(treasuryWallet.transferInterval(), TRANSFER_INTERVAL);
    }

    function testCheckUpkeepReturnsFalseUpkeepNeededAndZeroBytesPerformDataIfPaused() public {
        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);

        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));

        assertEq(upkeepNeeded, false);
        assertEq(performData, bytes(""));
    }

    function testCheckUpkeepReturnsFalseIfTransferIntervalNotReached() public {
        vm.startPrank(LP_MANAGER);
        // on transfer tax is routed to treasury wallet, so adding extra amount to treasury to keep lp healthy
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH + 2e16)) / MULTIPLIER;

        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
        assertEq(performData, bytes(""));
    }

    function testCheckUpkeepReturnsFalseIfTransferNotAllowedAndLPIsHealthy() public {
        vm.startPrank(address(treasuryWallet));
        // transfer FTN to donation to make treasury balance less than min health
        fundRaisingToken.transfer(DONATION, 210000000000000000000000000);
        vm.stopPrank();
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH + 2e16)) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
        assertEq(performData, bytes(""));
    }

    function testCheckUpkeepReturnsTrueIfLPIsNotHealthyAndTransferNotAllowed() public {
        vm.startPrank(address(treasuryWallet));
        // transfer FTN to donation to make treasury balance less than min health
        fundRaisingToken.transfer(DONATION, 210000000000000000000000000);
        vm.stopPrank();
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH - 2000)) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, true);
        bytes memory _performData = abi.encode(false, true);
        assertEq(performData, _performData);
    }

    function testCheckUpkeepReturnsUpKeepNeededTrueAndInitiateAddLiquidityAndInitiateTransferTrue() public {
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH)) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, true);
        bytes memory _performData = abi.encode(true, true);
        assertEq(performData, _performData);

        (bool initiateTransfer, bool initiateAddLiquidity) = abi.decode(_performData, (bool, bool));
        assertEq(initiateTransfer, true);
        assertEq(initiateAddLiquidity, true);
        vm.stopPrank();
    }

    function testPerformUpkeepOnlyCalledByRegistryAddress() public {
        vm.startPrank(address(20));
        bytes memory _performData = abi.encode(true, false);
        vm.expectRevert(TreasuryWallet.OnlyRegistry.selector);
        treasuryWallet.performUpkeep(_performData);
    }

    function testPerformUpkeepCannotInitiateTransferIfInitiateTransferIsFalseAndCannotInitiateAddLiquidityIfInitiateAddLiquidityIsFalse()
        public
    {
        vm.startPrank(address(factoryProxy));
        bytes memory _performData = abi.encode(false, false);
        uint256 balanceBeforePerformUpKeep = IERC20Metadata(fundRaisingToken).balanceOf(address(treasuryWallet));
        treasuryWallet.setRegistry(REGISTRY);
        vm.stopPrank();
        vm.startPrank(REGISTRY);
        treasuryWallet.performUpkeep(_performData);
        uint256 balanceAfterPerformUpKeep = IERC20Metadata(fundRaisingToken).balanceOf(address(treasuryWallet));

        assertEq(balanceAfterPerformUpKeep, balanceBeforePerformUpKeep);
    }

    function testPerformUpKeepTransferFundsToDonationWalletIfInitiateTransferIsTrue() public {
        vm.startPrank(address(factoryProxy));
        bytes memory _performData = abi.encode(true, false);
        uint256 totalSupplyBeforeBurn = fundRaisingToken.totalSupply();
        uint256 amountToTransferAndBurn = (fundRaisingToken.totalSupply() * 2e16) / 1e18; // 2% of total supply
        uint256 treasuryBalanceBeforeTransfer = fundRaisingToken.balanceOf(address(treasuryWallet));
        treasuryWallet.setRegistry(REGISTRY);
        vm.stopPrank();
        vm.startPrank(REGISTRY);
        treasuryWallet.performUpkeep(_performData);

        assertEq(fundRaisingToken.totalSupply(), totalSupplyBeforeBurn - amountToTransferAndBurn);
        assertEq(fundRaisingToken.balanceOf(DONATION), amountToTransferAndBurn);
        assertEq(
            fundRaisingToken.balanceOf(address(treasuryWallet)),
            treasuryBalanceBeforeTransfer - (2 * amountToTransferAndBurn)
        );
        vm.stopPrank();
    }

    function testPerformUpKeepAddLiquidityToLPToAdjustLPHealthIfInitiateAddLiquidityIsTrue() public {
        FactoryTest factoryTest = new FactoryTest();
        factoryTest.setUp();
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        Factory factory = factoryTest.factory();
        address nonProfitOrg = address(0x7);
        (address fundraisingTokenAddress,, address treasury,,,,) = factory.protocols(nonProfitOrg);
        address registry = factoryTest.registryAddress();

        // buy tokens to make lp under health
        address USDC_WHALE = factoryTest.USDC_WHALE();

        vm.startPrank(USDC_WHALE);

        uint128 amountToSwap = 650_000e6; // to make the LP un healthy
        PoolKey memory key = factory.getPoolKey(factoryTest.nonProfitOrg());
        IPermit2 permit2 = IPermit2(factory.permit2());
        UniversalRouter router = UniversalRouter(payable(factory.router()));
        IV4Quoter qouter = IV4Quoter(factory.quoter());
        uint256 slippage = 5e16;
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 3 hours);
        uint256 minAmountOut = _getMinAmountOut(key, amountToSwap, bytes(""), qouter, slippage, fundraisingTokenAddress);
        buyFundraisingToken(key, amountToSwap, uint128(minAmountOut), permit2, router, fundraisingTokenAddress);
        vm.stopPrank();
        vm.startPrank(address(factory));
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
        treasuryInstance.setRegistry(registry);
        vm.stopPrank();
        vm.startPrank(registry);
        bytes memory performData = abi.encode(false, true);
        treasuryInstance.performUpkeep(performData);
    }

    function testPerformUpKeepAddLiquidityToLPToAdjustLPHealthWhenUnderyingAssetIsETH() public {
        FactoryTest factoryTest = new FactoryTest();
        factoryTest.setUp();
        factoryTest.testCreatePoolOwnerCanCreatePoolUsingEtherAsUnderlyingToken();
        Factory factory = factoryTest.factory();
        address nonProfitOrg = address(0x27);
        (address _fundRaisingToken,, address treasury,,,,) = factory.protocols(nonProfitOrg);
        address registry = factoryTest.registryAddress();
        // buy tokens to make lp under health
        address USDC_WHALE = factoryTest.USDC_WHALE();

        vm.startPrank(USDC_WHALE);

        uint128 amountToSwap = 150 ether; // to make the LP un healthy
        vm.deal(USDC_WHALE, amountToSwap);
        PoolKey memory key = factory.getPoolKey(nonProfitOrg);

        IPermit2 permit2 = IPermit2(factory.permit2());
        UniversalRouter router = UniversalRouter(payable(factory.router()));
        IV4Quoter qouter = IV4Quoter(factory.quoter());
        uint256 slippage = 5e16;
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 3 hours);
        uint256 minAmountOut = _getMinAmountOut(key, amountToSwap, bytes(""), qouter, slippage, _fundRaisingToken);

        buyFundraisingToken(key, amountToSwap, uint128(minAmountOut), permit2, router, _fundRaisingToken);

        vm.startPrank(address(factory));
        vm.deal(registry, 10 ether);
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
        treasuryInstance.setRegistry(registry);
        vm.stopPrank();
        vm.startPrank(registry);
        bytes memory performData = abi.encode(false, true);
        treasuryInstance.performUpkeep(performData);

        assertEq(
            IERC20Metadata(_fundRaisingToken).balanceOf(factory.poolManager())
                >= (IERC20Metadata(_fundRaisingToken).totalSupply() * factoryTest.minLPHealthThreshhold()) / 1e18,
            true
        );
    }

    function testPerformUpKeepCannotInitiateTransferAndAddLiquidityIfPerfomDataReturnsFalse() public {
        FactoryTest factoryTest = new FactoryTest();
        factoryTest.setUp();
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        Factory factory = factoryTest.factory();
        address nonProfitOrg = address(0x7);
        (,, address treasury,,,,) = factory.protocols(nonProfitOrg);
        address registry = factoryTest.registryAddress();
        vm.startPrank(address(factory));
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
        treasuryInstance.setRegistry(registry);
        vm.stopPrank();
        vm.startPrank(registry);
        bytes memory performData = abi.encode(false, false);
        treasuryInstance.performUpkeep(performData);
    }

    function testEmergencyPauseOnlyCalledByFactory() public {
        vm.startPrank(DONATION);
        vm.expectRevert(TreasuryWallet.OnlyFactory.selector);
        treasuryWallet.emergencyPause(true);
        vm.stopPrank();
    }

    function testEmergencyPauseCanPauseTreasuryFunctionalities() public {
        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);
        assertEq(treasuryWallet.isTreasuryPaused(), true);
        vm.stopPrank();
    }

    function testEmergencyPauseCannotSetSamePauseStatusTwice() public {
        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);
        assertEq(treasuryWallet.isTreasuryPaused(), true);
        vm.expectRevert(TreasuryWallet.EmergencyPauseAlreadySet.selector);
        treasuryWallet.emergencyPause(true);
        vm.stopPrank();
    }

    function testEmergencyPauseCanResumeFunctionalities() public {
        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);
        assertEq(treasuryWallet.isTreasuryPaused(), true);
        treasuryWallet.emergencyPause(false);
        assertEq(treasuryWallet.isTreasuryPaused(), false);
        vm.stopPrank();
    }

    function testEmergencyWithdrawOnlyCalledByFactory() public {
        vm.startPrank(DONATION);
        vm.expectRevert(TreasuryWallet.OnlyFactory.selector);
        treasuryWallet.emergencyWithdraw(address(20));
        vm.stopPrank();
    }

    function testEmergencyWithdrawCannotWithdrawIfTreasuryNotPaused() public {
        vm.startPrank(factoryProxy);
        vm.expectRevert(TreasuryWallet.TreasuryNotPaused.selector);
        treasuryWallet.emergencyWithdraw(address(20));
    }

    function testEmergencyWithdrawCannotWithdrawIfTreasuryBalanceIsZero() public {
        vm.startPrank(address(treasuryWallet));
        uint256 availableBalance = IERC20Metadata(fundRaisingToken).balanceOf(address(treasuryWallet));

        IERC20Metadata(fundRaisingToken).transfer(address(20), availableBalance);
        vm.stopPrank();

        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);
        vm.expectRevert(TreasuryWallet.NoFundsAvailableForEmergencyWithdraw.selector);
        treasuryWallet.emergencyWithdraw(address(20));
    }

    function testEmergencyWithdrawCanTransferFundsToNonProfitAddress() public {
        vm.startPrank(factoryProxy);
        treasuryWallet.emergencyPause(true);
        uint256 availableBalance = IERC20Metadata(fundRaisingToken).balanceOf(address(treasuryWallet));
        uint256 withdrawnBalance = treasuryWallet.emergencyWithdraw(address(20));

        assertEq(availableBalance, withdrawnBalance);
        assertEq(IERC20Metadata(fundRaisingToken).balanceOf(address(20)), withdrawnBalance);
    }
}
