// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryWallet {
    /**
     * State Variables
     */
    address public donationAddress; // The address of the donation wallet
    IERC20 public fundraisingToken; // The fundraising token
    address public factoryAddress; // The address of the factory contract

    /**
     * Events
     */
    event FundraisingTokenSet(address fundraisingToken);

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
        _donationAddress = _donationAddress;
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
    function transferFunds() external {}
}
