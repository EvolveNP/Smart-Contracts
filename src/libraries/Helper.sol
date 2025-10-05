// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

library Helper {
    function encodeSqrtPriceX96(uint256 amount1, uint256 amount0) internal pure returns (uint160) {
        // price = amount1 / amount0
        // sqrtPriceX96 = sqrt(price) * 2^96
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");
        uint256 ratioX192 = (uint256(amount1) << 192) / amount0;
        // now take sqrt in Q192 format, then downcast to Q96
        return uint160(Math.sqrt(ratioX192));
    }

    function getMinAndMaxTick(uint160 _sqrtPriceX96, int24 _defaultTickSpacing)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 currentTick = TickMath.getTickAtSqrtPrice(_sqrtPriceX96);
        tickLower = (currentTick / _defaultTickSpacing) * _defaultTickSpacing - _defaultTickSpacing * 10000;
        tickUpper = (currentTick / _defaultTickSpacing) * _defaultTickSpacing + _defaultTickSpacing * 10000;
    }
}
