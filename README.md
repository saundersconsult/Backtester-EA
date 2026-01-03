# Backtester-EA

MetaTrader 5 Expert Advisor for precise signal validation backtesting with timezone support and exact entry timing.

## Features

- **Signal Validation**: Test signals from providers at exact times with exact entry/exit prices
- **Timezone Support**: Enter signals in your own timezone - EA converts to broker timezone automatically
- **Exact Time Entry**: Trade at specific date/time (down to the second) for precise signal testing
- **Flexible SL/TP**: Test with or without stop loss, take profit, or both
- **Risk Management**: Automatic lot sizing based on risk percentage and stop loss distance
- **Any Symbol/Timeframe**: Works on all MT5 symbols and timeframes
- **Pending Orders Only**: Places pending Limit/Stop orders (no market orders) for accurate backtest conditions

## Quick Start

1. Copy `MQL5/Experts/Backtester_EA.mq5` to MT5 `Experts` folder
2. Copy `MQL5/Include/BacktesterRisk.mqh` to MT5 `Include` folder
3. Compile in MetaEditor (F7)
4. In Strategy Tester: Set signal parameters → Run without Optimization → Check Journal

## Configuration

**Signal Settings:**
- `Signal Timezone UTC Offset`: Your signal's timezone (e.g., -5 for EST, 0 for UTC, +5.5 for IST)
- `Entry Year/Month/Day/Hour/Minute/Second`: Signal time in that timezone

**Order Details:**
- `Signal Direction`: BUY or SELL
- `Entry Price`: Exact entry price (required)
- `Stop Loss Price`: SL price, or 0 for no stop loss
- `Take Profit Price`: TP price, or 0 for no take profit

**Risk:**
- `Risk Percent`: Risk per trade as % (e.g., 1.0 = 1%)
- `Use Fixed Lot Size`: Optional fixed lot size instead of risk-based

## How It Works

1. **Entry Signal**: Specify time in your signal provider's timezone
2. **Timezone Conversion**: EA auto-detects broker UTC offset, converts signal time accordingly
3. **Order Placement**: At exact broker time, places pending order (Limit/Stop based on entry price vs current price)
4. **Backtest Result**: See if signal would have been profitable using actual tick data

## Documentation

See `docs/` folder:
- `PARAMETERS.md`: Detailed parameter guide
- `INSTALLATION.md`: Setup instructions

## Version

**v1.06** - Fixed optional SL/TP handling, UTC timezone support, risk-based lot sizing

## Requirements

- MetaTrader 5 build 3770+
- MQL5 compiler

## License

MIT License
