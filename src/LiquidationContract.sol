// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarginAccount.sol";
import "./LendingPool.sol";

contract LiquidationContract {
    MarginAccount marginAccount;
    LendingPool lendingPool;

    uint256 public maintenanceMargin;

    event PositionLiquidated(address indexed account);

    constructor(address _marginAccountAddress, address _lendingPoolAddress, uint256 _maintenanceMargin) {
        marginAccount = MarginAccount(_marginAccountAddress);
        lendingPool = LendingPool(_lendingPoolAddress);
        maintenanceMargin = _maintenanceMargin; // e.g., 50% means liquidation if margin level falls below 50%
    }

    function setMaintenanceMargin(uint256 _newMargin) external {
        // Only callable by authorized users
        maintenanceMargin = _newMargin;
    }

    function liquidatePosition(address account) external {
        require(isEligibleForLiquidation(account), "Account is not eligible for liquidation");
        // Logic to liquidate the position
        // This might involve selling off collateral and repaying the borrowed amount
        emit PositionLiquidated(account);
    }

    function isEligibleForLiquidation(address account) public view returns (bool) {
        uint256 marginLevel = marginAccount.calculateMarginLevel(account);
        return marginLevel < maintenanceMargin;
    }

}
