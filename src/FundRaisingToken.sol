// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FundRaisingToken is ERC20, Ownable {
    /**
     * State Variables
     */
    address public immutable lpManager; // The address of the liquidity pool manager
    address public immutable treasuryAddress; //The address of the treasury wallet
    address public lpAddress; // The address of the liquidity pool
    address public immutable donationAddress; // The address of the donation wallet
    uint256 immutable taxFee; // The tax fee on each transaction
    uint256 public immutable healthThreshold; // The health threshold for the liquidity pool
    uint256 public immutable minimumThreshold; // The minimum threshold for the liquidity pool
    uint256 public immutable maximumThreshold; // The maximum threshold for the liquidity pool
    uint256 configurableTaxFee; // A configurable tax fee on each transaction

    /**
     * Events
     */
    event LPAddressUpdated(address lpAddress);

    /**
     * Modifiers
     */
    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    modifier nonZeroAmount(uint256 _amount) {
        require(_amount > 0, "Zero amount");
        _;
    }

    modifier onlyTreasury(address _address) {
        require(_address == treasuryAddress, "Only treasury");
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
     * @param _taxFee Tax fee on each transaction (in basis points, e.g. 1e16 = 1%)
     * @param _healthThreshold Health threshold for the liquidity pool
     * @param _minimumThreshold Minimum threshold for the liquidity pool
     * @param _maximumThreshold Maximum threshold for the liquidity pool
     */
    constructor(
        string memory name,
        string memory symbol,
        address _lpManager,
        address _treasuryAddress,
        address _donationAddress,
        uint256 _totalSupply,
        uint256 _taxFee,
        uint256 _healthThreshold,
        uint256 _minimumThreshold,
        uint256 _maximumThreshold,
        uint256 _configurableTaxFee
    )
        ERC20(name, symbol)
        Ownable(msg.sender)
        nonZeroAddress(_lpManager)
        nonZeroAddress(_treasuryAddress)
        nonZeroAddress(_donationAddress)
        nonZeroAmount(_totalSupply)
    {
        require(_configurableTaxFee <= _taxFee, "Incorrect configurable tax fee");

        lpManager = _lpManager;
        treasuryAddress = _treasuryAddress;
        donationAddress = _donationAddress;
        taxFee = _taxFee;
        healthThreshold = _healthThreshold;
        minimumThreshold = _minimumThreshold;
        maximumThreshold = _maximumThreshold;
        configurableTaxFee = _configurableTaxFee;

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

    /**
     * @notice Sets the liquidity pool address. Only callable by the owner.
     * @param _lpAddress Address of the liquidity pool
     */
    function setLPAddress(address _lpAddress) external nonZeroAddress(_lpAddress) onlyOwner {
        lpAddress = _lpAddress;
        emit LPAddressUpdated(_lpAddress);
    }

    /**
     *
     * See {ERC20-_update}
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        // only calculate tax on transfer
        uint256 taxAmount = 0;
        if (
            (from != address(0) && to != address(0)) && (from != lpManager && to != lpManager)
                && (from != donationAddress && to != donationAddress) && (from != treasuryAddress && to != treasuryAddress)
                && (getTreasuryBalanceInPerecent() < maximumThreshold)
        ) {
            uint256 lpHealth = checkLPHealth();
            // If the LP is under the health threshold, a configurable % of the tax is routed to the LP as an auto‑liquidity top‑up; the remainder (if any) goes to the Treasury.
            if (lpHealth < healthThreshold) {
                taxAmount = (value * configurableTaxFee) / 1e18;
                super._update(from, lpAddress, taxAmount);

                if (taxFee > configurableTaxFee) {
                    taxAmount = (value * (taxFee - configurableTaxFee)) / 1e18;
                    super._update(from, treasuryAddress, taxAmount);
                }
            } else {
                // If the LP is above the health threshold, 100% of the tax goes to the Treasury.
                taxAmount = (value * taxFee) / 1e18;
                super._update(from, treasuryAddress, taxAmount);
            }
        }

        super._update(from, to, value - taxAmount);
    }

    /**
     * TODO
     */
    function checkLPHealth() internal pure returns (uint256) {
        return 1;
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
