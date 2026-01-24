// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IFactory {
    struct FundraisingProtocol {
        address fundraisingToken; // The address of the fundraising token
        address underlyingAddress; // The address of the underlying token (e.g., USDC, ETH)
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address hook; // The address of the hook
        address owner; // the non profit org wallet address
        bool isLPCreated; // whether the lp is created or not
    }

    function positionManager() external view returns (address);
    function poolManager() external view returns (address);
    function router() external view returns (address);
    function quoter() external view returns (address);
    function stateView() external view returns (address);
    function pauseAll() external view returns (bool);
    function getProtocol(address _owner) external view returns (FundraisingProtocol memory);
    function getPoolKey(address _owner) external view returns (PoolKey memory);
}
