//+------------------------------------------------------------------+
//|                                                Backtester_EA.mq5 |
//|                                    Copyright 2026, Backtester-EA |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Backtester-EA"
#property link      ""
#property version   "1.05"
#property description "Signal validator EA with timezone-based entry time, automatic broker TZ detection, and absolute price levels"

#include <Trade\Trade.mqh>
#include <BacktesterRisk.mqh>

//--- Input Parameters
input group "=== Order Settings ==="
enum ENUM_SIGNAL_DIRECTION
{
   SIGNAL_BUY,      // Buy Signal
   SIGNAL_SELL      // Sell Signal
};

input ENUM_SIGNAL_DIRECTION InpSignalDirection = SIGNAL_BUY;   // Signal Direction
input double InpEntryPrice = 0.0;                               // Entry Price (required)
input double InpStopLossPrice = 0.0;                           // Stop Loss Price (0=None)
input double InpTakeProfitPrice = 0.0;                         // Take Profit Price (0=None)

input group "=== Risk Management ==="
input double InpRiskPercent = 1.0;                             // Risk Per Trade (%)
input double InpStartingBalance = 10000.0;                     // Starting Balance
input bool   InpUseFixedLotSize = false;                       // Use Fixed Lot Size
input double InpFixedLotSize = 0.1;                            // Fixed Lot Size

input group "=== Execution Settings ==="
input int    InpMagicNumber = 123456;                          // Magic Number
input string InpSymbol = "";                                   // Symbol (empty=current)
input int    InpSlippage = 10;                                 // Slippage (points)
input string InpTradeComment = "Backtester-EA";                // Trade Comment

input group "=== Backtest Control ==="
input bool   InpTradeOncePerBar = true;                        // Trade Once Per Bar
input bool   InpEnableOptimization = false;                    // Enable Optimization

input group "=== Exact Entry Time ==="
input bool   InpUseExactTime = false;                          // Use Exact Entry Time
input double InpSignalTimezoneOffset = 0.0;                    // Signal Timezone UTC Offset (hours, e.g., -5 for EST)
input int    InpEntryYear = 2025;                              // Entry Year (in signal timezone)
input int    InpEntryMonth = 1;                                // Entry Month (1-12, in signal timezone)
input int    InpEntryDay = 1;                                  // Entry Day (1-31, in signal timezone)
input int    InpEntryHour = 9;                                 // Entry Hour (0-23, in signal timezone)
input int    InpEntryMinute = 30;                              // Entry Minute (0-59, in signal timezone)
input int    InpEntrySecond = 0;                               // Entry Second (0-59, in signal timezone)

