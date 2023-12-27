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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OrderBook {
    using SafeMath for uint256;

    struct Order {
        address trader;
        uint256 amount;
        uint256 price; // Price of tokenB in terms of tokenA
        uint256 timestamp;
        bool isBuy; // True if buying tokenA with tokenB
    }

    IERC20 public tokenA; // Base token
    IERC20 public tokenB; // Quote token
    Order[] public buyOrders; // Orders to buy tokenA
    Order[] public sellOrders; // Orders to sell tokenA

    event OrderPlaced(uint indexed orderId, address indexed trader, uint256 amount, uint256 price, bool isBuy);
    event OrderMatched(uint buyOrderId, uint sellOrderId, uint256 matchedAmount, uint256 matchedPrice);

    constructor(address _tokenAAddress, address _tokenBAddress) {
        tokenA = IERC20(_tokenAAddress);
        tokenB = IERC20(_tokenBAddress);
    }

    function placeLimitOrder(uint256 amount, uint256 price, bool isBuy) external {
        if (isBuy) {
            require(tokenB.transferFrom(msg.sender, address(this), amount.mul(price)), "Transfer failed");
        } else {
            require(tokenA.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        }

        Order memory newOrder = Order(msg.sender, amount, price, block.timestamp, isBuy);
        if (isBuy) {
            buyOrders.push(newOrder);
        } else {
            sellOrders.push(newOrder);
        }

        matchOrders();
        emit OrderPlaced(buyOrders.length - 1, msg.sender, amount, price, isBuy);
    }

    function matchOrders() private {
        for (uint i = 0; i < buyOrders.length; i++) {
            for (uint j = 0; j < sellOrders.length; j++) {
                if (buyOrders[i].amount == 0 || sellOrders[j].amount == 0) continue;
                if (buyOrders[i].price >= sellOrders[j].price) {
                    uint256 matchedAmount = min(buyOrders[i].amount, sellOrders[j].amount);
                    uint256 matchedPrice = sellOrders[j].price;

                    buyOrders[i].amount = buyOrders[i].amount.sub(matchedAmount);
                    sellOrders[j].amount = sellOrders[j].amount.sub(matchedAmount);

                    token.transfer(buyOrders[i].trader, matchedAmount); // Transfer tokens to buyer
                    token.transfer(sellOrders[j].trader, matchedAmount.mul(matchedPrice)); // Transfer payment to seller

                    emit OrderMatched(i, j, matchedAmount, matchedPrice);
                }
            }
        }
    }

    // Additional functions and logic
    // ...

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

}
