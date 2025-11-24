// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Swap} from "./abstracts/Swap.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DonationWallet
 * @notice A contract that manages fundraising tokens, automates token swaps, and transfers proceeds to non-profit organizations.
 * @dev Integrates with Uniswap V4 for liquidity and swaps, and Chainlink Automation for scheduled upkeep.
 *      Only authorized factory and registry contracts can perform sensitive operations.
 *
 * Features:
 * - Holds fundraising tokens for non-profit organizations.
 * - Uses Uniswap V4 hooks and swap logic to convert fundraising tokens into underlying currencies.
 * - Supports Chainlink Automation-compatible upkeep for automated swapping.
 * - Emits events for fund transfers.
 * - Access control enforced with modifiers limiting calls to factory and registry contracts.
 *
 * Errors:
 * - EmergencyPauseAlreadySet: Thrown if attempting to pause an already paused contract.
 * - NotFactory: Thrown when a function restricted to the factory contract is called by others.
 * - NotRegistry: Thrown when a function restricted to the registry contract is called by others.
 * - TransferFailed: Thrown if token or ETH transfers fail.
 */
contract DonationWallet is Swap, AutomationCompatibleInterface {
    using SafeERC20 for IERC20;
    /**
     * Error
     */
    error EmergencyPauseAlreadySet();
    error NotFactory();
    error NotRegistry();
    error TransferFailed();

    IERC20 public fundraisingToken; // Address of the FundRaisingToken contract
    address public owner; // Owner of the donationWallet
    address public factoryAddress; // The address of the factory contract
    address public registryAddress; // Address of the registry contract

    /**
     * @notice This event is used to log successful transfers to non-profit organizations.
     * @param recipient The address of the non-profit receiving funds.
     * @param amount The amount of funds transferred.
     * @dev Emitted when funds are transferred to a non-profit recipient.
     */
    event FundsTransferredToNonProfit(address recipient, uint256 amount);

    /**
     * @notice This event is used to notify when the contract's operational state changes.
     * @param pause Boolean indicating the pause state (true if paused, false if unpaused).
     * @dev Emitted when the contract is paused or unpaused.
     */
    event Paused(bool pause);

    modifier onlyRegistry() {
        if (msg.sender != registryAddress) revert NotRegistry();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != factoryAddress) revert NotFactory();
        _;
    }

    // fallback to receive ETH when swapping
    receive() external payable {}

    /**
     * @notice Initializes the contract with essential protocol addresses and ownership.
     *
     * @param _factoryAddress The address of the factory contract.
     * @param _owner The wallet address of the non-profit organization that receives donations.
     * @param _router The address of the Uniswap universal router.
     * @param _poolManager The address of the Uniswap v4 pool manager.
     * @param _permit2 The address of the Uniswap Permit2 contract.
     * @param _positionManager The address of the Uniswap v4 position manager.
     * @param _quoter The address of the Uniswap v4 quoter contract.
     * @param _fundraisingToken The address of the fundraising ERC20 token.
     * @dev Can only be called once due to the initializer modifier.
     */
    function initialize(
        address _factoryAddress,
        address _owner,
        address _router,
        address _poolManager,
        address _permit2,
        address _positionManager,
        address _quoter,
        address _fundraisingToken
    ) external initializer nonZeroAddress(_factoryAddress) nonZeroAddress(_owner) nonZeroAddress(_fundraisingToken) {
        __init(_router, _poolManager, _permit2, _positionManager, _quoter);
        owner = _owner;
        factoryAddress = _factoryAddress;
        fundraisingToken = IERC20(_fundraisingToken);
    }

    /**
     * @notice Called by Chainlink Automation to check if upkeep is needed.
     * @dev Returns true if the contract holds any fundraising tokens to be swapped.
     * @return upkeepNeeded Boolean indicating whether upkeep should be performed.
     * @return performData Additional data to pass to `performUpkeep`, empty here.
     */
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = IERC20(fundraisingToken).balanceOf(address(this)) > 0;

        performData = bytes("");
    }

    /**
     * @notice Called by Chainlink Automation to perform the upkeep when needed.
     * @dev Executes the swapping of fundraising tokens to the underlying currency and transfers the proceeds
     *      to the non-profit organization wallet.
     *      Restricted to be called only by the authorized registry contract.
     */
    function performUpkeep(bytes calldata) external onlyRegistry {
        swapFundraisingToken();
    }

    /**
     * @notice Sets the address of the registry contract.
     * @dev Can only be called by the factory contract.
     * @param _registryAddress The address of the new registry contract.
     */
    function setRegistry(address _registryAddress) external onlyFactory {
        registryAddress = _registryAddress;
    }

    /**
     * @notice Swaps all fundraising tokens held by the contract to underlying currency and transfers the proceeds to the non-profit organization wallet.
     * @dev This function is intended to be called by Chainlink Automation (Keepers).
     *      It determines the correct pool, calculates minimum expected output, performs the swap,
     *      and then transfers the swapped funds (ETH or ERC20) to the owner's address.
     *      Reverts if the token transfer or ETH transfer fails.
     *
     * Emits a {FundsTransferredToNonProfit} event indicating the owner and amount transferred.
     */
    function swapFundraisingToken() internal {
        uint256 amountIn = fundraisingToken.balanceOf(address(this));

        PoolKey memory key = IFactory(factoryAddress).getPoolKey(owner);

        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);
        bool isCurrency0FundraisingToken = currency0 == address(fundraisingToken);

        uint256 minAmountOut = getMinAmountOut(key, isCurrency0FundraisingToken, uint128(amountIn), bytes(""));

        uint256 amountOut =
            swapExactInputSingle(key, uint128(amountIn), uint128(minAmountOut), isCurrency0FundraisingToken);

        if (currency0 == address(0)) {
            (bool success,) = owner.call{value: amountOut}("");
            if (!success) revert TransferFailed();
        } else {
            isCurrency0FundraisingToken
                ? IERC20(currency1).safeTransfer(owner, amountOut)
                : IERC20(currency0).safeTransfer(owner, amountOut);
        }
        emit FundsTransferredToNonProfit(owner, amountOut);
    }
}
