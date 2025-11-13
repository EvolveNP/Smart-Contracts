// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";
import {console} from "forge-std/console.sol";

contract FundRaisingToken is ERC20 {
    /**
     * Errors
     */
    error ZeroAddress();
    error ZeroAmount();
    error OnlyTreasury();

    /**
     * State Variables
     */
    address public immutable lpManager; // The address of the liquidity pool manager
    address public immutable treasuryAddress; //The address of the treasury wallet
    uint8 _decimals;

    /**
     * Modifiers
     */
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasuryAddress) revert OnlyTreasury();
        _;
    }

    /**
     *
     * @param name Name of the fundraising token
     * @param symbol Symobl of the fundraising token
     * @param _lpManager Address of the liquidity pool manager
     * @param _treasuryAddress Address of the treasury wallet
     * @param _totalSupply Total supply of the fundraising token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address _lpManager,
        address _treasuryAddress,
        uint256 _totalSupply
    ) ERC20(name, symbol) nonZeroAddress(_lpManager) nonZeroAddress(_treasuryAddress) nonZeroAmount(_totalSupply) {
        lpManager = _lpManager;
        treasuryAddress = _treasuryAddress;
        _decimals = decimals_;

        // mint 75% to LP manager 100% = 1e18
        _mint(lpManager, (_totalSupply * 75e16) / 1e18);
        // mint 25% to treasury wallet
        _mint(treasuryAddress, (_totalSupply * 25e16) / 1e18);
    }

    /**
     * @notice Burns a specific amount of tokens from the treasury wallet.
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external nonZeroAmount(amount) onlyTreasury {
        _burn(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
