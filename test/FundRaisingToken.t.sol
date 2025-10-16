// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

contract FundRaisingTokenTest is Test {
    FundRaisingToken public fundRaisingToken;

    address public constant lpManager = address(0x1);
    address public constant treasuryAddress = address(0x2);
    address public constant donationAddress = address(0x3);
    address public constant factoryAddress = address(0x4);
    uint256 public constant totalSupply = 1e27; // 1 billion tokens with 18 decimals
    uint256 public constant taxFee = 2e16; // 2%
    uint256 public constant maximumThreshold = 30e16; // 30%

    function setUp() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            totalSupply,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorRevertsOnZeroLPManagerAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            address(0),
            treasuryAddress,
            donationAddress,
            factoryAddress,
            1e24,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorRevertsOnZeroTreasuryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            address(0),
            donationAddress,
            factoryAddress,
            1e24,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            address(0),
            factoryAddress,
            1e24,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            address(0),
            1e24,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorRevertsOnZeroTotalSupplyValue() public {
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            0,
            maximumThreshold,
            taxFee
        );
    }

    function testConstructorMintsCorrectAmountToLPManager() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            1e24,
            maximumThreshold,
            taxFee
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e22);
    }

    function testConstructorMintsCorrectAmountToTreasury() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            2e24,
            maximumThreshold,
            taxFee
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 150e22);
    }

    function testConstructorSetAllAddressesCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            1e24,
            maximumThreshold,
            taxFee
        );
        assertEq(fundRaisingToken.lpManager(), lpManager);
        assertEq(fundRaisingToken.treasuryAddress(), treasuryAddress);
        assertEq(fundRaisingToken.donationAddress(), donationAddress);
    }

    function testConstructorSetTotalSupplyCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken",
            "FRT",
            6,
            lpManager,
            treasuryAddress,
            donationAddress,
            factoryAddress,
            5e24,
            maximumThreshold,
            taxFee
        );
        assertEq(fundRaisingToken.totalSupply(), 5e24);
    }

    function testDecimalsReturnsTheDecimalOfTheToken() public view {
        assertEq(fundRaisingToken.decimals(), 6);
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

        vm.prank(treasuryAddress);
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
}
