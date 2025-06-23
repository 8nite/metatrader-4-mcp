//+------------------------------------------------------------------+
//|                                                   BreakoutEA.mq4 |
//|                        Copyright 2024, Breakout Strategy EA     |
//|                                 Professional Breakout Trading   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Breakout Strategy EA"
#property version   "1.00"
#property strict

// Input parameters
input group "=== STRATEGY SETTINGS ==="
input int      LookbackBars = 20;        // Lookback period for S/R levels  
input double   BreakoutPips = 5.0;       // Minimum breakout distance in pips
input double   RiskPercent = 2.0;        // Risk percentage per trade
input double   StopLossPips = 20.0;      // Stop loss in pips
input double   TakeProfitPips = 40.0;    // Take profit in pips
input bool     UseTrailing = true;       // Enable trailing stop
input double   TrailPips = 15.0;         // Trailing distance in pips

input group "=== VISUAL SETTINGS ==="
input bool     ShowSR = true;            // Show support/resistance lines
input color    SupportColor = clrBlue;   // Support line color
input color    ResistanceColor = clrRed; // Resistance line color

input group "=== RISK MANAGEMENT ==="
input int      MaxTrades = 2;            // Maximum concurrent trades
input double   MaxDailyLoss = 100.0;     // Maximum daily loss

// Global variables
double g_pointValue;
int g_digits;
datetime g_lastBar = 0;
double g_dailyBalance = 0;

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
    
    Print("Breakout EA initialized - Symbol: ", Symbol());
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    RemoveObjects();
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
            
        CheckRiskManagement();
        FindSRLevels();
        DrawSRLevels();
        CheckBreakouts();
        ManageTrades();
    }
}

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
    
    Comment("Breakout EA Active - Levels: " + IntegerToString(g_levelCount));
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
//| Draw S/R levels on chart                                        |
//+------------------------------------------------------------------+
void DrawSRLevels()
{
    if(!ShowSR) return;
    
    RemoveObjects();
    
    for(int i = 0; i < g_levelCount && i < 10; i++)
    {
        string name = "SR_" + IntegerToString(i);
        color lineColor = g_levels[i].isSupport ? SupportColor : ResistanceColor;
        
        ObjectCreate(name, OBJ_HLINE, 0, 0, g_levels[i].price);
        ObjectSet(name, OBJPROP_COLOR, lineColor);
        ObjectSet(name, OBJPROP_WIDTH, 2);
    }
    
    ChartRedraw();
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
        ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, 3, sl, tp, "Breakout Buy", MAGIC_NUM);
    }
    else
    {
        sl = NormalizeDouble(Bid + StopLossPips * g_pointValue, g_digits);
        tp = NormalizeDouble(Bid - TakeProfitPips * g_pointValue, g_digits);
        ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, 3, sl, tp, "Breakout Sell", MAGIC_NUM);
    }
    
    if(ticket > 0)
        Print("Trade opened: ", (isBuy ? "BUY" : "SELL"), " ", lots, " lots");
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