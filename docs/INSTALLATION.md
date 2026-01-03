# Installation Guide

## Quick Install

1. **Locate your MT5 Data Folder**:
   - Open MT5
   - Click File → Open Data Folder
   - This opens: `C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5`

2. **Copy Files**:
   ```
   Copy Backtester_EA.mq5 → MQL5\Experts\
   Copy BacktesterRisk.mqh → MQL5\Include\
   ```

3. **Compile**:
   - Open MetaEditor (F4 in MT5)
   - Open `Backtester_EA.mq5`
   - Click Compile (F7)
   - Should see "0 error(s), 0 warning(s)"

4. **Verify**:
   - In MT5 Navigator panel
   - Expand "Expert Advisors"
   - You should see "Backtester_EA"

## Detailed Installation

### Step 1: Install EA File

From this repository:
```
I:\Development\Backtester-EA\MQL5\Experts\Backtester_EA.mq5
```

Copy to MT5:
```
[MT5 Data Folder]\MQL5\Experts\Backtester_EA.mq5
```

### Step 2: Install Include Files

From this repository:
```
I:\Development\Backtester-EA\MQL5\Include\BacktesterRisk.mqh
```

Copy to MT5:
```
[MT5 Data Folder]\MQL5\Include\BacktesterRisk.mqh
```

### Step 3: Compile

1. Open MetaEditor
2. File → Open → Navigate to `Experts\Backtester_EA.mq5`
3. Press F7 (Compile)
4. Check "Toolbox" window for errors
5. If successful, `.ex5` file created in same folder

### Step 4: Attach to Chart

1. Open any chart in MT5
2. Find `Backtester_EA` in Navigator → Expert Advisors
3. Drag onto chart
4. Configure parameters in dialog
5. Click "OK"

## Using in Strategy Tester

1. **Open Strategy Tester**: Ctrl+R or View → Strategy Tester

2. **Select EA**: 
   - Expert Advisor: `Backtester_EA`

3. **Configure Test**:
   - Symbol: Choose your instrument
   - Period: Choose timeframe (M1, M5, H1, etc.)
   - Model: Every tick (most accurate)
   - Date range: Set start and end dates

4. **Set Parameters**:
   - Click "Expert properties" button
   - "Inputs" tab
   - Configure order settings, risk, etc.

5. **Run**:
   - Click "Start" button
   - Monitor results in "Results" and "Graph" tabs

## Optimization Setup

1. In Strategy Tester, enable "Optimization"

2. Click "Expert properties" → "Inputs" tab

3. Check boxes next to parameters to optimize

4. Set Start, Step, Stop values:
   ```
   Example for StopLossPoints:
   Start: 20
   Step: 10
   Stop: 200
   ```

5. Click "Start" to begin optimization

6. Results appear in "Optimization Results" tab

## Troubleshooting

### Compilation Errors

**Error**: "Cannot open include file BacktesterRisk.mqh"
- **Solution**: Verify BacktesterRisk.mqh is in `MQL5\Include\` folder

**Error**: "Trade.mqh not found"
- **Solution**: Update MT5 to latest version (includes standard library)

### Runtime Errors

**Error**: "Trade not allowed"
- **Solution**: Enable AutoTrading (Ctrl+E) or check Strategy Tester settings

**Error**: "Invalid stops"
- **Solution**: Ensure StopLoss and TakeProfit meet symbol's minimum levels

**Error**: "Invalid lot size"
- **Solution**: Check symbol's min/max lot sizes, adjust RiskPercent or use FixedLotSize

### EA Not Appearing

1. Refresh Navigator (right-click → Refresh)
2. Check compilation was successful
3. Restart MT5

## System Requirements

- MetaTrader 5 build 3770 or higher
- Windows 7/8/10/11 or Wine on Mac/Linux
- Sufficient historical data for backtesting

## Next Steps

After installation:
1. Read [PARAMETERS.md](PARAMETERS.md) for parameter details
2. Run a test backtest with default settings
3. Review results and adjust parameters
4. Optimize for your trading strategy

## Support

For issues or questions:
- Check docs folder for guides
- Review MT5 documentation
- Check MetaTrader forums
