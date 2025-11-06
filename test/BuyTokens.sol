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
    function test() public {}
    
    function buyFundraisingToken(
        PoolKey memory key,
        uint128 amountIn,
        uint128 minAmountOut,
        IPermit2 permit2,
        UniversalRouter router,
        address fundraisingTokenAddress
    ) internal {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bool _isCurrency0FundraisingToken = fundraisingTokenAddress == Currency.unwrap(key.currency0);
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: !_isCurrency0FundraisingToken,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        Currency currencyIn = _isCurrency0FundraisingToken ? key.currency1 : key.currency0;
        Currency currencyOut = _isCurrency0FundraisingToken ? key.currency0 : key.currency1;

        params[1] = abi.encode(currencyIn, amountIn);
        params[2] = abi.encode(currencyOut, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        uint256 deadline = block.timestamp + 40;
        address underlingCurrency =
            _isCurrency0FundraisingToken ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        if (underlingCurrency != address(0)) {
            IERC20(underlingCurrency).approve(address(permit2), type(uint256).max);
            permit2.approve(underlingCurrency, address(router), amountIn, uint48(deadline));
        }

        router.execute{value: amountIn}(commands, inputs, deadline);
    }

    function _getMinAmountOut(
        PoolKey memory _key,
        uint128 _exactAmount,
        bytes memory _hookData,
        IV4Quoter qouter,
        uint256 slippage,
        address _fundraisingTokenAddress
    ) internal returns (uint256 minAmountAmount) {
        bool _isCurrency0FundraisingToken =
            _fundraisingTokenAddress == Currency.unwrap(_key.currency0);
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: _key, zeroForOne: !_isCurrency0FundraisingToken, exactAmount: _exactAmount, hookData: _hookData
        });

        (uint256 amountOut,) = qouter.quoteExactInputSingle(params);

        return (amountOut * slippage) / 1e18;
    }
}
