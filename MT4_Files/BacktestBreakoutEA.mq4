//+------------------------------------------------------------------+
//|                                          BacktestBreakoutEA.mq4 |
//|                           Backtest Script for Breakout Strategy |
//|                                         Testing & Optimization  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Breakout Backtest"
#property version   "1.00"
#property strict

// Include the main breakout EA (if using include)
// Or copy the complete EA code here for standalone backtesting

// Additional backtest-specific parameters
input group "=== BACKTEST SETTINGS ==="
input bool     EnableBacktestMode = true;     // Enable backtest optimizations
input bool     PrintDetailedStats = true;     // Print detailed statistics
input bool     SaveBacktestReport = true;     // Save backtest report to file
input double   InitialDeposit = 10000.0;      // Initial deposit for testing
input string   BacktestComment = "Breakout Strategy Test"; // Backtest identifier

// Strategy parameters (same as main EA)
input group "=== STRATEGY SETTINGS ==="
input int      LookbackBars = 20;        // Lookback period for S/R levels  
input double   BreakoutPips = 5.0;       // Minimum breakout distance in pips
input double   RiskPercent = 2.0;        // Risk percentage per trade
input double   StopLossPips = 20.0;      // Stop loss in pips
input double   TakeProfitPips = 40.0;    // Take profit in pips
input bool     UseTrailing = true;       // Enable trailing stop
input double   TrailPips = 15.0;         // Trailing distance in pips

input group "=== RISK MANAGEMENT ==="
input int      MaxTrades = 2;            // Maximum concurrent trades
input double   MaxDailyLoss = 100.0;     // Maximum daily loss

// Backtest statistics
struct BacktestStats
{
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double grossProfit;
    double grossLoss;
    double netProfit;
    double profitFactor;
    double winRate;
    double avgWin;
    double avgLoss;
    double maxDrawdown;
    double maxConsecutiveWins;
    double maxConsecutiveLosses;
    double sharpeRatio;
};

BacktestStats g_stats;

// Global variables (same as main EA)
double g_pointValue;
int g_digits;
datetime g_lastBar = 0;
double g_dailyBalance = 0;
double g_initialBalance = 0;
double g_peakBalance = 0;

// S/R level structure
struct SRLevel
{
    double price;
    bool isSupport;
    int strength;
};

SRLevel g_levels[];
int g_levelCount = 0;

// Magic number
#define MAGIC_NUM 12345

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_pointValue = Point;
    g_digits = Digits;
    
    if(g_digits == 5 || g_digits == 3)
        g_pointValue *= 10;
        
    g_dailyBalance = AccountBalance();
    g_initialBalance = AccountBalance();
    g_peakBalance = AccountBalance();
    
    // Initialize backtest statistics
    InitializeStats();
    
    Print("Breakout EA Backtest initialized - Symbol: ", Symbol());
    Print("Initial Balance: ", g_initialBalance);
    Print("Testing Period: ", TimeToString(Time[Bars-1]), " to ", TimeToString(TimeCurrent()));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Calculate final statistics
    CalculateFinalStats();
    
    // Print detailed report
    if(PrintDetailedStats)
        PrintBacktestReport();
        
    // Save report to file
    if(SaveBacktestReport)
        SaveReportToFile();
        
    RemoveObjects();
    
    Print("Backtest completed. Final Balance: ", AccountBalance());
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(Time[0] != g_lastBar)
    {
        g_lastBar = Time[0];
        
        if(Hour() == 0 && Minute() == 0)
            g_dailyBalance = AccountBalance();
            
        // Update peak balance for drawdown calculation
        if(AccountBalance() > g_peakBalance)
            g_peakBalance = AccountBalance();
            
        CheckRiskManagement();
        FindSRLevels();
        CheckBreakouts();
        ManageTrades();
        
        // Update statistics periodically
        if(g_lastBar % 3600 == 0) // Every hour
            UpdateStatistics();
    }
}

//+------------------------------------------------------------------+
//| Initialize backtest statistics                                  |
//+------------------------------------------------------------------+
void InitializeStats()
{
    g_stats.totalTrades = 0;
    g_stats.winningTrades = 0;
    g_stats.losingTrades = 0;
    g_stats.grossProfit = 0;
    g_stats.grossLoss = 0;
    g_stats.netProfit = 0;
    g_stats.profitFactor = 0;
    g_stats.winRate = 0;
    g_stats.avgWin = 0;
    g_stats.avgLoss = 0;
    g_stats.maxDrawdown = 0;
    g_stats.maxConsecutiveWins = 0;
    g_stats.maxConsecutiveLosses = 0;
    g_stats.sharpeRatio = 0;
}

