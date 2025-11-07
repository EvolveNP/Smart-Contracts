// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {Factory} from "../src/Factory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {USDC} from "../src/mock/USDC.sol";

contract FundRaisingTokenTest is Test {
    FundRaisingToken public fundRaisingToken;

    address public constant lpManager = address(0x1);
    address public treasuryAddress;
    address public donationAddress;
    address public factoryAddress;
    uint256 public constant totalSupply = 1e27; // 1 billion tokens with 18 decimals
    uint256 public constant taxFee = 2e16; // 2%
    uint256 public constant maximumThreshold = 30e16; // 30%
    address public constant registryAddress = address(0x1);
    address public constant poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public constant positionManager = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant router = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant nonProfitOrg = address(0x7);
    address public fundraisingTokenAddress;
    address public usdc;
    address public constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address public constant quoter = 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203;
    address public constant stateView = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;
    address public constant nonProfitOrg2 = address(0x8);

    function setUp() public {
        usdc = address(new USDC(18));
        vm.startPrank(lpManager);
        address treasuryImplementation = address(new TreasuryWallet());
        address treasuryWalletBeacon = address(new UpgradeableBeacon(treasuryImplementation, msg.sender));
        // deploy donation wallet beacon
        address donationWalletImplementation = address(new DonationWallet());
        address donationWalletBeacon = address(new UpgradeableBeacon(donationWalletImplementation, msg.sender));

        address factoryImplementation = address(new Factory());
        Factory factory =
            Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        factory.initialize(
            registryAddress,
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            address(0x20),
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );
        factoryAddress = address(factory);
        factory.createFundraisingVault("FundraisingToken", "FTN", usdc, nonProfitOrg);

        (fundraisingTokenAddress,, treasuryAddress, donationAddress,,,) = factory.protocols(nonProfitOrg);
        fundRaisingToken = FundRaisingToken(fundraisingTokenAddress);
        vm.stopPrank();
    }

    function testConstructorRevertsOnZeroLPManagerAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, address(0), treasuryAddress, donationAddress, factoryAddress, 1e24
        );
    }

    function testConstructorRevertsOnZeroTreasuryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", 6, lpManager, address(0), donationAddress, factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, address(0), factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, address(0), 1e24
        );
    }

    function testConstructorRevertsOnZeroTotalSupplyValue() public {
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 0
        );
    }

    function testConstructorMintsCorrectAmountToLPManager() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e22);
    }

    function testConstructorMintsCorrectAmountToTreasury() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 2e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 150e22);
    }

    function testConstructorSetAllAddressesCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.lpManager(), lpManager);
        assertEq(fundRaisingToken.treasuryAddress(), treasuryAddress);
        assertEq(fundRaisingToken.donationAddress(), donationAddress);
    }

    function testConstructorSetTotalSupplyCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 5e24
        );
        assertEq(fundRaisingToken.totalSupply(), 5e24);
    }

    function testDecimalsReturnsTheDecimalOfTheToken() public view {
        assertEq(fundRaisingToken.decimals(), 18);
    }

    function testBurnRevertsOnZeroAmount() public {
        vm.prank(treasuryAddress);
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        fundRaisingToken.burn(0);
    }

    function testBurnRevertsIfNotCalledByTreasury() public {
        vm.prank(address(0x4));
        vm.expectRevert(FundRaisingToken.OnlyTreasury.selector);
        fundRaisingToken.burn(1e18);
    }

    function testBurnReducesTotalSupplyAndTreasuryBalance() public {
        uint256 initialTotalSupply = fundRaisingToken.totalSupply();
        uint256 initialTreasuryBalance = fundRaisingToken.balanceOf(treasuryAddress);
        uint256 burnAmount = 1e18;

        vm.prank(treasuryAddress);
        fundRaisingToken.burn(burnAmount);

        assertEq(fundRaisingToken.totalSupply(), initialTotalSupply - burnAmount);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), initialTreasuryBalance - burnAmount);
    }

    function testBurnCannotIncurTax() public {
        uint256 initialTotalSupply = fundRaisingToken.totalSupply();
        uint256 initialTreasuryBalance = fundRaisingToken.balanceOf(treasuryAddress);
        uint256 burnAmount = 1e18;
        console.log(treasuryAddress, "treas");
        vm.startPrank(treasuryAddress);
        fundRaisingToken.burn(burnAmount);

        assertEq(fundRaisingToken.totalSupply(), initialTotalSupply - burnAmount);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), initialTreasuryBalance - burnAmount);
    }

    function testTransferLpManagerCanTransferToLPPool() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);
    }

    function testTransferCannotCutTaxIfTransferInitiatedFromLPManager() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToLPManager() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(lpManager, 1e18);
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e25);
    }

    function testTransferCannotCutTaxIfTransferInitiatedFromDonationAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(donationAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(donationAddress), 1e18);

        vm.prank(donationAddress);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToDonationAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(donationAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(donationAddress), 1e18);
    }

    function testTransferCannotCutTaxIfTransferInitiatedFromTreasuryAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(treasuryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 1e18 + 25e25);

        vm.prank(treasuryAddress);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToTreasuryAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(treasuryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 1e18 + 25e25);
    }

    function testTransferCannotCutTaxIfTreasuryBalanceIsGreaterthanMaximumThreshold() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(treasuryAddress, 10e25);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);

        vm.prank(lpManager);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);

        vm.prank(address(0x10));
        fundRaisingToken.transfer(address(0x20), 1e18);

        assertEq(fundRaisingToken.balanceOf(address(0x20)), 1e18);

        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);
    }

    function testTransferCannotCutTaxIfTreasuryPaused() public {
        vm.startPrank(factoryAddress);
        TreasuryWallet(payable(treasuryAddress)).emergencyPause(true);
        assertEq(TreasuryWallet(payable(treasuryAddress)).isTreasuryPaused(), true);
        vm.startPrank(lpManager);
        fundRaisingToken.transfer(treasuryAddress, 10e25);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);
        
   
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
        vm.stopPrank();
        vm.prank(address(0x10));
        fundRaisingToken.transfer(address(0x20), 1e18);

        assertEq(fundRaisingToken.balanceOf(address(0x20)), 1e18);

        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);
    }

    function testTransferCutsTaxIfNotFromOrToSystemAddresses() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(address(0x20), 1e18);
        // 1e18 - 2% tax = 0.98e18
        assertEq(fundRaisingToken.balanceOf(address(0x20)), 1e18);
        // Treasury should receive 2% tax = 0.02e18
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 25e25);
    }

    function testTransferCutsTaxIfTreasuryBalanceIsLessThanMinimumThreshold() public {
        vm.startPrank(lpManager);
        address receiver = address(0x17);
        uint256 amountToTransfer = 20000e6;
        uint256 _taxFee = (amountToTransfer * taxFee) / 1e18;

        uint256 treasuryBalanceBeforeTransfer = fundRaisingToken.balanceOf(treasuryAddress);

        fundRaisingToken.transfer(receiver, amountToTransfer);

        assertEq(fundRaisingToken.balanceOf(receiver), amountToTransfer - _taxFee);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), treasuryBalanceBeforeTransfer + _taxFee);
    }

    //TODO
    function testFuzz_Transfer() public {}
}
