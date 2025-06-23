//+------------------------------------------------------------------+
//|                                                RSI_Template.mq4 |
//|                                            RSI Trading Strategy  |
//|                                   Template for MCP Development   |
//+------------------------------------------------------------------+
#property copyright "MCP MT4 Development"
#property version   "1.00"
#property strict

// EA Parameters
extern int RSI_Period = 14;
extern double RSI_Oversold = 30.0;
extern double RSI_Overbought = 70.0;
extern double LotSize = 0.1;
extern int MagicNumber = 54321;
extern int Slippage = 3;
extern bool UseStopLoss = true;
extern double StopLossPips = 50.0;
extern bool UseTakeProfit = true;
extern double TakeProfitPips = 100.0;

// Global variables
bool InBuyPosition = false;
bool InSellPosition = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("RSI EA Started - Period: ", RSI_Period, " Oversold: ", RSI_Oversold, " Overbought: ", RSI_Overbought);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("RSI EA Stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   double rsi_current = iRSI(Symbol(), 0, RSI_Period, PRICE_CLOSE, 0);
   double rsi_previous = iRSI(Symbol(), 0, RSI_Period, PRICE_CLOSE, 1);
   
   // Check current positions
   CheckPositions();
   
   // RSI Oversold - Buy Signal
   if(!InBuyPosition && rsi_previous >= RSI_Oversold && rsi_current < RSI_Oversold)
   {
      if(OpenBuyOrder())
      {
         InBuyPosition = true;
         Print("Buy signal triggered at RSI: ", rsi_current);
      }
   }
   
   // RSI Overbought - Sell Signal
   if(!InSellPosition && rsi_previous <= RSI_Overbought && rsi_current > RSI_Overbought)
   {
      if(OpenSellOrder())
      {
         InSellPosition = true;
         Print("Sell signal triggered at RSI: ", rsi_current);
      }
   }
   
   // Exit conditions
   if(InBuyPosition && rsi_current > RSI_Overbought)
   {
      CloseAllOrders(OP_BUY);
      InBuyPosition = false;
   }
   
   if(InSellPosition && rsi_current < RSI_Oversold)
   {
      CloseAllOrders(OP_SELL);
      InSellPosition = false;
   }
}

//+------------------------------------------------------------------+
//| Check current positions                                          |
//+------------------------------------------------------------------+
void CheckPositions()
{
   InBuyPosition = false;
   InSellPosition = false;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_BUY) InBuyPosition = true;
         if(OrderType() == OP_SELL) InSellPosition = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Open buy order                                                   |
//+------------------------------------------------------------------+
bool OpenBuyOrder()
{
   double sl = UseStopLoss ? Ask - StopLossPips * Point : 0;
   double tp = UseTakeProfit ? Ask + TakeProfitPips * Point : 0;
   
   int ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, sl, tp, "RSI Buy", MagicNumber, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("Buy order opened: ", ticket, " at ", Ask);
      return true;
   }
   else
   {
      Print("Error opening buy order: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Open sell order                                                  |
//+------------------------------------------------------------------+
bool OpenSellOrder()
{
   double sl = UseStopLoss ? Bid + StopLossPips * Point : 0;
   double tp = UseTakeProfit ? Bid - TakeProfitPips * Point : 0;
   
   int ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, sl, tp, "RSI Sell", MagicNumber, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("Sell order opened: ", ticket, " at ", Bid);
      return true;
   }
   else
   {
      Print("Error opening sell order: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close all orders of specified type                              |
//+------------------------------------------------------------------+
void CloseAllOrders(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
      {
         double closePrice = (orderType == OP_BUY) ? Bid : Ask;
         if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrYellow))
         {
            Print("Error closing order: ", GetLastError());
         }
      }
   }
}