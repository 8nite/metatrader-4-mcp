//+------------------------------------------------------------------+
//|                                        AdvancedBreakoutEA.mq4 |
//|                        Copyright 2024, Advanced Breakout EA     |
//|                                Professional Breakout Strategy   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Advanced Breakout EA"
#property link      ""
#property version   "1.00"
#property strict

//--- Input parameters for strategy configuration
//=== BREAKOUT STRATEGY SETTINGS ===
input int      LookbackPeriod = 20;           // Bars to look back for S/R levels
input double   BreakoutPips = 5.0;            // Minimum pips for valid breakout
input double   RiskPercent = 2.0;             // Risk percentage per trade
input bool     UseTrailingStop = true;        // Enable trailing stop
input double   TrailingStopPips = 15.0;       // Trailing stop distance in pips
input double   TrailingStepPips = 5.0;        // Trailing step in pips
input bool     UseDynamicTP = true;           // Use next S/R level as TP
input double   StaticTPPips = 30.0;           // Static TP in pips (if dynamic disabled)
input double   StopLossPips = 20.0;           // Stop loss in pips

//=== VISUAL SETTINGS ===
input bool     ShowSupportResistance = true;  // Show S/R lines
input bool     ShowBreakoutSignals = true;    // Show breakout arrows
input color    SupportColor = clrBlue;        // Support line color
input color    ResistanceColor = clrRed;      // Resistance line color
input color    BuySignalColor = clrLime;      // Buy signal color
input color    SellSignalColor = clrOrange;   // Sell signal color

//=== FILTERING SETTINGS ===
input bool     UseTimeFilter = false;         // Enable time filtering
input int      StartHour = 8;                 // Trading start hour
input int      EndHour = 18;                  // Trading end hour
input bool     UseVolumeFilter = true;        // Use volume confirmation
input double   MinVolumeMultiplier = 1.5;     // Minimum volume vs average
input bool     UseMomentumFilter = true;      // Use momentum confirmation
input int      MomentumPeriod = 14;           // Momentum indicator period

//=== RISK MANAGEMENT ===
input double   MaxDailyLoss = 100.0;         // Maximum daily loss in account currency
input int      MaxPositions = 2;             // Maximum concurrent positions
input bool     UseEquityProtection = true;   // Enable equity protection
input double   MaxDrawdownPercent = 10.0;    // Maximum drawdown percentage

//--- Global variables
double gPointValue;
double gTickSize;
int gDigits;
datetime gLastBarTime = 0;
double gDailyStartBalance = 0;
bool gTradingAllowed = true;

// Support and Resistance levels - MT4 compatible arrays
double gSRPrices[];
datetime gSRTimes[];
int gSRTouches[];
bool gSRIsSupport[];
int gSRCount = 0;

//--- Magic number for trades
#define MAGIC_NUMBER 20241201

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize symbol-specific variables
    gPointValue = Point;
    gDigits = Digits;
    
    // Adjust point value for 5-digit brokers
    if (gDigits == 5 || gDigits == 3) {
        gPointValue *= 10;
    }
    
    gDailyStartBalance = AccountBalance();
    
    Print("Advanced Breakout EA initialized for ", Symbol());
    Print("Point value: ", gPointValue);
    Print("Risk per trade: ", RiskPercent, "%");
    
    // Clean up old visual objects
    CleanUpVisuals();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanUpVisuals();
    Print("Advanced Breakout EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new bar
    if (Time[0] != gLastBarTime) {
        gLastBarTime = Time[0];
        
        // Reset daily balance at start of new day
        if (Hour() == 0 && Minute() == 0) {
            gDailyStartBalance = AccountBalance();
        }
        
        // Update trading permission
        UpdateTradingPermission();
        
        // Find support and resistance levels
        FindSupportResistanceLevels();
        
        // Draw visual elements
        if (ShowSupportResistance) {
            DrawSupportResistanceLevels();
        }
        
        // Check for breakout signals
        if (gTradingAllowed) {
            CheckBreakoutSignals();
        }
        
        // Manage existing trades
        ManageExistingTrades();
    }
}

