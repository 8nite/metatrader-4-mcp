//+------------------------------------------------------------------+
//|                                                    MCPBridge.mq4 |
//|                        Copyright 2024, MCP MT4 Integration       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MCP MT4 Integration"
#property link      ""
#property version   "1.00"
#property strict

//--- Input parameters
input int UpdateInterval = 1000; // Update interval in milliseconds

//--- Global variables
datetime lastUpdate = 0;
string filesPath = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   filesPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\";
   
   Print("MCP Bridge initialized. Files path: ", filesPath);
   
   // Create initial files
   WriteAccountInfo();
   WritePositionsInfo();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("MCP Bridge deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (TimeCurrent() - lastUpdate >= UpdateInterval / 1000)
   {
      // Update market data for major pairs
      WriteMarketData("EURUSD");
      WriteMarketData("GBPUSD"); 
      WriteMarketData("USDJPY");
      WriteMarketData("USDCHF");
      WriteMarketData("AUDUSD");
      WriteMarketData("USDCAD");
      
      // Update account and positions info
      WriteAccountInfo();
      WritePositionsInfo();
      
      // Process pending commands
      ProcessOrderCommands();
      ProcessCloseCommands();
      
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Write account information to file                                |
//+------------------------------------------------------------------+
void WriteAccountInfo()
{
   int fileHandle = FileOpen("account_info.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE)
   {
      FileWrite(fileHandle, "AccountNumber=" + IntegerToString(AccountNumber()));
      FileWrite(fileHandle, "AccountName=" + AccountName());
      FileWrite(fileHandle, "AccountServer=" + AccountServer());
      FileWrite(fileHandle, "AccountCompany=" + AccountCompany());
      FileWrite(fileHandle, "Currency=" + AccountCurrency());
      FileWrite(fileHandle, "Balance=" + DoubleToString(AccountBalance(), 2));
      FileWrite(fileHandle, "Equity=" + DoubleToString(AccountEquity(), 2));
      FileWrite(fileHandle, "Margin=" + DoubleToString(AccountMargin(), 2));
      FileWrite(fileHandle, "FreeMargin=" + DoubleToString(AccountFreeMargin(), 2));
      FileWrite(fileHandle, "MarginLevel=" + DoubleToString(AccountMarginLevel(), 2));
      FileWrite(fileHandle, "Leverage=" + IntegerToString(AccountLeverage()));
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Write market data for a symbol to file                          |
//+------------------------------------------------------------------+
void WriteMarketData(string symbol)
{
   string filename = "market_data_" + symbol + ".txt";
   int fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT);
   
   if (fileHandle != INVALID_HANDLE)
   {
      double bid = MarketInfo(symbol, MODE_BID);
      double ask = MarketInfo(symbol, MODE_ASK);
      double spread = MarketInfo(symbol, MODE_SPREAD);
      double high = MarketInfo(symbol, MODE_HIGH);
      double low = MarketInfo(symbol, MODE_LOW);
      
      FileWrite(fileHandle, "Symbol=" + symbol);
      FileWrite(fileHandle, "Bid=" + DoubleToString(bid, 5));
      FileWrite(fileHandle, "Ask=" + DoubleToString(ask, 5));
      FileWrite(fileHandle, "Spread=" + DoubleToString(spread, 1));
      FileWrite(fileHandle, "High=" + DoubleToString(high, 5));
      FileWrite(fileHandle, "Low=" + DoubleToString(low, 5));
      FileWrite(fileHandle, "Time=" + TimeToString(TimeCurrent()));
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Write positions information to file                             |
//+------------------------------------------------------------------+
void WritePositionsInfo()
{
   int fileHandle = FileOpen("positions.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE)
   {
      FileWrite(fileHandle, "TotalPositions=" + IntegerToString(OrdersTotal()));
      FileWrite(fileHandle, "");
      
      for (int i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderType() <= 1) // Only market orders (BUY/SELL)
            {
               FileWrite(fileHandle, "Ticket=" + IntegerToString(OrderTicket()));
               FileWrite(fileHandle, "Symbol=" + OrderSymbol());
               FileWrite(fileHandle, "Type=" + (OrderType() == OP_BUY ? "BUY" : "SELL"));
               FileWrite(fileHandle, "Lots=" + DoubleToString(OrderLots(), 2));
               FileWrite(fileHandle, "OpenPrice=" + DoubleToString(OrderOpenPrice(), 5));
               FileWrite(fileHandle, "CurrentPrice=" + DoubleToString(OrderType() == OP_BUY ? MarketInfo(OrderSymbol(), MODE_BID) : MarketInfo(OrderSymbol(), MODE_ASK), 5));
               FileWrite(fileHandle, "StopLoss=" + DoubleToString(OrderStopLoss(), 5));
               FileWrite(fileHandle, "TakeProfit=" + DoubleToString(OrderTakeProfit(), 5));
               FileWrite(fileHandle, "Profit=" + DoubleToString(OrderProfit(), 2));
               FileWrite(fileHandle, "OpenTime=" + TimeToString(OrderOpenTime()));
               FileWrite(fileHandle, "Comment=" + OrderComment());
               FileWrite(fileHandle, "---");
            }
         }
      }
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Process order commands from MCP server                          |
//+------------------------------------------------------------------+
void ProcessOrderCommands()
{
   if (FileIsExist("order_commands.txt"))
   {
      int fileHandle = FileOpen("order_commands.txt", FILE_READ | FILE_TXT);
      if (fileHandle != INVALID_HANDLE)
      {
         string jsonCommand = "";
         while (!FileIsEnding(fileHandle))
         {
            jsonCommand += FileReadString(fileHandle);
         }
         FileClose(fileHandle);
         
         // Delete the command file after reading
         FileDelete("order_commands.txt");
         
         // Parse and execute the order command
         ExecuteOrderCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Process close commands from MCP server                          |
//+------------------------------------------------------------------+
void ProcessCloseCommands()
{
   if (FileIsExist("close_commands.txt"))
   {
      int fileHandle = FileOpen("close_commands.txt", FILE_READ | FILE_TXT);
      if (fileHandle != INVALID_HANDLE)
      {
         string jsonCommand = "";
         while (!FileIsEnding(fileHandle))
         {
            jsonCommand += FileReadString(fileHandle);
         }
         FileClose(fileHandle);
         
         // Delete the command file after reading
         FileDelete("close_commands.txt");
         
         // Parse and execute the close command
         ExecuteCloseCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute order command (simplified JSON parsing)                 |
//+------------------------------------------------------------------+
void ExecuteOrderCommand(string jsonCommand)
{
   // Simple JSON parsing for order execution
   string symbol = ExtractJsonValue(jsonCommand, "symbol");
   string operation = ExtractJsonValue(jsonCommand, "operation");
   double lots = StringToDouble(ExtractJsonValue(jsonCommand, "lots"));
   double price = StringToDouble(ExtractJsonValue(jsonCommand, "price"));
   double stopLoss = StringToDouble(ExtractJsonValue(jsonCommand, "stop_loss"));
   double takeProfit = StringToDouble(ExtractJsonValue(jsonCommand, "take_profit"));
   string comment = ExtractJsonValue(jsonCommand, "comment");
   
   int orderType = -1;
   color arrowColor = clrNONE;
   
   if (operation == "BUY")
   {
      orderType = OP_BUY;
      price = MarketInfo(symbol, MODE_ASK);
      arrowColor = clrBlue;
   }
   else if (operation == "SELL")
   {
      orderType = OP_SELL;
      price = MarketInfo(symbol, MODE_BID);
      arrowColor = clrRed;
   }
   else if (operation == "BUY_LIMIT")
   {
      orderType = OP_BUYLIMIT;
      arrowColor = clrBlue;
   }
   else if (operation == "SELL_LIMIT")
   {
      orderType = OP_SELLLIMIT;
      arrowColor = clrRed;
   }
   else if (operation == "BUY_STOP")
   {
      orderType = OP_BUYSTOP;
      arrowColor = clrBlue;
   }
   else if (operation == "SELL_STOP")
   {
      orderType = OP_SELLSTOP;
      arrowColor = clrRed;
   }
   
   // Write result file
   int resultHandle = FileOpen("order_result.txt", FILE_WRITE | FILE_TXT);
   
   if (orderType >= 0)
   {
      int ticket = OrderSend(symbol, orderType, lots, price, 3, stopLoss, takeProfit, comment, 0, 0, arrowColor);
      
      if (ticket > 0)
      {
         Print("Order placed successfully. Ticket: ", ticket);
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": true,");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"symbol\": \"" + symbol + "\",");
            FileWrite(resultHandle, "\"operation\": \"" + operation + "\",");
            FileWrite(resultHandle, "\"lots\": " + DoubleToString(lots, 2) + ",");
            FileWrite(resultHandle, "\"price\": " + DoubleToString(price, 5));
            FileWrite(resultHandle, "}");
         }
      }
      else
      {
         int error = GetLastError();
         Print("Order failed. Error: ", error);
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": false,");
            FileWrite(resultHandle, "\"error\": " + IntegerToString(error) + ",");
            FileWrite(resultHandle, "\"description\": \"Order failed\"");
            FileWrite(resultHandle, "}");
         }
      }
   }
   else
   {
      if (resultHandle != INVALID_HANDLE)
      {
         FileWrite(resultHandle, "{");
         FileWrite(resultHandle, "\"success\": false,");
         FileWrite(resultHandle, "\"error\": \"Invalid operation type\",");
         FileWrite(resultHandle, "\"operation\": \"" + operation + "\"");
         FileWrite(resultHandle, "}");
      }
   }
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileClose(resultHandle);
   }
}

//+------------------------------------------------------------------+
//| Execute close command                                            |
//+------------------------------------------------------------------+
void ExecuteCloseCommand(string jsonCommand)
{
   int ticket = StringToInteger(ExtractJsonValue(jsonCommand, "ticket"));
   
   // Write result file
   int resultHandle = FileOpen("close_result.txt", FILE_WRITE | FILE_TXT);
   
   if (OrderSelect(ticket, SELECT_BY_TICKET))
   {
      bool result = false;
      double closePrice = 0;
      
      if (OrderType() == OP_BUY)
      {
         closePrice = MarketInfo(OrderSymbol(), MODE_BID);
         result = OrderClose(ticket, OrderLots(), closePrice, 3, clrRed);
      }
      else if (OrderType() == OP_SELL)
      {
         closePrice = MarketInfo(OrderSymbol(), MODE_ASK);
         result = OrderClose(ticket, OrderLots(), closePrice, 3, clrBlue);
      }
      
      if (result)
      {
         Print("Position closed successfully. Ticket: ", ticket);
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": true,");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"close_price\": " + DoubleToString(closePrice, 5));
            FileWrite(resultHandle, "}");
         }
      }
      else
      {
         int error = GetLastError();
         Print("Failed to close position. Error: ", error);
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": false,");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"error\": " + IntegerToString(error) + ",");
            FileWrite(resultHandle, "\"description\": \"Failed to close position\"");
            FileWrite(resultHandle, "}");
         }
      }
   }
   else
   {
      if (resultHandle != INVALID_HANDLE)
      {
         FileWrite(resultHandle, "{");
         FileWrite(resultHandle, "\"success\": false,");
         FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
         FileWrite(resultHandle, "\"error\": \"Order not found\"");
         FileWrite(resultHandle, "}");
      }
   }
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileClose(resultHandle);
   }
}

//+------------------------------------------------------------------+
//| Extract value from JSON string (simplified)                     |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int startPos = StringFind(json, searchKey);
   if (startPos == -1) return "";
   
   startPos += StringLen(searchKey);
   
   // Skip whitespace and quotes
   while (startPos < StringLen(json) && (StringGetChar(json, startPos) == ' ' || StringGetChar(json, startPos) == '"'))
      startPos++;
   
   int endPos = startPos;
   bool inQuotes = false;
   
   // Find end of value
   while (endPos < StringLen(json))
   {
      char c = StringGetChar(json, endPos);
      if (c == '"' && !inQuotes)
      {
         inQuotes = true;
      }
      else if (c == '"' && inQuotes)
      {
         break;
      }
      else if (!inQuotes && (c == ',' || c == '}'))
      {
         break;
      }
      endPos++;
   }
   
   return StringSubstr(json, startPos, endPos - startPos);
}