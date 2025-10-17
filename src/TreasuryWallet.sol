// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IFundraisingToken} from "./interfaces/IFundraisingToken.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Swap} from "./abstracts/Swap.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IDonationWallet} from "./interfaces/IDonationWallet.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {Helper} from "./libraries/Helper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";

contract TreasuryWallet is AutomationCompatibleInterface, Swap {
    /**
     * Errors
     */
    error OnlyFactory();
    error OnlyRegistry();
    error TransferFailed();
    error EmergencyPauseAlreadySet();
    /**
     * State Variables
     */

    address public donationAddress; // The address of the donation wallet
    IFundraisingToken public fundraisingToken; // The fundraising token
    address public factoryAddress; // The address of the factory contract
    address public registryAddress; // The address of the chainlink registry contract
    uint256 public lastTransferTimestamp;

    uint256 public minimumHealthThreshhold; // The minimum threshold for transferring funds
    uint256 public transferInterval; // The interval at which funds transferred to donation wallet
    uint256 internal minLPHealthThreshhold; // The health threshold
    uint256 internal constant MULTIPLIER = 1e18;
    int24 internal tickSpacing;
    bool paused;

    /**
     * Events
     */
    event FundTransferredToDonationWallet(uint256 amountTransferredAndBurned);
    event LPHealthAdjusted(address recipient, uint256 amount0, uint256 amount1);
    event Paused(bool paused);

    /**
     * Modifiers
     */
    modifier onlyFactory() {
        if (msg.sender != factoryAddress) revert OnlyFactory();
        _;
    }

    modifier onlyRegistry() {
        if (msg.sender != registryAddress) revert OnlyRegistry();
        _;
    }

    /**
     *
     * @param _donationAddress The address of the donation wallet
     * @param _factoryAddress The address of the factory contract
     * @param _registryAddress The address of the registry
     */
    function initialize(
        address _donationAddress,
        address _factoryAddress,
        address _registryAddress,
        address _router,
        address _poolManager,
        address _permit2,
        address _positionManager,
        address _quoter,
        uint256 _minimumHealthThreshhold,
        uint256 _transferInterval,
        uint256 _minLPHealthThreshhold,
        int24 _tickSpacing,
        address _fundraisingToken
    )
        external
        initializer
        nonZeroAddress(_donationAddress)
        nonZeroAddress(_factoryAddress)
        nonZeroAddress(_fundraisingToken)
        nonZeroAddress(_registryAddress)
        nonZeroAmount(_transferInterval)
    {
        __init(_router, _poolManager, _permit2, _positionManager, _quoter);
        donationAddress = _donationAddress;
        factoryAddress = _factoryAddress;
        registryAddress = _registryAddress;
        minimumHealthThreshhold = _minimumHealthThreshhold;
        transferInterval = _transferInterval;
        minLPHealthThreshhold = _minLPHealthThreshhold;
        tickSpacing = _tickSpacing;
        fundraisingToken = IFundraisingToken(_fundraisingToken);
    }

    /**
     * See {AutomationCompatibleInterace - checkUpKeep}
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 transferDate = lastTransferTimestamp + transferInterval;
        uint256 lpCurrentThreshold = getCurrentLPHealthThreshold();
        bool initiateTransfer = (block.timestamp >= transferDate && isTransferAllowed());
        bool initiateAddLiqudity = (minLPHealthThreshhold > lpCurrentThreshold);

        upkeepNeeded = !paused && (initiateTransfer || initiateAddLiqudity);

        if (upkeepNeeded) {
            performData = abi.encode(initiateTransfer, initiateAddLiqudity);
        } else {
            performData = bytes("");
        }
    }

    /**
     * See {AutomationCompatibleInterace - performUpkeep}
     */
    function performUpkeep(bytes calldata performData) external {
        (bool initiateTransfer, bool initiateAddLiquidity) = abi.decode(performData, (bool, bool));

        if (initiateTransfer) {
            transferFunds();
        }

        if (initiateAddLiquidity) {
            adjustLPHealth();
        }
    }

    /**
     * @notice Adjusts the health of the liquidity pool by swapping half of the fundraising token surplus for the underlying currency,
     *         adds liquidity to the pool, and sends any leftover tokens or ETH to the donation wallet.
     * @dev Calculates the amount to add to the LP based on the fundraising token supply and minimum threshold.
     *      Determines the pool key and currencies involved, swaps tokens as needed, and adds liquidity.
     *      Any remaining underlying currency or ETH is transferred to the donation wallet.
     * Emits a {LPHealthAdjusted} event after successful adjustment.
     */
    function adjustLPHealth() internal {
        // swap half of the amount in for currency0
        uint256 amountToAddToLP = (
            ((fundraisingToken.totalSupply() * minimumHealthThreshhold) / MULTIPLIER)
                - IFactory(factoryAddress).getFundraisingTokenBalance(address(fundraisingToken))
        ) / 2;

        address _owner = IDonationWallet(donationAddress).owner();
        PoolKey memory key = IFactory(factoryAddress).getPoolKey(_owner);

        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);
        bool isCurrency0FundraisingToken = currency0 == address(fundraisingToken);
        address underlyingCurrency = isCurrency0FundraisingToken ? currency1 : currency0;
        // get amount min out
        uint256 minAmountOut = getMinAmountOut(key, !isCurrency0FundraisingToken, uint128(amountToAddToLP), bytes(""));
        // swap token
        uint256 amountOut =
            swapExactInputSingle(key, uint128(amountToAddToLP), uint128(minAmountOut), isCurrency0FundraisingToken);
        uint256 _amount0 = isCurrency0FundraisingToken
            ? amountToAddToLP
            : currency0 == address(0) ? address(this).balance : IERC20(currency0).balanceOf(address(this));
        uint256 _amount1 = !isCurrency0FundraisingToken
            ? amountToAddToLP
            : currency0 == address(0) ? address(this).balance : IERC20(currency0).balanceOf(address(this));

        addLiquidity(key, _owner, currency0, currency1, _amount0, _amount1, isCurrency0FundraisingToken);

        // send leftovers to donation wallet
        if (underlyingCurrency == address(0) && address(this).balance > 0) {
            (bool success,) = donationAddress.call{value: address(this).balance}("");
            if (!success) revert TransferFailed();
        }
        if (underlyingCurrency != address(0) && IERC20(underlyingCurrency).balanceOf(address(this)) > 0) {
            IERC20(underlyingCurrency).transfer(donationAddress, IERC20(underlyingCurrency).balanceOf(address(this)));
        }

        emit LPHealthAdjusted(_owner, amountToAddToLP, amountOut);
    }

    /**
     * @notice Transfer funds to donation wallet and burn an equal amount
     * @dev Can only be called by the registry contract and
     *      only if the treasury wallet balance is above the minimum threshold
     */
    function transferFunds() public onlyRegistry {
        uint256 amountToTransferAndBurn = 0;
        if (isTransferAllowed()) {
            amountToTransferAndBurn = (fundraisingToken.totalSupply() * 2e16) / 1e18; // 2% of total supply
            fundraisingToken.transfer(donationAddress, amountToTransferAndBurn);
            fundraisingToken.burn(amountToTransferAndBurn);
        }

        emit FundTransferredToDonationWallet(amountToTransferAndBurn);
    }

    /**
     * @notice Checks if the treasury wallet's fundraising token balance meets the minimum threshold required to allow transfer and burn operations.
     * @dev Calculates the current threshold as the ratio of the treasury's fundraising token balance to the total supply, scaled by 1e18.
     *      Returns true if the threshold is greater than or equal to minimumHealthThreshhold, otherwise false.
     * @return True if transfer is allowed, false otherwise.
     */
    function isTransferAllowed() internal view returns (bool) {
        uint256 treasuryBalance = fundraisingToken.balanceOf(address(this));
        uint256 totalSupply = fundraisingToken.totalSupply();
        uint256 currentThreshold = ((treasuryBalance * 1e18) / totalSupply);
        if (currentThreshold >= minimumHealthThreshhold) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Calculates the current health threshold of the LP (Liquidity Pool) by dividing the fundraising token balance held by the factory by the total supply of the fundraising token, scaled by a multiplier.
     * @dev Uses the IFactory interface to get the fundraising token balance and accesses the total supply from the fundraisingToken contract.
     * @return The current LP health threshold as a uint256 value.
     */
    function getCurrentLPHealthThreshold() internal view returns (uint256) {
        uint256 lpBalance = IFactory(factoryAddress).getFundraisingTokenBalance(address(fundraisingToken));
        uint256 totalSupply = fundraisingToken.totalSupply();
        return (lpBalance * MULTIPLIER) / totalSupply;
    }

    /**
     * @notice Adds liquidity to a pool using the provided parameters and manages token approvals.
     * @dev This function handles both ERC20 and ETH liquidity positions, encodes necessary actions and parameters,
     *      calculates ticks and liquidity amounts, and interacts with the position manager to modify liquidities.
     *      It also approves the position manager to spend tokens via Permit2.
     * @param key The PoolKey struct containing pool identifiers and currencies.
     * @param _owner The address of the owner for whom liquidity is being added.
     * @param _currency0 The address of the first currency/token.
     * @param _currency1 The address of the second currency/token.
     * @param _amount0 The amount of currency0 to add as liquidity.
     * @param _amount1 The amount of currency1 to add as liquidity.
     * @param _isCurrencyZeroFundraisingToken Boolean indicating if currency0 is the fundraising token.
     */
    function addLiquidity(
        PoolKey memory key,
        address _owner,
        address _currency0,
        address _currency1,
        uint256 _amount0,
        uint256 _amount1,
        bool _isCurrencyZeroFundraisingToken
    ) internal {
        IPositionManager _positionManager = IPositionManager(positionManager);

        bytes memory actions;
        bytes[] memory params;
        address _underlyingAddress = _isCurrencyZeroFundraisingToken ? _currency1 : _currency0;
        if (_underlyingAddress == address(0)) {
            //ETH
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
            params = new bytes[](2);
        } else {
            // For ETH liquidity positions
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
            params = new bytes[](3);

            params[2] = abi.encode(address(0), _owner); // only for ETH liquidity positions
        }

        uint160 _sqrtPriceX96 = IFactory(factoryAddress).getSqrtPriceX96(_owner);

        (int24 tickLower, int24 tickUpper) = Helper.getMinAndMaxTick(_sqrtPriceX96, tickSpacing);

        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        uint128 _liquidity =
            LiquidityAmounts.getLiquidityForAmounts(_sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, _amount0, _amount1);

        params[0] = abi.encode(key, tickLower, tickUpper, _liquidity, _amount0, _amount1, 0xdead, bytes(""));

        params[1] = abi.encode(key.currency0, key.currency1);

        uint256 deadline = block.timestamp + 1000;

        uint256 valueToPass = key.currency0.isAddressZero() ? _amount0 : 0;

        // approve position manager to spend tokens on behalf of this contract

        if (!Currency.wrap(_currency0).isAddressZero()) {
            IERC20(_currency0).approve(address(permit2), _amount0);
            IPermit2(permit2).approve(_currency0, address(positionManager), uint160(_amount0), uint48(deadline));
        }

        if (!Currency.wrap(_currency1).isAddressZero()) {
            IERC20(_currency1).approve(address(permit2), _amount1);

            IPermit2(permit2).approve(_currency1, address(positionManager), uint160(_amount1), uint48(deadline));
        }

        _positionManager.modifyLiquidities{value: valueToPass}(abi.encode(actions, params), deadline);
    }

    /**
     * @notice Enables or disables emergency pause
     * @param _pause set true to enable emergency pause otherwise set false
     * @dev Only factory can set emergency pause
     */
    function emergencyPause(bool _pause) external onlyFactory {
        if (paused == _pause) revert EmergencyPauseAlreadySet();
        paused = _pause;
        emit Paused(_pause);
    }
}
