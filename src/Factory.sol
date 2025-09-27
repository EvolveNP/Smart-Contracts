// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FundRaisingToken} from "./FundRaisingToken.sol";
import {TreasuryWallet} from "./TreasuryWallet.sol";
import {DonationWallet} from "./DonationWallet.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";

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
    event LiquidityPoolCreated(address lpAddress, address owner);

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    /**
     *
     * @param _registryAddress The address of chainlink automation registry address
     */
    constructor(address _registryAddress, address _uniswapV4PoolManager)
        Ownable(msg.sender)
        nonZeroAddress(_registryAddress)
    {
        registryAddress = _registryAddress;
        uniswapV4PoolManager = _uniswapV4PoolManager;
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
     * @notice Creates a Uniswap V4 pool for the fundraising token and another currency
     * @param _currency0 The address of the first currency in the pool (fundraising token)
     * @param _currency1 The address of the second currency in the pool
     * @param _fee The fee tier of the pool
     * @param _sqrtPriceX96 The initial square root price of the pool
     * @param _tickSpacing The tick spacing of the pool
     * @param _hooks The address of the hooks contract
     * @param _owner The owner of the pool manager
     * @dev Only callable by the owner of the factory contract
     */
    function createPool(
        address _currency0,
        address _currency1,
        uint24 _fee,
        uint160 _sqrtPriceX96,
        int24 _tickSpacing,
        address _hooks,
        address _owner
    ) external onlyOwner {
        PoolKey memory poolKey = PoolKey({
            currency0: _currency0,
            currency1: _currency1,
            fee: _fee,
            tickSpacing: _tickSpacing,
            hooks: IHooks(_hooks)
        });

        IPoolManager poolManager = new PoolManager(msg.sender);

        poolManager.initialize(poolKey, _sqrtPriceX96);

        FundRaisingAddresses storage addresses = fundraisingAddresses[_owner];
        addresses.lpAddress = address(poolManager);

        // set lp address in fundraising token
        FundRaisingToken(addresses.fundraisingToken).setLPAddress(address(poolManager));

        // set lp address in treasury wallet
        TreasuryWallet(addresses.treasuryWallet).setLPAddress(address(poolManager));

        emit LiquidityPoolCreated(address(poolManager), _owner);
    }
}
