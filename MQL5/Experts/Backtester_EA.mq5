//+------------------------------------------------------------------+
//|                                                Backtester_EA.mq5 |
//|                                    Copyright 2026, Backtester-EA |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Backtester-EA"
#property link      ""
#property version   "1.11"
#property description "Signal validator EA with timezone-based entry time, visual lines, and absolute price levels"

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

input group "=== Visual Validation ==="
input bool   InpShowVisualLines = false;                       // Show entry/SL/TP lines on chart
input color  InpEntryLineColor = clrDodgerBlue;                // Entry line color
input color  InpTakeProfitLineColor = clrLimeGreen;            // Take Profit line color
input color  InpStopLossLineColor = clrRed;                    // Stop Loss line color
input int    InpEntryLineWidth = 1;                            // Entry line width (1-5)
input int    InpTpLineWidth = 1;                               // TP line width (1-5)
input int    InpSlLineWidth = 1;                               // SL line width (1-5)
input int    InpEntryLineStyle = STYLE_SOLID;                  // Entry line style
input int    InpTpLineStyle = STYLE_SOLID;                     // TP line style
input int    InpSlLineStyle = STYLE_SOLID;                     // SL line style

input group "=== Order Expiry ==="
enum ENUM_EXPIRY_MODE
{
   EXPIRY_MINUTES,     // Expire after N minutes from placement
   EXPIRY_HOURS,       // Expire after N hours from placement
   EXPIRY_ABSOLUTE     // Expire at specific date/time
};

input bool   InpUseExpiry = false;                             // Enable order/position expiry
input ENUM_EXPIRY_MODE InpExpiryMode = EXPIRY_MINUTES;         // Expiry mode
input int    InpExpiryMinutes = 60;                            // Minutes until expiry (for minutes mode)
input int    InpExpiryHours = 1;                               // Hours until expiry (for hours mode)
input double InpExpiryTimezoneOffset = 0.0;                    // Expiry absolute time timezone offset (hours)
input int    InpExpiryYear = 2025;                             // Expiry Year (absolute mode)
input int    InpExpiryMonth = 1;                               // Expiry Month (1-12, absolute mode)
input int    InpExpiryDay = 1;                                 // Expiry Day (1-31, absolute mode)
input int    InpExpiryHour = 0;                                // Expiry Hour (0-23, absolute mode)
input int    InpExpiryMinute = 0;                              // Expiry Minute (0-59, absolute mode)
input int    InpExpirySecond = 0;                              // Expiry Second (0-59, absolute mode)

//--- Global Variables
CTrade trade;
CBacktesterRisk riskCalc;
datetime lastBarTime = 0;
bool orderPlaced = false;
datetime exactEntryTime = 0;
bool exactTimeReached = false;
int brokerUTCOffsetSeconds = 0;  // Broker's UTC offset in seconds
string linePrefix = "";         // Prefix for visual objects
string persistentFlagName = ""; // Global variable key to persist one-and-done state
string normalizedSymbol = "";    // Cached normalized symbol
datetime expiryTime = 0;          // When to expire order/position (broker time)
bool expirySet = false;           // Whether expiryTime is active

//--- Helpers for visual lines
int ClampLineWidth(const int w)
{
   if(w < 1) return 1;
   if(w > 5) return 5;
   return w;
}

void DrawOrUpdateLine(const string name, const double price, const color lineColor, const int style, const int width, const int digits)
{
   if(price <= 0)
   {
      ObjectDelete(0, name);
      return;
   }

   double p = NormalizeDouble(price, digits);

   bool exists = (ObjectFind(0, name) >= 0);
   if(!exists)
   {
      // Create once; HLINE stays perfectly horizontal
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, p))
      {
         Print("Failed to create line: ", name, " error: ", GetLastError());
         return;
      }
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetDouble(0, name, OBJPROP_PRICE, p);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, ClampLineWidth(width));
}

void RemoveVisualLines()
{
   ObjectDelete(0, linePrefix + "Entry");
   ObjectDelete(0, linePrefix + "TP");
   ObjectDelete(0, linePrefix + "SL");
}

void UpdateVisualLines()
{
   if(!InpShowVisualLines)
   {
      RemoveVisualLines();
      return;
   }

   int digits = (int)SymbolInfoInteger((InpSymbol == "") ? _Symbol : InpSymbol, SYMBOL_DIGITS);

   DrawOrUpdateLine(linePrefix + "Entry", InpEntryPrice, InpEntryLineColor, InpEntryLineStyle, InpEntryLineWidth, digits);
   DrawOrUpdateLine(linePrefix + "TP", InpTakeProfitPrice, InpTakeProfitLineColor, InpTpLineStyle, InpTpLineWidth, digits);
   DrawOrUpdateLine(linePrefix + "SL", InpStopLossPrice, InpStopLossLineColor, InpSlLineStyle, InpSlLineWidth, digits);

   ChartRedraw(0);
}

