// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FundRaisingToken} from "./FundRaisingToken.sol";
import {TreasuryWallet} from "./TreasuryWallet.sol";
import {DonationWallet} from "./DonationWallet.sol";

contract Factory is Ownable {
    struct FundRaisingAddresses {
        address fundraisingToken; // The address of the fundraising token
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address lpAddress; // address of the lp pool
        address owner; // the non profit org wallet address
    }

    uint256 internal constant totalSupply = 1e9; // the total supply of fundraising token
    address internal immutable registryAddress; // The address of chainlink automation registry address
    mapping(address => FundRaisingAddresses) public fundraisingAddresses; // non profit org wallet address => FundRaisingAddresses

    event FundraisingVaultCreated(
        address fundraisingToken, address treasuryWallet, address donationWallet, address owner
    );

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    /**
     *
     * @param _registryAddress The address of chainlink automation registry address
     */
    constructor(address _registryAddress) Ownable(msg.sender) nonZeroAddress(_registryAddress) {
        registryAddress = _registryAddress;
    }

    /**
     * @notice deploys the contracts for specific non profit organization
     * @param _tokenName The name of the fundraising token
     * @param _tokenSymbol The symbol of the fundraising token
     * @param _owner The address of the owner who receives the donation
     * @dev only called by owner
     */
    function createFundraisingVault(string calldata _tokenName, string calldata _tokenSymbol, address _owner)
        external
        onlyOwner
    {
        // deploy donation wallet
        DonationWallet donationWallet = new DonationWallet(address(this), _owner);

        // deploy treasury wallet
        TreasuryWallet treasuryWallet = new TreasuryWallet(address(donationWallet), address(this), registryAddress);

        // Deploy fundraising token
        FundRaisingToken fundraisingToken = new FundRaisingToken(
            _tokenName, _tokenSymbol, owner(), address(donationWallet), address(treasuryWallet), totalSupply
        );

        // set fundraising token in donation wallet
        donationWallet.setFundraisingTokenAddress(address(fundraisingToken));

        // set fundraising token in treasury wallet

        treasuryWallet.setFundraisingToken(address(fundraisingToken));

        fundraisingAddresses[_owner] = FundRaisingAddresses(
            address(fundraisingToken), address(donationWallet), address(treasuryWallet), address(0), _owner
        );

        emit FundraisingVaultCreated(
            address(fundraisingToken), address(donationWallet), address(treasuryWallet), _owner
        );
    }

    /**
     * TODO
     */
    function createPool() external onlyOwner {
        // create a uniswap pool
    }
}
