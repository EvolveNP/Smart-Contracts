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
    /**
     * State Variables
     */

    address public immutable donationAddress; // The address of the donation wallet
    IFundraisingToken public fundraisingToken; // The fundraising token
    address public immutable factoryAddress; // The address of the factory contract
    address public registryAddress; // The address of the chainlink registry contract
    uint256 public lastTransferTimestamp;

    uint256 public constant MINIMUM_THRESHHOLD = 15e16; // The minimum threshold for transferring funds
    uint256 public constant TRANSFER_INTERVAL = 30 days; // The interval at which funds transferred to donation wallet
    uint256 internal constant HEALTH_THRESHHOLD = 7e16; // The health threshold
    uint256 internal constant MULTIPLIER = 1e18;

    /**
     * Events
     */
    event FundraisingTokenSet(address fundraisingToken);
    event FundTransferredToDonationWallet(uint256 amountTransferredAndBurned);
    event LPHealthAdjusted(address recipient, uint256 amount0, uint256 amount1);

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
    constructor(
        address _donationAddress,
        address _factoryAddress,
        address _registryAddress,
        address _router,
        address _poolManager,
        address _permit2,
        address _positionManager,
        address _quoter
    )
        Swap(_router, _poolManager, _permit2, _positionManager, _quoter)
        nonZeroAddress(_donationAddress)
        nonZeroAddress(_factoryAddress)
    {
        donationAddress = _donationAddress;
        factoryAddress = _factoryAddress;
        registryAddress = _registryAddress;
    }

    /**
     * See {AutomationCompatibleInterace - checkUpKeep}
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 transferDate = lastTransferTimestamp + TRANSFER_INTERVAL;
        uint256 lpCurrentThreshold = getCurrentLPHealthThreshold();
        bool initiateTransfer = (block.timestamp >= transferDate && isTransferAllowed());
        bool initiateAddLiqudity = (HEALTH_THRESHHOLD > lpCurrentThreshold);

        upkeepNeeded = (initiateTransfer || initiateAddLiqudity);

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

    function adjustLPHealth() internal {
        // swap half of the amount in for currency0
        uint256 amountToAddToLP = (
            ((fundraisingToken.totalSupply() * MINIMUM_THRESHHOLD) / MULTIPLIER)
                - IFactory(factoryAddress).getFundraisingTokenBalance(address(fundraisingToken))
        ) / 2;

        address _owner = IDonationWallet(donationAddress).owner();
        PoolKey memory key = IFactory(factoryAddress).getPoolKey(_owner);

        address currency0 = Currency.unwrap(key.currency0);
        address currency1 = Currency.unwrap(key.currency1);
        bool isCurrency0FundraisingToken = currency0 == address(fundraisingToken);
        // swap token
        uint256 amountOut = swapExactInputSingle(key, uint128(amountToAddToLP), 1, isCurrency0FundraisingToken);
        uint256 _amount0 = isCurrency0FundraisingToken
            ? amountToAddToLP
            : currency0 == address(0) ? address(this).balance : IERC20(currency0).balanceOf(address(this));
        uint256 _amount1 = !isCurrency0FundraisingToken
            ? amountToAddToLP
            : currency0 == address(0) ? address(this).balance : IERC20(currency0).balanceOf(address(this));

        addLiquidity(key, _owner, currency0, currency1, _amount0, _amount1, isCurrency0FundraisingToken);

        emit LPHealthAdjusted(_owner, amountToAddToLP, amountOut);
    }

    /**
     * @notice Sets the fundraising token address
     * @param _fundraisingToken The address of the fundraising token
     * @dev Only set via factory contract
     */
    function setFundraisingToken(address _fundraisingToken) external onlyFactory {
        fundraisingToken = IFundraisingToken(_fundraisingToken);
        emit FundraisingTokenSet(_fundraisingToken);
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
     * @notice Check if the conditions are mate to send fundraising token to donation wallet
     *         and burn
     */
    function isTransferAllowed() internal view returns (bool) {
        uint256 treasuryBalance = fundraisingToken.balanceOf(address(this));
        uint256 totalSupply = fundraisingToken.totalSupply();
        uint256 currentThreshold = ((treasuryBalance * 1e18) / totalSupply);
        if (currentThreshold >= MINIMUM_THRESHHOLD) {
            return true;
        } else {
            return false;
        }
    }

    function getCurrentLPHealthThreshold() internal view returns (uint256) {
        uint256 lpBalance = IFactory(factoryAddress).getFundraisingTokenBalance(address(fundraisingToken));
        uint256 totalSupply = fundraisingToken.totalSupply();
        return (lpBalance * MULTIPLIER) / totalSupply;
    }

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

        (int24 tickLower, int24 tickUpper) = Helper.getMinAndMaxTick(_sqrtPriceX96, 60);

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
}
