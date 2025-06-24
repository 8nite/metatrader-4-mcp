//+------------------------------------------------------------------+
//|                                                    MCP_Ultimate.mq4 |
//|                    Ultimate MCP Bridge for MT4 Integration          |
//|                   All-in-One Solution for Claude Code MCP           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MCP MT4 Integration"
#property link      "https://github.com/anthropics/claude-code"
#property version   "3.00"
#property strict
#property description "Ultimate MCP Bridge: Complete MT4 integration for Claude Code"
#property description "Features: Trading, Reporting, Backtesting, File I/O, Visual Indicators"

//--- Input parameters - Main Configuration
input group "=== MCP BRIDGE SETTINGS ==="
input int UpdateInterval = 1000;           // Update interval in milliseconds
input bool EnableFileReporting = true;     // Enable enhanced file-based reporting
input bool EnableBacktestTracking = true;  // Enable backtest status tracking
input bool EnableVisualMode = true;        // Show MCP status on chart
input bool EnableDebugMode = false;        // Enable debug logging

input group "=== REPORTING CONFIGURATION ==="
input string ReportsFolder = "mt4_reports"; // Reports folder name
input bool SaveDetailedLogs = true;         // Save detailed operation logs
input bool EnableJSONFormat = true;         // Use JSON format for reports
input int MaxLogFiles = 10;                 // Maximum log files to keep

input group "=== MARKET DATA SETTINGS ==="
input bool TrackMajorPairs = true;          // Track major currency pairs
input bool TrackMinorPairs = false;         // Track minor currency pairs
input bool TrackExoticPairs = false;        // Track exotic currency pairs
input bool TrackCommodities = false;        // Track commodities (XAUUSD, XAGUSD, WTIUSD)

//--- Global variables
datetime lastUpdate = 0;
string filesPath = "";
string mcpVersion = "3.00";

// File-based reporting variables
string StatusFilePath;
string ResultsFilePath;
string LogFilePath;
datetime BacktestStartTime;
datetime SessionStartTime;
int TotalTrades = 0;
double InitialBalance = 0;
double MaxDrawdown = 0;
double CurrentDrawdown = 0;
double MaxEquity = 0;
bool IsBacktesting = false;
int OperationCounter = 0;

