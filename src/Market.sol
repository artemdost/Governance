// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Market{
    using SafeERC20 for IERC20;

    IERC20 usdt;
    IERC20 govr;

    // хозяин, это будет Governance
    address owner;

    modifier onlyOwner(){
        require(msg.sender == owner, "Invalid owner");
        _;
    }

    // устанавливает USDT, только владелец
    function setUpUSDT(address _addr) public onlyOwner{
        usdt = IERC20(_addr);
    }

    // устанавливает USDT, только владелец
    function setUpGOVR(address _addr) public onlyOwner{
        govr = IERC20(_addr);
    }

    // купить токены голосования
    function buyGOVR(uint256 amount) public{
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        govr.safeTransfer(msg.sender, amount);
    }
}