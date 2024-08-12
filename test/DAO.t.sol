// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GOVR} from "../src/GOVR.sol";
import {USDT} from "../src/USDT.sol";
import {DAO} from "../src/DAO.sol";
import {NFT} from "../src/NFT.sol";

contract CounterTest is Test {
    USDT public usdt;
    GOVR public govr;
    DAO public dao;
    address deployer = vm.addr(1);
    address owner = vm.addr(2);
    address person1 = vm.addr(3);
    address person2 = vm.addr(4);
    address person3 = vm.addr(5);


    function setUp() public {
        usdt = new USDT(deployer);
        dao = new DAO(owner);
        govr = new GOVR(deployer);

        vm.startPrank(deployer);

        // выдаем стартовые бабки
        govr.mint(address(dao), 100 * 1000);
        usdt.mint(person1, 10 * 1000);
        usdt.mint(person2, 10 * 1000);
        usdt.mint(person3, 10 * 1000);

        vm.stopPrank();

        vm.startPrank(owner);

        // устанавливаем дефолтные адреса для маркета
        dao.setUpGOVR(address(govr));
        dao.setUpUSDT(address(usdt));

        vm.stopPrank();
    }

    function testBuy1000Govr() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        vm.stopPrank();

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
