// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

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
    uint256 public constant taxFee = 2e16; // The tax fee on each transaction 2% = 2e16 (in basis points, e.g. 1e16 = 1%)
    uint256 public constant healthThreshold = 1e18; // The health threshold for the liquidity pool
    uint256 public constant minimumThreshold = 15e16; // The minimum threshold for the liquidity pool 15% = 15e16
    uint256 public constant maximumThreshold = 30e16; // The maximum threshold for the liquidity pool 30% = 30e16
    uint256 public constant configurableTaxFee = 1e16; // A configurable tax fee on each transaction

    uint256 internal luanchTimestamp; // The timestamp when the token was launched
    uint256 internal constant perWalletCoolDownPeriod = 1 minutes;
    uint256 internal constant maxBuySize = 333e13; // 0.333% of total supply
    uint256 internal constant blocksToHold = 10;
    uint256 internal launchBlock; // The block number when the token was launched

    mapping(address => uint256) internal lastBuyTimestamp; // The last buy timestamp for each address

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
     */
    constructor(
        string memory name,
        string memory symbol,
        address _lpManager,
        address _treasuryAddress,
        address _donationAddress,
        uint256 _totalSupply
    )
        ERC20(name, symbol)
        Ownable(msg.sender)
        nonZeroAddress(_lpManager)
        nonZeroAddress(_treasuryAddress)
        nonZeroAddress(_donationAddress)
        nonZeroAmount(_totalSupply)
    {
        lpManager = _lpManager;
        treasuryAddress = _treasuryAddress;
        donationAddress = _donationAddress;

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
    function _update(address from, address to, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;

        // Exempt mint/burn
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Exempt system addresses
        if (
            from == lpManager || to == lpManager || from == donationAddress || to == donationAddress
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

    function isTransferBlocked(address _account) internal returns (bool) {}
}
