// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DonationWalletTest is Test {
    DonationWallet public donationWallet;
    address public constant factoryAddress = address(0x1);
    address public constant nonProfitOrgAddress = address(0x2);
    address public constant router = address(0x7);
    address public constant poolManager = address(0x8);
    address public constant permit2 = address(0x9);
    address public constant positionManager = address(0x10);
    address public constant quoter = address(0x11);
    address public constant fundraisingToken = address(0x12);

    function setUp() public {
        address donationWalletImplementation = address(new DonationWallet());
        address donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            address(0), nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroNonProfitOrgAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, address(0), router, poolManager, permit2, positionManager, quoter, fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroRouterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            address(0),
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, address(0), permit2, positionManager, quoter, fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroPermit2Address() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            address(0),
            positionManager,
            quoter,
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, address(0), quoter, fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroQuoterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            address(0),
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroFundraisingAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, address(0)
        );
    }

    function testConstructorSetsStateVariables() public {
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, fundraisingToken
        );
        assertEq(donationWallet.factoryAddress(), factoryAddress);
        assertEq(donationWallet.owner(), nonProfitOrgAddress);
        assertEq(address(donationWallet.router()), router);
        assertEq(address(donationWallet.poolManager()), poolManager);
        assertEq(address(donationWallet.permit2()), permit2);
        assertEq(address(donationWallet.positionManager()), positionManager);
        //     assertEq(address(donationWallet.fundraisingTokenAddress()), fundraisingToken);
    }
}
