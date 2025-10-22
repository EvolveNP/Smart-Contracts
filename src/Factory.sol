// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FundRaisingToken} from "./FundRaisingToken.sol";
import {TreasuryWallet} from "./TreasuryWallet.sol";
import {DonationWallet} from "./DonationWallet.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Helper} from "./libraries/Helper.sol";
import {FundraisingTokenHook} from "./Hook.sol";
import {IPoolInitializer_v4} from "@uniswap/v4-periphery/src/interfaces/IPoolInitializer_v4.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

/**
 * @title Factory Contract
 * @notice This contract serves as a factory for deploying and managing other contracts.
 * @dev Inherits from Ownable2StepUpgradeable to provide two-step ownership transfer functionality.
 * @custom:netspec The Factory contract enables the creation and management of contract instances, with secure ownership transfer mechanisms.
 */
contract Factory is Ownable2StepUpgradeable {
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
    error NotAdmin();
    error EmergencyPauseAlreadySet();
    error InvalidAmount0();

    struct FundRaisingAddresses {
        address fundraisingToken; // The address of the fundraising token
        address underlyingAddress; // The address of the underlying token (e.g., USDC, ETH)
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address hook; // The address of the hook
        address owner; // the non profit org wallet address
        bool isLPCreated; // whether the lp is created or not
        uint160 sqrtPriceX96;
    }

    uint256 public constant totalSupply = 1e9; // the total supply of fundraising token
    address public registryAddress; // The address of chainlink automation registry address
    mapping(address => FundRaisingAddresses) public fundraisingAddresses; // non profit org wallet address => FundRaisingAddresses

    // uniswap constants
    mapping(address => PoolKey) public poolKeys; // lp address => pool key:  store pool keys for easy access
    address public router; // The address of the uniswap universal router
    address public permit2; // The address of the uniswap permit2 contract
    int24 public constant defaultTickSpacing = 60; // default tick spacing for the pool
    address public poolManager; // The address of the uniswap v4 pool manager
    address public positionManager; // The address of the uniswap v4 position manager
    address public quoter; // Ther address of the uniswap v4 quoter
    address public treasuryWalletBeacon; // treasury wallet beacon
    address public donationWalletBeacon; // donatation wallet beacon
    bool public pauseAll; // pause all functionalities for all available vaults
    address admin; // The address of the admin that is used to call some functions via multisig

    /**
     *  @notice Emitted when a new fundraising vault is created.
     * @dev Contains the fundraising token, treasury wallet, donation wallet, and owner addresses.
     * @param fundraisingToken The address of the fundraising token.
     * @param treasuryWallet The address of the treasury wallet.
     * @param donationWallet The address of the donation wallet.
     * @param owner The address of the owner.
     */
    event FundraisingVaultCreated(
        address fundraisingToken, address treasuryWallet, address donationWallet, address owner
    );
    /**
     *  @notice Emitted when a new liquidity pool is created.
     * @dev Contains the currency addresses and owner.
     * @param currency0 The address of the first currency.
     * @param currency1 The address of the second currency.
     * @param owner The address of the owner.
     */
    event LiquidityPoolCreated(address currency0, address currency1, address owner);

    /**
     * @notice Emitted when the treasury wallet is paused or unpaused in an emergency.
     * @dev Contains the owner address, treasury wallet, and pause status.
     * @param owner The address of the owner.
     * @param treasuryWallet The address of the treasury wallet.
     * @param puase The pause status (true if paused, false otherwise).
     */
    event TreasuryEmergencyPause(address owner, address treasuryWallet, bool puase);
    /**
     * @notice Emitted when the donation wallet pause status is set in an emergency.
     * @dev Contains the owner address, donation wallet, and pause status.
     * @param owner The address of the owner.
     * @param donationWallet The address of the donation wallet.
     * @param pause The pause status (true if paused, false otherwise).
     */
    event DonationEmergencyPauseSet(address owner, address donationWallet, bool pause);

    event EmergencyPauseSet(bool pause);

    event AdminChanged(address oldAdmin, address newAdmin);

    /**
     * @notice Ensures that the provided address is not the zero address.
     * @dev Reverts with `ZeroAddress()` if `_address` is the zero address.
     * @param _address The address to validate.
     * @custom:netmod This modifier should be used to prevent zero address assignments in contract logic.
     */
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    /**
     *  @notice Ensures that the provided amount is not zero.
     * @dev Reverts with ZeroAmount() if `_amount` is zero.
     * @param _amount The amount to check for non-zero value.
     * @custom:netmod Guarantees that the function using this modifier will not execute with a zero amount.
     */
    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    modifier onlyAdmin() {
        if (admin != msg.sender) revert NotAdmin();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     *
     * @param _registryAddress The address of chainlink automation registry address
     * @param _poolManager The address of the uniswap v4 pool manager
     * @param _positionManager The address of the uniswap v4 position manager
     * @param _router The address of the uniswap universal router
     * @param _permit2 The address of the uniswap permit2 contract
     */
    function initialize(
        address _registryAddress,
        address _poolManager,
        address _positionManager,
        address _router,
        address _permit2,
        address _quoter,
        address _admin
    )
        external
        initializer
        nonZeroAddress(_registryAddress)
        nonZeroAddress(_poolManager)
        nonZeroAddress(_positionManager)
        nonZeroAddress(_router)
        nonZeroAddress(_permit2)
        nonZeroAddress(_quoter)
        nonZeroAddress(_admin)
    {
        __Ownable_init(msg.sender);
        __Ownable2Step_init();
        registryAddress = _registryAddress;
        poolManager = _poolManager;
        positionManager = _positionManager;
        router = _router;
        permit2 = _permit2;
        // deploy treasury wallet beacon
        address treasuryImplementation = address(new TreasuryWallet());
        treasuryWalletBeacon = address(new UpgradeableBeacon(treasuryImplementation, msg.sender));
        // deploy donation wallet beacon
        address donationWalletImplementation = address(new DonationWallet());
        donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));
        admin = _admin;
        quoter = _quoter;
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
        address _owner,
        uint256 _taxFee,
        uint256 _maximumThreshold,
        uint256 _minimumHealthThreshhold,
        uint256 _transferInterval,
        uint256 _minLPHealthThreshhold,
        int24 _tickSpacing
    ) external nonZeroAddress(_owner) nonZeroAddress(_underlyingAddress) onlyOwner {
        if (fundraisingAddresses[_owner].fundraisingToken != address(0)) {
            revert VaultAlreadyExists();
        }
        // deploy donation wallet
        DonationWallet donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));

        // deploy treasury wallet
        TreasuryWallet treasuryWallet = TreasuryWallet(address(new BeaconProxy(treasuryWalletBeacon, "")));

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
            totalSupply * 10 ** _decimals,
            _taxFee,
            _maximumThreshold
        );

        donationWallet.initialize(
            address(this), _owner, router, poolManager, permit2, positionManager, quoter, address(fundraisingToken)
        );

        treasuryWallet.initialize(
            address(donationWallet),
            address(this),
            registryAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            _minimumHealthThreshhold,
            _transferInterval,
            _minLPHealthThreshhold,
            _tickSpacing,
            address(fundraisingToken)
        );

        fundraisingAddresses[_owner] = FundRaisingAddresses(
            address(fundraisingToken),
            _underlyingAddress,
            address(treasuryWallet),
            address(donationWallet),
            address(0),
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
     * @param _amount0 The price of currency 0 (underlying asset)
     * @param _amount1 The price of the currency 1 (fundraising token)
     * @dev Only callable by the owner of the factory contract
     * @dev _sqrtPriceX96 calculated as floor(sqrt(token0/token1) * 2^96)
     */
    function createPool(address _owner, uint256 _amount0, uint256 _amount1)
        external
        payable
        nonZeroAddress(_owner)
        nonZeroAmount(_amount0)
        nonZeroAmount(_amount1)
        onlyOwner
    {
        IPositionManager _positionManager = IPositionManager(positionManager);

        bytes[] memory params = new bytes[](2);

        FundRaisingAddresses storage _fundraisingAddresses = fundraisingAddresses[_owner];
        if (_fundraisingAddresses.fundraisingToken == address(0) || _fundraisingAddresses.treasuryWallet == address(0))
        {
            revert FundraisingVaultNotCreated();
        }
        if (_fundraisingAddresses.isLPCreated) revert PoolAlreadyExists();

        address _currency0 = _fundraisingAddresses.underlyingAddress;
        address _currency1 = _fundraisingAddresses.fundraisingToken;

        if (_currency0 != address(0)) {
            IERC20(_currency0).transferFrom(msg.sender, address(this), _amount0);
        } else {
            if (_amount0 != msg.value) revert InvalidAmount0();
        }

        IERC20(_currency1).transferFrom(msg.sender, address(this), _amount1);

        if (_currency0 > _currency1) {
            (_currency0, _currency1) = (_currency1, _currency0);
            (_amount0, _amount1) = (_amount1, _amount0);
        }

        uint160 _startingPrice = Helper.encodeSqrtPriceX96(_amount1, _amount0);
        // wrap currencies
        Currency currency0 = Currency.wrap(_currency0);
        Currency currency1 = Currency.wrap(_currency1);

        // deploy hook
        IHooks hook = deployHook(_fundraisingAddresses.fundraisingToken);

        // transfer assets to this contract;

        PoolKey memory pool =
            PoolKey({currency0: currency0, currency1: currency1, fee: 0, tickSpacing: defaultTickSpacing, hooks: hook});

        params[0] = abi.encodeWithSelector(IPoolInitializer_v4.initializePool.selector, pool, _startingPrice);
        params[1] = getModifyLiqiuidityParams(pool, _amount0, _amount1, _startingPrice);

        uint256 deadline = block.timestamp + 1000;
        uint256 valueToPass = pool.currency0.isAddressZero() ? _amount0 : pool.currency1.isAddressZero() ? _amount1 : 0;

        if (!pool.currency0.isAddressZero()) {
            IERC20(_currency0).approve(address(permit2), _amount0);
            IPermit2(permit2).approve(_currency0, positionManager, uint160(_amount0), uint48(deadline));
        }

        if (!pool.currency1.isAddressZero()) {
            IERC20(_currency1).approve(address(permit2), _amount1);
            IPermit2(permit2).approve(_currency1, positionManager, uint160(_amount1), uint48(deadline));
        }

        _fundraisingAddresses.isLPCreated = true;
        _fundraisingAddresses.sqrtPriceX96 = _startingPrice;
        _fundraisingAddresses.hook = address(hook);

        // store pool key for easy access
        poolKeys[_owner] = pool;

        _positionManager.multicall{value: valueToPass}(params);

        emit LiquidityPoolCreated(
            _fundraisingAddresses.underlyingAddress, _fundraisingAddresses.fundraisingToken, _owner
        );
    }

    /**
     * @notice Sets the emergency pause state for the treasury wallet of a specific non-profit organization.
     * @param _nonProfitOrgOwner The address of the non-profit organization owner whose treasury wallet will be paused or unpaused.
     * @param _pause Boolean indicating whether to pause (true) or unpause (false) the treasury wallet.
     * @dev Only callable by the owner.
     */
    function setTreasuryEmergencyPause(address _nonProfitOrgOwner, bool _pause)
        external
        onlyOwner
        nonZeroAddress(_nonProfitOrgOwner)
    {
        TreasuryWallet treasury = TreasuryWallet(fundraisingAddresses[_nonProfitOrgOwner].treasuryWallet);
        treasury.emergencyPause(_pause);
        emit TreasuryEmergencyPause(_nonProfitOrgOwner, address(treasury), _pause);
    }

    /**
     * @notice Sets the emergency pause state for a donation wallet.
     * @param _nonProfitOrgOwner The address of the non-profit organization owner whose donation wallet will be paused or unpaused.
     * @param _pause Boolean indicating whether to pause (true) or unpause (false) donations.
     * @dev Only callable by the owner.
     */
    function setDonationEmergencyPause(address _nonProfitOrgOwner, bool _pause)
        external
        onlyOwner
        nonZeroAddress(_nonProfitOrgOwner)
    {
        DonationWallet donation = DonationWallet(fundraisingAddresses[_nonProfitOrgOwner].donationWallet);
        donation.emergencyPause(_pause);
        emit DonationEmergencyPauseSet(_nonProfitOrgOwner, address(donation), _pause);
    }

    /**
     * @notice Enable or disable emergency pause across all treasury and donations wallet
     * @param _pause true if to enable emergency pause across all treasury and donations wallet or false
     * @dev Only called by the admin
     */
    function setEmergencyPause(bool _pause) external onlyAdmin {
        if (pauseAll == _pause) revert EmergencyPauseAlreadySet();
        pauseAll = _pause;

        emit EmergencyPauseSet(_pause);
    }

    /**
     * @notice Set new admin address
     * @param _newAdmin The address of the admin
     * @dev Only called by the owner
     */
    function setAdmin(address _newAdmin) external onlyOwner {
        emit AdminChanged(admin, _newAdmin);
        admin = _newAdmin;
    }

    /**
     * @notice Returns the balance of the fundraising token held by the pool manager.
     * @dev Calls the `balanceOf` function of the ERC20 token at the specified address.
     * @param _fundraisingTokenAddress The address of the ERC20 fundraising token contract.
     * @return The token balance of the pool manager.
     * @custom:netspec Returns the current balance of the fundraising token for the pool manager.
     */
    function getFundraisingTokenBalance(address _fundraisingTokenAddress) external view returns (uint256) {
        return IERC20Metadata(_fundraisingTokenAddress).balanceOf(poolManager);
    }

    /**
     * @notice Returns the sqrtPriceX96 value associated with the specified owner address.
     * @dev Retrieves the uint160 sqrtPriceX96 from the fundraisingAddresses mapping for the given owner.
     * @param _owner The address of the owner whose sqrtPriceX96 value is to be fetched.
     * @return The sqrtPriceX96 value (uint160) for the specified owner.
     * @custom:netspec Returns fundraisingAddresses[_owner].sqrtPriceX96.
     */
    function getSqrtPriceX96(address _owner) external view returns (uint160) {
        return fundraisingAddresses[_owner].sqrtPriceX96;
    }

    /**
     * @notice Generates the parameters for adding initial liquidity to a Uniswap V4 pool.
     * @dev Prepares the actions and parameters required for the IPositionManager.modifyLiquidities call.
     * @param key The PoolKey struct representing the pool.
     * @param _amount0 The amount of currency0 to add as liquidity.
     * @param _amount1 The amount of currency1 to add as liquidity.
     * @param _startingPrice The initial sqrtPriceX96 for the pool.
     * @return Encoded bytes for the modifyLiquidities multicall.
     * @custom:netspec Returns encoded parameters for IPositionManager.modifyLiquidities to add initial liquidity to the pool.
     */
    function getModifyLiqiuidityParams(PoolKey memory key, uint256 _amount0, uint256 _amount1, uint160 _startingPrice)
        internal
        view
        returns (bytes memory)
    {
        bytes memory actions;
        bytes[] memory params;
        address _currency0 = Currency.unwrap(key.currency0);
        address _currency1 = Currency.unwrap(key.currency1);

        bool isETHPair = ((_currency0 == address(0)) || (_currency1 == address(0)));

        if (isETHPair) {
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
            params = new bytes[](2);
        } else {
            // For ETH liquidity positions
            actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
            params = new bytes[](3);

            params[2] = abi.encode(address(0), owner()); // only for ETH liquidity positions
        }

        (int24 tickLower, int24 tickUpper) = Helper.getMinAndMaxTick(_startingPrice, defaultTickSpacing);

        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        uint128 _liquidity =
            LiquidityAmounts.getLiquidityForAmounts(_startingPrice, sqrtPriceAX96, sqrtPriceBX96, _amount0, _amount1);

        params[0] = abi.encode(key, tickLower, tickUpper, _liquidity, _amount0, _amount1, 0xdead, bytes(""));

        params[1] = abi.encode(key.currency0, key.currency1);

        uint256 deadline = block.timestamp + 1000;

        return
            abi.encodeWithSelector(IPositionManager.modifyLiquidities.selector, abi.encode(actions, params), deadline);
    }

    function deployHook(address _fundraisingToken) internal returns (IHooks) {
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, _fundraisingToken);
        (, bytes32 salt) =
            HookMiner.find(address(this), flags, type(FundraisingTokenHook).creationCode, constructorArgs);

        IHooks hook = new FundraisingTokenHook{salt: salt}(poolManager, _fundraisingToken);

        return hook;
    }

    /**
     * @notice Returns the PoolKey associated with a given owner address.
     * @dev Retrieves the PoolKey struct from the mapping using the provided owner address.
     * @param _owner The address of the pool owner whose PoolKey is to be retrieved.
     * @return The PoolKey struct corresponding to the specified owner address.
     */
    function getPoolKey(address _owner) external view returns (PoolKey memory) {
        return poolKeys[_owner];
    }
}
