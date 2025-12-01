// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
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
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolInitializer_v4} from "@uniswap/v4-periphery/src/interfaces/IPoolInitializer_v4.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {FundRaisingToken} from "./FundRaisingToken.sol";
import {TreasuryWallet} from "./TreasuryWallet.sol";
import {DonationWallet} from "./DonationWallet.sol";
import {Helper} from "./libraries/Helper.sol";
import {FundraisingTokenHook} from "./Hook.sol";

/**
 * @title Factory Contract
 * @notice This contract serves as a factory for deploying and managing fundraising vaults and liquidity pools for non-profit organizations.
 * @dev Inherits from Ownable2StepUpgradeable for secure ownership transfer.
 *      Manages deployment of DonationWallet, TreasuryWallet, and FundRaisingToken contracts,
 *      handles pool creation on Uniswap V4, emergency pause features, and registry management.
 */
contract Factory is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
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
    error InvlidLPHealthThreshold();
    error OnlyCalledByNonProfitOrg();
    error ProtocolNotAvailable();
    error RegistryAlreadySet();
    error NotProtocolOwner();
    error DestinationAlreadyOccupied();

    struct FundraisingProtocol {
        address fundraisingToken; // The address of the fundraising token
        address underlyingAddress; // The address of the underlying token (e.g., USDC, ETH)
        address treasuryWallet; // the address of the treasury wallet
        address donationWallet; // the address of the donation wallet
        address hook; // The address of the hook
        address owner; // the non profit org wallet address
        bool isLPCreated; // whether the lp is created or not
    }

    uint256 public constant totalSupply = 1e9; // the total supply of fundraising token

    /**
     * @notice Mapping storing fundraising protocol details by non-profit owner address.
     * @dev Contains fundraising token, wallets, hook, owner, and LP creation state.
     */
    mapping(address => FundraisingProtocol) public protocols;

    /**
     * @notice Mapping storing Uniswap pool keys by owner.
     * @dev Used to quickly access pool details for a given non-profit owner.
     */
    mapping(address => PoolKey) internal poolKeys;

    address public router; // The address of the uniswap universal router
    address public permit2; // The address of the uniswap permit2 contract
    int24 public constant defaultTickSpacing = 60; // default tick spacing for the pool
    address public poolManager; // The address of the uniswap v4 pool manager
    address public positionManager; // The address of the uniswap v4 position manager
    address public stateView; // The address of the uniswap v4 state view
    address public quoter; // Ther address of the uniswap v4 quoter
    address public treasuryWalletBeacon; // treasury wallet beacon
    address public donationWalletBeacon; // donatation wallet beacon
    bool public pauseAll; // pause all functionalities for all available vaults
    address public admin; // The address of the admin that is used to call some functions via multisig

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
    event TreasuryEmergencyPauseSet(address owner, address treasuryWallet, bool puase);
    /**
     * @notice Emitted when the donation wallet pause status is set in an emergency.
     * @dev Contains the owner address, donation wallet, and pause status.
     * @param owner The address of the owner.
     * @param donationWallet The address of the donation wallet.
     * @param pause The pause status (true if paused, false otherwise).
     */
    event DonationEmergencyPauseSet(address owner, address donationWallet, bool pause);

    /**
     * @notice Emitted when emergency pause state is toggled for all treasury and donation wallets in the protocol.
     * @param pause The new global pause state (`true` if paused, `false` if unpaused).
     */
    event AllTreasuriesPaused(bool pause);

    /**
     * @notice Emitted when an emergency withdrawal is performed from a treasury wallet.
     * @param treasuryWallet The treasury wallet address from which funds were withdrawn.
     * @param owner The nonprofit organization owner who initiated the emergency withdrawal.
     * @param amount The amount of funds withdrawn in the emergency.
     */
    event EmergencyWithdrawn(address treasuryWallet, address owner, uint256 amount);

    /**
     * @notice Emitted when the registry contract address is updated for a specific treasury wallet.
     * @param treasuryWallet The treasury wallet contract address whose registry was updated.
     * @param registryAddress The new registry contract address set for the treasury wallet.
     */
    event RegistryAddressForTreasurySet(address treasuryWallet, address registryAddress);

    /**
     * @notice Emitted when the registry contract address is updated for a specific donation wallet.
     * @param donationWallet The donation wallet contract address whose registry was updated.
     * @param registryAddress The new registry contract address set for the donation wallet.
     */
    event RegistryAddressForDonationSet(address donationWallet, address registryAddress);

    event ProtocolOwnerChanged(address oldNonProfitOrgAddress, address newNonProfitOrgAddress);

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

    /**
     * @notice Modifier restricting access to admin-only functions.
     * @dev Reverts if the caller is not the configured admin address.
     */
    modifier onlyAdmin() {
        if (admin != msg.sender) revert NotAdmin();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the necessary Uniswap and protocol addresses.
     * @dev This function can only be called once due to the `initializer` modifier.
     *      All provided addresses must be non-zero.
     *      Sets the contract owner as the deployer (`msg.sender`).
     *
     * @param _poolManager The address of the Uniswap V4 pool manager contract.
     * @param _positionManager The address of the Uniswap V4 position manager contract.
     * @param _router The address of the Uniswap universal router contract.
     * @param _permit2 The address of the Uniswap Permit2 contract for token approvals.
     * @param _quoter The address of the Uniswap quoter contract for price queries.
     * @param _admin The address of the admin with special permissions in this protocol.
     * @param _treasuryWalletBeacon The beacon address for deploying TreasuryWallet proxies.
     * @param _donationWalletBeacon The beacon address for deploying DonationWallet proxies.
     * @param _stateView The address of the state view contract used for protocol state queries.
     */
    function initialize(
        address _poolManager,
        address _positionManager,
        address _router,
        address _permit2,
        address _quoter,
        address _admin,
        address _treasuryWalletBeacon,
        address _donationWalletBeacon,
        address _stateView
    )
        external
        initializer
        nonZeroAddress(_poolManager)
        nonZeroAddress(_positionManager)
        nonZeroAddress(_router)
        nonZeroAddress(_permit2)
        nonZeroAddress(_quoter)
        nonZeroAddress(_admin)
        nonZeroAddress(_treasuryWalletBeacon)
        nonZeroAddress(_donationWalletBeacon)
        nonZeroAddress(_stateView)
    {
        __Ownable_init(msg.sender);
        poolManager = _poolManager;
        positionManager = _positionManager;
        router = _router;
        permit2 = _permit2;
        treasuryWalletBeacon = _treasuryWalletBeacon;
        donationWalletBeacon = _donationWalletBeacon;
        admin = _admin;
        quoter = _quoter;
        stateView = _stateView;
    }

    /**
     * @notice Deploys and initializes contracts for a specific non-profit organization's fundraising vault.
     * @dev Can only be called by the contract owner.
     *      Reverts if a vault already exists for the given owner.
     *      Deploys new instances of DonationWallet and TreasuryWallet via beacon proxies.
     *      Creates a new fundraising token with decimals matching the underlying token if provided.
     *      Initializes the deployed wallets with relevant protocol parameters.
     *      Registers the deployed contracts in the `protocols` mapping.
     *
     * @param _tokenName The name of the fundraising token to be deployed.
     * @param _tokenSymbol The symbol of the fundraising token to be deployed.
     * @param _underlyingAddress The address of the underlying ERC20 token (e.g., USDC, ETH).
     *                           If `address(0)`, defaults to 18 decimals for the fundraising token.
     * @param _owner The address of the non-profit organization owner who will receive donations and own the vault.
     *
     * @custom:security Only the contract owner can call this function to prevent unauthorized vault creation.
     *                  Ensure `_owner` is a trusted entity to avoid misconfiguration.
     *
     * @custom:event Emits a {FundraisingVaultCreated} event with the addresses of the deployed fundraising token,
     *               donation wallet, treasury wallet, and the owner.
     */
    function createFundraisingVault(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        address _underlyingAddress,
        address _owner
    ) external nonZeroAddress(_owner) onlyOwner {
        if (protocols[_owner].fundraisingToken != address(0)) {
            revert VaultAlreadyExists();
        }
        // deploy donation wallet
        DonationWallet donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));

        // deploy treasury wallet
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(address(new BeaconProxy(treasuryWalletBeacon, ""))));

        uint8 _decimals = 18;
        if (_underlyingAddress != address(0)) {
            // set the decimals of the fundraising token same as underlying token
            _decimals = IERC20Metadata(_underlyingAddress).decimals();
        }

        // Deploy fundraising token
        FundRaisingToken fundraisingToken = new FundRaisingToken(
            _tokenName, _tokenSymbol, _decimals, owner(), address(treasuryWallet), totalSupply * 10 ** _decimals
        );

        donationWallet.initialize(
            address(this), _owner, router, poolManager, permit2, positionManager, quoter, address(fundraisingToken)
        );

        treasuryWallet.initialize(
            address(donationWallet),
            address(this),
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            defaultTickSpacing,
            address(fundraisingToken),
            stateView
        );

        protocols[_owner] = FundraisingProtocol(
            address(fundraisingToken),
            _underlyingAddress,
            address(treasuryWallet),
            address(donationWallet),
            address(0),
            _owner,
            false
        );

        emit FundraisingVaultCreated(
            address(fundraisingToken), address(donationWallet), address(treasuryWallet), _owner
        );
    }

    /**
     * @notice Creates a Uniswap V4 liquidity pool for a fundraising token and an underlying asset.
     * @dev Only callable by the factory contract owner.
     *      - Handles ERC20 or native asset transfers, pool initialization, liquidity provisioning,
     *        and deployment of a custom hook for swap-based donation processing.
     *      - Requires that the fundraising protocol is already registered for `_owner`.
     *      - Reverts if the fundraising vault or treasury wallet is missing,
     *        or if a liquidity pool for the owner has already been created.
     *      - The `_sqrtPriceX96` value is derived using Uniswap's Q96 price encoding formula
     *        via `encodeSqrtPriceX96(amount1, amount0)`.
     *
     * @param _owner The address representing the non-profit organization owner.
     * @param _amount0 The liquidity amount for token0 (can be native ETH if `address(0)` is underlying).
     * @param _amount1 The liquidity amount for token1 (fundraising token).
     * @param _salt The deterministic CREATE2 salt for deploying the FundraisingTokenHook,
     *             typically obtained from a `findSalt` helper function.
     *
     * @custom:security Caller must ensure:
     *                  - ERC20 approvals are granted to this contract for both tokens.
     *                  - Sufficient balances are available.
     *                  - The salt is pre-mined for a valid hook deployment address
     *                    compatible with Uniswap V4 hook flag requirements.
     *
     * @custom:effects
     *      - Transfers liquidity assets into the contract.
     *      - Deploys hook using CREATE2 for deterministic pool addressing.
     *      - Initializes the pool and mints initial liquidity.
     *      - Marks protocol as LP-created and stores hook and pool metadata.
     *
     * @custom:event Emits {LiquidityPoolCreated} with underlying token, fundraising token, and owner.
     */

    function createPool(address _owner, uint256 _amount0, uint256 _amount1, bytes32 _salt)
        external
        payable
        nonZeroAddress(_owner)
        nonZeroAmount(_amount0)
        nonZeroAmount(_amount1)
        onlyOwner
    {
        IPositionManager _positionManager = IPositionManager(positionManager);

        bytes[] memory params = new bytes[](2);

        FundraisingProtocol storage _protocol = protocols[_owner];
        if (_protocol.fundraisingToken == address(0) || _protocol.treasuryWallet == address(0)) {
            revert FundraisingVaultNotCreated();
        }
        if (_protocol.isLPCreated) revert PoolAlreadyExists();

        address _currency0 = _protocol.underlyingAddress;
        address _currency1 = _protocol.fundraisingToken;
        uint256 amount0 = _amount0;
        uint256 amount1 = _amount1;

        if (_currency0 != address(0)) {
            IERC20(_currency0).safeTransferFrom(msg.sender, address(this), amount0);
        } else {
            if (amount0 != msg.value) revert InvalidAmount0();
        }

        IERC20(_currency1).safeTransferFrom(msg.sender, address(this), amount1);

        if (_currency0 > _currency1) {
            (_currency0, _currency1) = (_currency1, _currency0);
            (amount0, amount1) = (amount1, amount0);
        }

        uint160 _startingPrice = Helper.encodeSqrtPriceX96(amount1, amount0);

        // wrap currencies
        Currency currency0 = Currency.wrap(_currency0);
        Currency currency1 = Currency.wrap(_currency1);

        // deploy hook
        IHooks hook = new FundraisingTokenHook{salt: _salt}(
            poolManager, _protocol.fundraisingToken, _protocol.treasuryWallet, _protocol.donationWallet, router, quoter
        );

        // transfer assets to this contract;

        PoolKey memory pool =
            PoolKey({currency0: currency0, currency1: currency1, fee: 0, tickSpacing: defaultTickSpacing, hooks: hook});

        params[0] = abi.encodeWithSelector(IPoolInitializer_v4.initializePool.selector, pool, _startingPrice);
        params[1] = getModifyLiqiuidityParams(pool, amount0, amount1, _startingPrice);

        uint256 deadline = block.timestamp + 1000;

        // Eth is always currency 0 as it is zero address
        uint256 valueToPass = pool.currency0.isAddressZero() ? amount0 : 0;

        // ether is always currency0
        if (!pool.currency0.isAddressZero()) {
            IERC20(_currency0).approve(address(permit2), amount0);
            IPermit2(permit2).approve(_currency0, positionManager, uint160(amount0), uint48(deadline));
        }

        IERC20(_currency1).approve(address(permit2), amount1);
        IPermit2(permit2).approve(_currency1, positionManager, uint160(amount1), uint48(deadline));

        _protocol.isLPCreated = true;
        _protocol.hook = address(hook);

        // store pool key for easy access
        poolKeys[_owner] = pool;

        _positionManager.multicall{value: valueToPass}(params);

        emit LiquidityPoolCreated(_protocol.underlyingAddress, _protocol.fundraisingToken, _owner);
    }

    /**
     * @notice Sets the emergency pause state for the treasury wallet of a specific non-profit organization.
     * @dev Can only be called by the non-profit organization owner.
     *      Reverts if called by anyone other than the protocol owner.
     *
     * @param _nonProfitOrgOwner The address of the non-profit organization owner whose treasury wallet will be paused or unpaused.
     * @param _pause Set to `true` to pause, or `false` to unpause the treasury wallet.
     *
     * @custom:security Only the non-profit organization owner can call this function to prevent unauthorized pause toggling.
     *                  Pausing the treasury wallet may halt critical fund operations.
     *
     * @custom:event Emits a {TreasuryEmergencyPauseSet} event indicating the new pause state for audit and tracking.
     */
    function setTreasuryPaused(address _nonProfitOrgOwner, bool _pause) external nonZeroAddress(_nonProfitOrgOwner) {
        FundraisingProtocol memory protocol = protocols[_nonProfitOrgOwner];
        // only called by non profit org
        if (msg.sender != protocol.owner) revert OnlyCalledByNonProfitOrg();
        TreasuryWallet treasury = TreasuryWallet(payable(protocol.treasuryWallet));
        treasury.emergencyPause(_pause);
        emit TreasuryEmergencyPauseSet(_nonProfitOrgOwner, address(treasury), _pause);
    }

    /**
     * @notice Enables or disables emergency pause across all treasury and donation wallets.
     * @dev Can only be called by the admin.
     *      Reverts if the pause state is already set to the requested value.
     *
     * @param _pause Set to `true` to enable emergency pause, or `false` to disable it.
     *
     * @custom:security Restricted to admin access to prevent unauthorized pausing of funds.
     *                  Pausing halts critical operations across all treasury and donation wallets.
     *
     * @custom:event Emits an {AllTreasuriesPaused} event indicating the new pause state.
     */
    function setAllTreasuriesPaused(bool _pause) external onlyAdmin {
        if (pauseAll == _pause) revert EmergencyPauseAlreadySet();
        pauseAll = _pause;

        emit AllTreasuriesPaused(_pause);
    }

    /**
     * @notice Allows a nonprofit organization to withdraw all available funds from its treasury wallet during an emergency.
     * @dev Can only be called by the nonprofit organization that owns the corresponding fundraising protocol.
     *      Reverts if the caller is not the registered protocol owner.
     *      Delegates the withdrawal logic to the associated `TreasuryWallet` contract,
     *      which must be in a paused state before this call can succeed.
     *
     * @custom:behavior This function triggers a full emergency withdrawal from the treasury wallet
     *                  to the nonprofit organization's address (`msg.sender`).
     *
     * @custom:event Emits an {EmergencyWithdrawn} event upon successful withdrawal,
     *               providing the treasury address, the nonprofit organization address, and the withdrawn amount.
     *
     * @custom:security Only callable by the protocol owner (`msg.sender == protocol.owner`).
     *                  Ensure the treasury is paused before calling to prevent reentrancy or double withdrawal.
     */
    function emergencyWithdraw() external {
        FundraisingProtocol memory protocol = protocols[msg.sender];
        // only called by non profit org
        if (msg.sender != protocol.owner) revert OnlyCalledByNonProfitOrg();

        TreasuryWallet treasury = TreasuryWallet(payable(protocol.treasuryWallet));
        uint256 withdrawnAmount = treasury.emergencyWithdraw(msg.sender);

        emit EmergencyWithdrawn(address(treasury), msg.sender, withdrawnAmount);
    }

    /**
     * @notice Updates the registry contract address for a specific nonprofit organization's treasury wallet.
     * @dev Can only be called by the contract owner.
     *      Reverts if the specified nonprofit organization does not have a registered treasury wallet. or
     *      if the provided registry address is already set in the treasury wallet
     *      The new registry address is forwarded to the corresponding `TreasuryWallet` contract.
     *
     * @param _nonProfitOrg The address of the nonprofit organization whose treasury registry is being updated.
     * @param _registryAddress The new registry contract address to associate with the treasury wallet.
     *
     * @custom:security Only callable by the contract owner to prevent unauthorized registry updates.
     *                  Ensure that `_registryAddress` points to a trusted and verified registry contract.
     *
     * @custom:event Emits a {RegistryAddressForTreasurySet} event after successfully updating the registry.
     */
    function setRegistryForTreasuryWallet(address _nonProfitOrg, address _registryAddress)
        external
        nonZeroAddress(_nonProfitOrg)
        nonZeroAddress(_registryAddress)
        onlyOwner
    {
        FundraisingProtocol memory protocol = protocols[_nonProfitOrg];
        // only called by non profit org
        if (protocol.treasuryWallet == address(0)) revert ProtocolNotAvailable();
        TreasuryWallet treasury = TreasuryWallet(payable(protocol.treasuryWallet));
        if (treasury.registryAddress() == _registryAddress) revert RegistryAlreadySet();
        treasury.setRegistry(_registryAddress);

        emit RegistryAddressForTreasurySet(protocol.treasuryWallet, _registryAddress);
    }

    /**
     * @notice Updates the registry contract address for a specific nonprofit organization's donation wallet.
     * @dev Can only be called by the contract owner.
     *      Reverts if the specified nonprofit organization does not have a registered donation wallet,
     *      or if the provided registry address is already set in the donation wallet.
     *      The new registry address is forwarded to the corresponding `DonationWallet` contract.
     *
     * @param _nonProfitOrg The address of the nonprofit organization whose donation registry is being updated.
     * @param _registryAddress The new registry contract address to associate with the donation wallet.
     *
     * @custom:security Only callable by the contract owner to prevent unauthorized registry changes.
     *                  Ensure `_registryAddress` points to a verified and trusted registry contract.
     *                  Avoid setting an identical registry address to prevent unnecessary state updates.
     *
     * @custom:event Emits a {RegistryAddressForDonationSet} event after successfully updating the registry.
     */
    function setRegistryForDonationWallet(address _nonProfitOrg, address _registryAddress)
        external
        nonZeroAddress(_nonProfitOrg)
        nonZeroAddress(_registryAddress)
        onlyOwner
    {
        FundraisingProtocol memory protocol = protocols[_nonProfitOrg];
        // only called by non profit org
        if (protocol.donationWallet == address(0)) revert ProtocolNotAvailable();
        DonationWallet donation = DonationWallet(payable(protocol.donationWallet));
        if (donation.registryAddress() == _registryAddress) revert RegistryAlreadySet();
        donation.setRegistry(_registryAddress);

        emit RegistryAddressForDonationSet(protocol.donationWallet, _registryAddress);
    }

    /**
     * @notice Transfers ownership of an existing nonprofit protocol to a new nonprofit address.
     *
     * @dev
     * Requirements:
     * - The caller must be the current owner of an existing protocol.
     * - `newNonProfitOrgAddress` must not be the zero address.
     * - `newNonProfitOrgAddress` must not already have a protocol registered.
     * - Updates protocol ownership in storage, including the associated `PoolKey`.
     * - Updates the owner of the linked `DonationWallet` contract.
     * - Emits a {ProtocolOwnerChanged} event on success.
     *
     * Effects:
     * - Removes the protocol and pool key mappings from the old owner address.
     * - Assigns the protocol and pool key to `newNonProfitOrgAddress`.
     * - Sets the protocol's `owner` field to `newNonProfitOrgAddress`.
     * - Calls `changeOwner` on the protocol's donation wallet.
     *
     * Reverts:
     * - {ProtocolNotAvailable} if the caller does not have a protocol registered.
     * - {NotProtocolOwner} if the caller is not the protocol owner.
     * - {DestinationAlreadyOccupied} if the new address already owns a protocol.
     *
     * @param newNonProfitOrgAddress The address to which ownership of the nonprofit protocol is transferred.
     */
    function changeNonProfitOrgOwner(address newNonProfitOrgAddress) external nonZeroAddress(newNonProfitOrgAddress) {
        FundraisingProtocol memory _protocol = protocols[msg.sender];

        if (_protocol.treasuryWallet == address(0)) revert ProtocolNotAvailable();

        if (_protocol.owner != msg.sender) revert NotProtocolOwner();

        if (protocols[newNonProfitOrgAddress].treasuryWallet != address(0)) revert DestinationAlreadyOccupied();

        PoolKey memory _key = poolKeys[msg.sender];

        delete protocols[msg.sender];
        delete poolKeys[msg.sender];

        _protocol.owner = newNonProfitOrgAddress;

        protocols[newNonProfitOrgAddress] = _protocol;
        poolKeys[newNonProfitOrgAddress] = _key;

        DonationWallet(payable(_protocol.donationWallet)).changeOwner(newNonProfitOrgAddress);

        emit ProtocolOwnerChanged(msg.sender, newNonProfitOrgAddress);
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
        if (!isETHPair) {
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

    /**
     * @notice Computes and returns a CREATE2 salt that will produce a valid hook deployment address
     *         matching the required Uniswap V4 hook flag bitmask for a specific non-profit protocol owner.
     *
     * @dev This function performs an off-chain-compatible deterministic salt search using
     *      `HookMiner.find`. It does NOT deploy the hook contract — the returned salt must be supplied to
     *       the deployment function that performs the actual CREATE2 contract creation.
     *
     *      The function reverts if no fundraising protocol has been initialized for the given owner.
     *
     * @param _nonProfitOrgOwner The address of the owner whose fundraising protocol configuration is used
     *                           to build constructor arguments for salt mining.
     *
     * @return salt The computed CREATE2 salt that results in a hook address whose lower bits satisfy
     *              the required Uniswap V4 hook flag constraints.
     */
    function findSalt(address _nonProfitOrgOwner) external view nonZeroAddress(_nonProfitOrgOwner) returns (bytes32) {
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
                | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        FundraisingProtocol memory protocol = protocols[_nonProfitOrgOwner];

        if (protocol.fundraisingToken == address(0)) revert ProtocolNotAvailable();

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(
            poolManager, protocol.fundraisingToken, protocol.treasuryWallet, protocol.donationWallet, router, quoter
        );
        (, bytes32 salt) =
            HookMiner.find(address(this), flags, type(FundraisingTokenHook).creationCode, constructorArgs);
        return salt;
    }
}
