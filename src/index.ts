#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import axios from "axios";
import { z } from "zod";
import * as fs from "fs";
import * as path from "path";

class MT4MCPServer {
  private server: Server;
  private mt4Host: string;
  private mt4Port: number;
  private reportsPath: string;

  constructor() {
    this.server = new Server(
      {
        name: "mt4-mcp-server",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // MT4 Windows machine connection - configurable via environment variables
    this.mt4Host = process.env.MT4_HOST || "192.168.50.161";
    this.mt4Port = parseInt(process.env.MT4_PORT || "8080");
    
    // Path for EA reports and status files (configurable via environment)
    this.reportsPath = process.env.MT4_REPORTS_PATH || "/tmp/mt4_reports";
    
    this.setupToolHandlers();
  }

  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: "get_account_info",
            description: "Get MetaTrader 4 account information",
            inputSchema: {
              type: "object",
              properties: {},
            },
          },
          {
            name: "get_market_data",
            description: "Get current market data for a symbol",
            inputSchema: {
              type: "object",
              properties: {
                symbol: {
                  type: "string",
                  description: "Trading symbol (e.g., EURUSD, GBPUSD)",
                },
              },
              required: ["symbol"],
            },
          },
          {
            name: "place_order",
            description: "Place a trading order in MetaTrader 4",
            inputSchema: {
              type: "object",
              properties: {
                symbol: {
                  type: "string",
                  description: "Trading symbol",
                },
                operation: {
                  type: "string",
                  enum: ["BUY", "SELL", "BUY_LIMIT", "SELL_LIMIT", "BUY_STOP", "SELL_STOP"],
                  description: "Order operation type",
                },
                lots: {
                  type: "number",
                  description: "Position size in lots",
                },
                price: {
                  type: "number",
                  description: "Order price (for pending orders)",
                },
                stop_loss: {
                  type: "number",
                  description: "Stop loss price",
                },
                take_profit: {
                  type: "number", 
                  description: "Take profit price",
                },
                comment: {
                  type: "string",
                  description: "Order comment",
                },
              },
              required: ["symbol", "operation", "lots"],
            },
          },
          {
            name: "get_positions",
            description: "Get all open positions",
            inputSchema: {
              type: "object",
              properties: {},
            },
          },
          {
            name: "close_position",
            description: "Close an open position",
            inputSchema: {
              type: "object",
              properties: {
                ticket: {
                  type: "number",
                  description: "Position ticket number",
                },
              },
              required: ["ticket"],
            },
          },
          {
            name: "get_history",
            description: "Get trading history",
            inputSchema: {
              type: "object", 
              properties: {
                days: {
                  type: "number",
                  description: "Number of days to look back",
                  default: 7,
                },
              },
            },
          },
          {
            name: "run_backtest",
            description: "Run a backtest on an Expert Advisor",
            inputSchema: {
              type: "object",
              properties: {
                expert: {
                  type: "string",
                  description: "Expert Advisor name (without .ex4 extension)",
                },
                symbol: {
                  type: "string",
                  description: "Trading symbol (e.g., EURUSD, GBPUSD)",
                },
                timeframe: {
                  type: "string",
                  enum: ["M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"],
                  description: "Timeframe for backtesting",
                },
                from_date: {
                  type: "string",
                  description: "Start date (YYYY-MM-DD format)",
                },
                to_date: {
                  type: "string",
                  description: "End date (YYYY-MM-DD format)",
                },
                initial_deposit: {
                  type: "number",
                  description: "Initial deposit amount",
                  default: 10000,
                },
                model: {
                  type: "string",
                  enum: ["Every tick", "Control points", "Open prices only"],
                  description: "Testing model",
                  default: "Every tick",
                },
                optimization: {
                  type: "boolean",
                  description: "Enable optimization",
                  default: false,
                },
                parameters: {
                  type: "object",
                  description: "Expert Advisor parameters as key-value pairs",
                  additionalProperties: true,
                },
              },
              required: ["expert", "symbol", "timeframe", "from_date", "to_date"],
            },
          },
          {
            name: "get_backtest_results",
            description: "Get results from the last backtest",
            inputSchema: {
              type: "object",
              properties: {
                detailed: {
                  type: "boolean",
                  description: "Include detailed trade-by-trade results",
                  default: false,
                },
              },
            },
          },
          {
            name: "list_experts",
            description: "List available Expert Advisors for backtesting",
            inputSchema: {
              type: "object",
              properties: {},
            },
          },
          {
            name: "get_backtest_status",
            description: "Get the current status of a running backtest",
            inputSchema: {
              type: "object",
              properties: {},
            },
          },
          {
            name: "sync_ea",
            description: "Upload EA file to MetaTrader 4 for compilation",
            inputSchema: {
              type: "object",
              properties: {
                ea_name: {
                  type: "string",
                  description: "Name of the EA file (without .mq4 extension)",
                },
                ea_content: {
                  type: "string",
                  description: "MQL4 source code content",
                },
              },
              required: ["ea_name", "ea_content"],
            },
          },
          {
            name: "compile_ea",
            description: "Compile an EA on MetaTrader 4 and get compilation results",
            inputSchema: {
              type: "object",
              properties: {
                ea_name: {
                  type: "string",
                  description: "Name of the EA to compile (without .mq4 extension)",
                },
              },
              required: ["ea_name"],
            },
          },
          {
            name: "list_local_eas",
            description: "List EAs in the local development folders",
            inputSchema: {
              type: "object",
              properties: {
                folder: {
                  type: "string",
                  enum: ["active", "templates", "compiled"],
                  description: "Which folder to list",
                  default: "active",
                },
              },
            },
          },
          {
            name: "sync_ea_from_file",
            description: "Sync an existing EA file to MetaTrader 4",
            inputSchema: {
              type: "object",
              properties: {
                file_path: {
                  type: "string",
                  description: "Path to the EA file to sync",
                },
                ea_name: {
                  type: "string",
                  description: "Name for the EA (optional, will extract from filename if not provided)",
                },
              },
              required: ["file_path"],
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "get_account_info":
            return await this.getAccountInfo();
          case "get_market_data":
            return await this.getMarketData(args as { symbol: string });
          case "place_order":
            return await this.placeOrder(args as any);
          case "get_positions":
            return await this.getPositions();
          case "close_position":
            return await this.closePosition(args as { ticket: number });
          case "get_history":
            return await this.getHistory(args as { days?: number });
          case "run_backtest":
            return await this.runBacktest(args as any);
          case "get_backtest_results":
            return await this.getBacktestResults(args as { detailed?: boolean });
          case "list_experts":
            return await this.listExperts();
          case "get_backtest_status":
            return await this.getBacktestStatus();
          case "sync_ea":
            return await this.syncEA(args as { ea_name: string; ea_content: string });
          case "compile_ea":
            return await this.compileEA(args as { ea_name: string });
          case "list_local_eas":
            return await this.listLocalEAs(args as { folder?: string });
          case "sync_ea_from_file":
            return await this.syncEAFromFile(args as { file_path: string; ea_name?: string });
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error instanceof Error ? error.message : String(error)}`,
            },
          ],
        };
      }
    });
  }

  private async makeApiCall(endpoint: string, data?: any): Promise<any> {
    try {
      const url = `http://${this.mt4Host}:${this.mt4Port}${endpoint}`;
      console.error(`Making API call to: ${url}`);
      if (data) {
        console.error(`Request data: ${JSON.stringify(data)}`);
      }
      
      const response = data 
        ? await axios.post(url, data, { timeout: 30000 })
        : await axios.get(url, { timeout: 30000 });
      
      console.error(`Response status: ${response.status}`);
      console.error(`Response data: ${JSON.stringify(response.data)}`);
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        const statusCode = error.response?.status || 'unknown';
        const statusText = error.response?.statusText || 'unknown';
        throw new Error(`MT4 API Error: Request failed with status code ${statusCode} (${statusText})`);
      }
      throw new Error(`Failed to connect to MT4 at ${this.mt4Host}:${this.mt4Port}: ${error}`);
    }
  }

  private async getAccountInfo() {
    const accountData = await this.makeApiCall("/api/account");

    return {
      content: [
        {
          type: "text",
          text: `MT4 Account Information:\n${JSON.stringify(accountData, null, 2)}`,
        },
      ],
    };
  }

  private async getMarketData(args: { symbol: string }) {
    const { symbol } = args;
    const marketData = await this.makeApiCall(`/api/market/${symbol}`);
    
    return {
      content: [
        {
          type: "text",
          text: `Market data for ${symbol}:\n${JSON.stringify(marketData, null, 2)}`,
        },
      ],
    };
  }

  private async placeOrder(args: {
    symbol: string;
    operation: string;
    lots: number;
    price?: number;
    stop_loss?: number;
    take_profit?: number;
    comment?: string;
  }) {
    const orderData = {
      symbol: args.symbol,
      operation: args.operation,
      lots: args.lots,
      price: args.price || 0,
      stop_loss: args.stop_loss || 0,
      take_profit: args.take_profit || 0,
      comment: args.comment || "",
    };

    const result = await this.makeApiCall("/api/order", orderData);

    return {
      content: [
        {
          type: "text",
          text: `Order result:\n${JSON.stringify(result, null, 2)}`,
        },
      ],
    };
  }

  private async getPositions() {
    const positionsData = await this.makeApiCall("/api/positions");
    
    return {
      content: [
        {
          type: "text",
          text: `Open Positions:\n${JSON.stringify(positionsData, null, 2)}`,
        },
      ],
    };
  }

  private async closePosition(args: { ticket: number }) {
    const result = await this.makeApiCall("/api/close", { ticket: args.ticket });

    return {
      content: [
        {
          type: "text",
          text: `Close position result:\n${JSON.stringify(result, null, 2)}`,
        },
      ],
    };
  }

  private async getHistory(args: { days?: number }) {
    const days = args.days || 7;
    const historyData = await this.makeApiCall(`/api/history?days=${days}`);
    
    return {
      content: [
        {
          type: "text",
          text: `Trading History (${days} days):\n${JSON.stringify(historyData, null, 2)}`,
        },
      ],
    };
  }

  private async runBacktest(args: {
    expert: string;
    symbol: string;
    timeframe: string;
    from_date: string;
    to_date: string;
    initial_deposit?: number;
    model?: string;
    optimization?: boolean;
    parameters?: Record<string, any>;
  }) {
    const backtestData = {
      expert: args.expert,
      symbol: args.symbol,
      timeframe: args.timeframe,
      from_date: args.from_date,
      to_date: args.to_date,
      initial_deposit: args.initial_deposit || 10000,
      model: args.model || "Every tick",
      optimization: args.optimization || false,
      parameters: args.parameters || {},
    };

    const result = await this.makeApiCall("/api/backtest", backtestData);

    return {
      content: [
        {
          type: "text",
          text: `Backtest initiated:\n${JSON.stringify(result, null, 2)}`,
        },
      ],
    };
  }

  private async getBacktestResults(args: { detailed?: boolean }) {
    try {
      // First try the API endpoint
      const detailed = args.detailed || false;
      const endpoint = detailed ? "/api/backtest/results?detailed=true" : "/api/backtest/results";
      const results = await this.makeApiCall(endpoint);

      return {
        content: [
          {
            type: "text",
            text: `Backtest Results:\n${JSON.stringify(results, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      // Fallback to file-based results
      return await this.getBacktestResultsFromFile(args.detailed || false);
    }
  }

  private async getBacktestResultsFromFile(detailed: boolean) {
    try {
      const resultsFile = path.join(this.reportsPath, "backtest_results.json");
      const htmlReportFile = path.join(this.reportsPath, "backtest_report.html");
      
      if (!fs.existsSync(resultsFile)) {
        return {
          content: [
            {
              type: "text",
              text: `No backtest results file found at ${resultsFile}. EA should write results to this file.`,
            },
          ],
        };
      }

      const resultsData = fs.readFileSync(resultsFile, 'utf8');
      const results = JSON.parse(resultsData);
      
      // Add file timestamp for freshness indication
      const stats = fs.statSync(resultsFile);
      results.file_updated = stats.mtime.toISOString();

      // If detailed results requested and HTML report exists, include a reference
      if (detailed && fs.existsSync(htmlReportFile)) {
        const htmlStats = fs.statSync(htmlReportFile);
        results.html_report = {
          path: htmlReportFile,
          updated: htmlStats.mtime.toISOString(),
          size: htmlStats.size
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `Backtest Results (from file):\n${JSON.stringify(results, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `Error reading backtest results file: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  private async listExperts() {
    try {
      const experts = await this.makeApiCall("/api/experts");
      return {
        content: [
          {
            type: "text",
            text: `Available Expert Advisors:\n${JSON.stringify(experts, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      // Fallback to common EA names if file not found
      const commonExperts = [
        "MACD Sample",
        "Moving Average",
        "RSI Sample",
        "EA_FileReporting_Template"
      ];
      
      return {
        content: [
          {
            type: "text",
            text: `Expert Advisors (fallback list - experts_list.txt not found on MT4 side):\n${JSON.stringify(commonExperts, null, 2)}\n\nNote: The MT4 bridge needs to create experts_list.txt file for accurate listing.`,
          },
        ],
      };
    }
  }

  private async getBacktestStatus() {
    try {
      // First try the API endpoint
      const status = await this.makeApiCall("/api/backtest/status");
      return {
        content: [
          {
            type: "text",
            text: `Backtest Status:\n${JSON.stringify(status, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      // Fallback to file-based status
      return await this.getBacktestStatusFromFile();
    }
  }

  private async getBacktestStatusFromFile() {
    try {
      const statusFile = path.join(this.reportsPath, "backtest_status.json");
      
      if (!fs.existsSync(statusFile)) {
        return {
          content: [
            {
              type: "text",
              text: `No backtest status file found at ${statusFile}. EA should write status to this file.`,
            },
          ],
        };
      }

      const statusData = fs.readFileSync(statusFile, 'utf8');
      const status = JSON.parse(statusData);
      
      // Add file timestamp for freshness indication
      const stats = fs.statSync(statusFile);
      status.file_updated = stats.mtime.toISOString();

      return {
        content: [
          {
            type: "text",
            text: `Backtest Status (from file):\n${JSON.stringify(status, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `Error reading backtest status file: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  private async syncEA(args: { ea_name: string; ea_content: string }) {
    try {
      // Ensure directories exist
      const activeDir = path.join(process.cwd(), "ea-strategies", "active");
      const logsDir = path.join(process.cwd(), "ea-strategies", "logs");
      
      if (!fs.existsSync(activeDir)) {
        fs.mkdirSync(activeDir, { recursive: true });
      }
      if (!fs.existsSync(logsDir)) {
        fs.mkdirSync(logsDir, { recursive: true });
      }
      
      // Save EA locally first
      const eaPath = path.join(activeDir, `${args.ea_name}.mq4`);
      fs.writeFileSync(eaPath, args.ea_content, 'utf8');
      
      // Create sync log
      const syncLogPath = path.join(logsDir, `${args.ea_name}_sync.log`);
      const logEntry = `EA Sync Attempt for ${args.ea_name}.mq4\nDate: ${new Date().toISOString()}\nStatus: READY\n\nFile saved to: ${eaPath}\nFile size: ${args.ea_content.length} bytes\n\n`;
      fs.writeFileSync(syncLogPath, logEntry, 'utf8');
      
      try {
        // Try to send EA to MT4 via API
        const syncData = {
          ea_name: args.ea_name,
          ea_content: args.ea_content
        };
        
        const result = await this.makeApiCall("/api/ea/upload", syncData);
        
        // Log successful API sync
        const successLog = logEntry + `API SYNC SUCCESSFUL:\n${JSON.stringify(result, null, 2)}\n`;
        fs.writeFileSync(syncLogPath, successLog, 'utf8');
        
        return {
          content: [
            {
              type: "text",
              text: `✅ EA Sync Successful!\n\nAPI Result: ${JSON.stringify(result, null, 2)}\n\nLocal copy saved to: ${eaPath}\nSync log: ${syncLogPath}`,
            },
          ],
        };
      } catch (apiError) {
        // API failed, provide manual instructions
        const manualLog = logEntry + `HTTP Bridge Missing Endpoints:\n- POST /api/ea/upload (for EA file upload)\n- POST /api/ea/compile (for remote compilation)\n\nMANUAL DEPLOYMENT INSTRUCTIONS:\n1. Copy ${args.ea_name}.mq4 to MT4/MQL4/Experts/ folder\n2. Open MetaEditor (F4 in MT4)\n3. Compile the EA (F7)\n4. Check for compilation errors\n5. Attach to chart for testing\n\nAlternatively:\n- Use develop.sh script for local management\n- Wait for HTTP bridge endpoint implementation\n`;
        fs.writeFileSync(syncLogPath, manualLog, 'utf8');
        
        return {
          content: [
            {
              type: "text",
              text: `⚠️ EA Sync Prepared (API endpoints not available)\n\nThe EA has been saved locally and is ready for deployment:\n\n📁 Local file: ${eaPath}\n📋 Sync log: ${syncLogPath}\n\n🔧 Manual deployment:\n1. Copy the EA file to your MT4/MQL4/Experts/ folder\n2. Compile in MetaEditor (F7)\n3. Attach to chart\n\n🚀 Automated deployment (when available):\n- Implement /api/ea/upload and /api/ea/compile endpoints in HTTP bridge\n- Then EA sync will work automatically\n\n📊 File size: ${args.ea_content.length} bytes\n⏰ Saved at: ${new Date().toLocaleString()}`,
            },
          ],
        };
      }
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `❌ EA Sync Failed: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  private async compileEA(args: { ea_name: string }) {
    try {
      // Ensure directories exist
      const logsDir = path.join(process.cwd(), "ea-strategies", "logs");
      const compiledDir = path.join(process.cwd(), "ea-strategies", "compiled");
      
      if (!fs.existsSync(logsDir)) {
        fs.mkdirSync(logsDir, { recursive: true });
      }
      if (!fs.existsSync(compiledDir)) {
        fs.mkdirSync(compiledDir, { recursive: true });
      }
      
      // Check if EA exists locally
      const activePath = path.join(process.cwd(), "ea-strategies", "active", `${args.ea_name}.mq4`);
      if (!fs.existsSync(activePath)) {
        return {
          content: [
            {
              type: "text",
              text: `❌ EA ${args.ea_name}.mq4 not found in ea-strategies/active/\n\nPlease sync the EA first using sync_ea tool.`,
            },
          ],
        };
      }
      
      try {
        // Try to compile via API
        const compileData = { ea_name: args.ea_name };
        const result = await this.makeApiCall("/api/ea/compile", compileData);
        
        // Save compilation log locally
        const logPath = path.join(logsDir, `${args.ea_name}_compilation.log`);
        const logContent = `Remote Compilation at ${new Date().toISOString()}\nEA: ${args.ea_name}.mq4\nStatus: SUCCESS\n\nResult:\n${JSON.stringify(result, null, 2)}`;
        fs.writeFileSync(logPath, logContent, 'utf8');
        
        // If compilation successful, mark as compiled
        if (result.success) {
          const compiledPath = path.join(compiledDir, `${args.ea_name}.mq4`);
          fs.copyFileSync(activePath, compiledPath);
        }
        
        return {
          content: [
            {
              type: "text",
              text: `✅ Remote EA Compilation Successful!\n\nResult: ${JSON.stringify(result, null, 2)}\n\n📋 Log saved to: ${logPath}\n📁 EA copied to compiled folder: ${result.success ? 'Yes' : 'No'}`,
            },
          ],
        };
      } catch (apiError) {
        // API failed, provide manual instructions and local compilation status
        const logPath = path.join(logsDir, `${args.ea_name}_compilation.log`);
        const fileStats = fs.statSync(activePath);
        
        const manualLog = `Local Compilation Status for ${args.ea_name}.mq4\nDate: ${new Date().toISOString()}\nStatus: READY FOR MANUAL COMPILATION\n\nFile Details:\n- Path: ${activePath}\n- Size: ${fileStats.size} bytes\n- Modified: ${fileStats.mtime.toISOString()}\n\nMANUAL COMPILATION INSTRUCTIONS:\n1. Copy ${args.ea_name}.mq4 to MT4/MQL4/Experts/ folder\n2. Open MetaEditor (F4 in MT4)\n3. Open the EA file\n4. Compile with F7 or Compile button\n5. Check Errors/Warnings tab for issues\n6. If successful, .ex4 file will be created\n\nAPI Error: ${apiError}\n\nNOTE: HTTP bridge missing /api/ea/compile endpoint`;
        fs.writeFileSync(logPath, manualLog, 'utf8');
        
        return {
          content: [
            {
              type: "text",
              text: `⚠️ Remote compilation not available - Manual compilation required\n\n📁 EA ready for manual compilation:\n- File: ${activePath}\n- Size: ${fileStats.size} bytes\n- Modified: ${fileStats.mtime.toLocaleString()}\n\n🔧 Manual steps:\n1. Copy EA to MT4/MQL4/Experts/ folder\n2. Open MetaEditor (F4)\n3. Compile with F7\n4. Check for errors in Errors tab\n\n📋 Status log: ${logPath}\n\n🚀 For automatic compilation:\n- Implement /api/ea/compile endpoint in HTTP bridge\n- Then remote compilation will work seamlessly`,
            },
          ],
        };
      }
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `❌ EA Compilation Process Failed: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  private async listLocalEAs(args: { folder?: string }) {
    try {
      const folder = args.folder || "active";
      
      // Check multiple possible locations
      const possibleDirs = [
        path.join(process.cwd(), "ea-strategies", folder),
        path.join(process.cwd(), "strategies"),
        path.join(process.cwd(), "mcp"),
        path.join(process.cwd(), "MT4_Files")
      ];
      
      let foundFiles: any[] = [];
      
      for (const eaDir of possibleDirs) {
        if (fs.existsSync(eaDir)) {
          const files = fs.readdirSync(eaDir)
            .filter(file => file.endsWith('.mq4'))
            .map(file => {
              const filePath = path.join(eaDir, file);
              const stats = fs.statSync(filePath);
              return {
                name: file,
                size: stats.size,
                modified: stats.mtime.toISOString(),
                path: filePath,
                folder: path.basename(eaDir)
              };
            });
          foundFiles = foundFiles.concat(files);
        }
      }
      
      if (foundFiles.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `No .mq4 files found in any EA folders. Searched:\n${possibleDirs.join('\n')}`,
            },
          ],
        };
      }
      
      return {
        content: [
          {
            type: "text",
            text: `Found ${foundFiles.length} EA files:\n${JSON.stringify(foundFiles, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `Error listing EAs: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  private async syncEAFromFile(args: { file_path: string; ea_name?: string }) {
    try {
      // Check if file exists
      if (!fs.existsSync(args.file_path)) {
        return {
          content: [
            {
              type: "text",
              text: `❌ File not found: ${args.file_path}`,
            },
          ],
        };
      }
      
      // Read the EA content
      const eaContent = fs.readFileSync(args.file_path, 'utf8');
      
      // Extract EA name from file path if not provided
      const fileName = path.basename(args.file_path, '.mq4');
      const eaName = args.ea_name || fileName;
      
      // Call the existing syncEA function
      return await this.syncEA({ ea_name: eaName, ea_content: eaContent });
      
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `❌ Error reading EA file: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("MT4 MCP server running on stdio");
  }
}

const server = new MT4MCPServer();
server.run().catch(console.error);