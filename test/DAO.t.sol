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
    NFT public nft;
    address deployer = vm.addr(1);
    address owner = vm.addr(2);
    address person1 = vm.addr(3);
    address person2 = vm.addr(4);
    address person3 = vm.addr(5);

    function setUp() public {
        usdt = new USDT(deployer);
        dao = new DAO(owner);
        govr = new GOVR(deployer);
        nft = new NFT(address(dao));

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

    function testMintOneVotingPersonFor() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

        dao.propose(address(nft), 0, "safeMint(address)", abi.encode(person1), "First mint");

        bytes32 propId = dao.generateProposalId(
            address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint"))
        );

        dao.vote(propId, 1);

        vm.warp(block.timestamp + 15 days);

        dao.execute(address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint")));

        vm.stopPrank();

        assertEq(nft.balanceOf(person1), 1);
    }

    function testMintTwoVotingPersonFor() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

        dao.propose(address(nft), 0, "safeMint(address)", abi.encode(person1), "First mint");

        bytes32 propId = dao.generateProposalId(
            address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint"))
        );

        dao.vote(propId, 1);

        vm.stopPrank();

        vm.startPrank(person2);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 2000);
        assertEq(govr.balanceOf(address(dao)), 98 * 1000);

        dao.vote(propId, 1);

        vm.warp(block.timestamp + 15 days);

        dao.execute(address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint")));

        vm.stopPrank();

        assertEq(nft.balanceOf(person1), 1);
    }

    function testMintTwoVotingPersonForAgainst() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

        dao.propose(address(nft), 0, "safeMint(address)", abi.encode(person1), "First mint");

        bytes32 propId = dao.generateProposalId(
            address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint"))
        );

        dao.vote(propId, 1);

        vm.stopPrank();

        vm.startPrank(person2);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 2000);
        assertEq(govr.balanceOf(address(dao)), 98 * 1000);

        dao.vote(propId, 0);

        vm.warp(block.timestamp + 15 days);

        vm.expectRevert("invalid state");

        dao.execute(address(nft), 0, "safeMint(address)", abi.encode(person1), keccak256(bytes("First mint")));
    }

    function testPauseTwoVotingPersonFor() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

        dao.propose(address(nft), 0, "pause()", abi.encode(), "First pause");

        bytes32 propId =
            dao.generateProposalId(address(nft), 0, "pause()", abi.encode(), keccak256(bytes("First pause")));

        dao.vote(propId, 1);

        vm.stopPrank();

        vm.startPrank(person2);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 2000);
        assertEq(govr.balanceOf(address(dao)), 98 * 1000);

        dao.vote(propId, 1);

        vm.warp(block.timestamp + 15 days);

        dao.execute(address(nft), 0, "pause()", abi.encode(), keccak256(bytes("First pause")));

        vm.stopPrank();

        vm.expectRevert();
        vm.prank(address(dao));
        nft.safeMint(address(dao));
    }

    function testPauseUnpauseTwoVotingPersonFor() public {
        vm.startPrank(person1);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 1000);
        assertEq(govr.balanceOf(address(dao)), 99 * 1000);

        dao.propose(address(nft), 0, "pause()", abi.encode(), "First pause");

        bytes32 propId =
            dao.generateProposalId(address(nft), 0, "pause()", abi.encode(), keccak256(bytes("First pause")));

        dao.vote(propId, 1);

        vm.stopPrank();

        vm.startPrank(person2);
        usdt.approve(address(dao), 1000);

        dao.buyGOVR(1000);

        assertEq(usdt.balanceOf(person1), 9 * 1000);
        assertEq(govr.balanceOf(person1), 1000);
        assertEq(usdt.balanceOf(address(dao)), 2000);
        assertEq(govr.balanceOf(address(dao)), 98 * 1000);

        dao.vote(propId, 1);

        vm.warp(block.timestamp + 15 days);

        dao.execute(address(nft), 0, "pause()", abi.encode(), keccak256(bytes("First pause")));

        dao.unpause(address(nft));

        vm.stopPrank();

        vm.startPrank(address(dao));
        nft.safeMint(person1);
        vm.stopPrank();
    }
}
