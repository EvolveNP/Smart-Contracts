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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Helper} from "./libraries/Helper.sol";

contract Factory is Ownable {
    using LiquidityAmounts for uint160;

    /**
     * Errors
     */
    error ZeroAddress();
    error VaultAlreadyExists();
    error FundraisingVaultNotCreated();
    error PoolAlreadyExists();
    error InvalidPairToken();
    error ZeroAmount();

    struct FundRaisingAddresses {
        address fundraisingToken; // The address of the fundraising token
        address underlyingAddress; // The address of the underlying token (e.g., USDC, ETH)
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address owner; // the non profit org wallet address
        bool isLPCreated; // whether the lp is created or not
        uint160 sqrtPriceX96;
    }

    uint256 public constant totalSupply = 1e9; // the total supply of fundraising token
    address public immutable registryAddress; // The address of chainlink automation registry address
    mapping(address => FundRaisingAddresses) public fundraisingAddresses; // non profit org wallet address => FundRaisingAddresses

    // uniswap constants
    mapping(address => PoolKey) public poolKeys; // lp address => pool key:  store pool keys for easy access
    address public immutable router; // The address of the uniswap universal router
    address public immutable permit2; // The address of the uniswap permit2 contract
    uint24 public constant defaultFee = 3000; // default fee tier for the pool
    int24 public constant defaultTickSpacing = 60; // default tick spacing for the pool
    address public immutable poolManager; // The address of the uniswap v4 pool manager
    address public immutable positionManager; // The address of the uniswap v4 position manager

    event FundraisingVaultCreated(
        address fundraisingToken, address treasuryWallet, address donationWallet, address owner
    );
    event LiquidityPoolCreated(address currency0, address currency1, address owner);
    event InitialLiquidityAdded(address owner, uint256 amount0, uint256 amount1);

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
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
     * @param _underlyingAddress The address of the underlying token (e.g., USDC, ETH). If address(0), defaults to 18 decimals
     * @param _owner The address of the owner who receives the donation
     * @dev only called by owner
     */
    function createFundraisingVault(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        address _underlyingAddress,
        address _owner
    ) external nonZeroAddress(_owner) nonZeroAddress(_underlyingAddress) onlyOwner {
        if (fundraisingAddresses[_owner].fundraisingToken != address(0)) revert VaultAlreadyExists();
        // deploy donation wallet
        DonationWallet donationWallet =
            new DonationWallet(address(this), _owner, router, poolManager, permit2, positionManager);

        // deploy treasury wallet
        TreasuryWallet treasuryWallet = new TreasuryWallet(
            address(donationWallet), address(this), registryAddress, router, poolManager, permit2, positionManager
        );
        uint8 _decimals = 18;
        if (_underlyingAddress != address(0)) {
            // set the decimals of the fundraising token same as underlying token
            _decimals = IERC20Metadata(_underlyingAddress).decimals();
        }

        // Deploy fundraising token
        FundRaisingToken fundraisingToken = new FundRaisingToken(
            _tokenName,
            _tokenSymbol,
            _decimals,
            owner(),
            address(treasuryWallet),
            address(donationWallet),
            address(this),
            totalSupply * 10 ** _decimals
        );

        // set fundraising token in donation wallet
        donationWallet.setFundraisingTokenAddress(address(fundraisingToken));

        // set fundraising token in treasury wallet

        treasuryWallet.setFundraisingToken(address(fundraisingToken));

        fundraisingAddresses[_owner] = FundRaisingAddresses(
            address(fundraisingToken),
            _underlyingAddress,
            address(treasuryWallet),
            address(donationWallet),
            _owner,
            false,
            0
        );

        emit FundraisingVaultCreated(
            address(fundraisingToken), address(donationWallet), address(treasuryWallet), _owner
        );
    }

    /**
     * @notice Creates a Uniswap V4 pool for the fundraising token and another currency
     * @param _owner The owner of the pool manager
     * @param _sqrtPriceX96 The initial price
     * @dev Only callable by the owner of the factory contract
     * @dev _sqrtPriceX96 calculated as floor(sqrt(token0/token1) * 2^96)
     */
    function createPool(address _owner, uint160 _sqrtPriceX96)
        external
        nonZeroAddress(_owner)
        nonZeroAmount(_sqrtPriceX96)
        onlyOwner
    {
        FundRaisingAddresses storage _fundraisingAddresses = fundraisingAddresses[_owner];
        if (_fundraisingAddresses.fundraisingToken == address(0) || _fundraisingAddresses.treasuryWallet == address(0))
        {
            revert FundraisingVaultNotCreated();
        }
        if (_fundraisingAddresses.isLPCreated) revert PoolAlreadyExists();

        // wrap currencies
        Currency currency0 = Currency.wrap(_fundraisingAddresses.underlyingAddress);
        Currency currency1 = Currency.wrap(_fundraisingAddresses.fundraisingToken);

        // ensure currency0 < currency1 by address value
        if (currency0 > currency1) {
            (currency0, currency1) = (currency1, currency0);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 0,
            tickSpacing: defaultTickSpacing,
            hooks: IHooks(address(0)) // currently we don't use hooks
        });

        IPoolManager _poolManager = IPoolManager(poolManager);

        _poolManager.initialize(poolKey, _sqrtPriceX96);

        _fundraisingAddresses.isLPCreated = true;
        _fundraisingAddresses.sqrtPriceX96 = _sqrtPriceX96;

        // store pool key for easy access
        poolKeys[_owner] = poolKey;

        emit LiquidityPoolCreated(
            _fundraisingAddresses.underlyingAddress, _fundraisingAddresses.fundraisingToken, _owner
        );
    }

    /**
     *
     * @param _amount0 The amount of currency0 to add as initial liquidity
     * @param _amount1 The amount of currency1 to add as initial liquidity
     * @param _owner The owner of the pool manager
     * @dev Only callable by the owner of the factory contract
     */
    function addLiquidity(uint256 _amount0, uint256 _amount1, address _owner)
        external
        payable
        nonZeroAmount(_amount0)
        nonZeroAmount(_amount1)
        onlyOwner
    {
        IPositionManager _positionManager = IPositionManager(positionManager);

        PoolKey memory key = poolKeys[_owner];

        bytes memory actions;
        bytes[] memory params;
        address _currency0 = Currency.unwrap(key.currency0);
        address _currency1 = Currency.unwrap(key.currency1);

        if (_currency0 == address(0)) {
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
            params = new bytes[](2);
        } else {
            // For ETH liquidity positions
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
            params = new bytes[](3);

            params[2] = abi.encode(address(0), owner()); // only for ETH liquidity positions
        }

        uint160 _sqrtPriceX96 = fundraisingAddresses[_owner].sqrtPriceX96;

        (int24 tickLower, int24 tickUpper) = Helper.getMinAndMaxTick(_sqrtPriceX96, defaultTickSpacing);

        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        uint128 _liquidity =
            LiquidityAmounts.getLiquidityForAmounts(_sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, _amount0, _amount1);

        params[0] = abi.encode(key, tickLower, tickUpper, _liquidity, _amount0, _amount1, _owner, bytes(""));

        params[1] = abi.encode(key.currency0, key.currency1);

        uint256 deadline = block.timestamp + 1000;

        uint256 valueToPass = key.currency0.isAddressZero() ? _amount0 : 0;

        // approve position manager to spend tokens on behalf of this contract

        if (!key.currency0.isAddressZero()) {
            IERC20(_currency0).approve(address(permit2), _amount0);
            IPermit2(permit2).approve(_currency0, positionManager, uint160(_amount0), uint48(deadline));
        }

        IERC20(_currency1).approve(address(permit2), _amount1);

        IPermit2(permit2).approve(_currency1, positionManager, uint160(_amount1), uint48(deadline));

        _positionManager.modifyLiquidities{value: valueToPass}(abi.encode(actions, params), deadline);

        emit InitialLiquidityAdded(_owner, _amount0, _amount1);
    }

    function getPoolKey(address _owner) external view returns (PoolKey memory) {
        return poolKeys[_owner];
    }
}
