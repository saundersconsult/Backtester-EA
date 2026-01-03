# Backtester-EA

MetaTrader 5 Expert Advisor for precise backtesting with configurable order entry parameters.

## Features

- **Configurable Order Entry**: Set order type, instrument, entry price, stop loss, and take profit
- **Risk Management**: Define risk as percentage of account balance
- **Flexible Balance**: Set starting account balance for backtesting
- **Any Timeframe**: Works on all MT5 timeframes (M1, M5, H1, D1, etc.)
- **Optimization Ready**: All parameters can be optimized in MT5 Strategy Tester

## Installation

1. Copy `MQL5/Experts/Backtester_EA.mq5` to your MT5 `Experts` folder
2. Copy files from `MQL5/Include/` to your MT5 `Include` folder
3. Compile in MetaEditor (F7)
4. Attach to any chart in MT5

## Parameters

### Order Settings
- **OrderType**: Market Buy, Market Sell, Buy Limit, Sell Limit, Buy Stop, Sell Stop
- **EntryPrice**: Entry price (0 = current market price for market orders)
- **StopLoss**: Stop loss price in points or absolute price
- **TakeProfit**: Take profit price in points or absolute price

### Risk Management
- **RiskPercent**: Risk per trade as % of balance (e.g., 1.0 = 1%)
- **StartingBalance**: Initial account balance for backtest

### Execution
- **Symbol**: Trading instrument (auto-detects current chart symbol)
- **MagicNumber**: Unique identifier for EA trades
- **EnableOptimization**: Enable/disable parameter optimization

## Usage

### Basic Backtest
1. Open Strategy Tester (Ctrl+R)
2. Select `Backtester_EA`
3. Configure parameters in "Inputs" tab
4. Set date range and run backtest

### With Optimization
1. Enable "Optimization" in Strategy Tester
2. Select parameters to optimize
3. Run optimization to find best settings

## Documentation

See `docs/` folder for:
- Detailed parameter descriptions
- Risk calculation examples
- Optimization guides
- Best practices

## Requirements

- MetaTrader 5 build 3770+
- MQL5 compiler

## License

MIT License - See LICENSE file