// Symbol lists for market data
string MajorPairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"};
string MinorPairs[] = {"EURJPY", "GBPJPY", "EURGBP", "EURAUD", "EURCHF", "EURAUD", "AUDCAD"};
string ExoticPairs[] = {"USDZAR", "USDTRY", "USDHKD", "USDSGD", "USDMXN", "USDSEK", "USDNOK"};
string Commodities[] = {"XAUUSD", "XAGUSD", "WTIUSD", "BRENTUSD"};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize paths
   filesPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\";
   StatusFilePath = ReportsFolder + "\\mcp_status.json";
   ResultsFilePath = ReportsFolder + "\\mcp_results.json";
   LogFilePath = ReportsFolder + "\\mcp_operations.log";
   
   SessionStartTime = TimeCurrent();
   
   Print("========================================");
   Print("MCP Ultimate Bridge v", mcpVersion, " Starting");
   Print("========================================");
   Print("Files path: ", filesPath);
   Print("File Reporting: ", (EnableFileReporting ? "Enabled" : "Disabled"));
   Print("Backtest Tracking: ", (EnableBacktestTracking ? "Enabled" : "Disabled"));
   Print("Visual Mode: ", (EnableVisualMode ? "Enabled" : "Disabled"));
   Print("Debug Mode: ", (EnableDebugMode ? "Enabled" : "Disabled"));
   
   // Initialize MCP Bridge functionality
   WriteAccountInfo();
   WritePositionsInfo();
   WriteExpertsList();
   CleanupOldLogFiles();
   
   // Initialize file-based reporting if enabled
   if(EnableFileReporting)
   {
      BacktestStartTime = TimeCurrent();
      InitialBalance = AccountBalance();
      MaxEquity = AccountEquity();
      IsBacktesting = IsTesting();
      
      // Create reports directory
      CreateDirectory(ReportsFolder);
      
      // Write initial status
      if(EnableBacktestTracking)
      {
         WriteMCPStatus("starting", 0, "MCP Ultimate Bridge initialized successfully");
      }
      
      LogOperation("INIT", "MCP Ultimate Bridge started", "");
   }
   
   // Setup visual indicators
   if(EnableVisualMode)
   {
      SetupVisualIndicators();
   }
   
   Print("MCP Ultimate Bridge initialization completed successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string reasonText = GetUninitReasonText(reason);
   Print("MCP Ultimate Bridge shutting down. Reason: ", reasonText);
   
   // Write final status and results if file reporting is enabled
   if(EnableFileReporting && EnableBacktestTracking)
   {
      WriteMCPStatus("completed", 100, "MCP Bridge session completed - " + reasonText);
      WriteMCPResults();
      LogOperation("DEINIT", "MCP Ultimate Bridge stopped", reasonText);
   }
   
   // Cleanup visual objects
   if(EnableVisualMode)
   {
      CleanupVisualIndicators();
   }
   
   Print("MCP Ultimate Bridge shutdown completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (TimeCurrent() - lastUpdate >= UpdateInterval / 1000)
   {
      OperationCounter++;
      
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
         UpdateMCPTracking();
      }
      
      // Update visual indicators
      if(EnableVisualMode)
      {
         UpdateVisualIndicators();
      }
      
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update MCP tracking information                                 |
//+------------------------------------------------------------------+
void UpdateMCPTracking()
{
   if(!EnableBacktestTracking) return;
   
   // Update status periodically (every 10 updates for performance)
   static int updateCount = 0;
   updateCount++;
   
   if(updateCount % 10 == 0)
   {
      double progress = CalculateSessionProgress();
      string status = IsBacktesting ? "backtesting" : "live_trading";
      WriteMCPStatus(status, progress, "Processing market data - " + IntegerToString(OperationCounter) + " operations");
   }
   
   // Track drawdown and equity
   double currentBalance = AccountBalance();
   double currentEquity = AccountEquity();
   
   CurrentDrawdown = InitialBalance - currentBalance;
   if(CurrentDrawdown > MaxDrawdown)
      MaxDrawdown = CurrentDrawdown;
      
   if(currentEquity > MaxEquity)
      MaxEquity = currentEquity;
}

//+------------------------------------------------------------------+
//| Calculate session progress percentage                           |
//+------------------------------------------------------------------+
double CalculateSessionProgress()
{
   if(!IsTesting()) 
   {
      // For live trading, calculate session progress
      datetime currentTime = TimeCurrent();
      datetime sessionStart = SessionStartTime;
      datetime sessionEnd = sessionStart + 86400; // 24 hours
      
      double sessionDuration = sessionEnd - sessionStart;
      double elapsed = currentTime - sessionStart;
      
      if(sessionDuration <= 0) return 0.0;
      
      double progress = (elapsed / sessionDuration) * 100.0;
      return MathMin(progress, 100.0);
   }
   else
   {
      // For backtesting, estimate based on tick count
      return MathMin((OperationCounter / 1000.0) * 100.0, 100.0);
   }
}

//+------------------------------------------------------------------+
//| Enhanced market data update for multiple symbol types          |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
   // Update major pairs if enabled
   if(TrackMajorPairs)
   {
      for(int i = 0; i < ArraySize(MajorPairs); i++)
      {
         WriteMarketData(MajorPairs[i]);
      }
   }
   
   // Update minor pairs if enabled
   if(TrackMinorPairs)
   {
      for(int i = 0; i < ArraySize(MinorPairs); i++)
      {
         WriteMarketData(MinorPairs[i]);
      }
   }
   
   // Update exotic pairs if enabled
   if(TrackExoticPairs)
   {
      for(int i = 0; i < ArraySize(ExoticPairs); i++)
      {
         WriteMarketData(ExoticPairs[i]);
      }
   }
   
   // Update commodities if enabled
   if(TrackCommodities)
   {
      for(int i = 0; i < ArraySize(Commodities); i++)
      {
         WriteMarketData(Commodities[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Setup visual indicators on chart                               |
//+------------------------------------------------------------------+
void SetupVisualIndicators()
{
   // Create MCP status panel
   if(ObjectFind("MCP_Status_Panel") < 0)
   {
      ObjectCreate("MCP_Status_Panel", OBJ_LABEL, 0, 0, 0);
      ObjectSet("MCP_Status_Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet("MCP_Status_Panel", OBJPROP_XDISTANCE, 10);
      ObjectSet("MCP_Status_Panel", OBJPROP_YDISTANCE, 20);
      ObjectSetText("MCP_Status_Panel", "MCP Ultimate v" + mcpVersion + " - Initializing...", 9, "Arial Bold", clrLime);
   }
   
   // Create operation counter
   if(ObjectFind("MCP_Operations") < 0)
   {
      ObjectCreate("MCP_Operations", OBJ_LABEL, 0, 0, 0);
      ObjectSet("MCP_Operations", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet("MCP_Operations", OBJPROP_XDISTANCE, 10);
      ObjectSet("MCP_Operations", OBJPROP_YDISTANCE, 40);
      ObjectSetText("MCP_Operations", "Operations: 0", 8, "Arial", clrWhite);
   }
   
   // Create session info
   if(ObjectFind("MCP_Session") < 0)
   {
      ObjectCreate("MCP_Session", OBJ_LABEL, 0, 0, 0);
      ObjectSet("MCP_Session", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet("MCP_Session", OBJPROP_XDISTANCE, 10);
      ObjectSet("MCP_Session", OBJPROP_YDISTANCE, 60);
      ObjectSetText("MCP_Session", "Session: " + TimeToString(SessionStartTime, TIME_DATE|TIME_MINUTES), 8, "Arial", clrYellow);
   }
}

//+------------------------------------------------------------------+
//| Update visual indicators with current status                   |
//+------------------------------------------------------------------+
void UpdateVisualIndicators()
{
   // Update status panel
   string statusText = "MCP Ultimate v" + mcpVersion + " - " + (IsBacktesting ? "BACKTEST" : "LIVE");
   color statusColor = IsBacktesting ? clrOrange : clrLime;
   ObjectSetText("MCP_Status_Panel", statusText, 9, "Arial Bold", statusColor);
   
   // Update operations counter
   ObjectSetText("MCP_Operations", "Operations: " + IntegerToString(OperationCounter), 8, "Arial", clrWhite);
   
   // Update session info with current equity
   string sessionInfo = "Equity: $" + DoubleToString(AccountEquity(), 2);
   if(MaxDrawdown > 0)
      sessionInfo += " | DD: $" + DoubleToString(MaxDrawdown, 2);
   ObjectSetText("MCP_Session", sessionInfo, 8, "Arial", clrYellow);
}

//+------------------------------------------------------------------+
//| Cleanup visual indicators                                       |
//+------------------------------------------------------------------+
void CleanupVisualIndicators()
{
   ObjectDelete("MCP_Status_Panel");
   ObjectDelete("MCP_Operations");
   ObjectDelete("MCP_Session");
}

//+------------------------------------------------------------------+
//| Enhanced logging system with rotation                          |
//+------------------------------------------------------------------+
void LogOperation(string operation, string description, string details)
{
   if(!SaveDetailedLogs) return;
   
   int fileHandle = FileOpen(LogFilePath, FILE_WRITE|FILE_READ|FILE_TXT);
   
   if(fileHandle != INVALID_HANDLE)
   {
      // Move to end of file
      FileSeek(fileHandle, 0, SEEK_END);
      
      string logEntry = StringFormat("%s | %s | %s | %s | %s\n",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         operation,
         description,
         details,
         "Op#" + IntegerToString(OperationCounter)
      );
      
      FileWriteString(fileHandle, logEntry);
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Cleanup old log files to prevent disk space issues            |
//+------------------------------------------------------------------+
void CleanupOldLogFiles()
{
   // This is a placeholder - MT4 doesn't have direct file enumeration
   // In practice, you would manually clean old files or use external tools
   if(EnableDebugMode)
      Print("Log cleanup: Limited to ", MaxLogFiles, " files (manual cleanup recommended)");
}

//+------------------------------------------------------------------+
//| Get human-readable uninit reason                                |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "EA stopped by user";
      case REASON_REMOVE:      return "EA removed from chart";
      case REASON_RECOMPILE:   return "EA recompiled";
      case REASON_CHARTCHANGE: return "Chart symbol/period changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      default:                 return "Unknown reason (" + IntegerToString(reason) + ")";
   }
}

//+------------------------------------------------------------------+
//| Write enhanced MCP status to JSON file                         |
//+------------------------------------------------------------------+
void WriteMCPStatus(string status, double progress, string message)
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
      
      string jsonStatus;
      if(EnableJSONFormat)
      {
         jsonStatus = StringFormat(
            "{\n"
            "  \"mcp_version\": \"%s\",\n"
            "  \"status\": \"%s\",\n"
            "  \"expert\": \"%s\",\n"
            "  \"symbol\": \"%s\",\n"
            "  \"timeframe\": \"%s\",\n"
            "  \"progress\": %.2f,\n"
            "  \"session_start\": \"%s\",\n"
            "  \"current_time\": \"%s\",\n"
            "  \"operations_count\": %d,\n"
            "  \"trades_executed\": %d,\n"
            "  \"open_trades\": %d,\n"
            "  \"current_balance\": %.2f,\n"
            "  \"current_equity\": %.2f,\n"
            "  \"max_equity\": %.2f,\n"
            "  \"current_drawdown\": %.2f,\n"
            "  \"max_drawdown\": %.2f,\n"
            "  \"is_testing\": %s,\n"
            "  \"market_tracking\": {\n"
            "    \"major_pairs\": %s,\n"
            "    \"minor_pairs\": %s,\n"
            "    \"exotic_pairs\": %s,\n"
            "    \"commodities\": %s\n"
            "  },\n"
            "  \"features\": {\n"
            "    \"file_reporting\": %s,\n"
            "    \"backtest_tracking\": %s,\n"
            "    \"visual_mode\": %s,\n"
            "    \"debug_mode\": %s,\n"
            "    \"detailed_logs\": %s\n"
            "  },\n"
            "  \"message\": \"%s\"\n"
            "}",
            mcpVersion,
            status,
            WindowExpertName(),
            Symbol(),
            PeriodToString(Period()),
            progress,
            TimeToString(SessionStartTime, TIME_DATE|TIME_SECONDS),
            TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
            OperationCounter,
            OrdersHistoryTotal(),
            openTrades,
            AccountBalance(),
            AccountEquity(),
            MaxEquity,
            CurrentDrawdown,
            MaxDrawdown,
            (IsTesting() ? "true" : "false"),
            (TrackMajorPairs ? "true" : "false"),
            (TrackMinorPairs ? "true" : "false"),
            (TrackExoticPairs ? "true" : "false"),
            (TrackCommodities ? "true" : "false"),
            (EnableFileReporting ? "true" : "false"),
            (EnableBacktestTracking ? "true" : "false"),
            (EnableVisualMode ? "true" : "false"),
            (EnableDebugMode ? "true" : "false"),
            (SaveDetailedLogs ? "true" : "false"),
            message
         );
      }
      else
      {
         // Simple text format
         jsonStatus = StringFormat(
            "MCP_Version=%s\n"
            "Status=%s\n"
            "Expert=%s\n"
            "Symbol=%s\n"
            "Progress=%.2f\n"
            "Operations=%d\n"
            "Balance=%.2f\n"
            "Equity=%.2f\n"
            "Message=%s\n",
            mcpVersion, status, WindowExpertName(), Symbol(), 
            progress, OperationCounter, AccountBalance(), AccountEquity(), message
         );
      }
      
      FileWrite(fileHandle, jsonStatus);
      FileClose(fileHandle);
      
      if(EnableDebugMode)
         Print("MCP Status updated: ", status, " (", DoubleToString(progress, 1), "%) - ", message);
   }
}

//+------------------------------------------------------------------+
//| Write comprehensive MCP results to JSON file                   |
//+------------------------------------------------------------------+
void WriteMCPResults()
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
      datetime sessionDuration = TimeCurrent() - SessionStartTime;
      
      string jsonResults;
      if(EnableJSONFormat)
      {
         jsonResults = StringFormat(
            "{\n"
            "  \"mcp_ultimate_results\": {\n"
            "    \"version\": \"%s\",\n"
            "    \"expert\": \"%s\",\n"
            "    \"symbol\": \"%s\",\n"
            "    \"timeframe\": \"%s\",\n"
            "    \"session_period\": \"%s to %s\",\n"
            "    \"session_duration_hours\": %.2f,\n"
            "    \"total_operations\": %d,\n"
            "    \"initial_balance\": %.2f,\n"
            "    \"final_balance\": %.2f,\n"
            "    \"final_equity\": %.2f,\n"
            "    \"max_equity\": %.2f,\n"
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
            "    \"win_rate_percentage\": %.2f,\n"
            "    \"session_type\": \"%s\"\n"
            "  },\n"
            "  \"market_tracking_summary\": {\n"
            "    \"major_pairs_tracked\": %d,\n"
            "    \"minor_pairs_tracked\": %d,\n"
            "    \"exotic_pairs_tracked\": %d,\n"
            "    \"commodities_tracked\": %d\n"
            "  },\n"
            "  \"account_details\": {\n"
            "    \"leverage\": %d,\n"
            "    \"currency\": \"%s\",\n"
            "    \"server\": \"%s\",\n"
            "    \"company\": \"%s\"\n"
            "  },\n"
            "  \"completion_info\": {\n"
            "    \"status\": \"completed\",\n"
            "    \"completion_time\": \"%s\",\n"
            "    \"is_backtest\": %s,\n"
            "    \"reports_folder\": \"%s\"\n"
            "  }\n"
            "}",
            mcpVersion,
            WindowExpertName(),
            Symbol(),
            PeriodToString(Period()),
            TimeToString(SessionStartTime, TIME_DATE),
            TimeToString(TimeCurrent(), TIME_DATE),
            sessionDuration / 3600.0,
            OperationCounter,
            InitialBalance,
            AccountBalance(),
            AccountEquity(),
            MaxEquity,
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
            (IsBacktesting ? "backtest" : "live_trading"),
            (TrackMajorPairs ? ArraySize(MajorPairs) : 0),
            (TrackMinorPairs ? ArraySize(MinorPairs) : 0),
            (TrackExoticPairs ? ArraySize(ExoticPairs) : 0),
            (TrackCommodities ? ArraySize(Commodities) : 0),
            AccountLeverage(),
            AccountCurrency(),
            AccountServer(),
            AccountCompany(),
            TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
            (IsTesting() ? "true" : "false"),
            ReportsFolder
         );
      }
      else
      {
         // Simple text format
         jsonResults = StringFormat(
            "MCP_Ultimate_Results\n"
            "Version=%s\n"
            "Expert=%s\n"
            "Symbol=%s\n"
            "Operations=%d\n"
            "FinalBalance=%.2f\n"
            "TotalProfit=%.2f\n"
            "WinRate=%.2f\n"
            "CompletionTime=%s\n",
            mcpVersion, WindowExpertName(), Symbol(), OperationCounter,
            AccountBalance(), totalProfit, winRate,
            TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
         );
      }
      
      FileWrite(fileHandle, jsonResults);
      FileClose(fileHandle);
      
      if(EnableDebugMode)
         Print("MCP Results written: ", totalTrades, " trades, ", DoubleToString(totalProfit, 2), " profit");
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
         LogOperation("ORDER", "Order command processed", jsonCommand);
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
         LogOperation("CLOSE", "Close command processed", jsonCommand);
      }
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
         LogOperation("BACKTEST", "Backtest command processed", jsonCommand);
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
         LogOperation("ORDER_SUCCESS", "Order placed: " + operation + " " + symbol, "Ticket: " + IntegerToString(ticket));
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
         LogOperation("ORDER_FAILED", "Order failed: " + operation + " " + symbol, "Error: " + IntegerToString(error));
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
      LogOperation("ORDER_INVALID", "Invalid operation type", operation);
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
         LogOperation("CLOSE_SUCCESS", "Position closed", "Ticket: " + IntegerToString(ticket) + ", Price: " + DoubleToString(closePrice, 5));
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
         LogOperation("CLOSE_FAILED", "Failed to close position", "Ticket: " + IntegerToString(ticket) + ", Error: " + IntegerToString(error));
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
      LogOperation("CLOSE_NOT_FOUND", "Order not found for close", "Ticket: " + IntegerToString(ticket));
   }
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileClose(resultHandle);
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
      WriteMCPStatus("backtest_requested", 0, "Backtest command received from MCP");
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
      // Add MCP Ultimate and other Expert Advisors
      FileWrite(fileHandle, "MCP_Ultimate|Ultimate MCP Bridge with All Features|Current");
      FileWrite(fileHandle, "MCPBridge_Unified|Unified MCP Bridge with Reporting|Legacy");
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
   if(EnableDebugMode)
      Print("Creating directory: ", path);
}
      MaxDrawdown = CurrentDrawdown;
      
   if(currentEquity > MaxEquity)
      MaxEquity = currentEquity;
}

//+------------------------------------------------------------------+
//| Calculate session progress percentage                           |
//+------------------------------------------------------------------+
double CalculateSessionProgress()
{
   if(!IsTesting()) 
   {
      // For live trading, return session progress
      datetime currentTime = TimeCurrent();
      double sessionDuration = currentTime - SessionStartTime;
      double dayDuration = 86400; // 24 hours
      
      double progress = (sessionDuration / dayDuration) * 100.0;
      return MathMin(progress, 100.0);
   }
   
   // For backtesting, estimate progress based on time
   datetime currentTime = TimeCurrent();
   datetime testEndTime = StrToTime("2024.12.31 23:59:59");
   
   double totalDuration = testEndTime - BacktestStartTime;
   double elapsed = currentTime - BacktestStartTime;
   
   if(totalDuration <= 0) return 0.0;
   
   double progress = (elapsed / totalDuration) * 100.0;
   return MathMin(progress, 100.0);
}

//+------------------------------------------------------------------+
//| Write MCP status to JSON file                                  |
//+------------------------------------------------------------------+
void WriteMCPStatus(string status, double progress, string message)
{
   if(!EnableFileReporting) return;
   
   int fileHandle = FileOpen(StatusFilePath, FILE_WRITE|FILE_TXT);
   
   if(fileHandle != INVALID_HANDLE)
   {
      // Count current trades and positions
      int openTrades = 0;
      int pendingOrders = 0;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderType() <= 1) openTrades++;
            else pendingOrders++;
         }
      }
      
      string jsonStatus = StringFormat(
         "{\n"
         "  \"mcp_version\": \"%s\",\n"
         "  \"status\": \"%s\",\n"
         "  \"timestamp\": \"%s\",\n"
         "  \"symbol\": \"%s\",\n"
         "  \"timeframe\": \"%s\",\n"
         "  \"progress\": %.2f,\n"
         "  \"session_start\": \"%s\",\n"
         "  \"current_time\": \"%s\",\n"
         "  \"operations_count\": %d,\n"
         "  \"trades_history\": %d,\n"
         "  \"open_trades\": %d,\n"
         "  \"pending_orders\": %d,\n"
         "  \"account_balance\": %.2f,\n"
         "  \"account_equity\": %.2f,\n"
         "  \"account_margin\": %.2f,\n"
         "  \"account_free_margin\": %.2f,\n"
         "  \"current_drawdown\": %.2f,\n"
         "  \"max_drawdown\": %.2f,\n"
         "  \"max_equity\": %.2f,\n"
         "  \"is_testing\": %s,\n"
         "  \"server_time\": \"%s\",\n"
         "  \"message\": \"%s\"\n"
         "}",
         mcpVersion,
         status,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         Symbol(),
         PeriodToString(Period()),
         progress,
         TimeToString(SessionStartTime, TIME_DATE|TIME_SECONDS),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         OperationCounter,
         OrdersHistoryTotal(),
         openTrades,
         pendingOrders,
         AccountBalance(),
         AccountEquity(),
         AccountMargin(),
         AccountFreeMargin(),
         CurrentDrawdown,
         MaxDrawdown,
         MaxEquity,
         (IsTesting() ? "true" : "false"),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         message
      );
      
      FileWrite(fileHandle, jsonStatus);
      FileClose(fileHandle);
      
      if(EnableDebugMode)
      {
         Print("MCP Status updated: ", status, " - ", message);
      }
   }
}

