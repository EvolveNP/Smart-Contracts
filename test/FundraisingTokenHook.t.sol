// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console, console2} from "forge-std/Test.sol";
import {FundraisingTokenHook} from "../src/Hook.sol";
import {FactoryTest} from "./Factory.t.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Factory} from "../src/Factory.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IV4Quoter} from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import {CustomRevert} from "@uniswap/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BuyFundraisingTokens} from "./BuyTokens.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {MockHook} from "../src/mock/MockHook.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IFundraisingToken} from "../src/interfaces/IFundraisingToken.sol";

contract FundraisingTokenHookTest is Test, BuyFundraisingTokens {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    FactoryTest factoryTest;
    IPoolManager poolManager;
    Factory factory;
    PoolKey key;
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    UniversalRouter public router; // The address of the uniswap universal router
    IPermit2 public permit2;
    IV4Quoter public qouter; // qouter
    uint256 public constant slippage = 5e16; // 5%

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        // create liquidity pool
        factoryTest = new FactoryTest();
        factoryTest.setUp();

        poolManager = IPoolManager(factoryTest.poolManager());
        factory = factoryTest.factory();
        permit2 = IPermit2(factory.permit2());
        router = UniversalRouter(payable(factory.router()));
        qouter = IV4Quoter(factory.quoter());
    }

    function testCannotBuyFundraisingTokenIfBlockToHoldNotPassed() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 100e6;
        uint128 minAmountOut = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);
        (address ftn,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        bool zeroForOne = ftn != Currency.unwrap(key.currency0);
        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        uint256 deadline = block.timestamp + 60;

        address underlyingCurryency = zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);

        IERC20(underlyingCurryency).approve(address(permit2), type(uint256).max);
        permit2.approve(underlyingCurryency, address(router), amountIn, uint48(deadline));

        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(key.hooks),
                IHooks.afterSwap.selector,
                abi.encodeWithSelector(FundraisingTokenHook.BlockToHoldNotPassed.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        router.execute(commands, inputs, deadline);
    }

    function testCannotBuyFundraisingTokenIfAmountGreaterThanMaxBuySize() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 200e6;
        uint128 minAmountOut = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        (address ftn,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        bool zeroForOne = ftn != Currency.unwrap(key.currency0);

        vm.roll(block.number + 10);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        uint256 deadline = block.timestamp + 60;

        IERC20(usdc).approve(address(permit2), type(uint256).max);
        permit2.approve(usdc, address(router), amountIn, uint48(deadline));
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(key.hooks),
                IHooks.afterSwap.selector,
                abi.encodeWithSelector(FundraisingTokenHook.AmountGreaterThanMaxBuyAmount.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        router.execute(commands, inputs, deadline);
    }

    function testCannotBuyFundraisingTokenIfCoolDownPeriodNotPassed() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 100e6;
        uint128 minAmountOut = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        (address ftn,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        bool zeroForOne = ftn != Currency.unwrap(key.currency0);

        vm.roll(block.number + 10);
        (address fundraisingTokenAddress,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        buyFundraisingToken(key, amountIn, 1, permit2, router, fundraisingTokenAddress);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        uint256 deadline = block.timestamp + 20;

        IERC20(usdc).approve(address(permit2), type(uint256).max);
        permit2.approve(usdc, address(router), amountIn, uint48(deadline));
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(key.hooks),
                IHooks.afterSwap.selector,
                abi.encodeWithSelector(FundraisingTokenHook.CoolDownPeriodNotPassed.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        router.execute(commands, inputs, deadline);
    }

    function testBuyTokensAgainAfterCoolDownPeriodPassed() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 100e6;
        uint128 minAmountOut = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        (address ftn,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        bool zeroForOne = ftn != Currency.unwrap(key.currency0);

        vm.roll(block.number + 10);
        (address fundraisingTokenAddress,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());
        buyFundraisingToken(key, amountIn, 1, permit2, router, fundraisingTokenAddress);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        Currency currencyIn = zeroForOne ? key.currency0 : key.currency1;
        Currency currencyOut = zeroForOne ? key.currency1 : key.currency0;

        params[1] = abi.encode(currencyIn, amountIn);
        params[2] = abi.encode(currencyOut, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);
        vm.warp(block.timestamp + 2 minutes);
        uint256 deadline = block.timestamp + 20;

        IERC20(usdc).approve(address(permit2), type(uint256).max);
        permit2.approve(usdc, address(router), amountIn, uint48(deadline));
        router.execute(commands, inputs, deadline);
    }

    function testBuyAnyTokensAmountAfterHoldingTimePassed() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 100e6;
        (address fundraisingTokenAddress,,,,,,) = factory.protocols(factoryTest.nonProfitOrg());

        // first buy
        vm.roll(block.number + 10);
        uint256 _minAmountOut1 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut1), permit2, router, fundraisingTokenAddress);

        //second buy after cool down period passed
        vm.warp(block.timestamp + 2 minutes);

        uint256 _minAmountOut2 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut2), permit2, router, fundraisingTokenAddress);

        // third buy after holding time passed
        vm.warp(block.timestamp + 2 hours);

        uint128 amountIn3 = 5000e6;

        uint256 _minAmountOut = _getMinAmountOut(key, amountIn3, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn3, uint128(_minAmountOut), permit2, router, fundraisingTokenAddress);
    }

    function testCannotIncurTaxIfTreasuryWalletIsPaused() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();

        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 100e6;
        (address fundraisingTokenAddress,, address treasuryWallet,,, address owner,) =
            factory.protocols(factoryTest.nonProfitOrg());
        vm.stopPrank();
        vm.startPrank(owner);
        uint256 treasuryBalanceBeforeBalance = IERC20(fundraisingTokenAddress).balanceOf(treasuryWallet);
        factory.setTreasuryPaused(owner, true);
        vm.stopPrank();

        vm.startPrank(USDC_WHALE);
        // first buy
        vm.roll(block.number + 10);
        uint256 _minAmountOut1 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut1), permit2, router, fundraisingTokenAddress);

        uint256 treasuryBalanceAfterBalance = IERC20(fundraisingTokenAddress).balanceOf(treasuryWallet);

        assertEq(treasuryBalanceBeforeBalance, treasuryBalanceAfterBalance);
    }

    function testCannotIncurTaxIfTreasuryIsMorethanMaximumHealthThreshold() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 10000000e6;
        (address fundraisingTokenAddress,, address treasuryWallet,,,,) = factory.protocols(factoryTest.nonProfitOrg());

        // first buy
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 2 hours);
        uint256 _minAmountOut1 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut1), permit2, router, fundraisingTokenAddress);

        // check the remaining amount to make treasury wallet to reach max threshold and send from user account
        // max threshold 30%

        uint256 remainingAmount = 3e14 - IERC20(fundraisingTokenAddress).balanceOf(treasuryWallet);

        IERC20(fundraisingTokenAddress).transfer(treasuryWallet, remainingAmount);

        assertEq(IERC20(fundraisingTokenAddress).balanceOf(treasuryWallet), 3e14);
        //second buy after cool down period passed
        vm.warp(block.timestamp + 2 minutes);

        uint256 _minAmountOut2 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut2), permit2, router, fundraisingTokenAddress);

        // third buy after holding time passed
        vm.warp(block.timestamp + 2 hours);

        uint128 amountIn3 = 5000000e6;

        uint256 _minAmountOut = _getMinAmountOut(key, amountIn3, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn3, uint128(_minAmountOut), permit2, router, fundraisingTokenAddress);

        assertEq(IERC20(fundraisingTokenAddress).balanceOf(treasuryWallet), 3e14);
    }

    function testIncurTaxOnSellingFundraisingToken() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());
        uint128 amountIn = 10000000e6;
        (address fundraisingTokenAddress, address underlingCurrency,,,,,) =
            factory.protocols(factoryTest.nonProfitOrg());

        // first buy
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 2 hours);
        uint256 _minAmountOut1 = _getMinAmountOut(key, amountIn, bytes(""), qouter, slippage, fundraisingTokenAddress);

        buyFundraisingToken(key, amountIn, uint128(_minAmountOut1), permit2, router, fundraisingTokenAddress);

        uint256 whaleUSDCBalanceBeforeBuyingUSDC = IERC20(underlingCurrency).balanceOf(USDC_WHALE);

        sellFundraisingToken(key, amountIn, uint128(1), permit2, router, fundraisingTokenAddress);

        uint256 whaleUSDCBalanceAfterBuyingUSDC = IERC20(underlingCurrency).balanceOf(USDC_WHALE);

        assertGt(whaleUSDCBalanceAfterBuyingUSDC, whaleUSDCBalanceBeforeBuyingUSDC);
    }

    function testBeforeSwapRevertsIfTaxFeeIsOutOfRange() public {
        // Setup pool + protocol
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);

        key = factory.getPoolKey(factoryTest.nonProfitOrg());

        (address ftn,, address treasuryWallet, address donationWallet,,,) =
            factory.protocols(factoryTest.nonProfitOrg());

        // Max positive int128 value (2^127 - 1)
        uint256 threshold = (uint256(1) << 130) - 1;

        // Your chosen swap amount (very large)
        uint256 swapAmount = threshold * 500;

        // Hook flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
                | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        // Deploy the hook via HookMiner
        bytes memory ctorArgs = abi.encode(address(poolManager), ftn, treasuryWallet, donationWallet);

        (address hookAddress, bytes32 salt) = HookMiner.find(USDC_WHALE, flags, type(MockHook).creationCode, ctorArgs);

        console.log("Hook deployed at:", hookAddress);

        MockHook hook = new MockHook{salt: salt}(address(poolManager), ftn, treasuryWallet, donationWallet);

        // Selling path → negative amountSpecified
        int256 amountSpecified = -int256(swapAmount);
        bool zeroForOne = true;

        SwapParams memory params =
            SwapParams({amountSpecified: amountSpecified, zeroForOne: zeroForOne, sqrtPriceLimitX96: 1});

        // Simulate time passing
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 3 hours);

        // Expect FeeToLarge revert
        vm.expectRevert(FundraisingTokenHook.FeeToLarge.selector);

        // Call hook
        hook.beforeSwapEntry(key, params, "");
    }

    function testGetTreasuryBalanceReturnsZeroIfFundraisingTokenTotalSupplyIsZero() public {
        vm.startPrank(USDC_WHALE);

        key = factory.getPoolKey(factoryTest.nonProfitOrg());

        (address ftn,, address treasuryWallet, address donationWallet,,,) =
            factory.protocols(factoryTest.nonProfitOrg());

        // Hook flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
                | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        // Deploy the hook via HookMiner
        bytes memory ctorArgs = abi.encode(address(poolManager), ftn, treasuryWallet, donationWallet);

        (address hookAddress, bytes32 salt) = HookMiner.find(USDC_WHALE, flags, type(MockHook).creationCode, ctorArgs);

        console.log("Hook deployed at:", hookAddress);

        MockHook hook = new MockHook{salt: salt}(address(poolManager), ftn, treasuryWallet, donationWallet);

        uint256 totalSupply = IERC20(ftn).totalSupply();
        vm.startPrank(factory.owner());
        IERC20(ftn).transfer(treasuryWallet, IERC20(ftn).balanceOf(factory.owner()));
        vm.startPrank(treasuryWallet);

        IFundraisingToken(ftn).burn(totalSupply);

        assertEq(hook._getTreasuryBalanceInPerecent(), 0);
        vm.stopPrank();
    }
}
