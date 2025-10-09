// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract FundraisingTokenHook is BaseHook {
    error TransactionNotAllowed();

    uint256 internal luanchTimestamp; // The timestamp when the token was launched
    uint256 internal constant perWalletCoolDownPeriod = 1 minutes;
    uint256 internal constant maxBuySize = 333e13; // 0.333% of total supply
    uint256 internal constant blocksToHold = 10;
    uint256 internal constant timeToHold = 1 hours;
    uint256 internal launchBlock; // The block number when the token was launched
    address public immutable factoryAddress; // The address of the factory contract
    address public immutable fundraisingTokenAddress; // The address of the token address

    mapping(address => uint256) internal lastBuyTimestamp; // The last buy timestamp for each address

    constructor(IPoolManager _poolManager, address _fundraisingTokenAddress) BaseHook(_poolManager) {
        fundraisingTokenAddress = _fundraisingTokenAddress;
        luanchTimestamp = block.timestamp;
        launchBlock = block.number;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     *  {See _beforeSwap in BaseHook.sol}
     */
    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata data)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Example: block certain swaps or collect analytics here
        // You can access params.amountSpecified, params.zeroForOne, etc.

        // No delta modification, no dynamic fee
        // check which currency is fundraising

        address currency0 = Currency.unwrap(key.currency0);

        bool isFundraisingTokenIsCurrencyZero = currency0 == fundraisingTokenAddress;

        bool isBuying;

        if (
            (isFundraisingTokenIsCurrencyZero && !params.zeroForOne)
                || (!isFundraisingTokenIsCurrencyZero && params.zeroForOne)
        ) isBuying = true;

        //    if(isTransferBlocked(sender, SwapParams.amount)) revert TransactionNotAllowed();
        if (isBuying && isTransferBlocked(sender, 10)) revert TransactionNotAllowed();

        BeforeSwapDelta delta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        uint24 newFee = 0;

        // Must return the correct selector to indicate success
        return (BaseHook.beforeSwap.selector, delta, newFee);
    }

    function isTransferBlocked(address _account, uint256 _amount) internal returns (bool) {
        // Block transfers during launch protection
        if (block.number < launchBlock + blocksToHold) return true;

        if (block.timestamp < luanchTimestamp + timeToHold) {
            // Block transfers if within time to hold after launch
            uint256 lastBuy = lastBuyTimestamp[_account];
            lastBuyTimestamp[_account] = block.timestamp;

            uint256 _maxBuySize = IERC20(fundraisingTokenAddress).totalSupply() * maxBuySize / 1e18;

            if (_amount > _maxBuySize) return true;

            // Block transfers if within cooldown
            if (lastBuy != 0 && block.timestamp < lastBuy + perWalletCoolDownPeriod) return true;
            return false;
        }
        return false;
    }
}
