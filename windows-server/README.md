# MT4 HTTP Bridge Server

Enhanced HTTP Bridge server for MetaTrader 4 integration with full EA development support.

## Features

### Core Trading Features
- Account information retrieval
- Real-time market data
- Order placement and management
- Position monitoring and closing
- Trading history access
- Backtesting support

### EA Development Features (NEW)
- **EA Upload**: Upload EA source files directly to MT4
- **EA Compilation**: Compile EAs using MetaEditor command line
- **EA Listing**: View all EAs in MT4 Experts directory
- **Compilation Logs**: Detailed error and warning reporting
- **MetaEditor Detection**: Automatic MetaEditor path detection

## Installation

### 1. Prerequisites
- Node.js 16+ installed on Windows
- MetaTrader 4 installed
- MCP Ultimate EA running in MT4

### 2. Install Dependencies
```cmd
cd windows-server
npm install
```

### 3. Configure Environment (Optional)
```cmd
# Set custom MT4 data path
set MT4_DATA_PATH=C:\Users\YourUser\AppData\Roaming\MetaQuotes\Terminal

# Set custom MetaEditor path
set MT4_INSTALL_PATH=C:\Program Files (x86)\MetaTrader 4\metaeditor64.exe

# Set custom port
set PORT=8080
```

### 4. Start the Server
```cmd
npm start
```

## API Endpoints

### Trading Endpoints
- `GET /api/account` - Get account information
- `GET /api/market/:symbol` - Get market data for symbol
- `POST /api/order` - Place trading order
- `GET /api/positions` - Get open positions
- `POST /api/close` - Close position
- `GET /api/history` - Get trading history
- `POST /api/backtest` - Run backtest
- `GET /api/backtest/results` - Get backtest results
- `GET /api/experts` - List available Expert Advisors

### EA Development Endpoints (NEW)
- `POST /api/ea/upload` - Upload EA source file
- `POST /api/ea/compile` - Compile EA using MetaEditor
- `GET /api/ea/list` - List EA files in Experts directory
- `GET /api/ea/metaeditor` - Get MetaEditor status and paths

### System Endpoints
- `GET /api/health` - Health check and feature list

## EA Upload API

### Upload EA Source File
```http
POST /api/ea/upload
Content-Type: application/json

{
  "ea_name": "MyStrategy",
  "ea_content": "//+------------------------------------------------------------------+\n//| EA Source Code Here..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "EA uploaded successfully",
  "ea_name": "MyStrategy",
  "file_path": "C:\\Users\\...\\MQL4\\Experts\\MyStrategy.mq4",
  "file_size": 15420,
  "experts_directory": "C:\\Users\\...\\MQL4\\Experts",
  "timestamp": "2025-06-24T02:00:00.000Z"
}
```

## EA Compilation API

### Compile EA
```http
POST /api/ea/compile
Content-Type: application/json

{
  "ea_name": "MyStrategy"
}
```

**Response:**
```json
{
  "success": true,
  "compiled": true,
  "ea_name": "MyStrategy",
  "source_file": "C:\\Users\\...\\MQL4\\Experts\\MyStrategy.mq4",
  "ex4_file": "C:\\Users\\...\\MQL4\\Experts\\MyStrategy.ex4",
  "errors": 0,
  "warnings": 2,
  "exit_code": 0,
  "log": "Compilation log content...",
  "log_file": "C:\\Users\\...\\MQL4\\Experts\\MyStrategy_compile.log",
  "timestamp": "2025-06-24T02:00:00.000Z",
  "message": "EA compiled successfully"
}
```

## Directory Structure

The server automatically detects MT4 installation and terminal directories:

```
MT4_DATA_PATH/
├── [32-char-hash]/          # Terminal instance directory
│   └── MQL4/
│       ├── Experts/         # EA files (.mq4 and .ex4)
│       ├── Include/         # Include files
│       └── Files/           # MCP communication files
```

## MetaEditor Integration

The server supports automatic MetaEditor detection with fallback paths:

1. `C:\Program Files (x86)\MetaTrader 4\metaeditor64.exe`
2. `C:\Program Files\MetaTrader 4\metaeditor64.exe`
3. `C:\Program Files (x86)\MT4\metaeditor64.exe`
4. `C:\Program Files\MT4\metaeditor64.exe`
5. Custom path from `MT4_INSTALL_PATH` environment variable

## Compilation Process

1. **Upload EA**: Source code uploaded to MT4 Experts directory
2. **Compile**: MetaEditor command line compilation with full logging
3. **Validation**: Check for .ex4 creation and parse error/warning counts
4. **Results**: Detailed compilation report with logs and file paths

## Error Handling

- **Path Detection**: Automatic MT4 and MetaEditor path detection
- **File Validation**: Verify file existence before operations
- **Compilation Logs**: Full MetaEditor output capture
- **Timeout Protection**: 30-second compilation timeout
- **Detailed Errors**: Comprehensive error reporting

## Integration with MCP

Works seamlessly with the enhanced MCP server:

```javascript
// MCP server automatically uses these endpoints
POST http://your-windows-machine:8080/api/ea/upload
POST http://your-windows-machine:8080/api/ea/compile
```

## Troubleshooting

### MetaEditor Not Found
```bash
# Set custom MetaEditor path
set MT4_INSTALL_PATH=C:\Your\Custom\Path\metaeditor64.exe
```

### MT4 Directory Not Found
```bash
# Set custom MT4 data path
set MT4_DATA_PATH=C:\Your\Custom\MetaQuotes\Terminal
```

### Compilation Fails
1. Check MetaEditor path is correct
2. Verify EA syntax is valid
3. Check compilation log for specific errors
4. Ensure MT4 is not running during compilation

### Permissions Issues
1. Run as Administrator if needed
2. Check MT4 directory write permissions
3. Ensure antivirus allows MetaEditor execution

## Security Notes

- The server runs on localhost by default
- Configure firewall rules for network access
- Validate EA source code before compilation
- Monitor compilation logs for security issues

## Full Automation Workflow

1. **MCP Server** → Send EA sync request
2. **HTTP Bridge** → Upload EA to MT4 Experts directory
3. **MetaEditor** → Compile EA with full logging
4. **HTTP Bridge** → Return compilation results
5. **MCP Server** → Update local logs and status
6. **MT4** → EA available for attachment to charts

The EA development workflow is now fully automated from Linux to Windows MT4!