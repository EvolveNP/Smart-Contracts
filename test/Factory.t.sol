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
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint160 public constant sqrtPriceX96 = 79228162514264337593543950336; // 1:1 price ratio

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.prank(owner);
        factory = new Factory(registryAddress, poolManager, positionManager, router, permit2);
        vm.prank(owner);
        factory.createFundraisingVault("FundraisingToken", "FTN", usdc, nonProfitOrg);

        (fundraisingTokenAddress,,,,,,) = factory.fundraisingAddresses(nonProfitOrg);
        vm.stopPrank();
    }

    function testConstructorRevertsOnZeroRegistryAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(address(0), poolManager, positionManager, router, permit2);
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(registryAddress, address(0), positionManager, router, permit2);
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(registryAddress, poolManager, address(0), router, permit2);
    }

    function testConstructorRevertsOnZeroRouterAddress() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(registryAddress, poolManager, positionManager, address(0), permit2);
    }

    function testConstructorRevertsOnZeroPermit2Address() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(registryAddress, poolManager, positionManager, router, address(0));
    }

    function testConstructorSetsStateVariables() public view {
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
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.transferOwnership(address(0x20));
        vm.stopPrank();

        vm.prank(owner);
        factory.transferOwnership(address(0x20));
        vm.stopPrank();

        assertEq(factory.owner(), address(0x20));
    }

    function testCreateFundraisingVaultRevertsIfNotOwner() public {
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createFundraisingVault("TokenName", "TKN", usdc, address(0x10));
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsOnZeroOwnerAddress() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createFundraisingVault("TokenName", "TKN", usdc, address(0));
        vm.stopPrank();
    }

    function testCreateFundraisingVaultRevertsIfVaultAlreadyExists() public {
        vm.prank(owner);
        factory.createFundraisingVault("TokenName", "TKN", usdc, owner);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(Factory.VaultAlreadyExists.selector);
        factory.createFundraisingVault("TokenName", "TKN", usdc, owner);
        vm.stopPrank();
    }

    function testCreateFundraisingVaultA() public {
        vm.prank(owner);
        factory.createFundraisingVault("TokenName", "TKN", usdc, owner);
        (address fundraisingToken,, address treasuryWallet, address donationWallet,,,) =
            factory.fundraisingAddresses(owner);
        assert(fundraisingToken != address(0));
        assert(donationWallet != address(0));
        assert(treasuryWallet != address(0));

        FundRaisingToken token = FundRaisingToken(fundraisingToken);
        console.log(token.balanceOf(treasuryWallet), "treasury balance");
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
        assertEq(dw.owner(), owner);
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

    function testCreateCannotCreatePoolWithZeroOwner() public {
        vm.prank(owner);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createPool(address(0), 1);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreatePoolIfVaultNotCreated() public {
        vm.prank(owner);
        vm.expectRevert(Factory.FundraisingVaultNotCreated.selector);
        factory.createPool(address(0x10), 1);
        vm.stopPrank();
    }

    function testCreatePoolCannotCreateSamePoolTwice() public {
        vm.prank(owner);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.prank(owner);
        vm.expectRevert(Factory.PoolAlreadyExists.selector);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.stopPrank();
    }

    function testCreatePoolOnlyOwnerCanCreatePool() public {
        vm.prank(owner);
        factory.createFundraisingVault("TokenName", "TKN", usdc, owner);

        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.createPool(owner, 1);
        vm.stopPrank();
    }

    function testCreatePoolOwnerCanCreateAPoolOnUniswap() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(usdc, fundraisingTokenAddress, nonProfitOrg);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.stopPrank();
    }

    function testAddLiquidityOnlyOwnerCanAddLiquidity() public {
        vm.prank(owner);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.prank(address(0x10));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x10)));
        factory.addLiquidity(1000, 1000, nonProfitOrg);
        vm.stopPrank();
    }

    function testAddLiquidityCannotAddLiquidityWithZeroAmount0() public {
        vm.startPrank(owner);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.addLiquidity(0, 1000, nonProfitOrg);
        vm.stopPrank();
    }

    function testAddLiquidityCannotAddLiquidityWithZeroAmount1() public {
        vm.startPrank(owner);
        factory.createPool(nonProfitOrg, sqrtPriceX96);
        vm.expectRevert(Factory.ZeroAmount.selector);
        factory.addLiquidity(1000, 0, nonProfitOrg);
        vm.stopPrank();
    }

    function testAddLiquidityAddsLiquidity() public {
        // 1. Owner creates the pool
        uint256 amount1 = IERC20Metadata(fundraisingTokenAddress).balanceOf(owner); // amount of fundraising token
        uint256 amount0 = 30_000_000_000; // amount of usdc

        uint160 _sqrtPriceX96 = Helper.encodeSqrtPriceX96(amount1, amount0);

        vm.startPrank(owner);
        factory.createPool(nonProfitOrg, _sqrtPriceX96);
        vm.stopPrank();

        // 2. Fund the owner with some tokens
        vm.startPrank(USDC_WHALE);
        IERC20Metadata(usdc).transfer(address(factory), amount0);
        vm.stopPrank();

        vm.startPrank(owner);
        IERC20Metadata(fundraisingTokenAddress).transfer(address(factory), amount1);
        vm.stopPrank();

        // 4. Add liquidity through factory
        vm.startPrank(owner);
        factory.addLiquidity(amount0, amount1, nonProfitOrg);
        vm.stopPrank();

        // 5. Verify liquidity was added (depends on your factory logic)
        console.log("USDC balance (factory):", IERC20Metadata(usdc).balanceOf(address(factory)));
        console.log(
            "FundraisingToken balance (factory):", IERC20Metadata(fundraisingTokenAddress).balanceOf(address(factory))
        );
    }
}
