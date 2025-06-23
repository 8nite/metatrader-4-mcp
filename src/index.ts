#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import axios from "axios";
import { z } from "zod";

class MT4MCPServer {
  private server: Server;
  private mt4Host: string;
  private mt4Port: number;

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
      const response = data 
        ? await axios.post(url, data, { timeout: 10000 })
        : await axios.get(url, { timeout: 10000 });
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`MT4 API Error: ${error.message} (${error.code})`);
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

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("MT4 MCP server running on stdio");
  }
}

const server = new MT4MCPServer();
server.run().catch(console.error);