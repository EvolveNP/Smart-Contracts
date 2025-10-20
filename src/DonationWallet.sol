// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Swap} from "./abstracts/Swap.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract DonationWallet is Swap, AutomationCompatibleInterface {
    using StateLibrary for IPoolManager;

    /**
     * Error
     */
    error EmergencyPauseAlreadySet();

    IERC20 public fundraisingTokenAddress; // Address of the FundRaisingToken contract
    address public owner; // Owner of the DonationWallet
    address public factoryAddress; // The address of the factory contract
    bool internal paused;

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

    /**
     * @notice Modifier to restrict access to functions to only the factory contract.
     * @dev Ensures that the provided address matches the factoryAddress state variable.
     * @param _addr The address to check against the factoryAddress.
     * @custom:netmod Only the factory contract can call functions using this modifier.
     */
    modifier onlyFactory(address _addr) {
        require(_addr == factoryAddress, "Only by factory");
        _;
    }

    /**
     *
     * @param _factoryAddress The address of the factory contract
     * @param _owner The wallet address of non profit organization that receives the donation
     * @param _router The address of the uniswap universal router
     * @param _poolManager The address of the uniswap v4 pool manager
     * @param _permit2 The address of the uniswap permit2 contract
     * @param _positionManager The address of the uniswap v4 position manager
     */
    function initialize(
        address _factoryAddress,
        address _owner,
        address _router,
        address _poolManager,
        address _permit2,
        address _positionManager,
        address _qouter,
        address _fundraisingToken
    ) external initializer nonZeroAddress(_factoryAddress) nonZeroAddress(_owner) nonZeroAddress(_fundraisingToken) {
        __init(_router, _poolManager, _permit2, _positionManager, _qouter);
        owner = _owner;
        factoryAddress = _factoryAddress;
        fundraisingTokenAddress = IERC20(_fundraisingToken);
    }

    /**
     * See {AutomationCompatibleInterace - checkUpKeep}
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = !paused && IERC20(fundraisingTokenAddress).balanceOf(address(this)) > 0;

        performData = bytes("");
    }

    /**
     * See {AutomationCompatibleInterace - performUpkeep}
     */
    function performUpkeep(bytes calldata performData) external {
        swapFundraisingToken();
    }

    /**
     * @notice Swap all fundraising tokens to currency0 and transfer to non profit organization wallet
     * @dev Callbale by chainlink automation
     */
    function swapFundraisingToken() internal {
        uint256 amountIn = fundraisingTokenAddress.balanceOf(address(this));

        PoolKey memory key = IFactory(factoryAddress).getPoolKey(owner);

        address currency0 = Currency.unwrap(key.currency0);
        bool isCurrency0FundraisingToken = currency0 == address(fundraisingTokenAddress);

        uint256 minAmountOut = getMinAmountOut(key, isCurrency0FundraisingToken, uint128(amountIn), bytes(""));

        uint256 amountOut =
            swapExactInputSingle(key, uint128(amountIn), uint128(minAmountOut), isCurrency0FundraisingToken);

        bool success = IERC20(currency0).transfer(owner, amountOut);

        require(success, "Transfer failed");

        emit FundsTransferredToNonProfit(owner, amountOut);
    }

    /**
     * @notice Enables or disables emergency pause
     * @param _pause set true to enable emergency pause otherwise set false
     * @dev Only factory can set emergency pause
     */
    function emergencyPause(bool _pause) external onlyFactory(msg.sender) {
        if (paused == _pause) revert EmergencyPauseAlreadySet();
        paused = _pause;
        emit Paused(_pause);
    }
}
