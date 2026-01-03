# Backtester-EA Parameters Guide (v1.06)

## Order Settings

### Signal Direction
Specifies trade direction:
- **BUY**: Place buy order (Limit if entry < ask, Stop if entry > ask)
- **SELL**: Place sell order (Limit if entry > bid, Stop if entry < bid)

### Entry Price (Required)
The price at which to enter the trade.
- Must be specified (cannot be 0)
- Compared against current bid/ask to determine Limit vs Stop order
- Examples:
  - BUY at 1.0850: If current ask=1.0852, uses Buy Limit; if ask=1.0848, uses Buy Stop
  - SELL at 1.0850: If current bid=1.0851, uses Sell Limit; if bid=1.0852, uses Sell Stop

### Stop Loss Price (Optional)
Absolute price where stop loss triggers.
- **0 (default)**: No stop loss
- **Specific price**: Activates stop loss at this level
- Examples: Entry=1.0850, Stop Loss=1.0800 (50 pips risk for EUR/USD)

### Take Profit Price (Optional)
Absolute price where take profit triggers.
- **0 (default)**: No take profit (manual exit)
- **Specific price**: Activates take profit at this level
- Examples: Entry=1.0850, Take Profit=1.0950 (100 pips profit for EUR/USD)

## Risk Management

### Risk Percent
Percentage of starting balance to risk per trade.
- **1.0**: Risk 1% of balance ($100 on $10,000 account)
- **2.0**: Risk 2% of balance ($200 on $10,000 account)
- Used to auto-calculate lot size based on stop loss distance
- Recommended range: 0.5% - 2%

### Starting Balance
Initial account balance for backtesting.
- Set to your intended trading account size
- Used for risk calculations and lot sizing
- Does not affect actual MT5 account

### Use Fixed Lot Size
Toggle between risk-based and fixed lot sizing.
- **false (default)**: Calculate lot size from RiskPercent and Stop Loss distance
- **true**: Use FixedLotSize parameter instead

### Fixed Lot Size
Manual lot size when UseFixedLotSize = true.
- Bypasses risk-based calculations
- Must comply with symbol's lot step and limits
- Typical example: 0.1 lots

## Execution Settings

### Magic Number
Unique identifier for all EA trades.
- Default: 123456
- Change if running multiple EAs on same account

### Symbol
Trading instrument.
- **Empty (default)**: Uses current chart symbol
- **Specific**: Enter symbol code (e.g., "EURUSD", "GBPUSD")

### Slippage
Maximum acceptable slippage in points for pending order fills.
- Default: 10 points
- Higher values = more lenient fill acceptance

### Trade Comment
Text identifier attached to each trade.
- Helps identify trades in journal
- Example: "Signal-Provider-A"

## Backtest Control

### Trade Once Per Bar
Controls trade frequency when not using exact time.
- **true (default)**: Maximum one trade per bar
- **false**: Can trade multiple times per bar

### Enable Optimization
Enable/disable parameter optimization in Strategy Tester.
- Used when testing different parameter ranges
- Set to false for single signal testing

## Signal Timezone & Exact Entry Time

### Use Exact Entry Time
Enable precise entry at exact date/time.
- **false (default)**: Standard entry logic
- **true**: Enter at specific date/time (down to second)

### Signal Timezone UTC Offset
Your signal provider's timezone as offset from UTC.
- **-5**: Eastern Standard Time (EST)
- **-6**: Central Standard Time (CST)
- **-8**: Pacific Standard Time (PST)
- **0**: UTC/GMT
- **+1**: Central European Time (CET)
- **+5.5**: Indian Standard Time (IST)
- **+9**: Japan Standard Time (JST)

EA will auto-convert your signal time to broker's timezone.

### Entry Year, Month, Day, Hour, Minute, Second
Signal entry time in your specified timezone.
- All values in 24-hour format
- Example: EST signal at 9:30:00 AM on Jan 15, 2025
  ```
  Signal Timezone UTC Offset: -5
  Entry Year: 2025
  Entry Month: 1
  Entry Day: 15
  Entry Hour: 9
  Entry Minute: 30
  Entry Second: 0
  ```
  EA automatically converts EST→UTC→Broker timezone

## Examples

### Example 1: Simple Buy Signal (No SL/TP)
```
Signal Direction: BUY
Entry Price: 1.0850
Stop Loss Price: 0
Take Profit Price: 0
Risk Percent: 1.0
Starting Balance: 10000
Use Exact Entry Time: false
```
Result: Places buy order when conditions met, no risk management.

### Example 2: EST Signal with Stop Loss
```
Signal Direction: BUY
Entry Price: 1.0850
Stop Loss Price: 1.0800 (50 pips risk)
Take Profit Price: 0
Risk Percent: 1.0
Starting Balance: 10000
Use Exact Entry Time: true
Signal Timezone UTC Offset: -5
Entry Year: 2025
Entry Month: 1
Entry Day: 15
Entry Hour: 14
Entry Minute: 30
Entry Second: 0
```
Result: At 2:30 PM EST (converted to broker time), places buy order with 50-pip stop loss.

### Example 3: Risk-Based Lot Sizing
```
Entry Price: 1.0850
Stop Loss Price: 1.0800 (50 points)
Risk Percent: 1.0
Starting Balance: 10000

Calculation:
- Risk amount = $10,000 × 1% = $100
- Point value on EURUSD = $10 per point
- Lot size = $100 / (50 points × $10) = 0.2 lots
```

### Example 4: IST Signal Testing
```
Signal Provider: India-based (IST = UTC+5:30)
Signal Timezone UTC Offset: +5.5
Entry Year: 2025
Entry Month: 1
Entry Day: 16
Entry Hour: 10
Entry Minute: 30
Entry Second: 0
```
EA converts: 10:30 IST → 5:00 UTC → Broker's local time

## Testing Checklist

- [ ] Set correct Signal Timezone offset for your signal provider
- [ ] Enter signal time in YOUR timezone (EA handles conversion)
- [ ] Specify Entry Price (required)
- [ ] Decide on Stop Loss (0 = no SL)
- [ ] Decide on Take Profit (0 = no TP)
- [ ] Set Risk Percent or Fixed Lot Size
- [ ] Run without Optimization checkbox
- [ ] Check Journal for timezone conversion verification
- [ ] Verify order placed at correct time/price

## Troubleshooting

**Order not placing:**
- Check Journal for error messages
- Verify Entry Price > 0
- Confirm exact time hasn't already passed in test date range
- Ensure sufficient tick data for backtest period

**Wrong time conversion:**
- Verify Signal Timezone UTC Offset is correct
- Check Journal shows correct "Converted to UTC" time
- Verify broker timezone detected correctly

**Wrong lot size:**
- For risk-based: Ensure Stop Loss price < Entry (BUY) or > Entry (SELL)
- For fixed: Verify lot size is within symbol limits
- Check Journal for calculated lot size
