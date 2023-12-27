// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
