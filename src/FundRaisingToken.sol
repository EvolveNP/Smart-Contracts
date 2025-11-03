// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FundRaisingToken is ERC20 {
    /**
     * Errors
     */
    error ZeroAddress();
    error ZeroAmount();
    error OnlyTreasury();
    error TransferBlocked();

    /**
     * State Variables
     */
    address public immutable lpManager; // The address of the liquidity pool manager
    address public immutable treasuryAddress; //The address of the treasury wallet
    address public immutable donationAddress; // The address of the donation wallet
    uint256 public constant taxFee = 2e16; // The tax fee on each transaction 2% = 2e16 (in basis points, e.g. 1e16 = 1%)
    uint256 public constant maximumThreshold = 30e16; // The maximum threshold for the liquidity pool 30% = 30e16
    address public immutable factoryAddress; // The address of the factory contract
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

    modifier onlyTreasury(address _address) {
        if (_address != treasuryAddress) revert OnlyTreasury();
        _;
    }

    /**
     *
     * @param name Name of the fundraising token
     * @param symbol Symobl of the fundraising token
     * @param _lpManager Address of the liquidity pool manager
     * @param _treasuryAddress Address of the treasury wallet
     * @param _donationAddress Address of the donation wallet
     * @param _totalSupply Total supply of the fundraising token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address _lpManager,
        address _treasuryAddress,
        address _donationAddress,
        address _factoryAddress,
        uint256 _totalSupply
    )
        ERC20(name, symbol)
        nonZeroAddress(_lpManager)
        nonZeroAddress(_treasuryAddress)
        nonZeroAddress(_donationAddress)
        nonZeroAddress(_factoryAddress)
        nonZeroAmount(_totalSupply)
    {
        lpManager = _lpManager;
        treasuryAddress = _treasuryAddress;
        donationAddress = _donationAddress;
        factoryAddress = _factoryAddress;
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
    function burn(uint256 amount) external nonZeroAmount(amount) onlyTreasury(msg.sender) {
        _burn(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     *
     * See {ERC20-_update}
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;

        // Exempt mint/burn
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Exempt system addresses
        if (
            from == factoryAddress || to == factoryAddress || from == donationAddress || to == donationAddress
                || from == treasuryAddress || to == treasuryAddress
        ) {
            super._update(from, to, amount);
            return;
        }

        // Only tax if treasury < max threshold
        if (getTreasuryBalanceInPerecent() < maximumThreshold) {
            // All tax → Treasury
            taxAmount = (amount * taxFee) / 1e18;
            if (taxAmount > 0) super._update(from, treasuryAddress, taxAmount);
        }

        // Net transfer to user
        unchecked {
            super._update(from, to, amount - taxAmount);
        }
    }

    /**
     * @notice Returns the treasury balance as a percentage of the total supply
     * @return Percentage of the total supply held by the treasury (in 1e18 format, e.g. 1e16 = 1%)
     */
    function getTreasuryBalanceInPerecent() internal view returns (uint256) {
        uint256 treasuryBalance = balanceOf(treasuryAddress);
        uint256 totalSupply = totalSupply();

        return (treasuryBalance * 1e18) / totalSupply;
    }
}
