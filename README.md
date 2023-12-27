# Momentum HFTDEX

An Orderbook DEX with support for High Frequency Trading.

Components of an Orderbook DEX:

* Order Types
* Matching Engine

Additional Features of HFTDEX

* Leveraged trading
* Liquidity Pools & Arbitrage

## HFTDEX Architecture

1. **Orderbook Contract**: Manages the limit orders, storing the buy and sell orders in sorted data structures to facilitate quick matching.

2. **Trade Executor Contract**: Responsible for matching buy and sell orders from the order book and executing trades.

3. **Margin Account Contract**: Handles margin accounts for each trader, tracking deposited collateral, borrowed funds, and managing liquidations as necessary.

4. **Collateral Management Contract**: Controls the collateral posted by users, ensuring that it is sufficient for the leverage provided and handling collateral updates.

5. **Pricing Oracle Contract**: Integrates with external or internal oracles to provide real-time price feeds for accurate margin and liquidation calculations.

6. **Leverage Management Contract**: Sets the rules for maximum leverage allowed, calculates required collateral, and enforces leverage limits.



## Order Types

Advanced order types are crucial in trading platforms, especially for sophisticated trading strategies. Here's a list of the order types:

1. **Limit Order**: An order to buy or sell an asset at a specified price or better.

2. **Market Order**: An order to buy or sell an asset immediately at the best available current price.

3. **Stop Order (Stop Loss)**: An order to buy or sell an asset once the price of the asset reaches a specified price, known as the stop price.

4. **Stop Limit Order**: Combines a stop order with a limit order. Once the stop price is reached, a limit order is triggered to buy/sell at a specific price or better.

5. **Trailing Stop Order**: Similar to a stop order, but the stop price trails the market price of the asset by a specified distance.

6. **Iceberg Order**: A large order that has been divided into smaller lots, hidden except for a small portion of the total order to mask the actual order quantity.

7. **Bracket Order**: A three-component order where an initial order (like a limit order) is placed along with two additional instructions for a stop loss and a take profit order.

8. **Good 'Til Canceled (GTC)**: An order to buy or sell at a set price that remains active until the investor cancels it or the trade is executed.

9. **Day Order**: An order that expires if not executed by the end of the trading day.

These advanced order types enable traders to implement complex trading strategies and manage risk more effectively in volatile markets.



