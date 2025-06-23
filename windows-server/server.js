import express from 'express';
import cors from 'cors';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

// MT4 data directory - configure this path for your MT4 installation
const MT4_DATA_PATH = process.env.MT4_DATA_PATH || 
  path.join(process.env.APPDATA, 'MetaQuotes', 'Terminal');

app.use(cors());
app.use(express.json());

// Helper function to read MT4 files
async function readMT4File(filename) {
  try {
    // Try multiple possible MT4 terminal folders
    const terminalFolders = await fs.readdir(MT4_DATA_PATH);
    
    for (const folder of terminalFolders) {
      if (folder.length === 32) { // Terminal folder names are 32-character hashes
        const filePath = path.join(MT4_DATA_PATH, folder, 'MQL4', 'Files', filename);
        try {
          const content = await fs.readFile(filePath, 'utf-8');
          return content.trim();
        } catch (err) {
          // File doesn't exist in this terminal folder, try next
          continue;
        }
      }
    }
    throw new Error(`File ${filename} not found in any terminal folder`);
  } catch (error) {
    throw new Error(`Failed to read MT4 file ${filename}: ${error.message}`);
  }
}

// Helper function to write MT4 files
async function writeMT4File(filename, content) {
  try {
    const terminalFolders = await fs.readdir(MT4_DATA_PATH);
    let written = false;
    
    for (const folder of terminalFolders) {
      if (folder.length === 32) {
        const filesDir = path.join(MT4_DATA_PATH, folder, 'MQL4', 'Files');
        try {
          await fs.mkdir(filesDir, { recursive: true });
          const filePath = path.join(filesDir, filename);
          await fs.writeFile(filePath, content, 'utf-8');
          written = true;
          break; // Write to first available terminal folder
        } catch (err) {
          continue;
        }
      }
    }
    
    if (!written) {
      throw new Error('No writable terminal folder found');
    }
  } catch (error) {
    throw new Error(`Failed to write MT4 file ${filename}: ${error.message}`);
  }
}

// API Routes

// Get account information
app.get('/api/account', async (req, res) => {
  try {
    const accountData = await readMT4File('account_info.txt');
    const lines = accountData.split('\\n');
    const info = {};
    
    for (const line of lines) {
      const [key, value] = line.split('=');
      if (key && value) {
        info[key.trim()] = value.trim();
      }
    }
    
    res.json(info);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get market data for a symbol
app.get('/api/market/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;
    const marketData = await readMT4File(`market_data_${symbol}.txt`);
    const lines = marketData.split('\\n');
    const data = {};
    
    for (const line of lines) {
      const [key, value] = line.split('=');
      if (key && value) {
        data[key.trim()] = value.trim();
      }
    }
    
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Place an order
app.post('/api/order', async (req, res) => {
  try {
    const orderCommand = {
      action: 'PLACE_ORDER',
      ...req.body,
      timestamp: Date.now(),
    };
    
    await writeMT4File('order_commands.txt', JSON.stringify(orderCommand));
    
    // Wait a moment for MT4 to process and read the result
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
      const result = await readMT4File('order_result.txt');
      res.json({ success: true, result: JSON.parse(result) });
    } catch (err) {
      res.json({ success: true, message: 'Order command sent to MT4' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get open positions
app.get('/api/positions', async (req, res) => {
  try {
    const positionsData = await readMT4File('positions.txt');
    const lines = positionsData.split('\\n');
    const positions = [];
    let currentPosition = {};
    
    for (const line of lines) {
      if (line === '---') {
        if (Object.keys(currentPosition).length > 0) {
          positions.push(currentPosition);
          currentPosition = {};
        }
      } else if (line.includes('=')) {
        const [key, value] = line.split('=');
        if (key && value) {
          currentPosition[key.trim()] = value.trim();
        }
      }
    }
    
    if (Object.keys(currentPosition).length > 0) {
      positions.push(currentPosition);
    }
    
    res.json({ positions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Close a position
app.post('/api/close', async (req, res) => {
  try {
    const closeCommand = {
      action: 'CLOSE_POSITION',
      ticket: req.body.ticket,
      timestamp: Date.now(),
    };
    
    await writeMT4File('close_commands.txt', JSON.stringify(closeCommand));
    
    // Wait for MT4 to process
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
      const result = await readMT4File('close_result.txt');
      res.json({ success: true, result: JSON.parse(result) });
    } catch (err) {
      res.json({ success: true, message: 'Close command sent to MT4' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get trading history
app.get('/api/history', async (req, res) => {
  try {
    const days = req.query.days || 7;
    const historyData = await readMT4File(`history_${days}d.txt`);
    const lines = historyData.split('\\n');
    const history = [];
    let currentTrade = {};
    
    for (const line of lines) {
      if (line === '---') {
        if (Object.keys(currentTrade).length > 0) {
          history.push(currentTrade);
          currentTrade = {};
        }
      } else if (line.includes('=')) {
        const [key, value] = line.split('=');
        if (key && value) {
          currentTrade[key.trim()] = value.trim();
        }
      }
    }
    
    if (Object.keys(currentTrade).length > 0) {
      history.push(currentTrade);
    }
    
    res.json({ history });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    mt4_path: MT4_DATA_PATH
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MT4 HTTP Bridge running on http://0.0.0.0:${PORT}`);
  console.log(`MT4 Data Path: ${MT4_DATA_PATH}`);
  console.log('Make sure MT4 is running with the MCPBridge Expert Advisor attached to a chart');
});