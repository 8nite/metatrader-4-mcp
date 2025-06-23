//+------------------------------------------------------------------+
//|                                             SimpleMA_Template.mq4 |
//|                                        Simple Moving Average EA   |
//|                                   Template for MCP Development    |
//+------------------------------------------------------------------+
#property copyright "MCP MT4 Development"
#property version   "1.00"
#property strict

// EA Parameters
extern int MA_Period = 14;
extern int MA_Shift = 0;
extern ENUM_MA_METHOD MA_Method = MODE_SMA;
extern ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;
extern double LotSize = 0.1;
extern int MagicNumber = 12345;
extern int Slippage = 3;

// Global variables
int BuyTicket = 0;
int SellTicket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("SimpleMA EA Started - MA Period: ", MA_Period);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("SimpleMA EA Stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   double ma_current = iMA(Symbol(), 0, MA_Period, MA_Shift, MA_Method, MA_Price, 0);
   double ma_previous = iMA(Symbol(), 0, MA_Period, MA_Shift, MA_Method, MA_Price, 1);
   
   double price_current = iClose(Symbol(), 0, 0);
   double price_previous = iClose(Symbol(), 0, 1);
   
   // Close existing positions if trend changes
   if(BuyTicket > 0 && price_current < ma_current)
   {
      CloseOrder(BuyTicket);
      BuyTicket = 0;
   }
   
   if(SellTicket > 0 && price_current > ma_current)
   {
      CloseOrder(SellTicket);
      SellTicket = 0;
   }
   
   // Open new positions based on MA crossover
   if(BuyTicket == 0 && price_previous <= ma_previous && price_current > ma_current)
   {
      BuyTicket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, 0, 0, "SimpleMA Buy", MagicNumber, 0, clrGreen);
      if(BuyTicket > 0)
         Print("Buy order opened: ", BuyTicket);
   }
   
   if(SellTicket == 0 && price_previous >= ma_previous && price_current < ma_current)
   {
      SellTicket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, 0, 0, "SimpleMA Sell", MagicNumber, 0, clrRed);
      if(SellTicket > 0)
         Print("Sell order opened: ", SellTicket);
   }
}

//+------------------------------------------------------------------+
//| Close order function                                             |
//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(OrderSelect(ticket, SELECT_BY_TICKET))
   {
      if(OrderType() == OP_BUY)
      {
         if(!OrderClose(ticket, OrderLots(), Bid, Slippage, clrRed))
            Print("Error closing buy order: ", GetLastError());
      }
      else if(OrderType() == OP_SELL)
      {
         if(!OrderClose(ticket, OrderLots(), Ask, Slippage, clrGreen))
            Print("Error closing sell order: ", GetLastError());
      }
   }
}