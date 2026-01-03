//+------------------------------------------------------------------+
//|                                            BacktesterRisk.mqh    |
//|                                    Copyright 2026, Backtester-EA |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Backtester-EA"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Risk calculation class                                           |
//+------------------------------------------------------------------+
class CBacktesterRisk
{
private:
   string m_symbol;
   double m_startingBalance;
   
public:
   //--- Constructor
   CBacktesterRisk() : m_symbol(""), m_startingBalance(10000.0) {}
   
   //--- Initialize
   void Init(string symbol, double startingBalance)
   {
      m_symbol = symbol;
      m_startingBalance = startingBalance;
   }
   
   //--- Calculate lot size based on risk percentage and stop loss
   double CalculateLotSize(double riskPercent, double stopLossPoints)
   {
      if(stopLossPoints <= 0)
      {
         Print("Error: Stop loss points must be greater than 0");
         return 0.01; // Minimum lot size
      }
      
      //--- Get symbol properties
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      //--- Calculate risk amount
      double riskAmount = m_startingBalance * (riskPercent / 100.0);
      
      //--- Calculate point value in account currency
      double pointValue = tickValue * (point / tickSize);
      
      //--- Calculate lot size
      double lotSize = riskAmount / (stopLossPoints * point * (tickValue / tickSize));
      
      //--- Normalize to lot step
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      
      //--- Ensure within allowed range
      if(lotSize < minLot)
         lotSize = minLot;
      if(lotSize > maxLot)
         lotSize = maxLot;
      
      Print("Risk Calculation:");
      Print("  Balance: ", m_startingBalance);
      Print("  Risk %: ", riskPercent);
      Print("  Risk Amount: ", riskAmount);
      Print("  SL Points: ", stopLossPoints);
      Print("  Calculated Lot: ", lotSize);
      
      return lotSize;
   }
   
   //--- Get risk amount for given lot size and stop loss
   double GetRiskAmount(double lotSize, double stopLossPoints)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      return lotSize * stopLossPoints * point * (tickValue / tickSize);
   }
   
   //--- Get risk percentage for given lot size and stop loss
   double GetRiskPercent(double lotSize, double stopLossPoints)
   {
      double riskAmount = GetRiskAmount(lotSize, stopLossPoints);
      return (riskAmount / m_startingBalance) * 100.0;
   }
};
//+------------------------------------------------------------------+
