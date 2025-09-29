// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IFundraisingToken} from "./interfaces/IFundraisingToken.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

contract TreasuryWallet is AutomationCompatibleInterface {
    /**
     * State Variables
     */
    address public immutable donationAddress; // The address of the donation wallet
    IFundraisingToken public fundraisingToken; // The fundraising token
    address public immutable factoryAddress; // The address of the factory contract
    address public registryAddress; // The address of the chainlink registry contract
    uint256 public constant minimumThreshold = 15e16; // The minimum threshold for transferring funds
    address public lpAddress; // The address of the Liquidity pool
    uint256 public constant transferInterval = 30 days; // The interval at which funds transferred to donation wallet
    uint256 public lastTransferTimestamp;
    uint256 internal constant healthThreshold = 7e16; // The health threshold

    /**
     * Events
     */
    event FundraisingTokenSet(address fundraisingToken);
    event FundTransferredToDonationWallet(uint256 amountTransferredAndBurned);
    event LPAddressSet(address lpAddress);
    event LPHealthAdjusted(address recipient, uint256 amount0, uint256 amount1);

    /**
     * Modifiers
     */
    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "Only factory");
        _;
    }

    modifier onlyRegistry() {
        require(msg.sender == registryAddress, "Only registry");
        _;
    }

    /**
     *
     * @param _donationAddress The address of the donation wallet
     * @param _factoryAddress The address of the factory contract
     * @param _registryAddress The address of the registry
     */
    constructor(address _donationAddress, address _factoryAddress, address _registryAddress)
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

    /**
     * TODO
     */
    function addLiquidity(
        uint256 _tokenId,
        uint256 _liquidity,
        uint256 _amount0,
        uint256 _amount1,
        address _currency0,
        address _currency1,
        address _recipient,
        address _positionManager
    ) internal {
        /**
         * TODO: Swap
         */
        IPositionManager positionManager = IPositionManager(_positionManager);
        // swap amount of fundraising token for currency0 and currency1
        bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);

        params[0] = abi.encode(_tokenId, _liquidity, _amount0, _amount1, IHooks(address(0)));

        // If converting fees to liquidity, forfeiting dust:
        Currency currency0 = Currency.wrap(_currency0); // tokenAddress1 = 0 for native ETH
        Currency currency1 = Currency.wrap(_currency1); // tokenAddress2 = 0 for native ETH
        params[1] = abi.encode(currency0, currency1);

        params[2] = abi.encode(address(0), _recipient);

        uint256 deadline = block.timestamp + 60;

        uint256 valueToPass = currency0.isAddressZero() ? _amount0 : 0;

        positionManager.modifyLiquidities{value: valueToPass}(abi.encode(actions, params), deadline);

        emit LPHealthAdjusted(_recipient, _amount0, _amount1);
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

    function setLPAddress(address _lpAddress) external onlyFactory nonZeroAddress(_lpAddress) {
        lpAddress = _lpAddress;
        emit LPAddressSet(_lpAddress);
    }

    /**
     * @notice Transfer funds to donation wallet and burn an equal amount
     * @dev Can only be called by the registry contract and
     *      only if the treasury wallet balance is above the minimum threshold
     */
    function transferFunds() internal onlyRegistry {
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
}
