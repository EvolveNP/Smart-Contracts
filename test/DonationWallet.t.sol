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
import {USDC} from "../src/mock/USDC.sol";

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
            donationWalletBeacon
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
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            address(0), nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroNonProfitOrgAddress() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, address(0), router, poolManager, permit2, positionManager, quoter, fundraisingToken
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
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, address(0), permit2, positionManager, quoter, fundraisingToken
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
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, address(0), quoter, fundraisingToken
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
            fundraisingToken
        );
    }

    function testConstructorRevertsOnZeroFundraisingAddress() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        vm.expectRevert(Swap.ZeroAddress.selector);
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, address(0)
        );
    }

    function testConstructorSetsStateVariables() public {
        donationWallet = DonationWallet(payable(address(new BeaconProxy(donationWalletBeacon, ""))));
        donationWallet.initialize(
            factoryAddress, nonProfitOrgAddress, router, poolManager, permit2, positionManager, quoter, fundraisingToken
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

        address nonProfigOrg = factoryTest.nonProfitOrg();

        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(nonProfigOrg);

        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        bytes memory performData = abi.encode(true, false);
        address _registryAddress = treasuryWallet.registryAddress();
        vm.startPrank(_registryAddress);
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

        address nonProfigOrg = factoryTest.nonProfitOrg2();

        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(nonProfigOrg);
        assertEq(underlyingAddress, address(0));
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        address _registryAddress = treasuryWallet.registryAddress();
        vm.startPrank(_registryAddress);
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

    function testPerformUpkeepSwapsFundraisingTokenToETHFailsIfOwnerCannotReceiveETH() public {
        FactoryTest factoryTest = new FactoryTest();

        factoryTest.setUp();

        Factory _factory = factoryTest.factory();
        address ownerThatNotReceiveETH = address(new USDC(6));
        address owner = _factory.owner();
        vm.startPrank(owner);
        _factory.createFundraisingVault("Fundraising TOken", "FTN", address(0), ownerThatNotReceiveETH);

        uint256 amount0 = 7 ether; // amount of Eth
        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(ownerThatNotReceiveETH);

        uint256 amount1 = IERC20(fundraisingTokenAddress).balanceOf(owner); // amount of fundraising token

        vm.deal(owner, amount0);

        uint256 tolerance = 2_200; // add some tolerance due to precision

        vm.startPrank(owner);
        console.log(fundraisingTokenAddress, amount1, "amount");
        IERC20(fundraisingTokenAddress).approve(address(_factory), amount1);
        bytes32 salt = _factory.findSalt(ownerThatNotReceiveETH);

        vm.expectEmit(true, true, true, false);
        emit Factory.LiquidityPoolCreated(address(0), fundraisingTokenAddress, ownerThatNotReceiveETH);
        _factory.createPool{value: amount0}(ownerThatNotReceiveETH, amount0, amount1, salt);

        // amount should be added as a liquidity
        assertEq(address(_factory).balance, 0);
        assertApproxEqAbs(
            IERC20(fundraisingTokenAddress).balanceOf(address(_factory.poolManager())), amount1, tolerance
        );

        assertEq(underlyingAddress, address(0));
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        address _registryAddress = treasuryWallet.registryAddress();
        vm.startPrank(_registryAddress);
        bytes memory performData = abi.encode(true, false);
        treasuryWallet.performUpkeep(performData);

        uint256 donationBalance = IERC20(fundraisingTokenAddress).balanceOf(_donationWallet);
        assertGt(donationBalance, 0);

        vm.expectRevert(DonationWallet.TransferFailed.selector);
        DonationWallet(payable(_donationWallet)).performUpkeep(bytes(""));
        vm.stopPrank();
    }

    function testPerformUpkeepSwapsFundraisingTokenAndSendToNonProfitOrgWhenUnderlyingAddressIsCurrency0AndFundraisingCurrency1()
        public
    {
        FactoryTest factoryTest = new FactoryTest();

        factoryTest.setUp();
        factoryTest.testCreatePoolWithCurrency0UnderlyingTokenAndCurrency1FundraisingToken();

        Factory _factory = factoryTest.factory();

        address nonProfigOrg = address(40);

        (
            address fundraisingTokenAddress,
            address underlyingAddress,
            address treasuryAddress,
            address _donationWallet,,,
        ) = _factory.protocols(nonProfigOrg);

        TreasuryWallet treasuryWallet = TreasuryWallet(payable(treasuryAddress));
        bytes memory performData = abi.encode(true, false);
        address _registryAddress = treasuryWallet.registryAddress();
        vm.startPrank(_registryAddress);
        treasuryWallet.performUpkeep(performData);

        uint256 donationBalance = IERC20(fundraisingTokenAddress).balanceOf(_donationWallet);
        assertGt(donationBalance, 0);
        address owner = DonationWallet(payable(_donationWallet)).owner();
        DonationWallet(payable(_donationWallet)).performUpkeep(bytes(""));
        vm.stopPrank();
        assertEq(IERC20(fundraisingTokenAddress).balanceOf(_donationWallet), 0);
        assertGt(IERC20(underlyingAddress).balanceOf(owner), 0);
    }

    function testReceive() public {
        vm.deal(address(donationWallet), 1 ether);
        assertEq(address(donationWallet).balance, 1 ether);
    }

    function testSetRegistryAddressOnlyCalledByFactory() public {
        vm.expectRevert(DonationWallet.NotFactory.selector);
        donationWallet.setRegistry(address(20));
    }

    function testSetRegistryAddressSetRegistryAddressCorrectly() public {
        vm.startPrank(address(factory));
        donationWallet.setRegistry(address(20));
        assertEq(donationWallet.registryAddress(), address(20));
        vm.stopPrank();
    }
}
