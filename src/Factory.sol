// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FundRaisingToken} from "./FundRaisingToken.sol";
import {TreasuryWallet} from "./TreasuryWallet.sol";
import {DonationWallet} from "./DonationWallet.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";

contract Factory is Ownable {
    using LiquidityAmounts for uint160;

    /**
     * Errors
     */
    error ZeroAddress();

    struct FundRaisingAddresses {
        address fundraisingToken; // The address of the fundraising token
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address lpAddress; // address of the lp pool
        address owner; // the non profit org wallet address
        address currency0; // address of currency0 in the lp
        address currency1; // address of currency1 in the lp
    }

    uint256 public constant totalSupply = 1e27; // the total supply of fundraising token
    address public immutable registryAddress; // The address of chainlink automation registry address
    mapping(address => FundRaisingAddresses) public fundraisingAddresses; // non profit org wallet address => FundRaisingAddresses

    // uniswap constants
    mapping(address => PoolKey) public poolKeys; // lp address => pool key:  store pool keys for easy access
    address public immutable router; // The address of the uniswap universal router
    address public immutable permit2; // The address of the uniswap permit2 contract
    uint24 public constant defaultFee = 3000; // default fee tier for the pool
    int24 public constant defaultTickSpacing = 60; // default tick spacing for the pool
    int24 public constant maxTick = 120; // max tick for the pool
    int24 public constant minTick = -120; // min tick for the
    address public immutable poolManager; // The address of the uniswap v4 pool manager
    address public immutable positionManager; // The address of the uniswap v4 position manager

    event FundraisingVaultCreated(
        address fundraisingToken, address treasuryWallet, address donationWallet, address owner
    );
    event LiquidityPoolCreated(address lpAddress, address owner);
    event InitialLiquidityAdded(address owner, uint256 amount0, uint256 amount1);

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    /**
     *
     * @param _registryAddress The address of chainlink automation registry address
     * @param _poolManager The address of the uniswap v4 pool manager
     * @param _positionManager The address of the uniswap v4 position manager
     * @param _router The address of the uniswap universal router
     * @param _permit2 The address of the uniswap permit2 contract
     */
    constructor(
        address _registryAddress,
        address _poolManager,
        address _positionManager,
        address _router,
        address _permit2
    )
        Ownable(msg.sender)
        nonZeroAddress(_registryAddress)
        nonZeroAddress(_poolManager)
        nonZeroAddress(_positionManager)
        nonZeroAddress(_router)
        nonZeroAddress(_permit2)
    {
        registryAddress = _registryAddress;
        poolManager = _poolManager;
        positionManager = _positionManager;
        router = _router;
        permit2 = _permit2;
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
        DonationWallet donationWallet =
            new DonationWallet(address(this), _owner, router, poolManager, permit2, positionManager);

        // deploy treasury wallet
        TreasuryWallet treasuryWallet = new TreasuryWallet(
            address(donationWallet), address(this), registryAddress, router, poolManager, permit2, positionManager
        );

        // Deploy fundraising token
        FundRaisingToken fundraisingToken = new FundRaisingToken(
            _tokenName,
            _tokenSymbol,
            owner(),
            address(donationWallet),
            address(treasuryWallet),
            address(this),
            totalSupply
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
     * @param _currency0 The address of the first currency in the pool ex: USDC
     * @param _currency1 The address of the second currency in the pool ex: FundRaisingToken
     * @param _sqrtPriceX96 The initial square root price of the pool
     * @param _owner The owner of the pool manager
     * @dev Only callable by the owner of the factory contract
     * @dev _sqrtPriceX96 calculated as floor(sqrt(token0/token1) * 2^96)
     */
    function createPool(address _currency0, address _currency1, uint160 _sqrtPriceX96, address _owner)
        external
        onlyOwner
    {
        // wrap currencies
        Currency currency0 = Currency.wrap(_currency0);
        Currency currency1 = Currency.wrap(_currency1);

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: defaultFee,
            tickSpacing: defaultTickSpacing,
            hooks: IHooks(address(0)) // currently we don't use hooks
        });

        IPoolManager _poolManager = IPoolManager(poolManager);

        _poolManager.initialize(poolKey, _sqrtPriceX96);

        FundRaisingAddresses storage addresses = fundraisingAddresses[_owner];
        addresses.lpAddress = address(poolManager);
        addresses.currency0 = _currency0;
        addresses.currency1 = _currency1;

        // store pool key for easy access
        poolKeys[_owner] = poolKey;

        emit LiquidityPoolCreated(address(poolManager), _owner);
    }

    /**
     *
     * @param _amount0 The amount of currency0 to add as initial liquidity
     * @param _amount1 The amount of currency1 to add as initial liquidity
     * @param _owner The owner of the pool manager
     * @dev Only callable by the owner of the factory contract
     */
    function addLiquidity(
        uint256 _amount0,
        uint256 _amount1,
        address _owner,
        uint160 _sqrtPriceX96,
        uint160 _sqrtPriceAX96,
        uint160 _sqrtPriceBX96
    ) external payable onlyOwner {
        IPositionManager _positionManager = IPositionManager(positionManager);

        PoolKey memory key = poolKeys[_owner];

        bytes memory actions;
        bytes[] memory params;
        if (Currency.unwrap(key.currency0) == address(0)) {
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
            params = new bytes[](2);
        } else {
            // For ETH liquidity positions
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
            params = new bytes[](3);

            params[2] = abi.encode(address(0), owner()); // only for ETH liquidity positions
        }

        uint128 liquidity =
            _sqrtPriceX96.getLiquidityForAmounts(_sqrtPriceAX96, _sqrtPriceBX96, uint128(_amount0), uint128(_amount1));

        params[0] = abi.encode(key, minTick, maxTick, liquidity, _amount0, _amount1, 0xdead, bytes(""));

        params[1] = abi.encode(key.currency0, key.currency1);

        uint256 deadline = block.timestamp + 60;

        uint256 valueToPass = key.currency0.isAddressZero() ? _amount0 : 0;

        _positionManager.modifyLiquidities{value: valueToPass}(abi.encode(actions, params), deadline);

        emit InitialLiquidityAdded(_owner, _amount0, _amount1);
    }

    function getPoolKey(address _owner) external view returns (PoolKey memory) {
        return poolKeys[_owner];
    }
}
