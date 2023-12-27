/*
███╗░░░███╗░█████╗░███╗░░░███╗███████╗███╗░░██╗████████╗██╗░░░██╗███╗░░░███╗
████╗░████║██╔══██╗████╗░████║██╔════╝████╗░██║╚══██╔══╝██║░░░██║████╗░████║
██╔████╔██║██║░░██║██╔████╔██║█████╗░░██╔██╗██║░░░██║░░░██║░░░██║██╔████╔██║
██║╚██╔╝██║██║░░██║██║╚██╔╝██║██╔══╝░░██║╚████║░░░██║░░░██║░░░██║██║╚██╔╝██║
██║░╚═╝░██║╚█████╔╝██║░╚═╝░██║███████╗██║░╚███║░░░██║░░░╚██████╔╝██║░╚═╝░██║
╚═╝░░░░░╚═╝░╚════╝░╚═╝░░░░░╚═╝╚══════╝╚═╝░░╚══╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░╚═╝

██╗░░██╗███████╗████████╗██████╗░███████╗██╗░░██╗
██║░░██║██╔════╝╚══██╔══╝██╔══██╗██╔════╝╚██╗██╔╝
███████║█████╗░░░░░██║░░░██║░░██║█████╗░░░╚███╔╝░
██╔══██║██╔══╝░░░░░██║░░░██║░░██║██╔══╝░░░██╔██╗░
██║░░██║██║░░░░░░░░██║░░░██████╔╝███████╗██╔╝╚██╗
╚═╝░░╚═╝╚═╝░░░░░░░░╚═╝░░░╚═════╝░╚══════╝╚═╝░░╚═╝
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * @title LendingPoolFactory
 * @author twizzwrld
 *
 * The LendingPoolFactory contract is a factory for creating LendingPool contracts. Each LendingPool represents a lending pool for a specific token and manages lending activities for that token.
 *
 * @notice This contract allows for the creation of multiple LendingPool instances, each associated with a specific token and annual interest rate.
 */

import "./LendingPool.sol";

contract LendingPoolFactory {
    address[] public lendingPools;

    event LendingPoolCreated(address indexed tokenAddress, address lendingPoolAddress);

    function createLendingPool(address tokenAddress, uint256 annualInterestRate) public {
        LendingPool newLendingPool = new LendingPool(tokenAddress, annualInterestRate);
        lendingPools.push(address(newLendingPool));
        emit LendingPoolCreated(tokenAddress, address(newLendingPool));
    }

    function getLendingPools() public view returns (address[] memory) {
        return lendingPools;
    }
}
