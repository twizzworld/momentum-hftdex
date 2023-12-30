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

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface PriceOracle {
    function calculatePrice() external view returns (uint256);
}

contract CLOBOrderBookDEX {
    struct Order {
        address trader;
        uint256 amountToken1;
        uint256 amountToken2;
        bool isBuyOrder;
        bool isActive;
        uint256 timestamp;
        uint256 limitPrice;
        uint256 stopPrice;
        uint256 trailingDistance;
        uint256 referencePrice;
        uint256 icebergTotalAmount;
        uint256 icebergVisibleAmount;
    }

    struct Trade {
        uint256 amountToken1;
        uint256 amountToken2;
        uint256 timestamp;
    }

    address public token1;
    address public token2;
    uint256 public nextOrderId = 1;
    mapping(uint256 => Order) public orders;
    uint256[] private buyOrderIds;
    uint256[] private sellOrderIds;
    PriceOracle public priceOracle;
    address private owner;
    Trade[] private trades; // Array to store trade data for VWAP calculation
    uint256 public vwapPrice; // VWAP price
    uint256 public currentVWAP;


    event OrderPlaced(uint256 orderId, address trader, uint256 amountToken1, uint256 amountToken2, bool isBuyOrder);
    event TradeExecuted(uint256 buyOrderId, uint256 sellOrderId, uint256 tradedAmountToken1, uint256 tradedAmountToken2);
    event StopOrderPlaced(uint256 orderId, address trader, uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, bool isBuyOrder);
    event StopLimitOrderPlaced(uint256 orderId, address trader, uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, uint256 limitPrice, bool isBuyOrder);
    event TrailingStopOrderPlaced(uint256 orderId, address trader, uint256 amountToken1, uint256 amountToken2, uint256 trailingDistance, bool isBuyOrder);
    event IcebergOrderPlaced(uint256 orderId, address trader, uint256 totalAmountToken1, uint256 totalAmountToken2, uint256 visibleAmountToken1, bool isBuyOrder);
    event OrderActivated(uint256 orderId);
    event OrderCancelled(uint256 orderId);
    event VWAPUpdated(uint256 newVWAP);


    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    function setPriceOracle(address oracleAddress) external onlyOwner {
        priceOracle = PriceOracle(oracleAddress);
    }

    function placeOrder(uint256 amountToken1, uint256 amountToken2, bool isBuyOrder) external {
        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, true, block.timestamp, 0, 0, 0, 0, 0, 0);

        if (isBuyOrder) {
            insertSorted(buyOrderIds, orderId, isBuyOrder);
        } else {
            insertSorted(sellOrderIds, orderId, isBuyOrder);
        }

        emit OrderPlaced(orderId, msg.sender, amountToken1, amountToken2, isBuyOrder);
        matchOrders();
    }

    function placeLimitOrder(uint256 amountToken1, uint256 amountToken2, uint256 limitPrice, bool isBuyOrder) external {
        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, true, block.timestamp, limitPrice, 0, 0, 0, 0, 0);

        if (isBuyOrder) {
            insertSorted(buyOrderIds, orderId, isBuyOrder);
        } else {
            insertSorted(sellOrderIds, orderId, isBuyOrder);
        }

        emit OrderPlaced(orderId, msg.sender, amountToken1, amountToken2, isBuyOrder);
        matchOrders();
    }

    function placeStopOrder(uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, bool isBuyOrder) external {
        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, 0, stopPrice, 0, 0, 0, 0);

        emit StopOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, stopPrice, isBuyOrder);
    }

    function placeStopLimitOrder(uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, uint256 limitPrice, bool isBuyOrder) external {
        require(stopPrice > 0 && limitPrice > 0, "Stop and limit prices must be set for stop-limit orders");
        require((isBuyOrder && limitPrice > stopPrice) || (!isBuyOrder && limitPrice < stopPrice), "Invalid stop-limit order prices");

        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, limitPrice, stopPrice, 0, 0, 0, 0);

        emit StopLimitOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, stopPrice, limitPrice, isBuyOrder);
    }

    function placeTrailingStopOrder(uint256 amountToken1, uint256 amountToken2, uint256 trailingDistance, bool isBuyOrder) external {
        require(trailingDistance > 0, "Trailing distance must be greater than 0");

        uint256 orderId = nextOrderId++;
        uint256 initialReferencePrice = isBuyOrder ? type(uint256).max : 0;

        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, 0, 0, trailingDistance, initialReferencePrice, 0, 0);

        emit TrailingStopOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, trailingDistance, isBuyOrder);
    }

    function placeIcebergOrder(uint256 totalAmountToken1, uint256 totalAmountToken2, uint256 visibleAmountToken1, bool isBuyOrder) external {
        require(visibleAmountToken1 > 0 && visibleAmountToken1 < totalAmountToken1, "Invalid iceberg order amounts");

        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, visibleAmountToken1, totalAmountToken2 * visibleAmountToken1 / totalAmountToken1, isBuyOrder, true, block.timestamp, 0, 0, 0, 0, totalAmountToken1, visibleAmountToken1);

        if (isBuyOrder) {
            insertSorted(buyOrderIds, orderId, true);
        } else {
            insertSorted(sellOrderIds, orderId, false);
        }

        emit IcebergOrderPlaced(orderId, msg.sender, totalAmountToken1, totalAmountToken2, visibleAmountToken1, isBuyOrder);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order already inactive");

        order.isActive = false;
        emit OrderCancelled(orderId);
        removeOrder(orderId, order.isBuyOrder);
    }

    function getBestBid() public view returns (uint256 bestBidPrice) {
        if (buyOrderIds.length == 0) return 0;
        Order storage bestBid = orders[buyOrderIds[buyOrderIds.length - 1]];
        bestBidPrice = safeDiv(bestBid.amountToken2, bestBid.amountToken1);
    }

    function getBestAsk() public view returns (uint256 bestAskPrice) {
        if (sellOrderIds.length == 0) return 0;
        Order storage bestAsk = orders[sellOrderIds[0]];
        bestAskPrice = safeDiv(bestAsk.amountToken2, bestAsk.amountToken1);
    }

    function getOrderBookDepth(bool isBuyOrder) public view returns (uint256) {
        return isBuyOrder ? buyOrderIds.length : sellOrderIds.length;
    }

    function getOrderState(uint256 orderId) public view returns (Order memory) {
        require(orderId < nextOrderId, "Invalid order ID");
        return orders[orderId];
    }

    function updateVWAP() internal {
        uint256 volumeWeightedSum = 0;
        uint256 totalVolume = 0;
        uint256 twentyFourHoursAgo = block.timestamp - 24 hours;

        for (uint i = trades.length; i > 0; i--) {
            Trade storage trade = trades[i - 1];
            if (trade.timestamp < twentyFourHoursAgo) break;

            volumeWeightedSum += trade.amountToken1 * trade.amountToken2;
            totalVolume += trade.amountToken1;
        }

        if (totalVolume > 0) {
            currentVWAP = volumeWeightedSum / totalVolume;
        } else {
            currentVWAP = 0;
        }
    }

    function triggerUpdateOrderStates() external onlyOwner {
        uint256 currentMarketPrice = priceOracle.calculatePrice();
        updateOrderStates(currentMarketPrice);
        activateStopOrders(currentMarketPrice);
    }

    function updateOrderStates(uint256 currentMarketPrice) internal {
        for (uint256 i = 1; i < nextOrderId; i++) {
            Order storage order = orders[i];
            if (!order.isActive && order.stopPrice > 0) {
                if ((order.isBuyOrder && currentMarketPrice >= order.stopPrice) ||
                    (!order.isBuyOrder && currentMarketPrice <= order.stopPrice)) {
                    order.isActive = true;
                    insertSorted(order.isBuyOrder ? buyOrderIds : sellOrderIds, i, order.isBuyOrder);
                    emit OrderActivated(i);
                }
            }

            if (order.trailingDistance > 0) {
                updateTrailingStopOrder(order, i, currentMarketPrice);
            }
        }
    }

    function activateStopOrders(uint256 currentMarketPrice) public {
    // Obtain the current market price from the price oracle
    for (uint256 i = 1; i < nextOrderId; i++) {
        Order storage order = orders[i];
        // Check if the order is a stop order and not already active
        if (!order.isActive && order.stopPrice > 0) {
            // Activate buy stop orders if the market price is above the stop price
            // Activate sell stop orders if the market price is below the stop price
            if ((order.isBuyOrder && currentMarketPrice >= order.stopPrice) ||
                (!order.isBuyOrder && currentMarketPrice <= order.stopPrice)) {
                order.isActive = true;
                insertSorted(order.isBuyOrder ? buyOrderIds : sellOrderIds, i, order.isBuyOrder);
                emit OrderActivated(i);  // Emit an event indicating the order is activated
            }
        }
    }
    }

    function updateTrailingStopOrder(Order storage order, uint256 orderId, uint256 currentMarketPrice) internal {
        if (order.isBuyOrder) {
            if (currentMarketPrice > order.referencePrice) {
                order.referencePrice = currentMarketPrice;
            } else if (currentMarketPrice <= order.referencePrice - order.trailingDistance) {
                order.isActive = true;
                insertSorted(buyOrderIds, orderId, true);
                emit OrderActivated(orderId);
            }
        } else {
            if (currentMarketPrice < order.referencePrice) {
                order.referencePrice = currentMarketPrice;
            } else if (currentMarketPrice >= order.referencePrice + order.trailingDistance) {
                order.isActive = true;
                insertSorted(sellOrderIds, orderId, false);
                emit OrderActivated(orderId);
            }
        }
    }

    function matchOrders() internal {
        uint256 i = 0;
        uint256 j = 0;

        while (i < buyOrderIds.length && j < sellOrderIds.length) {
            Order storage buyOrder = orders[buyOrderIds[i]];
            Order storage sellOrder = orders[sellOrderIds[j]];

            if (!buyOrder.isActive || !sellOrder.isActive) {
                if (!buyOrder.isActive) i++;
                if (!sellOrder.isActive) j++;
                continue;
            }

            if (isMatch(buyOrder, sellOrder)) {
                executeTrade(buyOrderIds[i], sellOrderIds[j]);
                if (!buyOrder.isActive) i++;
                if (!sellOrder.isActive) j++;
            } else {
                break; // No more matches possible
            }
        }
    }

    function isMatch(Order storage buyOrder, Order storage sellOrder) internal view returns (bool) {
        uint256 buyPricePerUnit = safeDiv(buyOrder.amountToken2, buyOrder.amountToken1);
        uint256 sellPricePerUnit = safeDiv(sellOrder.amountToken2, sellOrder.amountToken1);

        return (buyPricePerUnit >= sellOrder.limitPrice) && (sellPricePerUnit <= buyOrder.limitPrice);
    }

    function executeTrade(uint256 buyOrderId, uint256 sellOrderId) internal {
        Order storage buyOrder = orders[buyOrderId];
        Order storage sellOrder = orders[sellOrderId];

        uint256 tradeAmountToken1 = calculateTradeAmount(buyOrder, sellOrder);
        uint256 tradeAmountToken2 = tradeAmountToken1 * sellOrder.amountToken2 / sellOrder.amountToken1;

        require(IERC20(token1).transferFrom(sellOrder.trader, buyOrder.trader, tradeAmountToken1), "Token1 transfer failed");
        require(IERC20(token2).transferFrom(buyOrder.trader, sellOrder.trader, tradeAmountToken2), "Token2 transfer failed");

        // Record the trade for VWAP calculation
        trades.push(Trade({
            amountToken1: tradeAmountToken1,
            amountToken2: tradeAmountToken2,
            timestamp: block.timestamp
        }));

        updateOrder(buyOrder, tradeAmountToken1, tradeAmountToken2, buyOrderId);
        updateOrder(sellOrder, tradeAmountToken1, tradeAmountToken2, sellOrderId);

        if (buyOrder.icebergTotalAmount > 0) {
            revealNextIcebergPortion(buyOrder, buyOrderId);
        }
        if (sellOrder.icebergTotalAmount > 0) {
            revealNextIcebergPortion(sellOrder, sellOrderId);
        }

        emit TradeExecuted(buyOrderId, sellOrderId, tradeAmountToken1, tradeAmountToken2);

        // Update VWAP after each trade
        updateVWAP();
    }

    function updateOrder(Order storage order, uint256 tradeAmountToken1, uint256 tradeAmountToken2, uint256 orderId) internal {
        order.amountToken1 -= tradeAmountToken1;
        order.amountToken2 -= tradeAmountToken2;

        if (order.amountToken1 == 0) {
            order.isActive = false;
            removeOrder(orderId, order.isBuyOrder);
        }
    }

    function calculateTradeAmount(Order storage buyOrder, Order storage sellOrder) internal view returns (uint256) {
        uint256 minTradeAmountToken1 = min(buyOrder.amountToken1, sellOrder.amountToken1);

        if (buyOrder.limitPrice > 0 && sellOrder.limitPrice > 0) {
            uint256 buyPricePerUnit = safeDiv(buyOrder.amountToken2, buyOrder.amountToken1);
            uint256 sellPricePerUnit = safeDiv(sellOrder.amountToken2, sellOrder.amountToken1);

            if (buyPricePerUnit < sellPricePerUnit) {
                return 0;
            }
        }

        if (buyOrder.limitPrice == 0 || sellOrder.limitPrice == 0) {
            return minTradeAmountToken1;
        }

        uint256 maxBuyableAmountToken1 = safeDiv(buyOrder.amountToken2 * sellOrder.limitPrice, buyOrder.limitPrice);
        return min(minTradeAmountToken1, maxBuyableAmountToken1);
    }

    function removeOrder(uint256 orderId, bool isBuyOrder) internal {
        uint256[] storage orderArray = isBuyOrder ? buyOrderIds : sellOrderIds;
        for (uint256 i = 0; i < orderArray.length; i++) {
            if (orderArray[i] == orderId) {
                for (uint256 j = i; j < orderArray.length - 1; j++) {
                    orderArray[j] = orderArray[j + 1];
                }
                orderArray.pop();
                break;
            }
        }
    }

    function revealNextIcebergPortion(Order storage order, uint256 orderId) internal {
        uint256 remainingHiddenAmount = order.icebergTotalAmount - order.amountToken1;
        if (remainingHiddenAmount > 0) {
            uint256 nextVisibleAmount = min(remainingHiddenAmount, order.icebergVisibleAmount);
            order.amountToken1 = nextVisibleAmount;
            order.amountToken2 = order.amountToken2 * nextVisibleAmount / order.icebergVisibleAmount;
            insertSorted(order.isBuyOrder ? buyOrderIds : sellOrderIds, orderId, order.isBuyOrder);
        }
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function insertSorted(uint256[] storage orderArray, uint256 orderId, bool isBuyOrder) internal {
    if (orderArray.length == 0) {
        orderArray.push(orderId);
        return;
    }

    Order memory newOrder = orders[orderId];
    uint256 newOrderPrice = safeDiv(newOrder.amountToken2, newOrder.amountToken1);

    uint256 low = 0;
    uint256 high = orderArray.length - 1;

    while (low < high) {
        uint256 mid = low + (high - low) / 2;
        Order storage midOrder = orders[orderArray[mid]];
        uint256 midOrderPrice = safeDiv(midOrder.amountToken2, midOrder.amountToken1);

        if (isBuyOrder) {
            if (newOrderPrice > midOrderPrice || 
                (newOrderPrice == midOrderPrice && newOrder.timestamp < midOrder.timestamp)) {
                high = mid;
            } else {
                low = mid + 1;
            }
        } else {
            if (newOrderPrice < midOrderPrice || 
                (newOrderPrice == midOrderPrice && newOrder.timestamp < midOrder.timestamp)) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
    }

    // Check if the new order should be inserted at the end of the array
    if (low == orderArray.length - 1) {
        Order storage lastOrder = orders[orderArray[low]];
        uint256 lastOrderPrice = safeDiv(lastOrder.amountToken2, lastOrder.amountToken1);

        if ((isBuyOrder && (newOrderPrice > lastOrderPrice || 
            (newOrderPrice == lastOrderPrice && newOrder.timestamp < lastOrder.timestamp))) || 
            (!isBuyOrder && (newOrderPrice < lastOrderPrice || 
            (newOrderPrice == lastOrderPrice && newOrder.timestamp < lastOrder.timestamp)))) {
            orderArray.push(orderId);
            return;
        }
    }

    // Shift elements to the right and insert the new order
    orderArray.push(orderArray[orderArray.length - 1]); // Duplicate the last element
    for (uint256 i = orderArray.length - 2; i > low; i--) {
        orderArray[i] = orderArray[i - 1];
    }
    orderArray[low] = orderId;
}

}
