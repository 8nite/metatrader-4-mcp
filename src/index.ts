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
        ? await axios.post(url, data, { timeout: 10000 })
        : await axios.get(url, { timeout: 10000 });
      
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
    const experts = await this.makeApiCall("/api/experts");

    return {
      content: [
        {
          type: "text",
          text: `Available Expert Advisors:\n${JSON.stringify(experts, null, 2)}`,
        },
      ],
    };
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

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("MT4 MCP server running on stdio");
  }
}

const server = new MT4MCPServer();
server.run().catch(console.error);