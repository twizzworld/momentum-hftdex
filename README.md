# Momentum HFTDEX

An Orderbook DEX with support for High Frequency Trading.

Components of an Orderbook DEX:

* Order Types
* Matching Engine

Additional Features of HFTDEX

* Leveraged trading
* Liquidity Pools & Arbitrage

## HFTDEX Architecture

### Core

Orderbook Contracts.

1. **Orderbook Contract**: Orderbook for a token pair.
2. **OrderbookFactory**: Orderbook deployer for token pairs. Planned Pairs:
   * WETH
   * USDC
   * USDT
   * BTC
   * USDP
   * DAI
   * BUSD
   * UST
   * BNB
   * TUSD
   * UNI
   * AAVE
   * LINK
   * SOL
   * NEAR
   * HBAR
   * AVAX
   * MATIC
   * LTC
   * ICP

### Leveraged Trading Contracts

1. **MarginAccount**: To manage individual trader's margin accounts, tracking the amounts borrowed and the associated liabilities.

2. **LendingPool and LendingPoolFactory**: To facilitate the lending of assets. This pool can be funded by other users who earn interest on their lent assets.

3. **Liquidation Contract**: To handle the liquidation of positions that fall below a certain maintenance margin, ensuring lenders are repaid.

4. **Oracle**: To provide reliable price feeds which are crucial for calculating the value of collateral and triggering liquidations.

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



