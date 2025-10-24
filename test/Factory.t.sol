// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {Helper} from "../src/libraries/Helper.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FactoryTest is Test {
    Factory public factory;
    address public constant registryAddress = address(0x1);
    address public constant poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public constant positionManager = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant router = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant owner = 0xB3FFde53f0076295f2C183f13b4A07dE288Df61D;
    address public constant nonProfitOrg = address(0x7);
    address public fundraisingTokenAddress;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public constant quoter = 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203;
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint160 public constant sqrtPriceX96 = 79228162514264337593543950336; // 1:1 price ratio
    address treasuryWalletAddress;
    address donationWalletAddress;
    address constant admin = address(0x22);

    string tokenName = "Fundraising Token";
    string tokenSymbol = "FTN";
    uint256 taxFee = 2e16; // 2%
    uint256 maximumThreshold = 30e16; // 30%
    uint256 minimumHealthThreshhold = 5e16; // 7%
    uint256 transferInterval = 30 days;
    uint256 minLPHealthThreshhold = 5e16; // 5%
    int24 tickSpacing = 60;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.startPrank(owner);

        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        factory.initialize(registryAddress, poolManager, positionManager, router, permit2, quoter, admin);

        factory.createFundraisingVault(
            "FundraisingToken",
            "FTN",
            usdc,
            nonProfitOrg,
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );

        (fundraisingTokenAddress,, treasuryWalletAddress, donationWalletAddress,,,,) =
            factory.fundraisingAddresses(nonProfitOrg);
        vm.stopPrank();
    }

    function testInitializeRevertsOnZeroRegistryAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(address(0), poolManager, positionManager, router, permit2, quoter, admin);
    }

    function testInitializeRevertsOnZeroPoolManagerAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, address(0), positionManager, router, permit2, quoter, admin);
    }

    function testInitializeRevertsOnZeroPositionManagerAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, poolManager, address(0), router, permit2, quoter, admin);
    }

    function testInitializeRevertsOnZeroRouterAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, poolManager, positionManager, address(0), permit2, quoter, admin);
    }

    function testInitialzeRevertsOnZeroPermit2Address() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, poolManager, positionManager, router, address(0), quoter, admin);
    }

    function testInitializeRevertsOnZeroQuoterAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, poolManager, positionManager, router, permit2, address(0), admin);
    }

    function testInitializeRevertsOnZeroAdminAddress() public {
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.initialize(registryAddress, poolManager, positionManager, router, permit2, quoter, address(0));
    }

    function testInitializeSetsStateVariables() public view {
        assertEq(factory.registryAddress(), registryAddress);
        assertEq(factory.poolManager(), poolManager);
        assertEq(factory.positionManager(), positionManager);
        assertEq(factory.router(), router);
        assertEq(factory.permit2(), permit2);
    }

    function testOwnerIsSetCorrectly() public view {
        assertEq(factory.owner(), owner);
    }

    function testOnlyOwnerModifier() public {
        vm.startPrank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.transferOwnership(address(0x20));
        vm.stopPrank();

        vm.startPrank(owner);
        console.log(factory.owner(), "owner");
        factory.transferOwnership(address(0x20));
        vm.stopPrank();
        vm.startPrank(address(0x20));
        // two step ownership transfer
        factory.acceptOwnership();
        assertEq(factory.owner(), address(0x20));
    }

    function testCreateFundraisingVaultRevertsIfNotOwner() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createFundraisingVault(
            "TokenName",
            "TKN",
            usdc,
            nonProfitOrg,
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsOnZeroOwnerAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createFundraisingVault(
            "TokenName",
            "TKN",
            usdc,
            address(0),
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsOnUnderlyingAssetAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createFundraisingVault(
            "TokenName",
            "TKN",
            address(0),
            owner,
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsIfVaultAlreadyExists() public {
        vm.prank(owner);
        vm.expectRevert(Factory.VaultAlreadyExists.selector);
        factory.createFundraisingVault(
            "TokenName",
            "TKN",
            usdc,
            nonProfitOrg,
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );
        vm.stopPrank();
    }

    function testCreateFundraisingVaultAndEmitFundraisingVaultCreatedEvent() public {
        vm.prank(owner);
        factory.createFundraisingVault(
            "TokenName",
            "TKN",
            usdc,
            address(30),
            taxFee,
            maximumThreshold,
            minimumHealthThreshhold,
            transferInterval,
            minLPHealthThreshhold,
            tickSpacing
        );
        (address fundraisingToken,, address treasuryWallet, address donationWallet,,,,) =
            factory.fundraisingAddresses(address(30));
        assert(fundraisingToken != address(0));
        assert(donationWallet != address(0));
        assert(treasuryWallet != address(0));

        FundRaisingToken token = FundRaisingToken(fundraisingToken);
        assertEq(token.name(), "TokenName");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), IERC20Metadata(usdc).decimals());
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** token.decimals());
        assertEq(token.balanceOf(treasuryWallet), 250_000_000 * 10 ** token.decimals());
        assertEq(token.balanceOf(donationWallet), 0);
        assertEq(token.balanceOf(owner), 750_000_000 * 10 ** token.decimals());
        assertEq(token.lpManager(), factory.owner());
        assertEq(token.treasuryAddress(), treasuryWallet);
        assertEq(token.donationAddress(), donationWallet);
        assertEq(token.factoryAddress(), address(factory));

        DonationWallet dw = DonationWallet(donationWallet);
        assertEq(dw.owner(), address(30));
        assertEq(dw.factoryAddress(), address(factory));
        assertEq(address(dw.router()), router);
        assertEq(address(dw.poolManager()), poolManager);
        assertEq(address(dw.permit2()), permit2);
        assertEq(address(dw.positionManager()), positionManager);

        TreasuryWallet tw = TreasuryWallet(treasuryWallet);
        assertEq(tw.donationAddress(), donationWallet);
        assertEq(tw.factoryAddress(), address(factory));
        assertEq(tw.registryAddress(), registryAddress);
        assertEq(address(tw.router()), router);
        assertEq(address(tw.poolManager()), poolManager);
        assertEq(address(tw.permit2()), permit2);
        assertEq(address(tw.positionManager()), positionManager);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroOwnerAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createPool(address(0), 1, 1);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroAmount0() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.createPool(nonProfitOrg, 0, 1);
        vm.stopPrank();
    }

    function testCreateCannotCreatePoolWithZeroAmount1() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.createPool(nonProfitOrg, 1, 0);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreatePoolIfVaultNotCreated() public {
        vm.prank(owner);
        vm.expectRevert(Factory.FundraisingVaultNotCreated.selector);
        factory.createPool(address(0x10), 1, 1);
        vm.stopPrank();
    }

    function testCreatePoolOnlyOwnerCanCreatePool() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createPool(owner, 1, 1);
        vm.stopPrank();
    }

    function testCreatePoolOwnerCanCreateAPoolOnUniswap() public {
        vm.prank(owner);
        uint256 amount0 = 30_000_000_000; // amount of usdc
        uint256 amount1 = IERC20Metadata(fundraisingTokenAddress).balanceOf(owner); // amount of fundraising token

        vm.startPrank(USDC_WHALE);

        IERC20Metadata(usdc).transfer(owner, amount0);
        vm.stopPrank();

        vm.startPrank(owner);
        IERC20Metadata(usdc).approve(address(factory), amount0);
        IERC20Metadata(fundraisingTokenAddress).approve(address(factory), amount1);
        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(usdc, fundraisingTokenAddress, nonProfitOrg);
        factory.createPool(nonProfitOrg, amount0, amount1);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreateSamePoolTwice() public {
        testCreatePoolOwnerCanCreateAPoolOnUniswap();
        vm.startPrank(owner);
        vm.expectRevert(Factory.PoolAlreadyExists.selector);
        factory.createPool(nonProfitOrg, 1, 1);
        vm.stopPrank();
    }

    function testSwapFundraisingToken() public {
        testCreatePoolOwnerCanCreateAPoolOnUniswap();

        vm.startPrank(registryAddress);

        // transfer some amount to donation wallet
        vm.roll(block.number + 10);
        TreasuryWallet treasury = TreasuryWallet(treasuryWalletAddress);

        bytes memory performData = abi.encode(true, false);

        treasury.performUpkeep(performData);

        assert(IERC20Metadata(fundraisingTokenAddress).balanceOf(donationWalletAddress) > 0);

        assert(IERC20Metadata(usdc).balanceOf(donationWalletAddress) == 0);

        // swap fundraising token to usdc

        DonationWallet donation = DonationWallet(donationWalletAddress);

        donation.performUpkeep(bytes(""));

        assert(IERC20Metadata(usdc).balanceOf(nonProfitOrg) > 0);
    }
}
