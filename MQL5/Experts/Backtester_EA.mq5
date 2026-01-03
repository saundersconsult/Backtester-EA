//+------------------------------------------------------------------+
//|                                                Backtester_EA.mq5 |
//|                                    Copyright 2026, Backtester-EA |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Backtester-EA"
#property link      ""
#property version   "1.00"
#property description "Configurable backtesting EA with precise order entry parameters"

#include <Trade\Trade.mqh>
#include <BacktesterRisk.mqh>

//--- Input Parameters
input group "=== Order Settings ==="
enum ENUM_ORDER_TYPE_CUSTOM
{
   ORDER_MARKET_BUY,      // Market Buy
   ORDER_MARKET_SELL,     // Market Sell
   ORDER_BUY_LIMIT,       // Buy Limit
   ORDER_SELL_LIMIT,      // Sell Limit
   ORDER_BUY_STOP,        // Buy Stop
   ORDER_STOP_SELL        // Sell Stop
};

input ENUM_ORDER_TYPE_CUSTOM InpOrderType = ORDER_MARKET_BUY;  // Order Type
input double InpEntryPrice = 0.0;                               // Entry Price (0=Market)
input double InpStopLossPoints = 50.0;                         // Stop Loss (points)
input double InpTakeProfitPoints = 100.0;                      // Take Profit (points)

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
input int    InpEntryYear = 2025;                              // Entry Year
input int    InpEntryMonth = 1;                                // Entry Month (1-12)
input int    InpEntryDay = 1;                                  // Entry Day (1-31)
input int    InpEntryHour = 9;                                 // Entry Hour (0-23)
input int    InpEntryMinute = 30;                              // Entry Minute (0-59)
input int    InpEntrySecond = 0;                               // Entry Second (0-59)

//--- Global Variables
CTrade trade;
CBacktesterRisk riskCalc;
datetime lastBarTime = 0;
bool orderPlaced = false;
datetime exactEntryTime = 0;
bool exactTimeReached = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
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
   
   //--- Build exact entry time if enabled
   if(InpUseExactTime)
   {
      MqlDateTime dt;
      dt.year = InpEntryYear;
      dt.mon = InpEntryMonth;
      dt.day = InpEntryDay;
      dt.hour = InpEntryHour;
      dt.min = InpEntryMinute;
      dt.sec = InpEntrySecond;
      
      exactEntryTime = StructToTime(dt);
      
      if(exactEntryTime <= 0)
      {
         Print("Error: Invalid entry date/time specified");
         return INIT_PARAMETERS_INCORRECT;
      }
      
      Print("Exact entry time set to: ", TimeToString(exactEntryTime, TIME_DATE|TIME_SECONDS));
   }
   
   Print("Backtester-EA initialized successfully");
   Print("Symbol: ", symbol);
   Print("Starting Balance: ", InpStartingBalance);
   Print("Risk per trade: ", InpRiskPercent, "%");
   
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
         Print("Exact entry time reached: ", TimeToString(currentTime, TIME_DATE|TIME_SECONDS));
      }
      
      // Skip if we already placed order after reaching exact time
      if(exactTimeReached && orderPlaced)
         return;
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
   
   //--- Get symbol info
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   
   //--- Calculate lot size based on risk
   double lotSize;
   if(InpUseFixedLotSize)
   {
      lotSize = InpFixedLotSize;
   }
   else
   {
      lotSize = riskCalc.CalculateLotSize(InpRiskPercent, InpStopLossPoints);
   }
   
   //--- Get current prices
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double entryPrice = (InpEntryPrice > 0) ? InpEntryPrice : 0;
   
   //--- Calculate SL and TP
   double stopLoss = 0, takeProfit = 0;
   CalculateStopLevels(InpOrderType, entryPrice, stopLoss, takeProfit);
   
   //--- Place order based on type
   bool result = false;
   switch(InpOrderType)
   {
      case ORDER_MARKET_BUY:
         result = trade.Buy(lotSize, symbol, 0, stopLoss, takeProfit, InpTradeComment);
         break;
         
      case ORDER_MARKET_SELL:
         result = trade.Sell(lotSize, symbol, 0, stopLoss, takeProfit, InpTradeComment);
         break;
         
      case ORDER_BUY_LIMIT:
         if(entryPrice > 0)
            result = trade.BuyLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
         break;
         
      case ORDER_SELL_LIMIT:
         if(entryPrice > 0)
            result = trade.SellLimit(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
         break;
         
      case ORDER_BUY_STOP:
         if(entryPrice > 0)
            result = trade.BuyStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
         break;
         
      case ORDER_STOP_SELL:
         if(entryPrice > 0)
            result = trade.SellStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, InpTradeComment);
         break;
   }
   
   if(result)
   {
      datetime entryTime = TimeCurrent();
      Print("========================================");
      Print("Order placed successfully!");
      Print("Entry Time: ", TimeToString(entryTime, TIME_DATE|TIME_SECONDS));
      Print("Symbol: ", symbol);
      Print("Order Type: ", EnumToString(InpOrderType));
      Print("Lot Size: ", lotSize);
      Print("Entry Price: ", (entryPrice > 0 ? entryPrice : (InpOrderType == ORDER_MARKET_BUY ? ask : bid)));
      Print("Stop Loss: ", stopLoss);
      Print("Take Profit: ", takeProfit);
      Print("========================================");
      orderPlaced = true;
   }
   else
   {
      Print("Order failed. Error: ", GetLastError(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate stop loss and take profit levels                       |
//+------------------------------------------------------------------+
void CalculateStopLevels(ENUM_ORDER_TYPE_CUSTOM orderType, double entryPrice, double &sl, double &tp)
{
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   //--- Use entry price or current price
   double basePrice = (entryPrice > 0) ? entryPrice : 
                      ((orderType == ORDER_MARKET_BUY || orderType == ORDER_BUY_LIMIT || orderType == ORDER_BUY_STOP) ? ask : bid);
   
   //--- Calculate SL and TP based on order type
   if(orderType == ORDER_MARKET_BUY || orderType == ORDER_BUY_LIMIT || orderType == ORDER_BUY_STOP)
   {
      // Buy orders
      sl = (InpStopLossPoints > 0) ? basePrice - (InpStopLossPoints * point) : 0;
      tp = (InpTakeProfitPoints > 0) ? basePrice + (InpTakeProfitPoints * point) : 0;
   }
   else
   {
      // Sell orders
      sl = (InpStopLossPoints > 0) ? basePrice + (InpStopLossPoints * point) : 0;
      tp = (InpTakeProfitPoints > 0) ? basePrice - (InpTakeProfitPoints * point) : 0;
   }
   
   //--- Normalize prices
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
}
//+------------------------------------------------------------------+