//+------------------------------------------------------------------+
//| Write comprehensive MCP results to JSON file                   |
//+------------------------------------------------------------------+
void WriteMCPResults()
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
      double sessionDuration = TimeCurrent() - SessionStartTime;
      
      string jsonResults = StringFormat(
         "{\n"
         "  \"mcp_version\": \"%s\",\n"
         "  \"session_summary\": {\n"
         "    \"session_start\": \"%s\",\n"
         "    \"session_end\": \"%s\",\n"
         "    \"session_duration_hours\": %.2f,\n"
         "    \"total_operations\": %d,\n"
         "    \"symbol\": \"%s\",\n"
         "    \"timeframe\": \"%s\"\n"
         "  },\n"
         "  \"account_summary\": {\n"
         "    \"account_number\": %d,\n"
         "    \"account_name\": \"%s\",\n"
         "    \"account_server\": \"%s\",\n"
         "    \"account_currency\": \"%s\",\n"
         "    \"account_leverage\": %d,\n"
         "    \"initial_balance\": %.2f,\n"
         "    \"final_balance\": %.2f,\n"
         "    \"final_equity\": %.2f,\n"
         "    \"max_equity\": %.2f\n"
         "  },\n"
         "  \"trading_summary\": {\n"
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
         "  \"status\": \"completed\",\n"
         "  \"completion_time\": \"%s\",\n"
         "  \"is_backtest\": %s\n"
         "}",
         mcpVersion,
         TimeToString(SessionStartTime, TIME_DATE|TIME_SECONDS),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         sessionDuration / 3600.0,
         OperationCounter,
         Symbol(),
         PeriodToString(Period()),
         AccountNumber(),
         AccountName(),
         AccountServer(),
         AccountCurrency(),
         AccountLeverage(),
         InitialBalance,
         AccountBalance(),
         AccountEquity(),
         MaxEquity,
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
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         (IsTesting() ? "true" : "false")
      );
      
      FileWrite(fileHandle, jsonResults);
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Update market data for configured symbol groups                |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
   if(TrackMajorPairs)
   {
      for(int i = 0; i < ArraySize(MajorPairs); i++)
      {
         WriteMarketData(MajorPairs[i]);
      }
   }
   
   if(TrackMinorPairs)
   {
      for(int i = 0; i < ArraySize(MinorPairs); i++)
      {
         WriteMarketData(MinorPairs[i]);
      }
   }
   
   if(TrackExoticPairs)
   {
      for(int i = 0; i < ArraySize(ExoticPairs); i++)
      {
         WriteMarketData(ExoticPairs[i]);
      }
   }
   
   if(TrackCommodities)
   {
      for(int i = 0; i < ArraySize(Commodities); i++)
      {
         WriteMarketData(Commodities[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Log MCP operations                                              |
//+------------------------------------------------------------------+
void LogOperation(string operation, string description, string details)
{
   if(!SaveDetailedLogs) return;
   
   int fileHandle = FileOpen(LogFilePath, FILE_WRITE|FILE_TXT);
   
   if(fileHandle != INVALID_HANDLE)
   {
      string logEntry = StringFormat("[%s] %s: %s %s",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         operation,
         description,
         (details != "" ? "(" + details + ")" : "")
      );
      
      FileWrite(fileHandle, logEntry);
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Setup visual indicators on chart                               |
//+------------------------------------------------------------------+
void SetupVisualIndicators()
{
   // Create MCP status panel
   string panelName = "MCP_Status_Panel";
   if(ObjectFind(panelName) == -1)
   {
      ObjectCreate(panelName, OBJ_LABEL, 0, 0, 0);
      ObjectSet(panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet(panelName, OBJPROP_XDISTANCE, 10);
      ObjectSet(panelName, OBJPROP_YDISTANCE, 20);
      ObjectSetText(panelName, "MCP Ultimate v" + mcpVersion + " - Starting...", 10, "Arial Bold", clrLime);
   }
}

//+------------------------------------------------------------------+
//| Update visual indicators                                        |
//+------------------------------------------------------------------+
void UpdateVisualIndicators()
{
   string panelName = "MCP_Status_Panel";
   string statusText = StringFormat("MCP Ultimate v%s | Ops: %d | Bal: %.2f | Eq: %.2f | %s",
      mcpVersion,
      OperationCounter,
      AccountBalance(),
      AccountEquity(),
      (IsTesting() ? "BACKTEST" : "LIVE")
   );
   
   ObjectSetText(panelName, statusText, 10, "Arial Bold", clrLime);
}

//+------------------------------------------------------------------+
//| Cleanup visual indicators                                       |
//+------------------------------------------------------------------+
void CleanupVisualIndicators()
{
   ObjectDelete("MCP_Status_Panel");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Clean up old log files                                         |
//+------------------------------------------------------------------+
void CleanupOldLogFiles()
{
   // Implementation for cleaning old log files would go here
   // For now, just print a message
   if(EnableDebugMode)
   {
      Print("Log cleanup: Keeping last ", MaxLogFiles, " log files");
   }
}

//+------------------------------------------------------------------+
//| Get uninit reason text                                          |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_REMOVE: return "EA removed from chart";
      case REASON_RECOMPILE: return "EA recompiled";
      case REASON_CHARTCHANGE: return "Chart symbol or timeframe changed";
      case REASON_CHARTCLOSE: return "Chart closed";
      case REASON_PARAMETERS: return "EA parameters changed";
      case REASON_ACCOUNT: return "Account changed";
      case REASON_TEMPLATE: return "Template changed";
      case REASON_INITFAILED: return "Initialization failed";
      case REASON_CLOSE: return "Terminal closed";
      default: return "Unknown reason (" + IntegerToString(reason) + ")";
   }
}

//+------------------------------------------------------------------+
//| Convert period to string                                        |
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
//| Write account information to file                               |
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
      FileWrite(fileHandle, "MCPVersion=" + mcpVersion);
      FileWrite(fileHandle, "LastUpdate=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Write market data for a symbol to file                         |
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
      double volume = MarketInfo(symbol, MODE_VOLUME);
      
      FileWrite(fileHandle, "Symbol=" + symbol);
      FileWrite(fileHandle, "Bid=" + DoubleToString(bid, 5));
      FileWrite(fileHandle, "Ask=" + DoubleToString(ask, 5));
      FileWrite(fileHandle, "Spread=" + DoubleToString(spread, 1));
      FileWrite(fileHandle, "High=" + DoubleToString(high, 5));
      FileWrite(fileHandle, "Low=" + DoubleToString(low, 5));
      FileWrite(fileHandle, "Volume=" + DoubleToString(volume, 0));
      FileWrite(fileHandle, "Time=" + TimeToString(TimeCurrent()));
      FileWrite(fileHandle, "MCPVersion=" + mcpVersion);
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Write positions information to file                            |
//+------------------------------------------------------------------+
void WritePositionsInfo()
{
   int fileHandle = FileOpen("positions.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE)
   {
      int totalPositions = 0;
      int pendingOrders = 0;
      
      // Count positions and pending orders
      for (int i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderType() <= 1) totalPositions++;
            else pendingOrders++;
         }
      }
      
      FileWrite(fileHandle, "TotalPositions=" + IntegerToString(totalPositions));
      FileWrite(fileHandle, "PendingOrders=" + IntegerToString(pendingOrders));
      FileWrite(fileHandle, "MCPVersion=" + mcpVersion);
      FileWrite(fileHandle, "LastUpdate=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      FileWrite(fileHandle, "");
      
      for (int i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderType() <= 1) // Market orders (BUY/SELL)
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
               FileWrite(fileHandle, "Swap=" + DoubleToString(OrderSwap(), 2));
               FileWrite(fileHandle, "Commission=" + DoubleToString(OrderCommission(), 2));
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
//| Write list of available Expert Advisors                        |
//+------------------------------------------------------------------+
void WriteExpertsList()
{
   int fileHandle = FileOpen("experts_list.txt", FILE_WRITE | FILE_TXT);
   if (fileHandle != INVALID_HANDLE)
   {
      // Enhanced experts list with MCP Ultimate
      FileWrite(fileHandle, "MCP_Ultimate|Ultimate MCP Bridge v" + mcpVersion + "|Current");
      FileWrite(fileHandle, "MCPBridge_Unified|Unified MCP Bridge with Reporting|Available");
      FileWrite(fileHandle, "MCPBridge|Original MCP Bridge Expert Advisor|Legacy");
      FileWrite(fileHandle, "EA_FileReporting_Template|File Reporting Template|Template");
      FileWrite(fileHandle, "MACD Sample|Sample MACD Expert Advisor|Built-in");
      FileWrite(fileHandle, "Moving Average|Sample Moving Average EA|Built-in");
      FileWrite(fileHandle, "RSI|Relative Strength Index EA|Built-in");
      
      // Add timestamp and version info
      FileWrite(fileHandle, "");
      FileWrite(fileHandle, "MCPVersion=" + mcpVersion);
      FileWrite(fileHandle, "LastUpdate=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      FileWrite(fileHandle, "TotalExperts=7");
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Process order commands from MCP server                         |
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
         
         // Log the operation
         LogOperation("ORDER_CMD", "Processing order command", StringSubstr(jsonCommand, 0, 50) + "...");
         
         // Parse and execute the order command
         ExecuteOrderCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Process close commands from MCP server                         |
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
         
         // Log the operation
         LogOperation("CLOSE_CMD", "Processing close command", StringSubstr(jsonCommand, 0, 50) + "...");
         
         // Parse and execute the close command
         ExecuteCloseCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Process backtest commands from MCP server                      |
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
         
         // Log the operation
         LogOperation("BACKTEST_CMD", "Processing backtest command", StringSubstr(jsonCommand, 0, 50) + "...");
         
         // Execute the backtest command
         ExecuteBacktestCommand(jsonCommand);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute order command (enhanced JSON parsing)                  |
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
   
   if(comment == "") comment = "MCP_Ultimate_v" + mcpVersion;
   
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
         Print("MCP Order executed successfully. Ticket: ", ticket, " ", operation, " ", lots, " ", symbol);
         LogOperation("ORDER_SUCCESS", "Order executed", "Ticket: " + IntegerToString(ticket) + " " + operation + " " + symbol);
         
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": true,");
            FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"symbol\": \"" + symbol + "\",");
            FileWrite(resultHandle, "\"operation\": \"" + operation + "\",");
            FileWrite(resultHandle, "\"lots\": " + DoubleToString(lots, 2) + ",");
            FileWrite(resultHandle, "\"price\": " + DoubleToString(price, 5) + ",");
            FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
            FileWrite(resultHandle, "}");
         }
      }
      else
      {
         int error = GetLastError();
         Print("MCP Order failed. Error: ", error, " ", operation, " ", lots, " ", symbol);
         LogOperation("ORDER_ERROR", "Order failed", "Error: " + IntegerToString(error) + " " + operation + " " + symbol);
         
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": false,");
            FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
            FileWrite(resultHandle, "\"error\": " + IntegerToString(error) + ",");
            FileWrite(resultHandle, "\"description\": \"Order execution failed\",");
            FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
            FileWrite(resultHandle, "}");
         }
      }
   }
   else
   {
      LogOperation("ORDER_INVALID", "Invalid operation type", operation);
      if (resultHandle != INVALID_HANDLE)
      {
         FileWrite(resultHandle, "{");
         FileWrite(resultHandle, "\"success\": false,");
         FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
         FileWrite(resultHandle, "\"error\": \"Invalid operation type\",");
         FileWrite(resultHandle, "\"operation\": \"" + operation + "\",");
         FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
         FileWrite(resultHandle, "}");
      }
   }
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileClose(resultHandle);
   }
}

//+------------------------------------------------------------------+
//| Execute close command (enhanced)                               |
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
      string symbol = OrderSymbol();
      double lots = OrderLots();
      
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
         Print("MCP Position closed successfully. Ticket: ", ticket);
         LogOperation("CLOSE_SUCCESS", "Position closed", "Ticket: " + IntegerToString(ticket) + " " + symbol);
         
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": true,");
            FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"close_price\": " + DoubleToString(closePrice, 5) + ",");
            FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
            FileWrite(resultHandle, "}");
         }
      }
      else
      {
         int error = GetLastError();
         Print("MCP Failed to close position. Error: ", error, " Ticket: ", ticket);
         LogOperation("CLOSE_ERROR", "Failed to close position", "Error: " + IntegerToString(error) + " Ticket: " + IntegerToString(ticket));
         
         if (resultHandle != INVALID_HANDLE)
         {
            FileWrite(resultHandle, "{");
            FileWrite(resultHandle, "\"success\": false,");
            FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
            FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
            FileWrite(resultHandle, "\"error\": " + IntegerToString(error) + ",");
            FileWrite(resultHandle, "\"description\": \"Failed to close position\",");
            FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
            FileWrite(resultHandle, "}");
         }
      }
   }
   else
   {
      LogOperation("CLOSE_NOTFOUND", "Order not found", "Ticket: " + IntegerToString(ticket));
      if (resultHandle != INVALID_HANDLE)
      {
         FileWrite(resultHandle, "{");
         FileWrite(resultHandle, "\"success\": false,");
         FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
         FileWrite(resultHandle, "\"ticket\": " + IntegerToString(ticket) + ",");
         FileWrite(resultHandle, "\"error\": \"Order not found\",");
         FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"");
         FileWrite(resultHandle, "}");
      }
   }
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileClose(resultHandle);
   }
}

