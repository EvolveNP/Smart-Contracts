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
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";

contract FundraisingTokenHook is BaseHook {
    error TransactionNotAllowed();
    error BlockToHoldNotPassed();
    error AmountGreaterThanMaxBuyAmount();
    error CoolDownPeriodNotPassed();
    error FeeToLarge();

    uint256 internal launchTimestamp; // The timestamp when the token was launched
    uint256 internal constant perWalletCoolDownPeriod = 1 minutes;
    uint256 internal constant maxBuySize = 333e13; // 0.333% of total supply (scaled by 1e18)
    uint256 internal constant blocksToHold = 10;
    uint256 internal constant timeToHold = 1 hours;
    uint256 internal launchBlock; // The block number when the token was launched

    address public immutable fundraisingTokenAddress; // The address of the fundraising token
    address public immutable treasuryAddress;
    uint256 public constant maximumThreshold = 30e16; // The maximum threshold for the liquidity pool 30% = 30e16

    mapping(address => uint256) public lastBuyTimestamp; // The last buy timestamp for each address

    // 2% expressed with 18-decimal denominator
    uint256 public constant TAX_FEE_PERCENTAGE = 2e16; // 0.02 * 1e18 = 2e16 (2%)
    uint256 public constant TAX_FEE_DENOMINATOR = 1e18;

    /**
     * @notice Initializes the Hook contract with the specified PoolManager and fundraising token address.
     * @param _poolManager The address of the PoolManager contract.
     * @param _fundraisingTokenAddress The address of the fundraising token.
     * @param _treasuryAddress The address where fees will be sent (immutable).
     */
    constructor(address _poolManager, address _fundraisingTokenAddress, address _treasuryAddress)
        BaseHook(IPoolManager(_poolManager))
    {
        fundraisingTokenAddress = _fundraisingTokenAddress;
        launchTimestamp = block.timestamp;
        launchBlock = block.number;
        treasuryAddress = _treasuryAddress;
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
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        virtual
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // when selling we cut tax from specified amount in.
        bool isFundraisingTokenCurrency0 = Currency.unwrap(key.currency0) == fundraisingTokenAddress;
        bool isSelling =
            (isFundraisingTokenCurrency0 && params.zeroForOne) || (!isFundraisingTokenCurrency0 && !params.zeroForOne);

        uint256 feeAmount;
        bool isTaxCutEnabled = checkIfTaxIncurred(sender);
        if (isSelling && isTaxCutEnabled) {
            uint256 swapAmount =
                params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
            // Correct denominator usage
            feeAmount = (swapAmount * TAX_FEE_PERCENTAGE) / TAX_FEE_DENOMINATOR;

            // Ensure fits in signed int128 before casting in any downstream use
            if (feeAmount >= ((uint256(1) << 127) - 1)) revert FeeToLarge();

            poolManager.take(Currency.wrap(fundraisingTokenAddress), treasuryAddress, feeAmount);
        }

        BeforeSwapDelta returnDelta = toBeforeSwapDelta(
            int128(int256(feeAmount)), // Specified delta (fee amount)
            0 // Unspecified delta (no change)
        );
        return (BaseHook.beforeSwap.selector, returnDelta, 0);
    }

    /**
     * @notice Called after a swap — enforces restrictions on buys and collects fee for buys.
     */
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        address currency0 = Currency.unwrap(key.currency0);

        bool isFundraisingTokenIsCurrencyZero = currency0 == fundraisingTokenAddress;

        // isBuying: if fundraising token is currency0 and swap is one->zero? (original logic kept)
        bool isBuying = (isFundraisingTokenIsCurrencyZero && !params.zeroForOne)
            || (!isFundraisingTokenIsCurrencyZero && params.zeroForOne);

        uint256 feeAmount;
        bool isTaxCutEnabled = checkIfTaxIncurred(sender);
        if (isBuying && isTaxCutEnabled) {
            int256 _amountOut = params.zeroForOne ? delta.amount1() : delta.amount0();

            if (_amountOut <= 0) {
                return (BaseHook.afterSwap.selector, 0);
            }

            // use provided sender (not tx.origin)
            isTransferBlocked(sender, _amountOut);

            if (block.timestamp < launchTimestamp + timeToHold) lastBuyTimestamp[sender] = block.timestamp;

            feeAmount = (uint256(_amountOut) * TAX_FEE_PERCENTAGE) / TAX_FEE_DENOMINATOR;

            if(feeAmount >= ((uint256(1) << 127) - 1)) revert FeeToLarge();
            // sends the fee to treasury wallet
            poolManager.take(Currency.wrap(fundraisingTokenAddress), treasuryAddress, feeAmount);
        }
        return (BaseHook.afterSwap.selector, int128(int256(feeAmount)));
    }

    /**
     * @notice Enforces launch protection and per-wallet cooldowns and max buy size restrictions.
     * @dev Reverts when transfer is not allowed. Does NOT return a boolean.
     */
    function isTransferBlocked(address _account, int256 _amount) internal view {
        // Block transfers during launch protection (by block count)
        if (block.number < launchBlock + blocksToHold) revert BlockToHoldNotPassed();

        if (block.timestamp < launchTimestamp + timeToHold) {
            // Block transfers if within time to hold after launch
            uint256 lastBuy = lastBuyTimestamp[_account];

            // maxBuySize is stored scaled by 1e18, so multiply by totalSupply and divide by 1e18
            uint256 _maxBuySize = (IERC20(fundraisingTokenAddress).totalSupply() * maxBuySize) / 1e18;

            if (uint256(_amount) > _maxBuySize) revert AmountGreaterThanMaxBuyAmount();

            // Block transfers if within cooldown
            if (lastBuy != 0 && block.timestamp < lastBuy + perWalletCoolDownPeriod) revert CoolDownPeriodNotPassed();
        }
    }

    /**
     * @notice Returns the treasury balance as a percentage of the total supply
     * @return Percentage of the total supply held by the treasury (in 1e18 format, e.g. 1e16 = 1%)
     */
    function getTreasuryBalanceInPerecent() internal view returns (uint256) {
        uint256 treasuryBalance = IERC20(fundraisingTokenAddress).balanceOf(treasuryAddress);
        uint256 totalSupply = IERC20(fundraisingTokenAddress).totalSupply();

        return (treasuryBalance * 1e18) / totalSupply;
    }

    function checkIfTaxIncurred(address sender) internal view returns (bool) {
        return !ITreasury(treasuryAddress).isTreasuryPaused() && (getTreasuryBalanceInPerecent() < maximumThreshold)
            && sender != ITreasury(treasuryAddress).registryAddress();
    }
}
