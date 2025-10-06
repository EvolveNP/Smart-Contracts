// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IFactory {
    function getPoolKey(address _owner) external view returns (PoolKey memory);
    function addLiquidity(
        uint256 _amount0,
        uint256 _amount1,
        address _owner,
        uint160 _sqrtPriceX96,
        uint160 _sqrtPriceAX96,
        uint160 _sqrtPriceBX96
    ) external payable;
}
