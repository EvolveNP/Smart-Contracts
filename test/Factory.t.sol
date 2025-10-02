// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryTest is Test {
    Factory public factory;
    address public constant registryAddress = address(0x1);
    address public constant poolManager = address(0x2);
    address public constant positionManager = address(0x3);
    address public constant router = address(0x4);
    address public constant permit2 = address(0x5);
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
}
