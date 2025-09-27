// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DonationWallet {
    IERC20 public fundraisingTokenAddress; // Address of the FundRaisingToken contract
    address public immutable owner; // Owner of the DonationWallet
    address public immutable factoryAddress; // The address of the factory contract

    event FundraisingTokenAddressSet(address fundraisingToken);

    modifier onlyFactory(address _addr) {
        require(_addr == factoryAddress, "Only by factory");
        _;
    }

    /**
     *
     * @param _factoryAddress The address of the factory contract
     * @param _owner The wallet address of non profit organization that receives the donation
     */
    constructor(address _factoryAddress, address _owner) {
        owner = _owner;
        factoryAddress = _factoryAddress;
    }

    /**
     * TODO
     */
    function transferAsset() external view {
        require(fundraisingTokenAddress.balanceOf(address(this)) > 0, "No tokens to transfer");
    }

    /**
     * TODO
     */
    function swapFundraisingToken() external {
        // Logic to swap FundRaisingToken for ETH and send to treasury
    }

    /**
     * @notice Set the address of the fundraising token
     * @param _fundraisingToken The address of the fundraising token
     * @dev Only set vai factory contract
     */
    function setFundraisingTokenAddress(address _fundraisingToken) external onlyFactory(msg.sender) {
        fundraisingTokenAddress = IERC20(_fundraisingToken);
        emit FundraisingTokenAddressSet(_fundraisingToken);
    }
}
