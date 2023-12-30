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

/*
 * @title MomentumOrderBookDEX
 * @author twizzworld
 * Order Type: Central Limit Order Book (CLOB)
 * Trading Mechanism: Decentralized (On-Chain)
 * Asset Types: Crypto Tokens (ERC20)
 * Pricing Mechanism: Volume-Weighted Average Price (VWAP)
 *
 * This smart contract implements a decentralized exchange (DEX) using a Central Limit Order Book (CLOB) model. 
 * It supports various types of orders, including market, limit, stop, stop-limit, trailing stop, and iceberg orders. 
 * The contract handles ERC20 token pairs, allowing users to place buy or sell orders.
 *
 * Orders are matched algorithmically based on price and time priority. The contract includes functionality 
 * for order management, such as placing, activating, and cancelling orders. Additionally, it calculates and updates 
 * the Volume-Weighted Average Price (VWAP) based on executed trades over the last 24 hours, providing a fair 
 * and transparent pricing mechanism.
 *
 * The contract is designed with a focus on decentralization and on-chain execution, ensuring transparency, security, 
 * and trustless operation, making it a suitable solution for decentralized trading needs.
 */

contract MomentumOrderBookDEX {
    
    /**
     * @dev Represents an order in the order book.
     * @param trader The address of the trader who placed the order.
     * @param amountToken1 The amount of the first token in the trade pair. This could represent the amount of tokens being bought or sold, depending on 'isBuyOrder'.
     * @param amountToken2 The amount of the second token in the trade pair. This is often the counter value of 'amountToken1' in the other token of the pair.
     * @param isBuyOrder Boolean indicating if the order is a buy order (true) or a sell order (false).
     * @param isActive Boolean indicating if the order is active. An active order is one that is still valid and has not been fully executed or cancelled.
     * @param timestamp The block timestamp when the order was placed. Used for time-based order tracking and sorting.
     * @param limitPrice The price per unit of token1 at which the trader is willing to buy/sell. For limit orders, this sets the worst price at which the trader will execute.
     * @param stopPrice The price at which a stop order becomes active. Only relevant for stop and stop-limit orders.
     * @param trailingDistance The trailing distance for trailing stop orders, indicating how far the price should move against the order before it becomes active.
     * @param referencePrice The initial reference price for a trailing stop order. It adjusts as market conditions change.
     * @param icebergTotalAmount Total amount of the token to be traded in an iceberg order. Iceberg orders allow large orders to be hidden from the market view.
     * @param icebergVisibleAmount The visible amount of the iceberg order. Only this amount is shown to the market at any given time.
     */    
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

    /**
     * @notice Constructor for the CLOBOrderBookDEX contract.
     * @dev Initializes the contract, setting the addresses for the two tokens to be traded and the contract owner.
     * @param _token1 The address of the first token in the trading pair.
     * @param _token2 The address of the second token in the trading pair.
     * The 'owner' variable is set to the address deploying the contract, usually denoted by 'msg.sender'.
     */
    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @notice Places a new market order in the order book.
     * @dev Handles the placement of market orders, either buy or sell. 
     *      Assigns a unique orderId, creates a new Order struct, and adds it to the orders mapping.
     *      Inserts the orderId into the appropriate order array based on the order type.
     *      Emits an OrderPlaced event and calls matchOrders to attempt immediate matching with existing orders.
     *      Market orders are executed immediately at the best available price.
     * @param amountToken1 The amount of the first token in the trade pair, expressed in the smallest unit of the token (e.g., wei for ETH).
     * @param amountToken2 The amount of the second token in the trade pair, often representing the value of amountToken1 in the other token of the pair.
     * @param isBuyOrder A boolean indicating if the order is a buy (true) or a sell (false) market order.
     */    
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

    /**
     * @notice Places a new limit order in the order book.
     * @dev Handles the placement of limit orders, specifying the maximum or minimum price at which to buy or sell. 
     *      Generates a unique orderId, creates a new Order struct with the provided limit price, and adds it to the orders mapping.
     *      Inserts the orderId into the sorted buy or sell order arrays depending on the order type.
     *      Emits an OrderPlaced event and calls matchOrders to check for potential matches against existing orders.
     *      Limit orders are only executed when the market price reaches the specified limit price.
     * @param amountToken1 The amount of the first token in the trade pair, expressed in the smallest unit of the token (e.g., wei for ETH).
     * @param amountToken2 The amount of the second token in the trade pair, often representing the counter value of amountToken1.
     * @param limitPrice The price limit at which the order should be executed, expressed in the smallest unit of the token.
     * @param isBuyOrder A boolean indicating if the order is a buy (true) or sell (false) limit order.
     */
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

    /**
     * @notice Places a stop order in the order book.
     * @dev A stop order is placed in the order book but remains inactive until the stop price is reached. 
     *      When the stop price is reached, the order becomes active and behaves like a market order.
     *      This function creates a new order with the specified stop price and adds it to the orders mapping.
     *      The order is initially set to inactive (isActive = false). 
     *      Emits a StopOrderPlaced event.
     * @param amountToken1 The amount of the first token in the trade pair, expressed in the smallest unit of the token.
     * @param amountToken2 The amount of the second token in the trade pair.
     * @param stopPrice The price at which the order becomes active.
     * @param isBuyOrder Indicates whether the stop order is a buy (true) or sell (false) order.
     */
    function placeStopOrder(uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, bool isBuyOrder) external {
        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, 0, stopPrice, 0, 0, 0, 0);

        emit StopOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, stopPrice, isBuyOrder);
    }

    /**
     * @notice Places a stop-limit order in the order book.
     * @dev A stop-limit order combines the features of a stop order and a limit order. 
     *      It remains inactive until the stop price is reached, and then it becomes active as a limit order.
     *      This function creates a new order with both stop and limit prices and adds it to the orders mapping.
     *      The order is initially inactive (isActive = false). 
     *      Emits a StopLimitOrderPlaced event.
     *      Validates that both stop and limit prices are set and that they meet the buy/sell criteria.
     * @param amountToken1 The amount of the first token, in smallest unit.
     * @param amountToken2 The amount of the second token.
     * @param stopPrice The price at which the limit order becomes active.
     * @param limitPrice The limit price for the active order.
     * @param isBuyOrder Indicates if the stop-limit order is a buy (true) or sell (false) order.
    */
    function placeStopLimitOrder(uint256 amountToken1, uint256 amountToken2, uint256 stopPrice, uint256 limitPrice, bool isBuyOrder) external {
        require(stopPrice > 0 && limitPrice > 0, "Stop and limit prices must be set for stop-limit orders");
        require((isBuyOrder && limitPrice > stopPrice) || (!isBuyOrder && limitPrice < stopPrice), "Invalid stop-limit order prices");

        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, limitPrice, stopPrice, 0, 0, 0, 0);

        emit StopLimitOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, stopPrice, limitPrice, isBuyOrder);
    }

    /**
     * @notice Places a trailing stop order in the order book.
     * @dev A trailing stop order adjusts the stop price at a fixed amount or percentage below or above the market price, depending on the direction of the order.
     *      This function creates a new order with a trailing distance and adds it to the orders mapping.
     *      The order starts inactive (isActive = false) and its reference price is set to max or 0 depending on the order type.
     *      Emits a TrailingStopOrderPlaced event.
     *      Requires the trailing distance to be greater than 0.
     * @param amountToken1 The amount of the first token, in smallest unit.
     * @param amountToken2 The amount of the second token.
     * @param trailingDistance The distance from the market price to activate the order.
     * @param isBuyOrder Indicates if the trailing stop order is for buying (true) or selling (false).
     */
    function placeTrailingStopOrder(uint256 amountToken1, uint256 amountToken2, uint256 trailingDistance, bool isBuyOrder) external {
        require(trailingDistance > 0, "Trailing distance must be greater than 0");

        uint256 orderId = nextOrderId++;
        uint256 initialReferencePrice = isBuyOrder ? type(uint256).max : 0;

        orders[orderId] = Order(msg.sender, amountToken1, amountToken2, isBuyOrder, false, block.timestamp, 0, 0, trailingDistance, initialReferencePrice, 0, 0);

        emit TrailingStopOrderPlaced(orderId, msg.sender, amountToken1, amountToken2, trailingDistance, isBuyOrder);
    }

    /**
     * @notice Places an iceberg order in the order book.
     * @dev Iceberg orders allow large orders to be broken into smaller, less market-disruptive orders. 
     *      Only a part of the order (the "tip" of the iceberg) is visible on the order book. 
     *      As the visible part is executed, additional parts are revealed. 
     *      This function creates an iceberg order with a total amount and a visible amount.
     *      Validates that the visible amount is valid.
     *      Emits an IcebergOrderPlaced event.
     * @param totalAmountToken1 The total amount of the first token in the trade pair, in smallest unit.
     * @param totalAmountToken2 The total amount of the second token in the pair.
     * @param visibleAmountToken1 The visible amount of the first token in the order book.
     * @param isBuyOrder Indicates if the iceberg order is a buy (true) or sell (false) order.
     */
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

    /**
     * @notice Cancels an existing order in the order book.
     * @dev Allows a trader to cancel their own order. 
     *      The function checks that the caller is the owner of the order and that the order is active.
     *      Sets the order's active status to false and emits an OrderCancelled event.
    * @param orderId The identifier of the order to be cancelled.
    */
    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order already inactive");

        order.isActive = false;
        emit OrderCancelled(orderId);
        removeOrder(orderId, order.isBuyOrder);
    }

    /**
     * @notice Retrieves the best bid price from the order book.
     * @dev Returns the highest price that a buyer is willing to pay for a token. 
     *      If the buy order book is empty, returns zero.
     *      Calculates the best bid price as the division of amountToken2 by amountToken1 of the last buy order.
     * @return bestBidPrice The best bid price in the order book.
     */    
    function getBestBid() public view returns (uint256 bestBidPrice) {
        if (buyOrderIds.length == 0) return 0;
        Order storage bestBid = orders[buyOrderIds[buyOrderIds.length - 1]];
        bestBidPrice = safeDiv(bestBid.amountToken2, bestBid.amountToken1);
    }

    /**
     * @notice Retrieves the best ask price from the order book.
     * @dev Returns the lowest price that a seller is willing to accept for a token. 
     *      If the sell order book is empty, returns zero.
     *      Calculates the best ask price as the division of amountToken2 by amountToken1 of the first sell order.
     * @return bestAskPrice The best ask price in the order book.
     */
    function getBestAsk() public view returns (uint256 bestAskPrice) {
        if (sellOrderIds.length == 0) return 0;
        Order storage bestAsk = orders[sellOrderIds[0]];
        bestAskPrice = safeDiv(bestAsk.amountToken2, bestAsk.amountToken1);
    }

    /**
     * @notice Provides the depth of the order book.
     * @dev Returns the total number of active buy or sell orders in the order book.
     *      Helps in understanding the liquidity and depth of the market.
     * @param isBuyOrder Boolean to determine whether to return the depth of buy orders (true) or sell orders (false).
     * @return The number of active orders in the specified side of the order book.
     */
    function getOrderBookDepth(bool isBuyOrder) public view returns (uint256) {
        return isBuyOrder ? buyOrderIds.length : sellOrderIds.length;
    }

    /**
     * @notice Retrieves the state of a specific order by its ID.
     * @dev Returns all details of an order. 
     *      Validates that the order ID exists in the system before returning its state.
     * @param orderId The unique identifier of the order.
     * @return An Order struct containing all details of the order including trader, amounts, prices, and flags.
     */
    function getOrderState(uint256 orderId) public view returns (Order memory) {
        require(orderId < nextOrderId, "Invalid order ID");
        return orders[orderId];
    }

    /**
    * @notice Updates the Volume Weighted Average Price (VWAP) based on recent trades.
    * @dev Calculates VWAP using trades within the last 24 hours. 
    *      Iterates through the trades array in reverse order, summing up product of trade prices and amounts, 
     *      and divides by the total traded volume. VWAP is set to zero if there's no trading volume. Advanced order types are updated.
     *      This function is called after a new trade is executed.
    */
    function updateVWAP() internal {
        uint256 volumeWeightedSum = 0;
        uint256 totalVolume = 0;
        uint256 twentyFourHoursAgo = block.timestamp - 24 hours;

        for (uint i = trades.length; i > 0; i--) {
            Trade storage trade = trades[i - 1];
            if (trade.timestamp < twentyFourHoursAgo) break;

            volumeWeightedSum += trade.amountToken1 * trade.amountToken2;
            totalVolume += trade.amountToken2;
        }

        if (totalVolume > 0) {
            currentVWAP = volumeWeightedSum / totalVolume;
        } else {
            currentVWAP = 0;
        }

        updateOrderStates(currentVWAP);
        }

    /**
     * @notice Updates the state of all orders in the order book based on the current market price.
     * @param currentMarketPrice The current market price used to evaluate the orders. This contract uses the currentVWAP as this parameter.
     * 
     * This function iterates over all orders in the order book. For each order, it checks if the order is not already active and has a stop price. 
     * If the order is a buy order and the current market price is equal to or greater than the stop price, or if it's a sell order and the market price 
     * is equal to or less than the stop price, the order is activated. This is done by setting the order's 'isActive' status to true and inserting 
     * the order into the appropriate sorted order array (buy or sell). The function also emits an 'OrderActivated' event for each order that is activated.
     * 
     * Additionally, the function checks if the order has a trailing stop condition. If so, it calls `updateTrailingStopOrder` to potentially activate 
     * the trailing stop order based on the current market price and the order's specific conditions.
     */
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

    /**
     * @notice Updates trailing stop orders based on the current market price.
     * @param order The order to update, passed by storage reference.
     * @param orderId The unique identifier of the order.
     * @param currentMarketPrice The current market price used to evaluate the trailing stop condition.
     * 
     * This function is called for each order that has a trailing stop condition. It checks if the current market price has either risen above 
     * (for buy orders) or fallen below (for sell orders) the reference price by the specified trailing distance. If so, it activates the order:
     * 
     * - For buy orders, if the market price is higher than the order's reference price, the reference price is updated to the current market price. 
     *   If the market price has fallen to or below the reference price minus the trailing distance, the order is activated.
    * - For sell orders, if the market price is lower than the order's reference price, the reference price is updated to the current market price. 
     *   If the market price has risen to or above the reference price plus the trailing distance, the order is activated.
     * 
     * When an order is activated, it's inserted into the corresponding order array (buy or sell) and an 'OrderActivated' event is emitted.
     */
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

    /**
     * @notice Attempts to match buy and sell orders from the order book.
     * 
     * This function iterates through the lists of buy and sell orders. For each pair of orders, it checks if they are both active. 
     * If both orders are active, it calls 'isMatch' to determine if the orders can be matched based on their limit prices:
     * 
     * - If a match is found, 'executeTrade' is called to process the trade between the buy and sell orders.
     * - If either of the orders becomes inactive after the trade, the function advances to the next active order in the respective array.
     * 
     * The process continues until no more matches are possible or one of the order arrays is fully processed.
     */
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
                break;
            }
        }
    }

    /**
     * @notice Determines if two orders can be matched based on their prices.
     * @param buyOrder The buy order to be compared.
     * @param sellOrder The sell order to be compared.
    * @return bool Returns true if the buy order's price per unit is greater than or equal to the sell order's limit price, 
     * and the sell order's price per unit is less than or equal to the buy order's limit price; otherwise, returns false.
     * 
     * This function is critical in ensuring that trades occur at mutually agreeable prices. It calculates the price per unit of each order 
     * (amountToken2 divided by amountToken1) and compares these prices against the opposing order's limit price. A match occurs when the buy 
     * order's price per unit is at least the sell order's limit price, and the sell order's price per unit does not exceed the buy order's 
     * limit price, ensuring fair trading conditions for both parties.
     */
    function isMatch(Order storage buyOrder, Order storage sellOrder) internal view returns (bool) {
        uint256 buyPricePerUnit = safeDiv(buyOrder.amountToken2, buyOrder.amountToken1);
        uint256 sellPricePerUnit = safeDiv(sellOrder.amountToken2, sellOrder.amountToken1);

        return (buyPricePerUnit >= sellOrder.limitPrice) && (sellPricePerUnit <= buyOrder.limitPrice);
    }

    /**
     * @notice Executes a trade between a buy order and a sell order.
     * @param buyOrderId The identifier of the buy order.
     * @param sellOrderId The identifier of the sell order.
     * 
     * This function handles the execution of a trade when a match is found between a buy and a sell order. It:
     * 
     * - Calculates the trade amount (the amount of token1 that can be exchanged) based on the order details.
     * - Executes token transfers between the buyer and the seller, using the transfer functions of the IERC20 interface.
     * - Records the trade details (amounts and timestamp) for the Volume Weighted Average Price (VWAP) calculation.
     * - Updates the orders to reflect the executed trade.
     * - Handles iceberg order portions if applicable.
     * - Emits a 'TradeExecuted' event with trade details.
     * - Calls 'updateVWAP' to recalculate the VWAP based on the new trade data.
     * 
     * It ensures that trades are conducted in compliance with the order requirements and updates the state of the DEX accordingly.
     */   
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


    /**
     * @notice Updates an order's details after a trade has been executed.
     * @param order The order being updated.
     * @param tradeAmountToken1 The amount of token1 involved in the trade.
     * @param tradeAmountToken2 The amount of token2 involved in the trade.
     * @param orderId The identifier of the order being updated.
    * 
     * This function updates the amounts of tokens in an order post-trade, subtracting the traded amounts from the order's existing totals.
     * If the remaining amount of token1 in the order reaches zero, the order is marked as inactive and removed from the order book.
     * This function ensures that the order book accurately reflects the current state of all active orders.
     */
    function updateOrder(Order storage order, uint256 tradeAmountToken1, uint256 tradeAmountToken2, uint256 orderId) internal {
        order.amountToken1 -= tradeAmountToken1;
        order.amountToken2 -= tradeAmountToken2;

        if (order.amountToken1 == 0) {
            order.isActive = false;
            removeOrder(orderId, order.isBuyOrder);
        }
    }

    /**
     * @notice Calculates the tradeable amount of token1 based on the details of the buy and sell orders.
     * @param buyOrder The buy order involved in the trade.
     * @param sellOrder The sell order involved in the trade.
     * @return uint256 The amount of token1 that can be traded.
     * 
     * This function computes the minimum tradeable amount of token1 based on the available quantities in the buy and sell orders.
     * It respects the limit prices set in the orders to ensure that the trade occurs at acceptable prices for both parties.
     * A trade amount of zero is returned if the price conditions are not met, preventing any unfair trades.
     */
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

    /**
     * @notice Removes an order from the order book.
     * @param orderId The identifier of the order to be removed.
     * @param isBuyOrder A boolean indicating whether the order is a buy order.
     * 
     * This function removes an order from the order book, either from the buyOrderIds array or the sellOrderIds array, depending on the order type.
     * It shifts the remaining orders in the array to fill the gap left by the removed order, maintaining the integrity of the order book.
     * This is an essential cleanup operation following the completion or cancellation of an order.
     */
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

    /**
    * @notice Reveals the next portion of an iceberg order.
    * @param order The iceberg order being processed.
     * @param orderId The identifier of the iceberg order.
     * 
     * This function manages the iceberg order's visibility in the order book. It calculates the remaining hidden amount
     * and determines the next visible portion to be added to the order book.
     * The visible portion is updated in the order, and the order is re-inserted into the order book, ensuring
     * it maintains its position in the order queue.
     * This function is pivotal for the functionality of iceberg orders, allowing large orders to be executed
     * without revealing the total order size.
     */
    function revealNextIcebergPortion(Order storage order, uint256 orderId) internal {
        uint256 remainingHiddenAmount = order.icebergTotalAmount - order.amountToken1;
        if (remainingHiddenAmount > 0) {
            uint256 nextVisibleAmount = min(remainingHiddenAmount, order.icebergVisibleAmount);
            order.amountToken1 = nextVisibleAmount;
            order.amountToken2 = order.amountToken2 * nextVisibleAmount / order.icebergVisibleAmount;
            insertSorted(order.isBuyOrder ? buyOrderIds : sellOrderIds, orderId, order.isBuyOrder);
        }
    }

    /**
     * @notice Safely performs division to prevent division by zero errors.
     * @param a The dividend.
     * @param b The divisor.
     * @return uint256 The result of the division.
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }


    /**
     * @notice Returns the smaller of two numbers.
     * @param a The first number.
     * @param b The second number.
     * @return uint256 The smaller number.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }


    /**
     * @notice Inserts an order into the sorted order array.
     * @param orderArray The array of order IDs (either buy or sell orders).
     * @param orderId The ID of the order to insert.
     * @param isBuyOrder A boolean indicating if the order is a buy order.
     * 
     * This function inserts an order into the order array in a sorted manner, ensuring that the order book
     * maintains a correct order based on the price and timestamp of the orders. It uses a binary search
     * algorithm to find the correct position for the new order.
     * 
     * If the order array is empty, the new order is directly pushed to the array. If not, it compares
     * the new order's price (and timestamp, if prices are equal) with existing orders to find the right position.
     * 
     * For buy orders, it looks for a position where the new order's price is higher than or equal to existing orders.
     * For sell orders, it looks for a position where the new order's price is lower than or equal to existing orders.
     * 
     * Once the position is found, the function shifts other orders in the array to make space and inserts
     * the new order ID. This keeps the order book accurately sorted for efficient order matching.
     */
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
