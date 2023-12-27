// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Orderbook.sol";

contract OrderBookFactory {
    address[] public orderBooks;

    event OrderBookCreated(address indexed tokenA, address indexed tokenB, address orderBookAddress);

    function createOrderBook(address tokenA, address tokenB) public {
        OrderBook newOrderBook = new OrderBook(tokenA, tokenB);
        orderBooks.push(address(newOrderBook));
        emit OrderBookCreated(tokenA, tokenB, address(newOrderBook));
    }

    function getOrderBooks() public view returns (address[] memory) {
        return orderBooks;
    }
}