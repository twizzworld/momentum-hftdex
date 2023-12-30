```
███╗░░░███╗░█████╗░███╗░░░███╗███████╗███╗░░██╗████████╗██╗░░░██╗███╗░░░███╗
████╗░████║██╔══██╗████╗░████║██╔════╝████╗░██║╚══██╔══╝██║░░░██║████╗░████║
██╔████╔██║██║░░██║██╔████╔██║█████╗░░██╔██╗██║░░░██║░░░██║░░░██║██╔████╔██║
██║╚██╔╝██║██║░░██║██║╚██╔╝██║██╔══╝░░██║╚████║░░░██║░░░██║░░░██║██║╚██╔╝██║
██║░╚═╝░██║╚█████╔╝██║░╚═╝░██║███████╗██║░╚███║░░░██║░░░╚██████╔╝██║░╚═╝░██║
╚═╝░░░░░╚═╝░╚════╝░╚═╝░░░░░╚═╝╚══════╝╚═╝░░╚══╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░╚═╝

███╗░░░███╗░█████╗░██████╗░██╗░░██╗███████╗████████╗░██████╗
████╗░████║██╔══██╗██╔══██╗██║░██╔╝██╔════╝╚══██╔══╝██╔════╝
██╔████╔██║███████║██████╔╝█████═╝░█████╗░░░░░██║░░░╚█████╗░
██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗░██╔══╝░░░░░██║░░░░╚═══██╗
██║░╚═╝░██║██║░░██║██║░░██║██║░╚██╗███████╗░░░██║░░░██████╔╝
╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝░░░╚═╝░░░╚═════╝░
```

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
2. **OrderbookFactory**: Orderbook deployer for token pairs.

Tentative Supported Tokens:
```
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
```
### Leveraged Trading Contracts

1. **MarginAccount**: To manage individual trader's margin accounts, tracking the amounts borrowed and the associated liabilities.

2. **LendingPool and LendingPoolFactory**: To facilitate the lending of assets. This pool can be funded by other users who earn interest on their lent assets.

3. **Liquidation Contract**: To handle the liquidation of positions that fall below a certain maintenance margin, ensuring lenders are repaid.

4. **Oracle**: To provide reliable price feeds which are crucial for calculating the value of collateral and triggering liquidations.

## Order Types

HFTDEX currently supports:
```
1. Market Orders
2. Limit Orders
3. Stop Orders
4. Stop Limit Orders
5. Trailing Stop Orders
6. Iceberg Orders
```
Momentum plans to make more advanced order types available through the frontend. 

Traders can also make their own custom order types through utilizing the API.  



