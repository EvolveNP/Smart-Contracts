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

contract FundraisingTokenHookTest is Test {
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

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
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

        vm.roll(block.number + 10);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
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
        console.log(address(this), "addr");
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

        vm.roll(block.number + 10);

        swap(amountIn, 1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
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
        console.log(address(this), "addr");
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

    function testAfterSwapCannotBuyTokenIfBlockToHoldNotPassed() public {
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(USDC_WHALE);
        key = factory.getPoolKey(factoryTest.nonProfitOrg());

        uint256 amountToSwap = 100e6;
        vm.roll(block.number + 10);
        uint256 minAmountOut = getMinAmountOut(key, true, uint128(amountToSwap), bytes(""));
        console.log(minAmountOut, "min");
        //  vm.expectRevert(FundraisingTokenHook.TransactionNotAllowed.selector);
        console2.logBytes4(FundraisingTokenHook.TransactionNotAllowed.selector);
        swap(uint128(amountToSwap), uint128(minAmountOut));
    }

    function swap(uint128 amountIn, uint128 minAmountOut) internal {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
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

        router.execute(commands, inputs, deadline);

        uint256 amountOut = key.currency0.balanceOf(address(this));

        amountOut = key.currency0.balanceOf(USDC_WHALE);
        console.log(amountOut, "amount");
        require(amountOut >= minAmountOut, "Insufficient output amount");
    }

    function getMinAmountOut(PoolKey memory _key, bool _zeroForOne, uint128 _exactAmount, bytes memory _hookData)
        internal
        returns (uint256 minAmountAmount)
    {
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: _key,
            zeroForOne: _zeroForOne,
            exactAmount: _exactAmount,
            hookData: _hookData
        });

        (uint256 amountOut,) = qouter.quoteExactInputSingle(params);

        return (amountOut * slippage) / 1e18;
    }
}