//+------------------------------------------------------------------+
//| Update statistics during backtest                               |
//+------------------------------------------------------------------+
void UpdateStatistics()
{
    g_stats.totalTrades = 0;
    g_stats.winningTrades = 0;
    g_stats.losingTrades = 0;
    g_stats.grossProfit = 0;
    g_stats.grossLoss = 0;
    
    // Count closed trades from history
    for(int i = 0; i < OrdersHistoryTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if(OrderMagicNumber() == MAGIC_NUM && OrderSymbol() == Symbol())
            {
                g_stats.totalTrades++;
                
                if(OrderProfit() > 0)
                {
                    g_stats.winningTrades++;
                    g_stats.grossProfit += OrderProfit();
                }
                else if(OrderProfit() < 0)
                {
                    g_stats.losingTrades++;
                    g_stats.grossLoss += MathAbs(OrderProfit());
                }
            }
        }
    }
    
    // Calculate derived statistics
    if(g_stats.totalTrades > 0)
    {
        g_stats.winRate = (double)g_stats.winningTrades / g_stats.totalTrades * 100;
        g_stats.netProfit = g_stats.grossProfit - g_stats.grossLoss;
        
        if(g_stats.grossLoss > 0)
            g_stats.profitFactor = g_stats.grossProfit / g_stats.grossLoss;
            
        if(g_stats.winningTrades > 0)
            g_stats.avgWin = g_stats.grossProfit / g_stats.winningTrades;
            
        if(g_stats.losingTrades > 0)
            g_stats.avgLoss = g_stats.grossLoss / g_stats.losingTrades;
    }
    
    // Calculate drawdown
    double currentDrawdown = (g_peakBalance - AccountBalance()) / g_peakBalance * 100;
    if(currentDrawdown > g_stats.maxDrawdown)
        g_stats.maxDrawdown = currentDrawdown;
}

//+------------------------------------------------------------------+
//| Calculate final statistics                                      |
//+------------------------------------------------------------------+
void CalculateFinalStats()
{
    UpdateStatistics();
    
    // Calculate Sharpe ratio (simplified)
    if(g_stats.totalTrades > 1)
    {
        double returns[];
        ArrayResize(returns, g_stats.totalTrades);
        int index = 0;
        
        for(int i = 0; i < OrdersHistoryTotal(); i++)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            {
                if(OrderMagicNumber() == MAGIC_NUM && OrderSymbol() == Symbol())
                {
                    returns[index] = OrderProfit() / g_initialBalance * 100;
                    index++;
                }
            }
        }
        
        // Calculate mean and standard deviation
        double mean = 0;
        for(int i = 0; i < index; i++)
            mean += returns[i];
        mean /= index;
        
        double variance = 0;
        for(int i = 0; i < index; i++)
            variance += MathPow(returns[i] - mean, 2);
        variance /= (index - 1);
        
        double stdDev = MathSqrt(variance);
        if(stdDev > 0)
            g_stats.sharpeRatio = mean / stdDev;
    }
}

