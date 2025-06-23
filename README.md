# MCP MetaTrader 4 Server

A Model Context Protocol (MCP) server that provides cross-platform integration with MetaTrader 4 trading platform over network.

**Author**: 8nite (8nite@qmlab.io)

## Features

- **Account Information**: Get real-time account details (balance, equity, margin, etc.)
- **Market Data**: Retrieve current market prices for trading symbols
- **Order Management**: Place market and pending orders
- **Position Management**: View and close open positions
- **Trading History**: Access historical trading data
- **Backtesting**: Run backtests on Expert Advisors with detailed configuration
- **Expert Advisor Management**: List and manage available EAs
- **File-Based Fallback**: Robust status and results tracking when API endpoints fail
- **EA Development**: Remote EA creation, editing, sync, and compilation with error reporting
- **Cross-Platform**: Linux MCP server connects to Windows MT4 via HTTP

## Architecture

The integration uses HTTP communication between the MCP server and MT4:

1. **MCP Server** (Linux - Node.js/TypeScript) - Provides tools for Claude Code
2. **HTTP Bridge** (Windows - Node.js) - Converts HTTP requests to file I/O
3. **MT4 Expert Advisor** (Windows - MQL4) - Handles trading operations
4. **Network Communication** - JSON-based data exchange via HTTP API

## Setup

### 1. Install MCP Server (Linux Machine - 192.168.50.X)

```bash
npm install
npm run build
```

### 2. Install HTTP Bridge (Windows Machine - 192.168.50.161)

1. Copy the `windows-server/` folder to your Windows machine
2. Install Node.js on Windows if not already installed
3. Navigate to the `windows-server` folder and run:
```cmd
npm install
npm start
```
4. The HTTP bridge will start on port 8080

### 3. Install MT4 Expert Advisor (Windows Machine)

**Option A: Unified EA (Recommended)**
1. Copy `MT4_Files/MCPBridge_Unified.mq4` to your MT4 `MQL4/Experts/` folder
2. Compile the Expert Advisor in MetaEditor
3. Attach the Expert Advisor to any chart in MT4
4. Configure EA inputs:
   - `EnableFileReporting`: true (for enhanced reporting)
   - `EnableBacktestTracking`: true (for backtest monitoring)
5. Ensure "Allow DLL imports" is enabled in MT4 settings

**Option B: Legacy EA**
1. Copy `MT4_Files/MCPBridge.mq4` to your MT4 `MQL4/Experts/` folder
2. Follow same compilation and attachment process
3. Limited to basic MCP functionality without enhanced reporting

### 4. Configure Claude Code (Linux Machine)

Add the MCP server to your Claude Code configuration:

```bash
claude mcp add mt4-server npm run start
```

Or configure manually with custom IP:

```bash
MT4_HOST=192.168.50.161 MT4_PORT=8080 claude mcp add mt4-server npm run start
```

Or in your MCP settings:

```json
{
  "mcpServers": {
    "mt4-server": {
      "command": "node",
      "args": ["dist/index.js"],
      "env": {
        "MT4_HOST": "192.168.50.161",
        "MT4_PORT": "8080"
      }
    }
  }
}
```

## Usage

Once configured, you can use these tools in Claude Code:

### Get Account Information
```
Use the get_account_info tool to see my MT4 account details
```

### Get Market Data
```
Get current market data for EURUSD using get_market_data
```

### Place Orders
```
Place a BUY order for 0.1 lots of EURUSD with stop loss at 1.0850 and take profit at 1.0950
```

### View Positions
```
Show me all my open positions using get_positions
```

### Close Position
```
Close position with ticket number 12345
```

### Run Backtest
```
Run a backtest on MACD Sample Expert Advisor for EURUSD H1 from 2024-01-01 to 2024-12-31 with initial deposit 10000
```

### List Expert Advisors
```
Show me all available Expert Advisors for backtesting
```

### Get Backtest Results
```
Get the results from the last backtest with detailed information
```

### Monitor Backtest Status
```
Check the current status of a running backtest
```

## EA Development Workflow

### List Local EAs
```
Show me all EAs in the active development folder
```

### Sync EA to MT4
```
Upload MyStrategy EA to MetaTrader for compilation
```

### Compile EA
```
Compile MyStrategy EA and show any errors or warnings
```

