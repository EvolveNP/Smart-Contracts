// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FundRaisingToken is ERC20 {
    address public immutable lpManager; // The address of the liquidity pool manager
    address public immutable treasuryAddress; //The address of the treasury wallet
    address public immutable lpAddress; // The address of the liquidity pool
    address public immutable donationAddress; // The address of the donation wallet
    uint256 immutable taxFee; // The tax fee on each transaction
    uint256 public immutable healthThreshold; // The health threshold for the liquidity pool
    uint256 public immutable minimumThreshold; // The minimum threshold for the liquidity pool
    uint256 public immutable maximumThreshold; // The maximum threshold for the liquidity pool

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
        address _lpAddress,
        address _treasuryAddress,
        address _donationAddress,
        uint256 _totalSupply,
        uint256 _taxFee,
        uint256 _healthThreshold,
        uint256 _minimumThreshold,
        uint256 _maximumThreshold
    ) ERC20(name, symbol) nonZeroAddress(_lpManager) nonZeroAddress(_treasuryAddress) nonZeroAmount(_totalSupply) {
        lpManager = _lpManager;
        lpAddress = _lpAddress;
        treasuryAddress = _treasuryAddress;
        donationAddress = _donationAddress;
        taxFee = _taxFee;
        healthThreshold = _healthThreshold;
        minimumThreshold = _minimumThreshold;
        maximumThreshold = _maximumThreshold;

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
     *
     * See {ERC20-_update}
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        // only calculate tax on transfer
        uint256 taxAmount = 0;
        if (
            (from != address(0) && to != address(0)) && (from != lpManager && to != lpManager)
                && (from != donationAddress && to != donationAddress) && (from != treasuryAddress && to != treasuryAddress)
        ) {
            uint256 lpHealth = checkLPHealth();
            require(lpHealth >= healthThreshold, "LP health below threshold");
            taxAmount = (value * taxFee) / 1e18;

            super._update(from, treasuryAddress, taxAmount);
        }

        super._update(from, to, value - taxAmount);
    }

    /**
     * TODO
     */
    function checkLPHealth() internal pure returns (uint256) {
        return 1;
    }
}