//+------------------------------------------------------------------+
//| Execute backtest command (enhanced)                            |
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
   
   LogOperation("BACKTEST_REQ", "Backtest requested", expert + " " + symbol + " " + timeframe);
   
   // Write backtest results file
   int resultHandle = FileOpen("backtest_results.txt", FILE_WRITE | FILE_TXT);
   
   if (resultHandle != INVALID_HANDLE)
   {
      FileWrite(resultHandle, "{");
      FileWrite(resultHandle, "\"status\": \"acknowledged\",");
      FileWrite(resultHandle, "\"mcp_version\": \"" + mcpVersion + "\",");
      FileWrite(resultHandle, "\"message\": \"Backtest command received by MCP Ultimate\",");
      FileWrite(resultHandle, "\"expert\": \"" + expert + "\",");
      FileWrite(resultHandle, "\"symbol\": \"" + symbol + "\",");
      FileWrite(resultHandle, "\"timeframe\": \"" + timeframe + "\",");
      FileWrite(resultHandle, "\"period\": \"" + fromDate + " to " + toDate + "\",");
      FileWrite(resultHandle, "\"initial_deposit\": " + DoubleToString(initialDeposit, 2) + ",");
      FileWrite(resultHandle, "\"model\": \"" + model + "\",");
      FileWrite(resultHandle, "\"file_reporting\": " + (EnableFileReporting ? "\"enabled\"" : "\"disabled\"") + ",");
      FileWrite(resultHandle, "\"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",");
      FileWrite(resultHandle, "\"instructions\": [");
      FileWrite(resultHandle, "\"1. Open MT4 Strategy Tester (Ctrl+R)\",");
      FileWrite(resultHandle, "\"2. Select Expert: " + expert + "\",");
      FileWrite(resultHandle, "\"3. Select Symbol: " + symbol + "\",");
      FileWrite(resultHandle, "\"4. Set Timeframe: " + timeframe + "\",");
      FileWrite(resultHandle, "\"5. Set Period: " + fromDate + " - " + toDate + "\",");
      FileWrite(resultHandle, "\"6. Set Initial Deposit: " + DoubleToString(initialDeposit, 2) + "\",");
      FileWrite(resultHandle, "\"7. Select Model: " + model + "\",");
      FileWrite(resultHandle, "\"8. Ensure MCP_Ultimate is running for enhanced reporting\",");
      FileWrite(resultHandle, "\"9. Click Start to run backtest\"");
      FileWrite(resultHandle, "]");
      FileWrite(resultHandle, "}");
      
      FileClose(resultHandle);
   }
   
   Print("MCP Backtest command processed for: ", expert, " on ", symbol);
   
   // If file reporting is enabled, update status
   if(EnableFileReporting && EnableBacktestTracking)
   {
      WriteMCPStatus("backtest_requested", 0, "Backtest command received: " + expert + " " + symbol);
   }
}

//+------------------------------------------------------------------+
//| Extract value from JSON string (enhanced)                      |
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
//| Create directory if it doesn't exist                           |
//+------------------------------------------------------------------+
void CreateDirectory(string path)
{
   if(EnableDebugMode)
   {
      Print("MCP: Creating directory: ", path);
   }
}