//--- Trade state helpers
bool HasActiveTradeOrOrder()
{
   // Open positions
   for(int i=0; i<PositionsTotal(); ++i)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == normalizedSymbol)
            return true;
      }
   }

   // Pending orders
   for(int i=0; i<OrdersTotal(); ++i)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == normalizedSymbol)
            return true;
      }
   }

   return false;
}

bool HasHistoricalTrade()
{
   if(!HistorySelect(0, LONG_MAX))
      return false;

   // Check historical deals (closed/filled orders)
   int deals = HistoryDealsTotal();
   for(int i=0; i<deals; ++i)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;
      if(!HistoryDealSelect(dealTicket))
         continue;

      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(magic == InpMagicNumber && StringCompare(dealSymbol, normalizedSymbol, true) == 0)
         return true;
   }

   // Fallback: check historical orders if no deals matched
   int total = HistoryOrdersTotal();
   for(int i=0; i<total; ++i)
   {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!HistoryOrderSelect(ticket))
         continue;

      long magic = HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      string ordSymbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      if(magic == InpMagicNumber && StringCompare(ordSymbol, normalizedSymbol, true) == 0)
         return true;
   }

   return false;
}

//--- Persistent guard helpers
string BuildPersistentKey()
{
   return StringFormat("BTEA_%s_%d_PLACED", normalizedSymbol, InpMagicNumber);
}

bool HasPersistentFlag()
{
   string key = BuildPersistentKey();
   if(GlobalVariableCheck(key))
   {
      double val = GlobalVariableGet(key);
      return (val == 1.0);
   }
   return false;
}

void SetPersistentFlag()
{
   string key = BuildPersistentKey();
   GlobalVariableSet(key, 1.0);
}

bool HasAnyTradeRecord()
{
   if(HasActiveTradeOrOrder())
      return true;
   if(HasHistoricalTrade())
      return true;
   if(HasPersistentFlag())
      return true;
   return false;
}

void MarkPlaced()
{
   orderPlaced = true;
   SetPersistentFlag();
}

void ClearExpiry()
{
   expiryTime = 0;
   expirySet = false;
}

