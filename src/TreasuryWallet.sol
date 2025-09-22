// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IFundraisingToken} from "./interfaces/IFundraisingToken.sol";
import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";

contract TreasuryWallet is AutomationCompatibleInterface {
    /**
     * State Variables
     */
    address public immutable donationAddress; // The address of the donation wallet
    IFundraisingToken public fundraisingToken; // The fundraising token
    address public immutable factoryAddress; // The address of the factory contract
    address public registryAddress; // The address of the chainlink registry contract
    uint256 public constant minimumThreshold = 15e16; // The minimum threshold for transferring funds

    //  address internal

    /**
     * Events
     */
    event FundraisingTokenSet(address fundraisingToken);
    event FundTransferredToDonationWallet(uint256 amountTransferredAndBurned);

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

    constructor(address _donationAddress, address _factoryAddress, address _registryAddress)
        nonZeroAddress(_donationAddress)
        nonZeroAddress(_factoryAddress)
    {
        donationAddress = _donationAddress;
        factoryAddress = _factoryAddress;
        registryAddress = _registryAddress;
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) {}

    function performUpkeep(bytes calldata performData) external {}

    /**
     *
     * @param _fundraisingToken The address of the fundraising token
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
    function transferFunds() external onlyRegistry {
        uint256 amountToTransferAndBurn = 0;
        if (isTransferAllowed()) {
            amountToTransferAndBurn = fundraisingToken.totalSupply() * 2e16 / 1e18; // 2% of total supply
            fundraisingToken.transfer(donationAddress, amountToTransferAndBurn);
            fundraisingToken.burn(amountToTransferAndBurn);
        }

        emit FundTransferredToDonationWallet(amountToTransferAndBurn);
    }

    function isTransferAllowed() internal view returns (bool) {
        uint256 treasuryBalance = fundraisingToken.balanceOf(address(this));
        uint256 totalSupply = fundraisingToken.totalSupply();
        uint256 currentThreshold = (treasuryBalance * 1e18 / totalSupply);
        if (currentThreshold >= minimumThreshold) {
            return true;
        } else {
            return false;
        }
    }
}
