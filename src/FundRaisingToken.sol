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
    error OnlyFactory();

    /**
     * State Variables
     */
    address public immutable lpManager; // The address of the liquidity pool manager
    address public immutable treasuryAddress; //The address of the treasury wallet
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
    uint256 internal constant timeToHold = 1 hours;
    uint256 internal launchBlock; // The block number when the token was launched
    address public immutable factoryAddress; // The address of the factory contract
    mapping(address => uint256) internal lastBuyTimestamp; // The last buy timestamp for each address
    uint8 _decimals;

    /**
     * Events
     */
    event LuanchBlockAndTimestampSet(uint256 launchBlock, uint256 luanchTimestamp);

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

    modifier onlyFactory() {
        if (msg.sender != factoryAddress) revert OnlyFactory();
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

    function setLuanchBlockAndTimestamp() external onlyFactory {
        if (launchBlock == 0) {
            launchBlock = block.number;
            luanchTimestamp = block.timestamp;
        }
        emit LuanchBlockAndTimestampSet(launchBlock, luanchTimestamp);
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

    /**
     * TODO: Use this in uniswap hook
     * @notice Checks if a transfer is blocked based on launch protection, cooldown period, and max buy size.
     * @param _account The address of the account to check
     * @param _amount The amount to be transferred
     * @return True if the transfer is blocked, false otherwise
     */
    function isTransferBlocked(address _account, uint256 _amount) internal returns (bool, bool) {
        // Block transfers during launch protection
        if (launchBlock == 0 && luanchTimestamp == 0) return (false, false); // Not launched yet
        //Hold for a specific block after launch
        if (block.number < launchBlock + blocksToHold) return (true, false);

        if (block.timestamp < luanchTimestamp + timeToHold) {
            // Block transfers if within time to hold after launch
            uint256 lastBuy = lastBuyTimestamp[_account];
            lastBuyTimestamp[_account] = block.timestamp;

            uint256 _maxBuySize = totalSupply() * maxBuySize / 1e18;

            if (_amount > _maxBuySize) return (true, false);

            // Block transfers if within cooldown
            if (lastBuy != 0 && block.timestamp < lastBuy + perWalletCoolDownPeriod) return (true, false);
            return (false, true);
        }
        return (false, false);
    }

    function updateLastBuyTimestamp(address _account) internal {
        lastBuyTimestamp[_account] = block.timestamp;
    }
}
