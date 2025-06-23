//+------------------------------------------------------------------+
//|                                              MCPBridge_Unified.mq4 |
//|                      Unified MCP Bridge with File-Based Reporting |
//|                        Copyright 2024, MCP MT4 Integration        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MCP MT4 Integration"
#property link      ""
#property version   "2.00"
#property strict

//--- Input parameters
input int UpdateInterval = 1000; // Update interval in milliseconds
input bool EnableFileReporting = true; // Enable enhanced file-based reporting
input bool EnableBacktestTracking = true; // Enable backtest status tracking

//--- Global variables
datetime lastUpdate = 0;
string filesPath = "";

// File-based reporting variables
string StatusFilePath = "mt4_reports\\backtest_status.json";
string ResultsFilePath = "mt4_reports\\backtest_results.json";
datetime BacktestStartTime;
int TotalTrades = 0;
double InitialBalance = 0;
double MaxDrawdown = 0;
double CurrentDrawdown = 0;
bool IsBacktesting = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   filesPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\";
   
   Print("MCP Bridge Unified v2.0 initialized. Files path: ", filesPath);
   Print("File Reporting: ", (EnableFileReporting ? "Enabled" : "Disabled"));
   Print("Backtest Tracking: ", (EnableBacktestTracking ? "Enabled" : "Disabled"));
   
   // Initialize MCP Bridge functionality
   WriteAccountInfo();
   WritePositionsInfo();
   WriteExpertsList();
   
   // Initialize file-based reporting if enabled
   if(EnableFileReporting)
   {
      BacktestStartTime = TimeCurrent();
      InitialBalance = AccountBalance();
      IsBacktesting = IsTesting();
      
      // Create reports directory
      CreateDirectory("mt4_reports");
      
      // Write initial status
      if(EnableBacktestTracking)
      {
         WriteBacktestStatus("starting", 0, "MCP Bridge initialized with backtest tracking");
      }
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("MCP Bridge Unified deinitialized. Reason: ", reason);
   
   // Write final status and results if file reporting is enabled
   if(EnableFileReporting && EnableBacktestTracking)
   {
      WriteBacktestStatus("completed", 100, "MCP Bridge session completed");
      WriteBacktestResults();
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (TimeCurrent() - lastUpdate >= UpdateInterval / 1000)
   {
      // MCP Bridge core functionality
      UpdateMarketData();
      WriteAccountInfo();
      WritePositionsInfo();
      
      // Process MCP commands
      ProcessOrderCommands();
      ProcessCloseCommands();
      ProcessBacktestCommands();
      
      // File-based reporting updates
      if(EnableFileReporting)
      {
         UpdateBacktestTracking();
      }
      
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update market data for major pairs                              |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
   // Update market data for major pairs
   WriteMarketData("EURUSD");
   WriteMarketData("GBPUSD"); 
   WriteMarketData("USDJPY");
   WriteMarketData("USDCHF");
   WriteMarketData("AUDUSD");
   WriteMarketData("USDCAD");
   WriteMarketData("NZDUSD");
   WriteMarketData("EURJPY");
   WriteMarketData("GBPJPY");
   WriteMarketData("EURGBP");
}

//+------------------------------------------------------------------+
//| Update backtest tracking information                            |
//+------------------------------------------------------------------+
void UpdateBacktestTracking()
{
   if(!EnableBacktestTracking) return;
   
   // Update status periodically (every 10 updates for performance)
   static int updateCount = 0;
   updateCount++;
   
   if(updateCount % 10 == 0)
   {
      double progress = CalculateBacktestProgress();
      string status = IsBacktesting ? "backtesting" : "live_trading";
      WriteBacktestStatus(status, progress, "Processing market data");
   }
   
   // Track drawdown
   double currentBalance = AccountBalance();
   CurrentDrawdown = InitialBalance - currentBalance;
   if(CurrentDrawdown > MaxDrawdown)
      MaxDrawdown = CurrentDrawdown;
}

//+------------------------------------------------------------------+
//| Calculate backtest progress percentage                           |
//+------------------------------------------------------------------+
double CalculateBacktestProgress()
{
   if(!IsTesting()) return 100.0;
   
   // For live trading, return current time progress
   datetime currentTime = TimeCurrent();
   datetime dayStart = StrToTime(TimeToString(currentTime, TIME_DATE) + " 00:00:00");
   datetime dayEnd = dayStart + 86400; // 24 hours
   
   double dayDuration = dayEnd - dayStart;
   double elapsed = currentTime - dayStart;
   
   if(dayDuration <= 0) return 0.0;
   
   double progress = (elapsed / dayDuration) * 100.0;
   return MathMin(progress, 100.0);
}

//+------------------------------------------------------------------+
//| Write backtest status to JSON file                              |
//+------------------------------------------------------------------+
void WriteBacktestStatus(string status, double progress, string message)
{
   if(!EnableFileReporting) return;
   
   int fileHandle = FileOpen(StatusFilePath, FILE_WRITE|FILE_TXT);
   
   if(fileHandle != INVALID_HANDLE)
   {
      // Count current trades
      int openTrades = 0;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderType() <= 1) openTrades++; // Only market orders
         }
      }
      
      string jsonStatus = StringFormat(
         "{\n"
         "  \"status\": \"%s\",\n"
         "  \"expert\": \"%s\",\n"
         "  \"symbol\": \"%s\",\n"
         "  \"timeframe\": \"%s\",\n"
         "  \"progress\": %.2f,\n"
         "  \"start_time\": \"%s\",\n"
         "  \"current_time\": \"%s\",\n"
         "  \"trades_executed\": %d,\n"
         "  \"open_trades\": %d,\n"
         "  \"current_balance\": %.2f,\n"
         "  \"current_equity\": %.2f,\n"
         "  \"current_drawdown\": %.2f,\n"
         "  \"max_drawdown\": %.2f,\n"
         "  \"is_testing\": %s,\n"
         "  \"message\": \"%s\"\n"
         "}",
         status,
         WindowExpertName(),
         Symbol(),
         PeriodToString(Period()),
         progress,
         TimeToString(BacktestStartTime, TIME_DATE|TIME_SECONDS),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         OrdersHistoryTotal(),
         openTrades,
         AccountBalance(),
         AccountEquity(),
         CurrentDrawdown,
         MaxDrawdown,
         (IsTesting() ? "true" : "false"),
         message
      );
      
      FileWrite(fileHandle, jsonStatus);
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Write comprehensive backtest results to JSON file               |
//+------------------------------------------------------------------+
void WriteBacktestResults()
{
   if(!EnableFileReporting) return;
   
   int fileHandle = FileOpen(ResultsFilePath, FILE_WRITE|FILE_TXT);
   
   if(fileHandle != INVALID_HANDLE)
   {
      // Calculate comprehensive statistics
      double totalProfit = AccountProfit();
      int totalTrades = OrdersHistoryTotal();
      int profitTrades = 0;
      int lossTrades = 0;
      double largestProfit = 0;
      double largestLoss = 0;
      double grossProfit = 0;
      double grossLoss = 0;
      
      // Analyze historical orders
      for(int i = 0; i < totalTrades; i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
            double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();
            if(orderProfit > 0)
            {
               profitTrades++;
               grossProfit += orderProfit;
               if(orderProfit > largestProfit) largestProfit = orderProfit;
            }
            else if(orderProfit < 0)
            {
               lossTrades++;
               grossLoss += MathAbs(orderProfit);
               if(orderProfit < largestLoss) largestLoss = orderProfit;
            }
         }
      }
      
      double winRate = totalTrades > 0 ? (profitTrades * 100.0 / totalTrades) : 0;
      double profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;
      double expectedPayoff = totalTrades > 0 ? totalProfit / totalTrades : 0;
      
      string jsonResults = StringFormat(
         "{\n"
         "  \"summary\": {\n"
         "    \"expert\": \"%s\",\n"
         "    \"symbol\": \"%s\",\n"
         "    \"timeframe\": \"%s\",\n"
         "    \"period\": \"%s to %s\",\n"
         "    \"initial_deposit\": %.2f,\n"
         "    \"final_balance\": %.2f,\n"
         "    \"final_equity\": %.2f,\n"
         "    \"total_net_profit\": %.2f,\n"
         "    \"gross_profit\": %.2f,\n"
         "    \"gross_loss\": %.2f,\n"
         "    \"profit_factor\": %.2f,\n"
         "    \"expected_payoff\": %.2f,\n"
         "    \"absolute_drawdown\": %.2f,\n"
         "    \"maximal_drawdown\": %.2f,\n"
         "    \"total_trades\": %d,\n"
         "    \"profit_trades\": %d,\n"
         "    \"loss_trades\": %d,\n"
         "    \"largest_profit_trade\": %.2f,\n"
         "    \"largest_loss_trade\": %.2f,\n"
         "    \"win_rate\": %.2f\n"
         "  },\n"
         "  \"performance_metrics\": {\n"
         "    \"account_leverage\": %d,\n"
         "    \"account_currency\": \"%s\",\n"
         "    \"account_server\": \"%s\",\n"
         "    \"account_company\": \"%s\"\n"
         "  },\n"
         "  \"status\": \"completed\",\n"
         "  \"completion_time\": \"%s\",\n"
         "  \"is_backtest\": %s\n"
         "}",
         WindowExpertName(),
         Symbol(),
         PeriodToString(Period()),
         TimeToString(BacktestStartTime, TIME_DATE),
         TimeToString(TimeCurrent(), TIME_DATE),
         InitialBalance,
         AccountBalance(),
         AccountEquity(),
         totalProfit,
         grossProfit,
         grossLoss,
         profitFactor,
         expectedPayoff,
         CurrentDrawdown,
         MaxDrawdown,
         totalTrades,
         profitTrades,
         lossTrades,
         largestProfit,
         largestLoss,
         winRate,
         AccountLeverage(),
         AccountCurrency(),
         AccountServer(),
         AccountCompany(),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         (IsTesting() ? "true" : "false")
      );
      
      FileWrite(fileHandle, jsonResults);
      FileClose(fileHandle);
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
      double marginLevel = AccountEquity() > 0 && AccountMargin() > 0 ? AccountEquity() / AccountMargin() * 100 : 0;
      FileWrite(fileHandle, "MarginLevel=" + DoubleToString(marginLevel, 2));
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

//+------------------------------------------------------------------+
//| Write list of available Expert Advisors                         |
//+------------------------------------------------------------------+
void WriteExpertsList()
{
   int fileHandle = FileOpen("experts_list.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE)
   {
      // Add common Expert Advisors (user should update this list)
      FileWrite(fileHandle, "MCPBridge_Unified|Unified MCP Bridge with Reporting|Current");
      FileWrite(fileHandle, "MCPBridge|Original MCP Bridge Expert Advisor|Legacy");
      FileWrite(fileHandle, "EA_FileReporting_Template|File Reporting Template|Template");
      FileWrite(fileHandle, "MACD Sample|Sample MACD Expert Advisor|Built-in");
      FileWrite(fileHandle, "Moving Average|Sample Moving Average EA|Built-in");
      FileWrite(fileHandle, "RSI|Relative Strength Index EA|Built-in");
      
      // Note: In a real implementation, this would scan the Experts folder
      // For now, users need to manually add their EAs to this list
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Process backtest commands from MCP server                       |
//+------------------------------------------------------------------+
void ProcessBacktestCommands()
{
   if (FileIsExist("backtest_commands.txt"))
   {
      int fileHandle = FileOpen("backtest_commands.txt", FILE_READ | FILE_TXT);
      if (fileHandle != INVALID_HANDLE)
      {
         string jsonCommand = "";
         while (!FileIsEnding(fileHandle))
         {
            jsonCommand += FileReadString(fileHandle);
         }
         FileClose(fileHandle);
         
         // Delete the command file after reading
         FileDelete("backtest_commands.txt");
         
         // Execute the backtest command
         ExecuteBacktestCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute backtest command                                         |
//+------------------------------------------------------------------+
void ExecuteBacktestCommand(string jsonCommand)
{
   // Extract backtest parameters
   string expert = ExtractJsonValue(jsonCommand, "expert");
   string symbol = ExtractJsonValue(jsonCommand, "symbol");
   string timeframe = ExtractJsonValue(jsonCommand, "timeframe");
   string fromDate = ExtractJsonValue(jsonCommand, "from_date");
   string toDate = ExtractJsonValue(jsonCommand, "to_date");
   double initialDeposit = StringToDouble(ExtractJsonValue(jsonCommand, "initial_deposit"));
   string model = ExtractJsonValue(jsonCommand, "model");
   bool optimization = ExtractJsonValue(jsonCommand, "optimization") == "true";
   
   // Write backtest results file
   int resultHandle = FileOpen("backtest_results.txt", FILE_WRITE | FILE_TXT);
   
   if (resultHandle != INVALID_HANDLE)
   {
      // Note: MT4 doesn't have direct API for programmatic backtesting
      // This is a simulation of what the results would look like
      
      FileWrite(resultHandle, "{");
      FileWrite(resultHandle, "\"status\": \"acknowledged\",");
      FileWrite(resultHandle, "\"message\": \"Backtest command received - Use Strategy Tester or enable file reporting\",");
      FileWrite(resultHandle, "\"expert\": \"" + expert + "\",");
      FileWrite(resultHandle, "\"symbol\": \"" + symbol + "\",");
      FileWrite(resultHandle, "\"timeframe\": \"" + timeframe + "\",");
      FileWrite(resultHandle, "\"period\": \"" + fromDate + " to " + toDate + "\",");
      FileWrite(resultHandle, "\"initial_deposit\": " + DoubleToString(initialDeposit, 2) + ",");
      FileWrite(resultHandle, "\"model\": \"" + model + "\",");
      FileWrite(resultHandle, "\"file_reporting\": " + (EnableFileReporting ? "\"enabled\"" : "\"disabled\"") + ",");
      FileWrite(resultHandle, "\"instructions\": [");
      FileWrite(resultHandle, "\"1. Open MT4 Strategy Tester (Ctrl+R)\",");
      FileWrite(resultHandle, "\"2. Select Expert: " + expert + "\",");
      FileWrite(resultHandle, "\"3. Select Symbol: " + symbol + "\",");
      FileWrite(resultHandle, "\"4. Set Timeframe: " + timeframe + "\",");
      FileWrite(resultHandle, "\"5. Set Period: " + fromDate + " - " + toDate + "\",");
      FileWrite(resultHandle, "\"6. Set Initial Deposit: " + DoubleToString(initialDeposit, 2) + "\",");
      FileWrite(resultHandle, "\"7. Select Model: " + model + "\",");
      FileWrite(resultHandle, "\"8. Enable 'File Reporting' and 'Backtest Tracking' in EA inputs\",");
      FileWrite(resultHandle, "\"9. Click Start to run backtest with enhanced reporting\"");
      FileWrite(resultHandle, "]");
      FileWrite(resultHandle, "}");
      
      FileClose(resultHandle);
   }
   
   Print("Backtest command processed for: ", expert, " on ", symbol);
   
   // If file reporting is enabled and we're in testing mode, update status
   if(EnableFileReporting && EnableBacktestTracking)
   {
      WriteBacktestStatus("backtest_requested", 0, "Backtest command received from MCP");
   }
}

//+------------------------------------------------------------------+
//| Convert period to string                                         |
//+------------------------------------------------------------------+
string PeriodToString(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Create directory if it doesn't exist                            |
//+------------------------------------------------------------------+
void CreateDirectory(string path)
{
   // Note: MT4 automatically creates directories when writing files
   // This is a placeholder for directory creation logic
   Print("Creating directory: ", path);
}