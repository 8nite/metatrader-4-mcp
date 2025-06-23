# Required HTTP Bridge Endpoints for EA Development

The Windows HTTP bridge needs these additional endpoints for EA development:

## 1. EA Upload Endpoint
```
POST /api/ea/upload
Content-Type: application/json

{
  "ea_name": "MyEA",
  "ea_content": "//+------------------------------------------------------------------+\n//| EA Source Code Here..."
}

Response:
{
  "success": true,
  "message": "EA uploaded successfully",
  "file_path": "MQL4/Experts/MyEA.mq4"
}
```

## 2. EA Compilation Endpoint
```
POST /api/ea/compile
Content-Type: application/json

{
  "ea_name": "MyEA"
}

Response:
{
  "success": true,
  "compiled": true,
  "warnings": 0,
  "errors": 0,
  "log": "compilation output...",
  "ex4_path": "MQL4/Experts/MyEA.ex4"
}
```

## 3. Implementation Notes

The HTTP bridge should:

1. **EA Upload**: Write .mq4 files to MT4's `MQL4/Experts/` directory
2. **EA Compilation**: Use MetaEditor command line to compile:
   ```cmd
   metaeditor64.exe /compile:"C:\Path\To\MT4\MQL4\Experts\MyEA.mq4" /log
   ```
3. **Error Handling**: Parse compilation logs for errors/warnings
4. **File Management**: Ensure proper file permissions and paths

## 4. Example Implementation (Node.js)

```javascript
// EA Upload
app.post('/api/ea/upload', (req, res) => {
  const { ea_name, ea_content } = req.body;
  const filePath = path.join(MT4_EXPERTS_PATH, `${ea_name}.mq4`);
  
  fs.writeFileSync(filePath, ea_content, 'utf8');
  
  res.json({
    success: true,
    message: 'EA uploaded successfully',
    file_path: filePath
  });
});

// EA Compilation
app.post('/api/ea/compile', (req, res) => {
  const { ea_name } = req.body;
  const sourceFile = path.join(MT4_EXPERTS_PATH, `${ea_name}.mq4`);
  
  // Use child_process to run MetaEditor
  const { spawn } = require('child_process');
  const compiler = spawn('metaeditor64.exe', [
    `/compile:${sourceFile}`,
    '/log'
  ]);
  
  // Handle compilation output...
});
```