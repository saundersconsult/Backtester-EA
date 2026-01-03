# Backtester-EA Parameters Guide

## Order Settings

### OrderType
Defines the type of order to place:
- **Market Buy**: Immediate buy at current ask price
- **Market Sell**: Immediate sell at current bid price
- **Buy Limit**: Buy when price reaches specified level (below current price)
- **Sell Limit**: Sell when price reaches specified level (above current price)
- **Buy Stop**: Buy when price reaches specified level (above current price)
- **Sell Stop**: Sell when price reaches specified level (below current price)

### EntryPrice
- **0 or empty**: Use current market price (for market orders)
- **Specific value**: Use this price for pending orders (Limit/Stop)
- Must be appropriate for the order type chosen

### StopLossPoints
Distance from entry price to stop loss in points.
- Example: 50 points on EURUSD = 0.0050 (5 pips on 5-digit broker)
- Must be greater than minimum stop level for symbol
- Used in risk calculation

### TakeProfitPoints
Distance from entry price to take profit in points.
- Example: 100 points on EURUSD = 0.0100 (10 pips on 5-digit broker)
- Must be greater than minimum stop level for symbol

## Risk Management

### RiskPercent
Percentage of account balance to risk per trade.
- **1.0**: Risk 1% of balance
- **2.0**: Risk 2% of balance
- Recommended: 0.5% - 2% for conservative trading
- Higher values increase both profit potential and risk

### StartingBalance
Initial account balance for backtest simulation.
- Set to match your intended account size
- Used for risk calculations
- Does not affect actual MT5 account balance (backtest only)

### UseFixedLotSize
Toggle between risk-based and fixed lot sizing.
- **false**: Calculate lot size based on RiskPercent
- **true**: Use FixedLotSize parameter

### FixedLotSize
Fixed lot size when UseFixedLotSize is true.
- Must be within symbol's min/max lot size limits
- Bypasses risk-based calculations

## Execution Settings

### MagicNumber
Unique identifier for EA trades.
- Allows EA to identify its own trades
- Use different numbers for multiple EAs on same account
- Default: 123456

### Symbol
Trading instrument.
- **Empty**: Use current chart symbol
- **Specific**: Trade specific symbol (e.g., "EURUSD")

### Slippage
Maximum acceptable price slippage in points.
- Only applies to market orders
- Protects against poor fills during volatile conditions
- Default: 10 points

### TradeComment
Comment attached to each trade.
- Helps identify trades in trade history
- Useful for tracking different EA configurations

## Backtest Control

### TradeOncePerBar
Controls trade frequency.
- **true**: Only one trade per bar (recommended for backtesting)
- **false**: Trade on every tick (may place multiple orders)
- Ignored when UseExactTime is enabled

### EnableOptimization
Flag for optimization mode.
- Set parameters you want to optimize in Strategy Tester
- Use "Optimization" tab to define ranges

## Exact Entry Time

### UseExactTime
Enable precise entry timing down to the second.
- **false**: Use standard entry logic (per bar or per tick)
- **true**: Enter order at exact date/time specified below
- When enabled, overrides TradeOncePerBar setting

### EntryYear
Year for exact entry (e.g., 2025).

### EntryMonth
Month for exact entry (1-12).

### EntryDay
Day for exact entry (1-31).

### EntryHour
Hour for exact entry (0-23, 24-hour format).

### EntryMinute
Minute for exact entry (0-59).

### EntrySecond
Second for exact entry (0-59).

**Example**: To enter at January 15, 2025 at 9:30:15 AM:
```
UseExactTime: true
EntryYear: 2025
EntryMonth: 1
EntryDay: 15
EntryHour: 9
EntryMinute: 30
EntrySecond: 15
```

## Risk Calculation Examples

### Example 1: Conservative (1% Risk)
```
Starting Balance: $10,000
Risk Percent: 1.0%
Stop Loss: 50 points
Symbol: EURUSD

Risk Amount = $10,000 × 1% = $100
Lot Size = $100 / (50 points × point value) ≈ 0.20 lots
```

### Example 2: Aggressive (5% Risk)
```
Starting Balance: $10,000
Risk Percent: 5.0%
Stop Loss: 50 points
Symbol: EURUSD

Risk Amount = $10,000 × 5% = $500
Lot Size = $500 / (50 points × point value) ≈ 1.00 lots
```

### Example 3: Fixed Lot
```
UseFixedLotSize: true
FixedLotSize: 0.1
Stop Loss: 50 points

Lot Size = 0.1 (fixed, regardless of risk %)
```

### Example 4: Exact Time Entry
```
UseExactTime: true
EntryYear: 2025
EntryMonth: 3
EntryDay: 15
EntryHour: 14
EntryMinute: 30
EntrySecond: 0

Order will be placed at: 2025.03.15 14:30:00
Perfect for tracking specific market events or news releases
```

## Optimization Tips

1. **Optimize Stop Loss and Take Profit**:
   - StopLossPoints: 20 to 200 (step 10)
   - TakeProfitPoints: 40 to 400 (step 20)

2. **Optimize Risk Settings**:
   - RiskPercent: 0.5 to 3.0 (step 0.5)

3. **Test Multiple Timeframes**:
   - Run optimization on M5, M15, H1, H4, D1

4. **Forward Testing**:
   - After optimization, test on different date ranges
   - Validate results are consistent

## Best Practices

1. **Risk Management**:
   - Never risk more than 2% per trade
   - Account for multiple simultaneous trades

2. **Stop Loss**:
   - Always use stop loss
   - Place beyond noise level for timeframe

3. **Take Profit**:
   - Aim for minimum 1:1.5 risk/reward ratio
   - Consider market conditions and volatility

4. **Starting Balance**:
   - Set realistic balance you plan to trade with
   - Test with different balance levels

5. **Backtesting**:
   - Use quality historical data
   - Test on sufficient data (1+ years)
   - Consider spread and commission costs