void HandleExpiry()
{
   if(!InpUseExpiry || !expirySet || expiryTime <= 0)
      return;

   datetime now = TimeCurrent();
   if(now < expiryTime)
      return;

   bool acted = false;

   // Cancel pending orders for this magic/symbol
   for(int i=OrdersTotal()-1; i>=0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && StringCompare(OrderGetString(ORDER_SYMBOL), normalizedSymbol, true) == 0)
      {
         if(trade.OrderDelete(ticket))
         {
            acted = true;
            Print("[Expiry] Pending order deleted: ", ticket);
         }
         else
         {
            Print("[Expiry] Failed to delete pending order ", ticket, " error=", GetLastError());
         }
      }
   }

   // Close open position for this magic/symbol
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && StringCompare(PositionGetString(POSITION_SYMBOL), normalizedSymbol, true) == 0)
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         if(trade.PositionClose(sym))
         {
            acted = true;
            Print("[Expiry] Position closed for symbol: ", sym);
         }
         else
         {
            Print("[Expiry] Failed to close position for symbol: ", sym, " error=", GetLastError());
         }
      }
   }

   if(acted)
   {
      ClearExpiry();
      // Keep persistent flag; this still counts as the single signal handled
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Normalize and cache symbol (uppercase) for consistent comparisons
   normalizedSymbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   normalizedSymbol = StringUpper(normalizedSymbol);
   ClearExpiry();

   //--- Set trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   //--- Set visual object prefix and persistent key
   linePrefix = StringFormat("BTEA_%d_", InpMagicNumber);
   persistentFlagName = BuildPersistentKey();
   
   //--- Detect broker's UTC offset
   datetime serverTime = TimeCurrent();   // Server time in broker timezone
   datetime gmtTime = TimeGMT();          // GMT/UTC time
   brokerUTCOffsetSeconds = (int)(serverTime - gmtTime);
   
   double brokerUTCOffset = brokerUTCOffsetSeconds / 3600.0;
   Print("Broker UTC offset: ", brokerUTCOffset, " hours");
   
   //--- Initialize risk calculator
   string symbol = normalizedSymbol;
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

   //--- Build absolute expiry (broker local) if configured and absolute mode
   if(InpUseExpiry && InpExpiryMode == EXPIRY_ABSOLUTE)
   {
      MqlDateTime dtExp;
      dtExp.year = InpExpiryYear;
      dtExp.mon = InpExpiryMonth;
      dtExp.day = InpExpiryDay;
      dtExp.hour = InpExpiryHour;
      dtExp.min = InpExpiryMinute;
      dtExp.sec = InpExpirySecond;
      datetime expSignal = StructToTime(dtExp);
      if(expSignal <= 0)
      {
         Print("Error: Invalid expiry date/time specified");
         return INIT_PARAMETERS_INCORRECT;
      }

      int expTzOffsetSeconds = (int)(InpExpiryTimezoneOffset * 3600);
      datetime expUtc = expSignal - expTzOffsetSeconds;
      expiryTime = expUtc + brokerUTCOffsetSeconds;
      expirySet = true;
      Print("Expiry (absolute) set to broker time: ", TimeToString(expiryTime, TIME_DATE|TIME_SECONDS));
   }

   //--- Visual lines (optional)
   UpdateVisualLines();

   //--- If any active or historical trades exist for this magic/symbol, mark as placed to prevent duplicates
   if(HasAnyTradeRecord())
   {
      orderPlaced = true;
      Print("Found existing trade/order/history (or persistent flag) for this signal. Will not place another.");
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   RemoveVisualLines();
   Print("Backtester-EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
   // React to any deal/order involving our magic + symbol; mark placed to prevent re-entry
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_DEAL_UPDATE)
   {
      long magic = (long)trans.deal_magic;
      string sym = trans.symbol;
      if(magic == InpMagicNumber && StringCompare(sym, normalizedSymbol, true) == 0)
      {
         MarkPlaced();
      }
   }

   if(trans.type == TRADE_TRANSACTION_ORDER_ADD || trans.type == TRADE_TRANSACTION_ORDER_UPDATE || trans.type == TRADE_TRANSACTION_ORDER_DELETE)
   {
      long magic = (long)trans.order_magic;
      string sym = trans.symbol;
      if(magic == InpMagicNumber && StringCompare(sym, normalizedSymbol, true) == 0)
      {
         MarkPlaced();
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Handle expiry for existing orders/positions before guards
   HandleExpiry();

   //--- Global guard: if anything exists or was flagged, stop immediately
   if(HasAnyTradeRecord())
   {
      orderPlaced = true;
      return;
   }

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
   string symbol = normalizedSymbol;
   
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
         Print(">>> Lot: ", lotSize, " SL: ", (stopLoss > 0 ? DoubleToString(stopLoss, digits) : "None"), 
               " TP: ", (takeProfit > 0 ? DoubleToString(takeProfit, digits) : "None"));
         result = trade.BuyLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
      else
      {
         orderTypeStr = "Buy Stop";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") >= Ask (", ask, ")");
         Print(">>> Lot: ", lotSize, " SL: ", (stopLoss > 0 ? DoubleToString(stopLoss, digits) : "None"), 
               " TP: ", (takeProfit > 0 ? DoubleToString(takeProfit, digits) : "None"));
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
         Print(">>> Lot: ", lotSize, " SL: ", (stopLoss > 0 ? DoubleToString(stopLoss, digits) : "None"), 
               " TP: ", (takeProfit > 0 ? DoubleToString(takeProfit, digits) : "None"));
         result = trade.SellLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
      }
      else
      {
         orderTypeStr = "Sell Stop";
         Print(">>> Placing ", orderTypeStr, " - Entry (", entryPrice, ") <= Bid (", bid, ")");
         Print(">>> Lot: ", lotSize, " SL: ", (stopLoss > 0 ? DoubleToString(stopLoss, digits) : "None"), 
               " TP: ", (takeProfit > 0 ? DoubleToString(takeProfit, digits) : "None"));
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
      MarkPlaced();

      //--- Set expiry time relative to placement if configured
      if(InpUseExpiry)
      {
         if(InpExpiryMode == EXPIRY_MINUTES)
         {
            expiryTime = TimeCurrent() + (InpExpiryMinutes * 60);
            expirySet = true;
            Print("Expiry set (minutes): ", InpExpiryMinutes, " -> ", TimeToString(expiryTime, TIME_DATE|TIME_SECONDS));
         }
         else if(InpExpiryMode == EXPIRY_HOURS)
         {
            expiryTime = TimeCurrent() + (InpExpiryHours * 3600);
            expirySet = true;
            Print("Expiry set (hours): ", InpExpiryHours, " -> ", TimeToString(expiryTime, TIME_DATE|TIME_SECONDS));
         }
         // Absolute mode already set in OnInit
      }
   }
   else
   {
      Print("Order failed. Error: ", GetLastError(), " - ", trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
