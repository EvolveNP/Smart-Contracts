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
import {Currency} from "v4-core/src/types/Currency.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";

contract Factory is Ownable {
    struct FundRaisingAddresses {
        address fundraisingToken; // The address of the fundraising token
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address lpAddress; // address of the lp pool
        address owner; // the non profit org wallet address
        address currency0; // address of currency0 in the lp
        address currency1; // address of currency1 in the lp
    }

    uint256 internal constant totalSupply = 1e9; // the total supply of fundraising token
    address internal immutable registryAddress; // The address of chainlink automation registry address
    mapping(address => FundRaisingAddresses) public fundraisingAddresses; // non profit org wallet address => FundRaisingAddresses

    event FundraisingVaultCreated(
        address fundraisingToken, address treasuryWallet, address donationWallet, address owner
    );
    event LiquidityPoolCreated(address lpAddress, address owner);
    event InitialLiquidityAdded(address owner, uint256 amount0, uint256 amount1);

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
            address(fundraisingToken),
            address(donationWallet),
            address(treasuryWallet),
            address(0),
            _owner,
            address(0),
            address(0)
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
        // wrap currencies

        Currency currency0 = Currency.wrap(_currency0);
        Currency currency1 = Currency.wrap(_currency1);

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: _fee,
            tickSpacing: _tickSpacing,
            hooks: IHooks(_hooks)
        });

        IPoolManager poolManager = new PoolManager(msg.sender);

        poolManager.initialize(poolKey, _sqrtPriceX96);

        FundRaisingAddresses storage addresses = fundraisingAddresses[_owner];
        addresses.lpAddress = address(poolManager);
        addresses.currency0 = _currency0;
        addresses.currency1 = _currency1;

        // set lp address in fundraising token
        FundRaisingToken(addresses.fundraisingToken).setLPAddress(address(poolManager));

        // set lp address in treasury wallet
        TreasuryWallet(addresses.treasuryWallet).setLPAddress(address(poolManager));

        emit LiquidityPoolCreated(address(poolManager), _owner);
    }

    function addInitialLquidity(uint256 _amount0, uint256 _amount1, address _positionManager, address _owner)
        external
        onlyOwner
    {
        IPositionManager positionManager = IPositionManager(_positionManager);

        FundRaisingAddresses memory addresses = fundraisingAddresses[_owner];

        bytes memory actions;
        if (addresses.currency1 == address(0)) {
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        } else {
            // For ETH liquidity positions
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        }
        bytes[] memory params = new bytes[](2); // new bytes[](3) for ETH liquidity positions

        params[0] = abi.encode(
            PoolKey({
                currency0: Currency.wrap(addresses.currency0),
                currency1: Currency.wrap(addresses.currency1),
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(address(0))
            }),
            -120,
            120,
            _amount0,
            _amount1,
            0xdead
        );

        Currency currency1 = Currency.wrap(addresses.currency1);
        Currency currency0 = Currency.wrap(addresses.currency0);

        params[1] = abi.encode(currency0, currency1); // add another param for ETH liquidity positions
        params[2] = abi.encode(address(0), owner()); // only for ETH liquidity positions

        uint256 deadline = block.timestamp + 60;

        uint256 valueToPass = currency0.isAddressZero() ? _amount0 : 0;

        positionManager.modifyLiquidities{value: valueToPass}(abi.encode(actions, params), deadline);

        emit InitialLiquidityAdded(_owner, _amount0, _amount1);
    }
}
