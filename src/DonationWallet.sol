// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DonationWallet {
    IERC20 public immutable fundraisingTokenAddress; // Address of the FundRaisingToken contract
    address public immutable owner; // Owner of the DonationWallet

    constructor(address _fundraisingTokenAddress, address _owner) {
        fundraisingTokenAddress = IERC20(_fundraisingTokenAddress);
        owner = _owner;
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
}
