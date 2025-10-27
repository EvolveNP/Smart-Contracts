// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Factory} from "../src/Factory.sol";

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
    address donationWalletImplementation;
    address donationWalletBeacon;
    Factory factory;
    address registryAddress = address(0x21);

    function setUp() public {
        donationWalletImplementation = address(new DonationWallet());
        donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, address(30), bytes(""))));
        factory.initialize(address(20), poolManager, positionManager, router, permit2, quoter, address(21));

        donationWallet.initialize(
            address(factory),
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            address(0),
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroNonProfitOrgAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            address(0),
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroRouterAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            address(0),
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            address(0),
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroPermit2Address() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            address(0),
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            address(0),
            quoter,
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroQuoterAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            address(0),
            fundraisingToken,
            registryAddress
        );
    }

    function testConstructorRevertsOnZeroFundraisingAddress() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            address(0),
            registryAddress
        );
    }

    function testConstructorSetsStateVariables() public {
        donationWallet = DonationWallet(address(new BeaconProxy(donationWalletBeacon, "")));
        donationWallet.initialize(
            factoryAddress,
            nonProfitOrgAddress,
            router,
            poolManager,
            permit2,
            positionManager,
            quoter,
            fundraisingToken,
            registryAddress
        );
        assertEq(donationWallet.factoryAddress(), factoryAddress);
        assertEq(donationWallet.owner(), nonProfitOrgAddress);
        assertEq(address(donationWallet.router()), router);
        assertEq(address(donationWallet.poolManager()), poolManager);
        assertEq(address(donationWallet.permit2()), permit2);
        assertEq(address(donationWallet.positionManager()), positionManager);
        vm.stopPrank();
    }

    function test_emergencyPuase_only_called_by_factory() public {
        vm.startPrank(address(20));
        vm.expectRevert(DonationWallet.NotFactory.selector);
        donationWallet.emergencyPause(true);
        vm.stopPrank();
    }

    function testEmergencyPauseCannotSetSameEmergencyStatusTwice() public {
        vm.startPrank(address(factory));
        donationWallet.emergencyPause(true);
        vm.expectRevert(DonationWallet.EmergencyPauseAlreadySet.selector);
        donationWallet.emergencyPause(true);
    }

    function testCheckUpKeepReturnsFalseIfEmergencyPauseEnabledInDonation() public {
        vm.startPrank(address(factory));
        donationWallet.emergencyPause(true);
        (bool upkeepNeeded,) = donationWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpKeepReturnsFalseIfEmergencyPauseEnabledFromFactory() public {
        vm.startPrank(address(21));
        factory.setEmergencyPause(true);
        (bool upkeepNeeded,) = donationWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
    }

    // function testCheckUpKeepReturnsFalseIfNoFundraisingTokenAvailable() public view {
    //     (bool upkeepNeeded,) = donationWallet.checkUpkeep(bytes(""));
    //     assertEq(upkeepNeeded, false);
    // }
}
