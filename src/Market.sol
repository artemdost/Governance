// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Market Contract
/// @notice Provides functionalities to manage and purchase governance tokens (GOVR) using USDT.
/// @dev This contract is meant to be inherited by other contracts. It uses OpenZeppelin's SafeERC20 library.
abstract contract Market {
    using SafeERC20 for IERC20;

    /// @notice The USDT ERC20 token contract.
    IERC20 public usdt;

    /// @notice The GOVR (Governance) ERC20 token contract.
    IERC20 public govr;

    /// @notice The owner of the contract, typically the Governance contract.
    address public owner;

    /// @notice Restricts function access to the owner of the contract.
    modifier onlyOwner() {
        require(msg.sender == owner, "Invalid owner");
        _;
    }

    /**
     * @notice Sets the address of the USDT token contract.
     * @dev This function can only be called by the owner of the contract.
     * @param _addr The address of the USDT token contract.
     */
    function setUpUSDT(address _addr) public onlyOwner {
        usdt = IERC20(_addr);
    }

    /**
     * @notice Sets the address of the GOVR token contract.
     * @dev This function can only be called by the owner of the contract.
     * @param _addr The address of the GOVR token contract.
     */
    function setUpGOVR(address _addr) public onlyOwner {
        govr = IERC20(_addr);
    }

    /**
     * @notice Allows users to buy GOVR tokens by paying with USDT.
     * @dev The function transfers the specified amount of USDT from the user's account to the contract,
     *      and then transfers the same amount of GOVR tokens from the contract to the user.
     * @param amount The amount of GOVR tokens to purchase.
     */
    function buyGOVR(uint256 amount) public {
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        govr.safeTransfer(msg.sender, amount);
    }
}