//+------------------------------------------------------------------+
//| Update trading permission based on risk management rules        |
//+------------------------------------------------------------------+
void UpdateTradingPermission()
{
    gTradingAllowed = true;
    
    // Check daily loss limit
    double dailyPL = AccountBalance() - gDailyStartBalance;
    if (dailyPL <= -MaxDailyLoss) {
        gTradingAllowed = false;
        Comment("Trading stopped: Daily loss limit reached");
        return;
    }
    
    // Check equity protection
    if (UseEquityProtection) {
        double currentDrawdown = (gDailyStartBalance - AccountEquity()) / gDailyStartBalance * 100;
        if (currentDrawdown >= MaxDrawdownPercent) {
            gTradingAllowed = false;
            Comment("Trading stopped: Maximum drawdown reached");
            return;
        }
    }
    
    // Check maximum positions
    if (CountOpenPositions() >= MaxPositions) {
        gTradingAllowed = false;
        Comment("Trading stopped: Maximum positions reached");
        return;
    }
    
    // Check time filter
    if (UseTimeFilter) {
        int currentHour = Hour();
        if (currentHour < StartHour || currentHour > EndHour) {
            gTradingAllowed = false;
            Comment("Trading stopped: Outside trading hours");
            return;
        }
    }
    
    Comment("Advanced Breakout EA - Ready to trade | S/R Levels: " + IntegerToString(gSRCount));
}

//+------------------------------------------------------------------+
//| Find support and resistance levels                              |
//+------------------------------------------------------------------+
void FindSupportResistanceLevels()
{
    gSRCount = 0;
    ArrayResize(gSRPrices, 0);
    ArrayResize(gSRTimes, 0);
    ArrayResize(gSRTouches, 0);
    ArrayResize(gSRIsSupport, 0);
    
    // Find swing highs and lows
    for (int i = LookbackPeriod; i >= 2; i--) {
        
        // Check for swing high (resistance)
        if (High[i] > High[i+1] && High[i] > High[i-1] && 
            High[i] > High[i+2] && High[i] > High[i-2]) {
            
            // Verify this level with multiple touches
            int touches = CountTouches(High[i], true, i);
            if (touches >= 2) {
                AddSRLevel(High[i], Time[i], touches, false);
            }
        }
        
        // Check for swing low (support)
        if (Low[i] < Low[i+1] && Low[i] < Low[i-1] && 
            Low[i] < Low[i+2] && Low[i] < Low[i-2]) {
            
            // Verify this level with multiple touches
            int touches = CountTouches(Low[i], false, i);
            if (touches >= 2) {
                AddSRLevel(Low[i], Time[i], touches, true);
            }
        }
    }
    
    // Sort levels by strength (touches)
    SortSRLevelsByStrength();
}

//+------------------------------------------------------------------+
//| Count touches of a price level                                  |
//+------------------------------------------------------------------+
int CountTouches(double level, bool isHigh, int startBar)
{
    int touches = 1; // The bar that created the level
    double tolerance = BreakoutPips * gPointValue;
    
    for (int i = startBar + 1; i < LookbackPeriod * 2 && i < Bars; i++) {
        if (isHigh) {
            if (MathAbs(High[i] - level) <= tolerance) {
                touches++;
            }
        } else {
            if (MathAbs(Low[i] - level) <= tolerance) {
                touches++;
            }
        }
    }
    
    return touches;
}

//+------------------------------------------------------------------+
//| Add support/resistance level                                    |
//+------------------------------------------------------------------+
void AddSRLevel(double price, datetime time, int touches, bool isSupport)
{
    gSRCount++;
    ArrayResize(gSRPrices, gSRCount);
    ArrayResize(gSRTimes, gSRCount);
    ArrayResize(gSRTouches, gSRCount);
    ArrayResize(gSRIsSupport, gSRCount);
    
    gSRPrices[gSRCount-1] = price;
    gSRTimes[gSRCount-1] = time;
    gSRTouches[gSRCount-1] = touches;
    gSRIsSupport[gSRCount-1] = isSupport;
}

