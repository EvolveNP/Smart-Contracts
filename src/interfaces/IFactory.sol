// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IFactory {
    function getPoolKey(address _owner) external view returns (PoolKey memory);
    function addLiquidity(uint256 _amount0, uint256 _amount1, address _owner) external payable;

    function getFundraisingTokenBalance(address _fundraisingTokenAddress) external view returns (uint256);
    function positionManager() external view returns (address);
    function poolManager() external view returns (address);
    function getSqrtPriceX96(address _owner) external returns (uint160);

    function pauseAll() external view returns (bool);
}
