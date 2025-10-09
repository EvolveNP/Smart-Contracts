// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";

contract DonationWalletTest is Test {
    DonationWallet public donationWallet;
    address public constant factoryAddress = address(0x1);
    address public constant nonProfitOrgAddress = address(0x2);
    address public constant router = address(0x7);
    address public constant poolManager = address(0x8);
    address public constant permit2 = address(0x9);
    address public constant positionManager = address(0x10);
    address public constant quoter = address(0x11);

    function setUp() public {
        donationWallet = new DonationWallet(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter
        );
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(address(0), nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter);
    }

    function testConstructorRevertsOnZeroNonProfitOrgAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(factoryAddress, address(0), router, poolManager, permit2, positionManager, quoter);
    }

    function testConstructorRevertsOnZeroRouterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(
            factoryAddress, nonProfitOrgAddress, address(0), poolManager, permit2, positionManager, quoter
        );
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(factoryAddress, nonProfitOrgAddress, router, address(0), permit2, positionManager, quoter);
    }

    function testConstructorRevertsOnZeroPermit2Address() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(
            factoryAddress, nonProfitOrgAddress, router, poolManager, address(0), positionManager, quoter
        );
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, address(0), quoter);
    }

    function testConstructorRevertsOnZeroQuoterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new DonationWallet(factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, poolManager, address(0));
    }

    function testConstructorSetsStateVariables() public view {
        assertEq(donationWallet.factoryAddress(), factoryAddress);
        assertEq(donationWallet.owner(), nonProfitOrgAddress);
        assertEq(address(donationWallet.router()), router);
        assertEq(address(donationWallet.poolManager()), poolManager);
        assertEq(address(donationWallet.permit2()), permit2);
        assertEq(address(donationWallet.positionManager()), positionManager);
    }
}
