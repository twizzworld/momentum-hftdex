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
 * @title MarginAccount
 * @author twizzwrld
 *
 * The MarginAccount contract serves as the core of a decentralized margin trading system. It enables users to deposit, withdraw, borrow, and repay assets for margin trading.
 *
 * This contract operates with a designated trading token and interacts with a lending pool contract for borrowing and liquidation purposes.
 *
 * @notice This contract is designed to provide a margin trading platform where users can leverage their deposits for trading activities.
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarginAccount {
    struct Account {
        uint256 balance;
        uint256 borrowed;
        uint256 marginLevel;
    }

    mapping(address => Account) public accounts;
    mapping(address => bool) private admins;
    IERC20 public tradingToken; // The token used for trading
    address public lendingPool; // Address of the lending pool contract

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);

    constructor(address _tradingToken, address _lendingPool) {
        tradingToken = IERC20(_tradingToken);
        lendingPool = _lendingPool;
    }

    function deposit(uint256 amount) external {
        tradingToken.transferFrom(msg.sender, address(this), amount);
        accounts[msg.sender].balance += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(accounts[msg.sender].balance >= amount, "Insufficient balance");
        // Additional checks for margin requirements
        tradingToken.transfer(msg.sender, amount);
        accounts[msg.sender].balance -= amount;
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
    require(amount > 0, "Invalid amount");
    uint256 maxBorrowable = accounts[msg.sender].balance * maxLeverage / 100;
    require(accounts[msg.sender].borrowed + amount <= maxBorrowable, "Exceeds max borrowable amount");
    
    // Interact with LendingPool to borrow funds
    lendingPool.borrow(amount, msg.sender);  // Assuming lendingPool has a borrow function

    accounts[msg.sender].borrowed += amount;
    emit Borrow(msg.sender, amount);
    }


    function repay(uint256 amount) external {
    require(amount > 0 && accounts[msg.sender].borrowed >= amount, "Invalid amount");
    tradingToken.transferFrom(msg.sender, address(this), amount);

    // Assuming the LendingPool contract has a repay function
    lendingPool.repay(amount, msg.sender);

    accounts[msg.sender].borrowed -= amount;
    emit Repay(msg.sender, amount);
    }

    uint256 public maxLeverage = 10; // Default max leverage (1% increments)

    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        require(_maxLeverage <= 10, "Max leverage is 10%");
        maxLeverage = _maxLeverage;
    }

    function liquidateAccount(address account) external {
    require(isLiquidator(msg.sender), "Not authorized to liquidate");
    uint256 marginLevel = calculateMarginLevel(account);
    require(marginLevel < MINIMUM_MARGIN_LEVEL, "Margin level is sufficient");

    Account storage targetAccount = accounts[account];
    uint256 amountToLiquidate = targetAccount.borrowed;
    
    // Interact with LendingPool for liquidation
    lendingPool.liquidate(amountToLiquidate, account); // Assuming lendingPool has a liquidate function

    targetAccount.borrowed = 0;
    emit AccountLiquidated(account);
    }

    function isLiquidator(address _address) internal view returns (bool) {
        // Implementation for checking if an address is an authorized liquidator
    }

    function calculateMarginLevel(address account) public view returns (uint256) {
    Account storage userAccount = accounts[account];
    if (userAccount.borrowed == 0) {
        return type(uint256).max; // Max value if no borrowing
    }

    // Example calculation (pseudocode):
    // marginLevel = (currentBalance / borrowedAmount) * 100
    // The actual calculation would depend on how you value the current balance
    // and the borrowed amount, which might involve market price data from an oracle

    uint256 currentBalanceValue = getCurrentMarketValue(userAccount.balance);
    uint256 borrowedValue = userAccount.borrowed; // Assuming 1-to-1 value for simplicity

    uint256 marginLevel = (currentBalanceValue * 100) / borrowedValue;
    return marginLevel;
    }

    function getCurrentMarketValue(uint256 balance) internal view returns (uint256) {
        // Implementation to get the current market value of the balance
        // Typically involves interacting with a price oracle
    }


    function addAdmin(address _admin) external onlyOwner {
    admins[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
    admins[_admin] = false;
    }
    
    function isAdmin(address _admin) public view returns (bool) {
    return admins[_admin];
    }


}
