// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IV4Quoter} from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";

abstract contract Swap {
    UniversalRouter public immutable router; // The address of the uniswap universal router
    IPoolManager public immutable poolManager; // The address of the uniswap v4 pool manager
    IPermit2 public immutable permit2; // The address of the uniswap permit2 contract
    IPositionManager public immutable positionManager; // The address of the uniswap v4 position manager
    IV4Quoter public immutable qouter; // qouter

    error ZeroAddress();

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    constructor(address _router, address _poolManager, address _permit2, address _positionManager, address _quoter)
        nonZeroAddress(_router)
        nonZeroAddress(_poolManager)
        nonZeroAddress(_permit2)
        nonZeroAddress(_positionManager)
    {
        router = UniversalRouter(payable(_router));
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
        positionManager = IPositionManager(_positionManager);
        qouter = IV4Quoter(_quoter);
    }

    function swapExactInputSingle(
        PoolKey memory key,
        uint128 amountIn,
        uint128 minAmountOut,
        bool _isCurrency0FundraisingToken
    ) internal returns (uint256 amountOut) {
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
                zeroForOne: _isCurrency0FundraisingToken,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        Currency currencyIn = _isCurrency0FundraisingToken ? key.currency0 : key.currency1;
        Currency currencyOut = _isCurrency0FundraisingToken ? key.currency1 : key.currency0;

        params[1] = abi.encode(currencyIn, amountIn);
        params[2] = abi.encode(currencyOut, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        address currencyInAddress = Currency.unwrap(currencyIn);

        // Execute the swap
        uint256 deadline = block.timestamp + 20;

        approveTokenWithPermit2(currencyInAddress, uint160(amountIn), uint48(deadline));

        router.execute(commands, inputs, deadline);

        // Verify and return the output amount
        amountOut = key.currency0.balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");
        return amountOut;
    }

    function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    function getMinAmountOut(
        PoolKey calldata _key,
        bool _zeroForOne,
        uint128 _exactAmount,
        bytes calldata _hookData,
        uint256 _slippage
    ) internal returns (uint256 minAmountAmount) {
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: _key,
            zeroForOne: _zeroForOne,
            exactAmount: _exactAmount,
            hookData: _hookData
        });

        (uint256 amountOut,) = qouter.quoteExactInputSingle(params);

        return (amountOut * _slippage) / 1e18;
    }
}
