// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryWallet {
    /**
     * State Variables
     */
    address public immutable donationAddress; // The address of the donation wallet
    IERC20 public fundraisingToken; // The fundraising token
    address public immutable factoryAddress; // The address of the factory contract
    uint256 public constant minimumThreshold = 15e16; // The minimum threshold for transferring funds

    //  address internal

    /**
     * Events
     */
    event FundraisingTokenSet(address fundraisingToken);
    event TransferFunds(uint256 amountTransferredAndBurned);

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

    constructor(address _donationAddress, address _factoryAddress)
        nonZeroAddress(_donationAddress)
        nonZeroAddress(_factoryAddress)
    {
        donationAddress = _donationAddress;
        factoryAddress = _factoryAddress;
    }

    /**
     *
     * @param _fundraisingToken The address of the fundraising token
     */
    function setFundraisingToken(address _fundraisingToken) external onlyFactory {
        fundraisingToken = IERC20(_fundraisingToken);
        emit FundraisingTokenSet(_fundraisingToken);
    }

    /**
     * TODO: Responsible for transferring funds to the donation wallet based on a predefined schedule
     */
    function transferFunds() external {
        uint256 amountToTransferAndBurn = 0;
        if (isTransferAllowed()) {
            amountToTransferAndBurn = fundraisingToken.totalSupply() * 2e16 / 1e18; // 2% of total supply
            fundraisingToken.transfer(donationAddress, amountToTransferAndBurn);
            fundraisingToken.transfer(address(0), amountToTransferAndBurn);
        }

        emit TransferFunds(amountToTransferAndBurn);
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
