// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
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
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata data
    ) internal override returns (bytes4, int128) {
        address currency0 = Currency.unwrap(key.currency0);

        bool isFundraisingTokenIsCurrencyZero = currency0 == fundraisingTokenAddress;

        bool isBuying;
        int128 _amountOut = delta.amount0();
        if (
            (isFundraisingTokenIsCurrencyZero && !params.zeroForOne)
                || (!isFundraisingTokenIsCurrencyZero && params.zeroForOne)
        ) isBuying = true;

        if (isBuying && isTransferBlocked(sender, _amountOut)) revert TransactionNotAllowed();

        if (block.timestamp < luanchTimestamp + timeToHold) lastBuyTimestamp[sender] = block.timestamp;

        return (BaseHook.afterSwap.selector, 0);
    }

    function isTransferBlocked(address _account, int128 _amount) internal view returns (bool) {
        // Block transfers during launch protection
        if (block.number < launchBlock + blocksToHold) return true;

        if (block.timestamp < luanchTimestamp + timeToHold) {
            // Block transfers if within time to hold after launch
            uint256 lastBuy = lastBuyTimestamp[_account];

            uint256 _maxBuySize = IERC20(fundraisingTokenAddress).totalSupply() * maxBuySize / 1e18;

            if (uint256(uint128(_amount)) > _maxBuySize) return true;

            // Block transfers if within cooldown
            if (lastBuy != 0 && block.timestamp < lastBuy + perWalletCoolDownPeriod) return true;
            return false;
        }
        return false;
    }
}
