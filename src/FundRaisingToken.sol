// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FundRaisingToken is ERC20 {
    address public lpManager; // The address of the liquidity pool manager
    address public treasuryAddress; //The address of the treasury wallet

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    /**
     *
     * @param name Name of the fundraising token
     * @param symbol Symobl of the fundraising token
     */
    constructor(
        string memory name,
        string memory symbol,
        address _lpManager,
        address _treasuryAddress,
        uint256 _totalSupply
    ) ERC20(name, symbol) nonZeroAddress(_lpManager) nonZeroAddress(_treasuryAddress) {
        lpManager = _lpManager;
        treasuryAddress = _treasuryAddress;

        // mint 75% to LP manager 100% = 1e18
        _mint(_lpManager, (_totalSupply * 75e16) / 1e18);
        // mint 25% to treasury wallet
        _mint(_treasuryAddress, (_totalSupply * 25e16) / 1e18);
    }

    function checkLPHealth() internal pure returns (uint256) {
        return 1;
    }
}
