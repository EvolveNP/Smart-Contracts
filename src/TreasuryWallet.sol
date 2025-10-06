// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IFundraisingToken} from "./interfaces/IFundraisingToken.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Swap} from "./abstracts/Swap.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

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
    uint256 public constant minimumThreshold = 15e16; // The minimum threshold for transferring funds
    uint256 public constant transferInterval = 30 days; // The interval at which funds transferred to donation wallet
    uint256 public lastTransferTimestamp;
    uint256 internal constant healthThreshold = 7e16; // The health threshold

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
        address _positionManager
    )
        Swap(_router, _poolManager, _permit2, _positionManager)
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
        uint256 transferDate = lastTransferTimestamp + transferInterval;
        uint256 lpCurrentThreshold = 1e18; //TODO
        bool initiateTransfer = (block.timestamp >= transferDate && isTransferAllowed());
        bool initiateAddLiqudity = (healthThreshold > lpCurrentThreshold);

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
            // addLiquidity();
        }
    }

    function adjustLPHealth(uint128 _amount0, uint128 _amount1, address _owner) internal {
        // swap half of the amount in for currency0
        PoolKey memory key = IFactory(factoryAddress).getPoolKey(_owner);
        // TODO
        uint256 amountOut = swapExactInputSingle(key, uint128(_amount0 * 95e16) / 1e18, 1, true); // swap 5% slippage

        IFactory(factoryAddress).addLiquidity(
            _amount0 / 2,
            amountOut,
            _owner,
            0, // _sqrtPriceX96
            0, // _sqrtPriceAX96
            0 // _sqrtPriceBX96
        );
        emit LPHealthAdjusted(_owner, _amount0, _amount1);
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
        if (currentThreshold >= minimumThreshold) {
            return true;
        } else {
            return false;
        }
    }

    function getReserves() internal pure returns (uint128 reserve0, uint128 reserve1) {
        return (0, 0); // TODO
    }
}
