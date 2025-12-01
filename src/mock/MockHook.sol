// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {FundraisingTokenHook} from "../Hook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract MockHook is FundraisingTokenHook {
    constructor(
        address _poolManager,
        address _fundraisingTokenAddress,
        address _treasuryAddress,
        address _donationAddress,
        address _routerAddress,
        address _quoterAddress
    )
        FundraisingTokenHook(
            _poolManager, _fundraisingTokenAddress, _treasuryAddress, _donationAddress, _routerAddress, _quoterAddress
        )
    {}

    function beforeSwapEntry(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData) external {
        _beforeSwap(msg.sender, key, params, hookData);
    }

    function _getTreasuryBalanceInPerecent() external view returns (uint256) {
        return getTreasuryBalanceInPerecent();
    }
}
