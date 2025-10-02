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

abstract contract Swap {
    UniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;
    IPositionManager public immutable positionManager;

    constructor(address _router, address _poolManager, address _permit2, address _positionManager) {
        router = UniversalRouter(payable(_router));
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
        positionManager = IPositionManager(_positionManager);
    }

    function swapExactInputSingle(PoolKey memory key, uint128 amountIn, uint128 minAmountOut)
        internal
        returns (uint256 amountOut)
    {
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

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute(commands, inputs, deadline);

        // Verify and return the output amount
        amountOut = key.currency1.balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");
        return amountOut;
    }

    function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) external {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }
}
