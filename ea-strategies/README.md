# EA Strategy Development

## Folder Structure

- `templates/` - Base EA templates and examples
- `active/` - EAs under development
- `compiled/` - Successfully compiled EAs ready for deployment
- `logs/` - Compilation logs and error reports

## Workflow

1. Create/edit EA in `active/` folder
2. Use `sync_ea` tool to upload to MT4
3. Use `compile_ea` tool to compile remotely
4. Check compilation results and fix errors
5. Compiled EAs are moved to `compiled/` folder
6. Deploy to MT4 for testing/backtesting

## File Naming Convention

- `MyStrategy.mq4` - Main EA file
- `MyStrategy_v1.0.mq4` - Versioned EA
- `MyStrategy.log` - Compilation log
- `MyStrategy.ex4` - Compiled EA (downloaded from MT4)