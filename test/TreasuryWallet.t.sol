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
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, LP_MANAGER, address(treasuryWallet), DONATION, FACTORY, 1e27, 2e16, 30e16
        );

        treasuryWallet.initialize(
            DONATION,
            factoryProxy,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroDonationAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            address(0),
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroFactoryAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            address(0),
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroRegistryAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            address(0),
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroRouterAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            address(0),
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPoolManagerAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            address(0),
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPermit2Address() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            address(0),
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPositionManagerAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            address(0),
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroQuoterAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            address(0),
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroFundraisingTokenAddress() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(0)
        );
    }

    function testRevertOnZeroTransferInterval() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        vm.expectRevert(Swap.ZeroAmount.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            0,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testCannotInitializeTwice() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector); // expected since initialize should only be callable once
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testInitializeSetsValuesCorrectly() public {
        treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryBeacon, ""))));
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );

        assertEq(treasuryWallet.donationAddress(), DONATION);
        assertEq(treasuryWallet.factoryAddress(), FACTORY);
        assertEq(treasuryWallet.registryAddress(), REGISTRY);
        assertEq(treasuryWallet.minimumHealthThreshhold(), MIN_HEALTH);
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
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * MIN_LP_HEALTH) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
        assertEq(performData, bytes(""));
    }

    function testCheckUpkeepReturnsFalseIfTransferNotAllowedAndLPIsHealthy() public {
        vm.startPrank(address(treasuryWallet));
        // transfer FTN to donation to make treasury balance less than min health
        fundRaisingToken.transfer(DONATION, 200000000000000000000000000);
        vm.stopPrank();
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * MIN_LP_HEALTH) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
        assertEq(performData, bytes(""));
    }

    function testCheckUpkeepReturnsTrueIfLPIsNotHealthyAndTransferNotAllowed() public {
        vm.startPrank(address(treasuryWallet));
        // transfer FTN to donation to make treasury balance less than min health
        fundRaisingToken.transfer(DONATION, 200000000000000000000000000);
        vm.stopPrank();
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH - 15e15)) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP - 2000); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, true);
        bytes memory _performData = abi.encode(false, true);
        assertEq(performData, _performData);
    }

    function testCheckUpkeepReturnsUpKeepNeededTrueAndInitiateAddLiquidityAndInitiateTransferTrue() public {
        vm.warp(31 days);
        vm.startPrank(LP_MANAGER);
        uint256 minFTNNeededINLP = (fundRaisingToken.totalSupply() * (MIN_LP_HEALTH - 15e15)) / MULTIPLIER;
        fundRaisingToken.transfer(POOL_MANAGER, minFTNNeededINLP - 2000); // send FTN token to pool manager. consider it is in Liquidity pool
        (bool upkeepNeeded, bytes memory performData) = treasuryWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, true);
        bytes memory _performData = abi.encode(true, true);
        assertEq(performData, _performData);

        (bool initiateTransfer, bool initiateAddLiquidity) = abi.decode(_performData, (bool, bool));
        assertEq(initiateTransfer, true);
        assertEq(initiateAddLiquidity, true);
        vm.stopPrank();
    }

    function testPerformUpKeepTransferFundsToDonationWalletIfInitiateTransferIsTrue() public {
        vm.startPrank(REGISTRY);
        bytes memory _performData = abi.encode(true, false);
        uint256 totalSupplyBeforeBurn = fundRaisingToken.totalSupply();
        uint256 amountToTransferAndBurn = (fundRaisingToken.totalSupply() * 2e16) / 1e18; // 2% of total supply
        uint256 treasuryBalanceBeforeTransfer = fundRaisingToken.balanceOf(address(treasuryWallet));
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
        (,, address treasury,,,,) = factory.protocols(nonProfitOrg);
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
        uint256 minAmountOut = _getMinAmountOut(key, true, amountToSwap, bytes(""), qouter, slippage);
        buyFundraisingToken(key, amountToSwap, uint128(minAmountOut), permit2, router);
        vm.startPrank(registry);
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
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
        uint256 minAmountOut = _getMinAmountOut(key, true, amountToSwap, bytes(""), qouter, slippage);

        buyFundraisingToken(key, amountToSwap, uint128(minAmountOut), permit2, router);

        vm.startPrank(registry);
        vm.deal(registry, 10 ether);
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
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
        vm.startPrank(registry);
        TreasuryWallet treasuryInstance = TreasuryWallet(payable(treasury));
        bytes memory performData = abi.encode(false, false);
        treasuryInstance.performUpkeep(performData);
    }
}
