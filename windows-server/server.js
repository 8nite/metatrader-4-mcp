import express from "express";
import cors from "cors";
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { spawn } from "child_process";
import { promisify } from "util";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

// MT4 data directory - configure this path for your MT4 installation
const MT4_DATA_PATH =
  "C:\\Users\\herbe\\AppData\\Roaming\\MetaQuotes\\Terminal"; //process.env.MT4_DATA_PATH || path.join(process.env.APPDATA, 'MetaQuotes', 'Terminal');

// MT4 installation path for MetaEditor
const MT4_INSTALL_PATH =
  process.env.MT4_INSTALL_PATH ||
  "C:\\Program Files (x86)\\Pepperstone MetaTrader 4\\metaeditor.exe";

// Alternative paths to try for MetaEditor
const METAEDITOR_PATHS = MT4_INSTALL_PATH; //[process.env.MT4_INSTALL_PATH].filter(Boolean);

app.use(cors());
app.use(express.json());

// Helper function to read MT4 files
async function readMT4File(filename) {
  try {
    // Try multiple possible MT4 terminal folders
    const terminalFolders = await fs.readdir(MT4_DATA_PATH);

    for (const folder of terminalFolders) {
      if (folder.length === 32) {
        // Terminal folder names are 32-character hashes
        const filePath = path.join(
          MT4_DATA_PATH,
          folder,
          "MQL4",
          "Files",
          filename
        );
        try {
          const content = await fs.readFile(filePath, "utf-8");
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
        const filesDir = path.join(MT4_DATA_PATH, folder, "MQL4", "Files");
        try {
          await fs.mkdir(filesDir, { recursive: true });
          const filePath = path.join(filesDir, filename);
          await fs.writeFile(filePath, content, "utf-8");
          written = true;
          break; // Write to first available terminal folder
        } catch (err) {
          continue;
        }
      }
    }

    if (!written) {
      throw new Error("No writable terminal folder found");
    }
  } catch (error) {
    throw new Error(`Failed to write MT4 file ${filename}: ${error.message}`);
  }
}

// Helper function to find MT4 Experts directory
async function findMT4ExpertsDirectory() {
  try {
    const terminalFolders = await fs.readdir(MT4_DATA_PATH);

    for (const folder of terminalFolders) {
      if (folder.length === 32) {
        // Terminal folder names are 32-character hashes
        const expertsPath = path.join(MT4_DATA_PATH, folder, "MQL4", "Experts");
        try {
          await fs.access(expertsPath);
          return expertsPath;
        } catch (err) {
          continue;
        }
      }
    }

    throw new Error("No MT4 Experts directory found");
  } catch (error) {
    throw new Error(`Failed to find MT4 Experts directory: ${error.message}`);
  }
}

// Helper function to find MetaEditor executable
async function findMetaEditor() {
  for (const editorPath of METAEDITOR_PATHS) {
    try {
      await fs.access(editorPath);
      return editorPath;
    } catch (err) {
      continue;
    }
  }
  throw new Error(
    "MetaEditor not found. Please set MT4_INSTALL_PATH environment variable."
  );
}

// Helper function to compile EA using MetaEditor
async function compileEA(eaPath) {
  return new Promise(async (resolve, reject) => {
    try {
      const metaEditorPath = await findMetaEditor();
      const logFile = path.join(
        path.dirname(eaPath),
        `${path.basename(eaPath, ".mq4")}_compile.log`
      );

      // MetaEditor command line compilation
      const compiler = spawn(metaEditorPath, [
        `/compile:${eaPath}`,
        `/log:${logFile}`,
        `/inc:${path.dirname(eaPath)}\\..\\Include`,
      ]);

      let stdout = "";
      let stderr = "";

      compiler.stdout?.on("data", (data) => {
        stdout += data.toString();
      });

      compiler.stderr?.on("data", (data) => {
        stderr += data.toString();
      });

      compiler.on("close", async (code) => {
        try {
          // Read compilation log if it exists
          let logContent = "";
          try {
            logContent = await fs.readFile(logFile, "utf-8");
          } catch (logErr) {
            logContent = "Compilation log not available";
          }

          // Check if .ex4 file was created
          const ex4Path = eaPath.replace(".mq4", ".ex4");
          let compiled = false;
          try {
            await fs.access(ex4Path);
            compiled = true;
          } catch (ex4Err) {
            // .ex4 not created, compilation likely failed
          }

          // Parse log for errors and warnings
          const errors = (logContent.match(/\d+ error\(s\)/gi) || [
            "0 error(s)",
          ])[0];
          const warnings = (logContent.match(/\d+ warning\(s\)/gi) || [
            "0 warning(s)",
          ])[0];

          const errorCount = parseInt(errors.match(/\d+/)[0]) || 0;
          const warningCount = parseInt(warnings.match(/\d+/)[0]) || 0;

          resolve({
            success: errorCount === 0,
            compiled: compiled,
            exit_code: code,
            errors: errorCount,
            warnings: warningCount,
            log: logContent,
            stdout: stdout,
            stderr: stderr,
            ex4_path: compiled ? ex4Path : null,
            log_file: logFile,
          });
        } catch (parseError) {
          reject(
            new Error(
              `Failed to parse compilation results: ${parseError.message}`
            )
          );
        }
      });

      compiler.on("error", (error) => {
        reject(new Error(`Failed to start MetaEditor: ${error.message}`));
      });

      // Set timeout for compilation
      setTimeout(() => {
        compiler.kill();
        reject(new Error("Compilation timeout after 30 seconds"));
      }, 30000);
    } catch (error) {
      reject(error);
    }
  });
}

// API Routes

// Get account information
app.get("/api/account", async (req, res) => {
  try {
    const accountData = await readMT4File("account_info.txt");
    const lines = accountData.split("\\n");
    const info = {};

    for (const line of lines) {
      const [key, value] = line.split("=");
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
app.get("/api/market/:symbol", async (req, res) => {
  try {
    const { symbol } = req.params;
    const marketData = await readMT4File(`market_data_${symbol}.txt`);
    const lines = marketData.split("\\n");
    const data = {};

    for (const line of lines) {
      const [key, value] = line.split("=");
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
app.post("/api/order", async (req, res) => {
  try {
    const orderCommand = {
      action: "PLACE_ORDER",
      ...req.body,
      timestamp: Date.now(),
    };

    await writeMT4File("order_commands.txt", JSON.stringify(orderCommand));

    // Wait a moment for MT4 to process and read the result
    await new Promise((resolve) => setTimeout(resolve, 1000));

    try {
      const result = await readMT4File("order_result.txt");
      res.json({ success: true, result: JSON.parse(result) });
    } catch (err) {
      res.json({ success: true, message: "Order command sent to MT4" });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get open positions
app.get("/api/positions", async (req, res) => {
  try {
    const positionsData = await readMT4File("positions.txt");
    const lines = positionsData.split("\\n");
    const positions = [];
    let currentPosition = {};

    for (const line of lines) {
      if (line === "---") {
        if (Object.keys(currentPosition).length > 0) {
          positions.push(currentPosition);
          currentPosition = {};
        }
      } else if (line.includes("=")) {
        const [key, value] = line.split("=");
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
app.post("/api/close", async (req, res) => {
  try {
    const closeCommand = {
      action: "CLOSE_POSITION",
      ticket: req.body.ticket,
      timestamp: Date.now(),
    };

    await writeMT4File("close_commands.txt", JSON.stringify(closeCommand));

    // Wait for MT4 to process
    await new Promise((resolve) => setTimeout(resolve, 1000));

    try {
      const result = await readMT4File("close_result.txt");
      res.json({ success: true, result: JSON.parse(result) });
    } catch (err) {
      res.json({ success: true, message: "Close command sent to MT4" });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get trading history
app.get("/api/history", async (req, res) => {
  try {
    const days = req.query.days || 7;
    const historyData = await readMT4File(`history_${days}d.txt`);
    const lines = historyData.split("\\n");
    const history = [];
    let currentTrade = {};

    for (const line of lines) {
      if (line === "---") {
        if (Object.keys(currentTrade).length > 0) {
          history.push(currentTrade);
          currentTrade = {};
        }
      } else if (line.includes("=")) {
        const [key, value] = line.split("=");
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

// Run backtest
app.post("/api/backtest", async (req, res) => {
  try {
    const backtestCommand = {
      action: "RUN_BACKTEST",
      ...req.body,
      timestamp: Date.now(),
    };

    await writeMT4File(
      "backtest_commands.txt",
      JSON.stringify(backtestCommand)
    );

    res.json({
      success: true,
      message: "Backtest command sent to MT4",
      expert: req.body.expert,
      symbol: req.body.symbol,
      timeframe: req.body.timeframe,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get backtest results
app.get("/api/backtest/results", async (req, res) => {
  try {
    const detailed = req.query.detailed === "true";
    const filename = detailed
      ? "backtest_results_detailed.txt"
      : "backtest_results.txt";

    const resultsData = await readMT4File(filename);

    try {
      const results = JSON.parse(resultsData);
      res.json(results);
    } catch (parseError) {
      // If not JSON, return as text report
      res.json({ report: resultsData });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// List available Expert Advisors
app.get("/api/experts", async (req, res) => {
  try {
    const expertsData = await readMT4File("experts_list.txt");
    const lines = expertsData.split("\\n").filter((line) => line.trim());
    const experts = lines.map((line) => {
      const parts = line.split("|");
      return {
        name: parts[0]?.trim(),
        description: parts[1]?.trim() || "",
        modified: parts[2]?.trim() || "",
      };
    });

    res.json({ experts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// EA Upload endpoint
app.post("/api/ea/upload", async (req, res) => {
  try {
    const { ea_name, ea_content } = req.body;

    if (!ea_name || !ea_content) {
      return res.status(400).json({
        success: false,
        error: "Missing ea_name or ea_content",
      });
    }

    // Find MT4 Experts directory
    const expertsDir = await findMT4ExpertsDirectory();
    const eaFilePath = path.join(expertsDir, `${ea_name}.mq4`);

    // Write EA file to MT4 Experts directory
    await fs.writeFile(eaFilePath, ea_content, "utf-8");

    // Verify file was written
    const stats = await fs.stat(eaFilePath);

    res.json({
      success: true,
      message: "EA uploaded successfully",
      ea_name: ea_name,
      file_path: eaFilePath,
      file_size: stats.size,
      experts_directory: expertsDir,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("EA Upload Error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
      mt4_path: MT4_DATA_PATH,
    });
  }
});

// EA Compilation endpoint
app.post("/api/ea/compile", async (req, res) => {
  try {
    const { ea_name } = req.body;

    if (!ea_name) {
      return res.status(400).json({
        success: false,
        error: "Missing ea_name",
      });
    }

    // Find MT4 Experts directory and EA file
    const expertsDir = await findMT4ExpertsDirectory();
    const eaFilePath = path.join(expertsDir, `${ea_name}.mq4`);

    // Check if EA file exists
    try {
      await fs.access(eaFilePath);
    } catch (accessError) {
      return res.status(404).json({
        success: false,
        error: `EA file not found: ${ea_name}.mq4`,
        expected_path: eaFilePath,
      });
    }

    // Compile EA
    console.log(`Starting compilation of ${ea_name}...`);
    const compilationResult = await compileEA(eaFilePath);

    res.json({
      success: compilationResult.success,
      compiled: compilationResult.compiled,
      ea_name: ea_name,
      source_file: eaFilePath,
      ex4_file: compilationResult.ex4_path,
      errors: compilationResult.errors,
      warnings: compilationResult.warnings,
      exit_code: compilationResult.exit_code,
      log: compilationResult.log,
      log_file: compilationResult.log_file,
      timestamp: new Date().toISOString(),
      message: compilationResult.success
        ? "EA compiled successfully"
        : `Compilation failed with ${compilationResult.errors} error(s)`,
    });
  } catch (error) {
    console.error("EA Compilation Error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
      ea_name: req.body.ea_name,
    });
  }
});

// List EA files in Experts directory
app.get("/api/ea/list", async (req, res) => {
  try {
    const expertsDir = await findMT4ExpertsDirectory();
    const files = await fs.readdir(expertsDir);

    const eaFiles = [];
    for (const file of files) {
      if (file.endsWith(".mq4") || file.endsWith(".ex4")) {
        const filePath = path.join(expertsDir, file);
        const stats = await fs.stat(filePath);
        eaFiles.push({
          name: file,
          path: filePath,
          size: stats.size,
          modified: stats.mtime.toISOString(),
          type: file.endsWith(".mq4") ? "source" : "compiled",
        });
      }
    }

    res.json({
      success: true,
      experts_directory: expertsDir,
      files: eaFiles,
      count: eaFiles.length,
    });
  } catch (error) {
    console.error("EA List Error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// Get MetaEditor status and path
app.get("/api/ea/metaeditor", async (req, res) => {
  try {
    const metaEditorPath = await findMetaEditor();
    const expertsDir = await findMT4ExpertsDirectory();

    res.json({
      success: true,
      metaeditor_path: metaEditorPath,
      experts_directory: expertsDir,
      mt4_data_path: MT4_DATA_PATH,
      available_paths: METAEDITOR_PATHS,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
      mt4_data_path: MT4_DATA_PATH,
      searched_paths: METAEDITOR_PATHS,
    });
  }
});

// Health check endpoint
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    mt4_path: MT4_DATA_PATH,
    features: [
      "account_info",
      "market_data",
      "orders",
      "positions",
      "history",
      "backtesting",
      "ea_upload",
      "ea_compilation",
    ],
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`MT4 HTTP Bridge running on http://0.0.0.0:${PORT}`);
  console.log(`MT4 Data Path: ${MT4_DATA_PATH}`);
  console.log(
    "Make sure MT4 is running with the MCPBridge Expert Advisor attached to a chart"
  );
});