//--- Global Variables
CTrade trade;
CBacktesterRisk riskCalc;
datetime lastBarTime = 0;
bool orderPlaced = false;
datetime exactEntryTime = 0;
bool exactTimeReached = false;
int brokerUTCOffsetSeconds = 0;  // Broker's UTC offset in seconds

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Detect broker's UTC offset
   datetime serverTime = TimeCurrent();   // Server time in broker timezone
   datetime gmtTime = TimeGMT();          // GMT/UTC time
   brokerUTCOffsetSeconds = (int)(serverTime - gmtTime);
   
   double brokerUTCOffset = brokerUTCOffsetSeconds / 3600.0;
   Print("Broker UTC offset: ", brokerUTCOffset, " hours");
   
   //--- Initialize risk calculator
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   riskCalc.Init(symbol, InpStartingBalance);
   
   //--- Validate inputs
   if(InpRiskPercent <= 0 || InpRiskPercent > 100)
   {
      Print("Error: Risk percent must be between 0 and 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpStartingBalance <= 0)
   {
      Print("Error: Starting balance must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpEntryPrice <= 0)
   {
      Print("Error: Entry price must be specified");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Build exact entry time if enabled
   if(InpUseExactTime)
   {
      //--- Create time from inputs (in signal timezone)
      MqlDateTime dtSignal;
      dtSignal.year = InpEntryYear;
      dtSignal.mon = InpEntryMonth;
      dtSignal.day = InpEntryDay;
      dtSignal.hour = InpEntryHour;
      dtSignal.min = InpEntryMinute;
      dtSignal.sec = InpEntrySecond;
      
      datetime signalTime = StructToTime(dtSignal);
      
      if(signalTime <= 0)
      {
         Print("Error: Invalid entry date/time specified");
         return INIT_PARAMETERS_INCORRECT;
      }
      
      //--- Convert signal timezone to UTC
      int signalTZOffsetSeconds = (int)(InpSignalTimezoneOffset * 3600);
      datetime utcTime = signalTime - signalTZOffsetSeconds;
      
      //--- Convert UTC to broker's local time
      exactEntryTime = utcTime + brokerUTCOffsetSeconds;
      
      Print("Signal time entered: ", TimeToString(signalTime, TIME_DATE|TIME_SECONDS), 
            " (", InpSignalTimezoneOffset, " UTC)");
      Print("Converted to UTC: ", TimeToString(utcTime, TIME_DATE|TIME_SECONDS));
      Print("Broker UTC offset: ", (brokerUTCOffsetSeconds / 3600.0), " hours");
      Print("Exact entry time (broker local): ", TimeToString(exactEntryTime, TIME_DATE|TIME_SECONDS));
   }
   
   Print("Backtester-EA initialized successfully");
   Print("Symbol: ", symbol);
   Print("Starting Balance: ", InpStartingBalance);
   Print("Risk per trade: ", InpRiskPercent, "%");
   if(InpStopLossPrice > 0)
      Print("Stop Loss: ", InpStopLossPrice);
   if(InpTakeProfitPrice > 0)
      Print("Take Profit: ", InpTakeProfitPrice);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Backtester-EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- If using exact entry time, check if we've reached it
   if(InpUseExactTime)
   {
      datetime currentTime = TimeCurrent();
      
      // Skip if exact time not reached yet
      if(!exactTimeReached && currentTime < exactEntryTime)
         return;
      
      // Mark as reached when time matches or passes
      if(!exactTimeReached && currentTime >= exactEntryTime)
      {
         exactTimeReached = true;
         Print(">>> EXACT TIME REACHED: ", TimeToString(currentTime, TIME_DATE|TIME_SECONDS));
         Print(">>> Proceeding to place order...");
      }
      
      // Skip if we already placed order after reaching exact time
      if(exactTimeReached && orderPlaced)
      {
         return;
      }
      
      if(!exactTimeReached)
      {
         Print("DEBUG: Waiting for exact time. Current: ", TimeToString(currentTime, TIME_DATE|TIME_SECONDS), 
               " Target: ", TimeToString(exactEntryTime, TIME_DATE|TIME_SECONDS));
         return;
      }
   }
   else
   {
      //--- Check if we should trade once per bar (only when not using exact time)
      if(InpTradeOncePerBar)
      {
         datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
         if(currentBarTime == lastBarTime)
            return;
         lastBarTime = currentBarTime;
      }
      
      //--- Skip if order already placed (for single-trade mode)
      if(orderPlaced)
         return;
   }
   
   Print(">>> Preparing order placement...");
   
   //--- Get symbol info
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   
   //--- Get current prices
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double entryPrice = InpEntryPrice;
   
   Print(">>> Current Prices - Bid: ", bid, " Ask: ", ask);
   Print(">>> Entry Price: ", entryPrice);
   Print(">>> Signal Direction: ", (InpSignalDirection == SIGNAL_BUY ? "BUY" : "SELL"));
   
   //--- Calculate lot size based on risk
   double lotSize;
   if(InpUseFixedLotSize)
   {
      lotSize = InpFixedLotSize;
   }
   else
   {
      // Calculate stop loss distance in points for risk calculation
      double stopLossDistance = 0;
      
      if(InpStopLossPrice > 0)
      {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         stopLossDistance = MathAbs(entryPrice - InpStopLossPrice) / point;
      }
      else
      {
         stopLossDistance = 50; // Default if no SL specified
      }
      
      lotSize = riskCalc.CalculateLotSize(InpRiskPercent, stopLossDistance);
   }
   
   //--- Use absolute SL and TP prices
   double stopLoss = InpStopLossPrice;
   double takeProfit = InpTakeProfitPrice;
   
   //--- Normalize prices
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(stopLoss > 0)
      stopLoss = NormalizeDouble(stopLoss, digits);
   if(takeProfit > 0)
      takeProfit = NormalizeDouble(takeProfit, digits);
   
   Print(">>> Determining order type...");
   
   //--- Declare variables for order placement
   bool result = false;
   string orderTypeStr = "";
   
   if(InpSignalDirection == SIGNAL_BUY)
   {
      // Buy signal: use Limit if entry below current price, Stop if above
      if(entryPrice < ask)
      {
         orderTypeStr = "Buy Limit";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") < Ask (", ask, ")");
         Print(">>> Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
         result = trade.BuyLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
      else
      {
         orderTypeStr = "Buy Stop";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") >= Ask (", ask, ")");
         Print(">>> Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
         result = trade.BuyStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
   }
   else // SIGNAL_SELL
   {
      // Sell signal: use Limit if entry above current price, Stop if below
      if(entryPrice > bid)
      {
         orderTypeStr = "Sell Limit";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") > Bid (", bid, ")");
         Print(">>> Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
         result = trade.SellLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
      else
      {
         orderTypeStr = "Sell Stop";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") <= Bid (", bid, ")");
         Print(">>> Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
         result = trade.SellStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
   }
   
   Print(">>> Order placement result: ", (result ? "SUCCESS" : "FAILED"));
   if(!result)
   {
      Print(">>> Error code: ", GetLastError());
      Print(">>> Return code: ", trade.ResultRetcode());
      Print(">>> Description: ", trade.ResultRetcodeDescription());
   }
   
   if(result)
   {
      datetime entryTime = TimeCurrent();
      Print("========================================");
      Print("SIGNAL VALIDATED - Pending Order Placed");
      Print("Signal Time: ", TimeToString(entryTime, TIME_DATE|TIME_SECONDS));
      Print("Symbol: ", symbol);
      Print("Direction: ", (InpSignalDirection == SIGNAL_BUY ? "BUY" : "SELL"));
      Print("Order Type: ", orderTypeStr);
      Print("Lot Size: ", lotSize);
      Print("Entry Price: ", DoubleToString(entryPrice, digits));
      Print("Stop Loss: ", (stopLoss > 0 ? DoubleToString(stopLoss, digits) : "None"));
      Print("Take Profit: ", (takeProfit > 0 ? DoubleToString(takeProfit, digits) : "None"));
      Print("Current Ask: ", DoubleToString(ask, digits), " | Bid: ", DoubleToString(bid, digits));
      Print("========================================");
      orderPlaced = true;
   }
   else
   {
      Print("Order failed. Error: ", GetLastError(), " - ", trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
