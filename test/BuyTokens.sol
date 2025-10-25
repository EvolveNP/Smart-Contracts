// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

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
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

abstract contract BuyFundraisingTokens {
    function buyFundraisingToken(
        PoolKey memory key,
        uint128 amountIn,
        uint128 minAmountOut,
        IPermit2 permit2,
        UniversalRouter router
    ) internal {
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

        uint256 deadline = block.timestamp + 40;
        address usdc = Currency.unwrap(key.currency0);
        if (usdc != address(0)) {
            IERC20(usdc).approve(address(permit2), type(uint256).max);
            permit2.approve(usdc, address(router), amountIn, uint48(deadline));
        }

        router.execute{value: amountIn}(commands, inputs, deadline);
    }

    function _getMinAmountOut(
        PoolKey memory _key,
        bool _zeroForOne,
        uint128 _exactAmount,
        bytes memory _hookData,
        IV4Quoter qouter,
        uint256 slippage
    ) internal returns (uint256 minAmountAmount) {
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
