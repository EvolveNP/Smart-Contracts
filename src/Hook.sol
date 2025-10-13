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

    /**
     * @notice Initializes the Hook contract with the specified PoolManager and fundraising token address.
     * @param _poolManager The address of the PoolManager contract.
     * @param _fundraisingTokenAddress The address of the fundraising token.
     * Sets the fundraising token address, records the current timestamp as the launch time, and stores the current block number as the launch block.
     */
    constructor(IPoolManager _poolManager, address _fundraisingTokenAddress) BaseHook(_poolManager) {
        fundraisingTokenAddress = _fundraisingTokenAddress;
        luanchTimestamp = block.timestamp;
        launchBlock = block.number;
    }

    /**
     * @notice Returns the permissions for each hook event in the contract.
     * @dev This function overrides the base implementation to specify which hook events are enabled.
     * @return permissions A struct containing boolean flags for each hook event.
     * @custom:natspec The returned `Hooks.Permissions` struct indicates which hook events are permitted.
     * Only `afterSwap` is enabled; all other events are disabled.
     */
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

    /**
     * @notice Checks if the swap is a buy operation for the fundraising token and enforces transfer restrictions.
     * @notice Updates the last buy timestamp for the sender if the swap occurs before the hold period ends.
     * @notice Reverts with TransactionNotAllowed if the transfer is blocked for the sender.
     * @param sender The address initiating the swap.
     * @param key The pool key containing currency information.
     * @param params The parameters of the swap, including direction.
     * @param delta The balance delta resulting from the swap.
     * @param data Additional calldata passed to the hook.
     * @return selector The selector for the afterSwap hook.
     * @return int128 Reserved value, currently always 0.
     * @dev Hook function called after a swap operation in the pool.
     * @custom:netspc Called internally after a swap to enforce fundraising token rules and update buy timestamps.
     */
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

    /**
     * @notice Determines if a transfer should be blocked based on launch protection and cooldown rules.
     * @dev Blocks transfers during the initial launch period and enforces per-wallet cooldowns and max buy size restrictions.
     * @param _account The address of the account attempting the transfer.
     * @param _amount The amount being transferred.
     * @return Returns true if the transfer is blocked, false otherwise.
     * @custom:netspec
     * - If the current block is within the launch protection period, returns true.
     * - If the current timestamp is within the time to hold after launch:
     *     - Blocks transfers exceeding the maximum buy size.
     *     - Blocks transfers if the account is within the cooldown period after their last buy.
     * - Otherwise, returns false.
     */
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
