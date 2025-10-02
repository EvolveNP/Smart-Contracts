// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {FundRaisingToken} from "../src/FundRaisingToken.sol";

contract FactoryTest is Test {
    Factory public factory;
    address public constant registryAddress = address(0x1);
    address public constant poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public constant positionManager = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant router = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant owner = address(0x6);

    function setUp() public {
        vm.prank(owner);
        factory = new Factory(registryAddress, poolManager, positionManager, router, permit2);
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
        factory.createFundraisingVault("TokenName", "TKN", address(0x10));
        vm.stopPrank();
    }

    function testCreateFundraisingVault() public {
        vm.prank(owner);
        factory.createFundraisingVault("TokenName", "TKN", owner);
        (address fundraisingToken, address treasuryWallet, address donationWallet,,,,) =
            factory.fundraisingAddresses(owner);
        assert(fundraisingToken != address(0));
        assert(donationWallet != address(0));
        assert(treasuryWallet != address(0));

        FundRaisingToken token = FundRaisingToken(fundraisingToken);
        assertEq(token.name(), "TokenName");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** 18);
        assertEq(token.balanceOf(treasuryWallet), 250_000_000 * 10 ** 18);
        assertEq(token.balanceOf(donationWallet), 0);
        assertEq(token.balanceOf(owner), 750_000_000 * 10 ** 18);
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
}
