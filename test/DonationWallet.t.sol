// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Factory} from "../src/Factory.sol";
import {FactoryTest} from "./Factory.t.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DonationWalletTest is Test {
    DonationWallet public donationWallet;
    address public constant factoryAddress = address(0x1);
    address public constant nonProfitOrgAddress = address(0x2);
    address public constant router = address(0x7);
    address public constant poolManager = address(0x8);
    address public constant permit2 = address(0x9);
    address public constant positionManager = address(0x10);
    address public constant quoter = address(0x11);
    address public fundraisingToken;
    address donationWalletImplementation;
    address donationWalletBeacon;
    Factory factory;
    address registryAddress = address(0x21);

    function setUp() public {
        donationWalletImplementation = address(new DonationWallet());
        donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        address factoryImplementation = address(new Factory());
        factory = Factory(address(new TransparentUpgradeableProxy(factoryImplementation, address(30), bytes(""))));
        factory.initialize(
            address(20),
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            address(21),
            address(22),
            donationWalletBeacon,
            address(23)
        );
        fundraisingToken = address(new FundRaisingToken("FundRaisingToken", "FRT", 6, address(10), address(10), 2e24));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
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

    function testCheckUpKeepReturnsFalseIfNoFundraisingTokenAvailable() public view {
        (bool upkeepNeeded,) = donationWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpKeepReturnsTrueIfFundraisingTokenAvailable() public {
        vm.startPrank(address(10));
        FundRaisingToken(fundraisingToken).transfer(address(donationWallet), 1e6);
        (bool upkeepNeeded,) = donationWallet.checkUpkeep(bytes(""));
        assertEq(upkeepNeeded, true);
    }

    function testPerformUpkeepOnlyCalledByRegistry() public {
        vm.startPrank(address(20));
        vm.expectRevert(DonationWallet.NotRegistry.selector);
        donationWallet.performUpkeep(bytes(""));
        vm.stopPrank();
    }

    function testPerformUpkeepSwapsFundraisingTokenAndSendToNonProfitOrg() public {
        FactoryTest factoryTest = new FactoryTest();

        factoryTest.setUp();
        factoryTest.testCreatePoolOwnerCanCreateAPoolOnUniswap();

        Factory _factory = factoryTest.factory();
        address _registryAddress = _factory.registryAddress();
        address nonProfigOrg = factoryTest.nonProfitOrg();
        vm.startPrank(_registryAddress);
        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(nonProfigOrg);

        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        bytes memory performData = abi.encode(true, false);
        treasuryWallet.performUpkeep(performData);

        uint256 donationBalance = IERC20(fundraisingTokenAddress).balanceOf(_donationWallet);
        assertGt(donationBalance, 0);
        address owner = DonationWallet(payable(_donationWallet)).owner();
        DonationWallet(payable(_donationWallet)).performUpkeep(bytes(""));
        vm.stopPrank();
        assertEq(IERC20(fundraisingTokenAddress).balanceOf(_donationWallet), 0);
        assertGt(IERC20(underlyingAddress).balanceOf(owner), 0);
    }

    function testPerformUpkeepSwapsFundraisingTokenToETHandSendToNonProfitOrg() public {
        FactoryTest factoryTest = new FactoryTest();

        factoryTest.setUp();
        factoryTest.testCreatePoolOwnerCanCreatePoolUsingEtherAsUnderlyingToken();

        Factory _factory = factoryTest.factory();
        address _registryAddress = _factory.registryAddress();
        address nonProfigOrg = factoryTest.nonProfitOrg2();
        vm.startPrank(_registryAddress);
        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(nonProfigOrg);
        assertEq(underlyingAddress, address(0));
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        bytes memory performData = abi.encode(true, false);
        treasuryWallet.performUpkeep(performData);

        uint256 donationBalance = IERC20(fundraisingTokenAddress).balanceOf(_donationWallet);
        assertGt(donationBalance, 0);
        address owner = DonationWallet(payable(_donationWallet)).owner();
        DonationWallet(payable(_donationWallet)).performUpkeep(bytes(""));
        vm.stopPrank();
        assertEq(IERC20(fundraisingTokenAddress).balanceOf(_donationWallet), 0);
        assertGt(owner.balance, 0);
    }

    function testReceive() public {
        vm.deal(address(donationWallet), 1 ether);
        assertEq(address(donationWallet).balance, 1 ether);
    }
}
