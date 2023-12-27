// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LendingPool is ReentrancyGuard {
    IERC20 public lendingToken;

    // Struct to store lender's details
    struct Lender {
        uint256 amountDeposited;
        uint256 interestEarned;
    }

    // Mapping of lender addresses to their details
    mapping(address => Lender) public lenders;

    // Interest rate per annum (e.g., 5% interest would be stored as 500)
    uint256 public annualInterestRate;

    event Deposited(address indexed lender, uint256 amount);
    event Withdrawn(address indexed lender, uint256 amount);

    constructor(address _lendingTokenAddress, uint256 _annualInterestRate) {
        lendingToken = IERC20(_lendingTokenAddress);
        annualInterestRate = _annualInterestRate;
    }

    // Deposit tokens into the lending pool
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        lendingToken.transferFrom(msg.sender, address(this), amount);
        
        Lender storage lender = lenders[msg.sender];
        lender.amountDeposited += amount;
        emit Deposited(msg.sender, amount);
    }

    // Withdraw tokens from the lending pool
    function withdraw(uint256 amount) external nonReentrant {
        Lender storage lender = lenders[msg.sender];
        require(lender.amountDeposited >= amount, "Insufficient balance");

        uint256 interest = calculateInterest(lender.amountDeposited);
        lender.amountDeposited -= amount;
        lender.interestEarned += interest;

        lendingToken.transfer(msg.sender, amount + interest);
        emit Withdrawn(msg.sender, amount);
    }

    // Calculate interest for a lender
    function calculateInterest(uint256 depositAmount) public view returns (uint256) {
        // Basic interest calculation formula
        // Assuming interest calculation for the entire deposit period
        return depositAmount * annualInterestRate / 10000; // Divide by 10000 to adjust for percentage and rate representation
    }

    function emergencyWithdraw(address _to, uint256 _amount) external onlyOwner {
    // Additional checks and balances
    lendingToken.transfer(_to, _amount);
    }

    function getTotalPoolBalance() public view returns (uint256) {
    return lendingToken.balanceOf(address(this));
    }

}