//+------------------------------------------------------------------+
//| Print detailed backtest report                                  |
//+------------------------------------------------------------------+
void PrintBacktestReport()
{
    Print("========================================");
    Print("BREAKOUT STRATEGY BACKTEST REPORT");
    Print("========================================");
    Print("Testing Period: ", TimeToString(Time[Bars-1]), " to ", TimeToString(TimeCurrent()));
    Print("Initial Deposit: $", DoubleToString(g_initialBalance, 2));
    Print("Final Balance: $", DoubleToString(AccountBalance(), 2));
    Print("Net Profit: $", DoubleToString(g_stats.netProfit, 2));
    Print("Net Profit %: ", DoubleToString((AccountBalance() - g_initialBalance) / g_initialBalance * 100, 2), "%");
    Print("----------------------------------------");
    Print("Total Trades: ", g_stats.totalTrades);
    Print("Winning Trades: ", g_stats.winningTrades);
    Print("Losing Trades: ", g_stats.losingTrades);
    Print("Win Rate: ", DoubleToString(g_stats.winRate, 2), "%");
    Print("----------------------------------------");
    Print("Gross Profit: $", DoubleToString(g_stats.grossProfit, 2));
    Print("Gross Loss: $", DoubleToString(g_stats.grossLoss, 2));
    Print("Profit Factor: ", DoubleToString(g_stats.profitFactor, 2));
    Print("Average Win: $", DoubleToString(g_stats.avgWin, 2));
    Print("Average Loss: $", DoubleToString(g_stats.avgLoss, 2));
    Print("----------------------------------------");
    Print("Maximum Drawdown: ", DoubleToString(g_stats.maxDrawdown, 2), "%");
    Print("Sharpe Ratio: ", DoubleToString(g_stats.sharpeRatio, 3));
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Save backtest report to file                                    |
//+------------------------------------------------------------------+
void SaveReportToFile()
{
    string filename = "BacktestReport_" + Symbol() + "_" + 
                     StringSubstr(TimeToString(TimeCurrent()), 0, 10) + ".txt";
                     
    int handle = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if(handle != INVALID_HANDLE)
    {
        FileWrite(handle, "BREAKOUT STRATEGY BACKTEST REPORT");
        FileWrite(handle, "=====================================");
        FileWrite(handle, "Symbol: " + Symbol());
        FileWrite(handle, "Testing Period: " + TimeToString(Time[Bars-1]) + " to " + TimeToString(TimeCurrent()));
        FileWrite(handle, "Parameters:");
        FileWrite(handle, "- Lookback Bars: " + IntegerToString(LookbackBars));
        FileWrite(handle, "- Breakout Pips: " + DoubleToString(BreakoutPips, 1));
        FileWrite(handle, "- Risk Percent: " + DoubleToString(RiskPercent, 1) + "%");
        FileWrite(handle, "- Stop Loss: " + DoubleToString(StopLossPips, 1) + " pips");
        FileWrite(handle, "- Take Profit: " + DoubleToString(TakeProfitPips, 1) + " pips");
        FileWrite(handle, "- Trailing Stop: " + (UseTrailing ? "Yes" : "No"));
        FileWrite(handle, "");
        FileWrite(handle, "RESULTS:");
        FileWrite(handle, "Initial Deposit: $" + DoubleToString(g_initialBalance, 2));
        FileWrite(handle, "Final Balance: $" + DoubleToString(AccountBalance(), 2));
        FileWrite(handle, "Net Profit: $" + DoubleToString(g_stats.netProfit, 2));
        FileWrite(handle, "Net Profit %: " + DoubleToString((AccountBalance() - g_initialBalance) / g_initialBalance * 100, 2) + "%");
        FileWrite(handle, "Total Trades: " + IntegerToString(g_stats.totalTrades));
        FileWrite(handle, "Win Rate: " + DoubleToString(g_stats.winRate, 2) + "%");
        FileWrite(handle, "Profit Factor: " + DoubleToString(g_stats.profitFactor, 2));
        FileWrite(handle, "Maximum Drawdown: " + DoubleToString(g_stats.maxDrawdown, 2) + "%");
        FileWrite(handle, "Sharpe Ratio: " + DoubleToString(g_stats.sharpeRatio, 3));
        
        FileClose(handle);
        Print("Backtest report saved to: ", filename);
    }
}

// Include all the main EA functions here (or use #include if preferred)
// [All the functions from BreakoutEA.mq4 should be included here]

//+------------------------------------------------------------------+
//| Check risk management rules                                     |
//+------------------------------------------------------------------+
void CheckRiskManagement()
{
    double dailyPL = AccountBalance() - g_dailyBalance;
    if(dailyPL <= -MaxDailyLoss)
    {
        Comment("Trading stopped - Daily loss limit reached");
        return;
    }
    
    Comment("Breakout EA Backtest - Levels: " + IntegerToString(g_levelCount) + 
            " | Trades: " + IntegerToString(g_stats.totalTrades) +
            " | P&L: $" + DoubleToString(AccountBalance() - g_initialBalance, 2));
}

//+------------------------------------------------------------------+
//| Find support and resistance levels                              |
//+------------------------------------------------------------------+
void FindSRLevels()
{
    g_levelCount = 0;
    ArrayResize(g_levels, 0);
    
    for(int i = LookbackBars; i >= 3; i--)
    {
        // Check for swing high
        if(High[i] > High[i+1] && High[i] > High[i-1] &&
           High[i] > High[i+2] && High[i] > High[i-2])
        {
            int touches = CountTouches(High[i], true);
            if(touches >= 2)
                AddLevel(High[i], false, touches);
        }
        
        // Check for swing low  
        if(Low[i] < Low[i+1] && Low[i] < Low[i-1] &&
           Low[i] < Low[i+2] && Low[i] < Low[i-2])
        {
            int touches = CountTouches(Low[i], false);
            if(touches >= 2)
                AddLevel(Low[i], true, touches);
        }
    }
}

//+------------------------------------------------------------------+
//| Count price level touches                                       |
//+------------------------------------------------------------------+
int CountTouches(double level, bool isHigh)
{
    int touches = 1;
    double tolerance = BreakoutPips * g_pointValue;
    
    for(int i = 1; i < LookbackBars * 2 && i < Bars; i++)
    {
        if(isHigh && MathAbs(High[i] - level) <= tolerance)
            touches++;
        else if(!isHigh && MathAbs(Low[i] - level) <= tolerance)
            touches++;
    }
    
    return touches;
}

//+------------------------------------------------------------------+
//| Add S/R level                                                   |
//+------------------------------------------------------------------+
void AddLevel(double price, bool isSupport, int strength)
{
    g_levelCount++;
    ArrayResize(g_levels, g_levelCount);
    
    g_levels[g_levelCount-1].price = price;
    g_levels[g_levelCount-1].isSupport = isSupport;
    g_levels[g_levelCount-1].strength = strength;
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                      |
//+------------------------------------------------------------------+
void CheckBreakouts()
{
    if(g_levelCount == 0) return;
    if(GetOpenTrades() >= MaxTrades) return;
    
    double price = (Ask + Bid) / 2;
    double tolerance = BreakoutPips * g_pointValue;
    
    for(int i = 0; i < g_levelCount; i++)
    {
        double level = g_levels[i].price;
        
        // Bullish breakout
        if(!g_levels[i].isSupport && price > level + tolerance)
        {
            if(ValidateSignal(true))
                OpenTrade(true);
        }
        
        // Bearish breakout  
        if(g_levels[i].isSupport && price < level - tolerance)
        {
            if(ValidateSignal(false))
                OpenTrade(false);
        }
    }
}

//+------------------------------------------------------------------+
//| Validate trading signal                                         |
//+------------------------------------------------------------------+
bool ValidateSignal(bool isBuy)
{
    // Check if already have position in same direction
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MAGIC_NUM && OrderSymbol() == Symbol())
            {
                if((isBuy && OrderType() == OP_BUY) || 
                   (!isBuy && OrderType() == OP_SELL))
                    return false;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Open new trade                                                  |
//+------------------------------------------------------------------+
void OpenTrade(bool isBuy)
{
    double lots = CalculatePosition();
    if(lots <= 0) return;
    
    double sl, tp;
    int ticket;
    
    if(isBuy)
    {
        sl = NormalizeDouble(Ask - StopLossPips * g_pointValue, g_digits);
        tp = NormalizeDouble(Ask + TakeProfitPips * g_pointValue, g_digits);
        ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, 3, sl, tp, "Backtest Buy", MAGIC_NUM);
    }
    else
    {
        sl = NormalizeDouble(Bid + StopLossPips * g_pointValue, g_digits);
        tp = NormalizeDouble(Bid - TakeProfitPips * g_pointValue, g_digits);
        ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, 3, sl, tp, "Backtest Sell", MAGIC_NUM);
    }
    
    if(ticket > 0)
    {
        Print("Backtest trade opened: ", (isBuy ? "BUY" : "SELL"), " ", lots, " lots at ", 
              TimeToString(TimeCurrent()));
    }
}

//+------------------------------------------------------------------+
//| Calculate position size                                         |
//+------------------------------------------------------------------+
double CalculatePosition()
{
    double balance = AccountBalance();
    double risk = balance * RiskPercent / 100;
    
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    if(g_digits == 5 || g_digits == 3)
        pipValue *= 10;
    
    double lots = risk / (StopLossPips * pipValue);
    
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    lots = MathMax(minLot, MathMin(maxLot, NormalizeDouble(lots, 2)));
    
    return lots;
}

//+------------------------------------------------------------------+
//| Manage existing trades                                          |
//+------------------------------------------------------------------+
void ManageTrades()
{
    if(!UseTrailing) return;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MAGIC_NUM && OrderSymbol() == Symbol())
            {
                ApplyTrailingStop(OrderTicket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int ticket)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double trailDist = TrailPips * g_pointValue;
    
    if(OrderType() == OP_BUY)
    {
        double newSL = NormalizeDouble(Bid - trailDist, g_digits);
        if(newSL > OrderStopLoss() && newSL > OrderOpenPrice())
        {
            OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0);
        }
    }
    else if(OrderType() == OP_SELL)
    {
        double newSL = NormalizeDouble(Ask + trailDist, g_digits);
        if(newSL < OrderStopLoss() && newSL < OrderOpenPrice())
        {
            OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0);
        }
    }
}

//+------------------------------------------------------------------+
//| Get number of open trades                                       |
//+------------------------------------------------------------------+
int GetOpenTrades()
{
    int count = 0;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MAGIC_NUM && OrderSymbol() == Symbol())
                count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Remove chart objects                                            |
//+------------------------------------------------------------------+
void RemoveObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(StringFind(name, "SR_") == 0)
            ObjectDelete(name);
    }
} 