### Create New EA from Template
```bash
cd ea-strategies
./develop.sh new MyNewStrategy SimpleMA_Template.mq4
./develop.sh edit MyNewStrategy
```

## File Structure

```
├── src/
│   └── index.ts                    # MCP server implementation
├── ea-strategies/                  # EA development workspace
│   ├── templates/                  # EA templates and examples
│   ├── active/                     # EAs under development
│   ├── compiled/                   # Successfully compiled EAs
│   ├── logs/                       # Compilation logs and error reports
│   ├── develop.sh                  # Development helper script
│   └── README.md                   # EA development guide
├── MT4_Files/
│   ├── MCPBridge_Unified.mq4      # Unified MCP Bridge with enhanced reporting
│   └── MCPBridge.mq4              # Legacy MCP Bridge (basic functionality)
├── dist/                          # Compiled JavaScript
├── MCPBridge_Unified_Guide.md     # Complete setup guide for unified EA
├── bridge-endpoints-needed.md     # Required HTTP bridge endpoints
├── package.json
└── tsconfig.json
```

## Data Files

The Expert Advisor creates these files in MT4's `MQL4/Files/` folder:

- `account_info.txt` - Account information
- `market_data_[SYMBOL].txt` - Market data for each symbol
- `positions.txt` - Open positions
- `order_commands.txt` - Incoming order commands
- `close_commands.txt` - Position close commands

### File-Based Reporting (New Feature)

For enhanced backtest monitoring, EAs can write to the reports directory:

- `mt4_reports/backtest_status.json` - Real-time backtest status and progress
- `mt4_reports/backtest_results.json` - Detailed backtest results and statistics
- `mt4_reports/backtest_report.html` - Optional HTML report for detailed analysis

The MCP server automatically falls back to reading these files when API endpoints are unavailable.

**Configuration**: Set `MT4_REPORTS_PATH` environment variable to customize the reports directory (default: `/tmp/mt4_reports`)

## Security Notes

- This integration is for educational/personal use
- Never share your MT4 login credentials
- Test thoroughly on a demo account before using with real money
- The file-based communication is simple but not encrypted

## Limitations

- File I/O based communication has some latency
- Limited to MT4 platform capabilities
- Requires MT4 to be running with the Expert Advisor attached
- No real-time streaming data (periodic updates only)

## Troubleshooting

1. **MCP Server not responding**: Check that MT4 is running with the Expert Advisor
2. **No market data**: Ensure the symbols are available in your MT4 Market Watch
3. **Orders not executing**: Verify that automated trading is enabled in MT4
4. **File access errors**: Check MT4 data path configuration and file permissions
5. **Backtest status/results not available**: 
   - Check if API endpoints are responding (server will auto-fallback to files)
   - Ensure EA is writing to `mt4_reports/` directory using the provided template
   - Verify `MT4_REPORTS_PATH` environment variable is set correctly
6. **File-based fallback not working**: Ensure reports directory exists and has proper permissions

## Environment Variables

- `MT4_HOST`: IP address of Windows machine running MT4 (default: 192.168.50.161)
- `MT4_PORT`: Port number for HTTP bridge (default: 8080)  
- `MT4_REPORTS_PATH`: Directory path for EA report files (default: /tmp/mt4_reports)

## EA Integration Guide

To enable file-based reporting in your Expert Advisors:

1. Copy the `EA_FileReporting_Template.mq4` code into your EA
2. Call `WriteBacktestStatus()` periodically during backtesting
3. Call `WriteBacktestResults()` when backtest completes
4. Ensure MT4 has write permissions to the reports directory

The MCP server will automatically detect and use these files when API endpoints fail.

## Unified EA Setup

**MCPBridge_Unified.mq4** combines both MCP communication and enhanced reporting:

### Key Features
- **All MCP Bridge Functions**: Account info, market data, order management
- **Enhanced Backtest Reporting**: Real-time status and comprehensive results
- **Configurable Options**: Enable/disable reporting features as needed
- **Live Trading Support**: Works for both backtesting and live trading

### Quick Setup
1. Use `MCPBridge_Unified.mq4` instead of separate EAs
2. Enable both `EnableFileReporting` and `EnableBacktestTracking` in EA inputs
3. Full MCP functionality with automatic file-based fallback

See `MCPBridge_Unified_Guide.md` for detailed setup instructions.