//+------------------------------------------------------------------+
//| Sort SR levels by strength (touches)                            |
//+------------------------------------------------------------------+
void SortSRLevelsByStrength()
{
    for (int i = 0; i < gSRCount - 1; i++) {
        for (int j = 0; j < gSRCount - 1 - i; j++) {
            if (gSRTouches[j] < gSRTouches[j+1]) {
                // Swap all arrays
                double tempPrice = gSRPrices[j];
                datetime tempTime = gSRTimes[j];
                int tempTouches = gSRTouches[j];
                bool tempIsSupport = gSRIsSupport[j];
                
                gSRPrices[j] = gSRPrices[j+1];
                gSRTimes[j] = gSRTimes[j+1];
                gSRTouches[j] = gSRTouches[j+1];
                gSRIsSupport[j] = gSRIsSupport[j+1];
                
                gSRPrices[j+1] = tempPrice;
                gSRTimes[j+1] = tempTime;
                gSRTouches[j+1] = tempTouches;
                gSRIsSupport[j+1] = tempIsSupport;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw support and resistance levels                              |
//+------------------------------------------------------------------+
void DrawSupportResistanceLevels()
{
    // Clean previous lines
    for (int i = ObjectsTotal() - 1; i >= 0; i--) {
        string objName = ObjectName(i);
        if (StringFind(objName, "SR_") == 0) {
            ObjectDelete(objName);
        }
    }
    
    // Draw current levels
    for (int i = 0; i < gSRCount && i < 10; i++) { // Limit to 10 strongest levels
        string objName = "SR_" + IntegerToString(i);
        color lineColor = gSRIsSupport[i] ? SupportColor : ResistanceColor;
        
        ObjectCreate(objName, OBJ_HLINE, 0, 0, gSRPrices[i]);
        ObjectSet(objName, OBJPROP_COLOR, lineColor);
        ObjectSet(objName, OBJPROP_WIDTH, 2);
        ObjectSet(objName, OBJPROP_STYLE, STYLE_SOLID);
        
        // Add label with touches count
        string labelName = objName + "_label";
        ObjectCreate(labelName, OBJ_TEXT, 0, Time[1], gSRPrices[i]);
        ObjectSetText(labelName, "T:" + IntegerToString(gSRTouches[i]), 8, "Arial", lineColor);
    }
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                      |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
    if (gSRCount == 0) return;
    
    double currentPrice = (Bid + Ask) / 2;
    double tolerance = BreakoutPips * gPointValue;
    
    // Check each S/R level for breakout
    for (int i = 0; i < gSRCount; i++) {
        double level = gSRPrices[i];
        bool isSupport = gSRIsSupport[i];
        
        // Bullish breakout (price above resistance)
        if (!isSupport && currentPrice > level + tolerance) {
            if (ValidateBreakout(true, i)) {
                ExecuteBreakoutTrade(true, level, i);
            }
        }
        
        // Bearish breakout (price below support)
        if (isSupport && currentPrice < level - tolerance) {
            if (ValidateBreakout(false, i)) {
                ExecuteBreakoutTrade(false, level, i);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Validate breakout signal with additional filters                |
//+------------------------------------------------------------------+
bool ValidateBreakout(bool isBullish, int levelIndex)
{
    // Volume filter
    if (UseVolumeFilter && Bars > 10) {
        double avgVolume = 0;
        for (int i = 1; i <= 10; i++) {
            avgVolume += Volume[i];
        }
        avgVolume /= 10;
        
        if (Volume[0] < avgVolume * MinVolumeMultiplier) {
            return false;
        }
    }
    
    // Momentum filter
    if (UseMomentumFilter && Bars > MomentumPeriod + 2) {
        double momentum = iMomentum(Symbol(), 0, MomentumPeriod, PRICE_CLOSE, 1);
        double prevMomentum = iMomentum(Symbol(), 0, MomentumPeriod, PRICE_CLOSE, 2);
        
        if (isBullish && momentum <= prevMomentum) return false;
        if (!isBullish && momentum >= prevMomentum) return false;
    }
    
    // Check if we already have a position in this direction
    if (HasPositionInDirection(isBullish)) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Execute breakout trade                                           |
//+------------------------------------------------------------------+
void ExecuteBreakoutTrade(bool isBuy, double breakoutLevel, int levelIndex)
{
    double lotSize = CalculateLotSize();
    if (lotSize <= 0) return;
    
    double sl = CalculateStopLoss(isBuy, breakoutLevel);
    double tp = CalculateTakeProfit(isBuy, levelIndex);
    
    int ticket = -1;
    string comment = "Breakout_" + (isBuy ? "Buy" : "Sell") + "_" + IntegerToString(levelIndex);
    
    if (isBuy) {
        ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, sl, tp, comment, MAGIC_NUMBER);
        
        if (ShowBreakoutSignals && ticket > 0) {
            string arrowName = "BuySignal_" + IntegerToString(ticket);
            ObjectCreate(arrowName, OBJ_ARROW, 0, Time[0], Low[0] - 10*gPointValue);
            ObjectSet(arrowName, OBJPROP_ARROWCODE, 233);
            ObjectSet(arrowName, OBJPROP_COLOR, BuySignalColor);
        }
    } else {
        ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, sl, tp, comment, MAGIC_NUMBER);
        
        if (ShowBreakoutSignals && ticket > 0) {
            string arrowName = "SellSignal_" + IntegerToString(ticket);
            ObjectCreate(arrowName, OBJ_ARROW, 0, Time[0], High[0] + 10*gPointValue);
            ObjectSet(arrowName, OBJPROP_ARROWCODE, 234);
            ObjectSet(arrowName, OBJPROP_COLOR, SellSignalColor);
        }
    }
    
    if (ticket > 0) {
        Print("Breakout trade executed: ", (isBuy ? "BUY" : "SELL"), " ", lotSize, " lots at ", 
              (isBuy ? Ask : Bid), " SL:", sl, " TP:", tp);
    } else {
        Print("Failed to execute breakout trade. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double accountBalance = AccountBalance();
    double riskAmount = accountBalance * RiskPercent / 100;
    double stopLossPips = StopLossPips;
    
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    if (Digits == 5 || Digits == 3) {
        pipValue = pipValue * 10;
    }
    
    double lotSize = riskAmount / (stopLossPips * pipValue);
    
    // Normalize lot size
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, MathRound(lotSize / lotStep) * lotStep));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate stop loss level                                       |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy, double breakoutLevel)
{
    double slDistance = StopLossPips * gPointValue;
    
    if (isBuy) {
        return NormalizeDouble(Ask - slDistance, gDigits);
    } else {
        return NormalizeDouble(Bid + slDistance, gDigits);
    }
}

//+------------------------------------------------------------------+
//| Calculate take profit level                                     |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy, int currentLevelIndex)
{
    if (UseDynamicTP) {
        // Find next S/R level in the direction of trade
        double nextLevel = FindNextSRLevel(isBuy, currentLevelIndex);
        if (nextLevel > 0) {
            return nextLevel;
        }
    }
    
    // Use static TP
    double tpDistance = StaticTPPips * gPointValue;
    
    if (isBuy) {
        return NormalizeDouble(Ask + tpDistance, gDigits);
    } else {
        return NormalizeDouble(Bid - tpDistance, gDigits);
    }
}

//+------------------------------------------------------------------+
//| Find next support/resistance level for dynamic TP              |
//+------------------------------------------------------------------+
double FindNextSRLevel(bool isBuy, int currentLevelIndex)
{
    double currentLevel = gSRPrices[currentLevelIndex];
    double bestLevel = 0;
    double minDistance = 100 * gPointValue; // Minimum distance for valid level
    
    for (int i = 0; i < gSRCount; i++) {
        if (i == currentLevelIndex) continue;
        
        double level = gSRPrices[i];
        
        if (isBuy && level > currentLevel) {
            if (level - currentLevel >= minDistance) {
                if (bestLevel == 0 || level < bestLevel) {
                    bestLevel = level;
                }
            }
        } else if (!isBuy && level < currentLevel) {
            if (currentLevel - level >= minDistance) {
                if (bestLevel == 0 || level > bestLevel) {
                    bestLevel = level;
                }
            }
        }
    }
    
    return bestLevel;
}

//+------------------------------------------------------------------+
//| Manage existing trades (trailing stop, etc.)                   |
//+------------------------------------------------------------------+
void ManageExistingTrades()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderMagicNumber() == MAGIC_NUMBER && OrderSymbol() == Symbol()) {
                if (UseTrailingStop) {
                    ApplyTrailingStop(OrderTicket());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                 |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int ticket)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double trailDistance = TrailingStopPips * gPointValue;
    double trailStep = TrailingStepPips * gPointValue;
    
    if (OrderType() == OP_BUY) {
        double newSL = NormalizeDouble(Bid - trailDistance, gDigits);
        if (newSL > OrderStopLoss() + trailStep || OrderStopLoss() == 0) {
            if (newSL > OrderOpenPrice()) { // Only move SL to profit
                bool result = OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0);
                if (result) {
                    Print("Trailing stop applied to BUY order ", ticket, " new SL: ", newSL);
                }
            }
        }
    } else if (OrderType() == OP_SELL) {
        double newSL = NormalizeDouble(Ask + trailDistance, gDigits);
        if (newSL < OrderStopLoss() - trailStep || OrderStopLoss() == 0) {
            if (newSL < OrderOpenPrice()) { // Only move SL to profit
                bool result = OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0);
                if (result) {
                    Print("Trailing stop applied to SELL order ", ticket, " new SL: ", newSL);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Count open positions                                            |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderMagicNumber() == MAGIC_NUMBER && OrderSymbol() == Symbol()) {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check if we have position in direction                          |
//+------------------------------------------------------------------+
bool HasPositionInDirection(bool isBuy)
{
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderMagicNumber() == MAGIC_NUMBER && OrderSymbol() == Symbol()) {
                if ((isBuy && OrderType() == OP_BUY) || (!isBuy && OrderType() == OP_SELL)) {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Clean up visual objects                                         |
//+------------------------------------------------------------------+
void CleanUpVisuals()
{
    for (int i = ObjectsTotal() - 1; i >= 0; i--) {
        string objName = ObjectName(i);
        if (StringFind(objName, "SR_") == 0 || 
            StringFind(objName, "BuySignal_") == 0 || 
            StringFind(objName, "SellSignal_") == 0) {
            ObjectDelete(objName);
        }
    }
    ChartRedraw();
}