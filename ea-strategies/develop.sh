#!/bin/bash

# EA Development Helper Script
# Usage: ./develop.sh [command] [ea_name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVE_DIR="$SCRIPT_DIR/active"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
COMPILED_DIR="$SCRIPT_DIR/compiled"
LOGS_DIR="$SCRIPT_DIR/logs"

case "$1" in
    "list")
        echo "=== EA Development Status ==="
        echo
        echo "Templates available:"
        ls -la "$TEMPLATES_DIR"/*.mq4 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
        echo
        echo "Active development:"
        ls -la "$ACTIVE_DIR"/*.mq4 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
        echo
        echo "Compiled EAs:"
        ls -la "$COMPILED_DIR"/*.mq4 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
        echo
        echo "Recent logs:"
        ls -la "$LOGS_DIR"/*.log 2>/dev/null | tail -5 | awk '{print "  " $9 " (" $6 " " $7 " " $8 ")"}'
        ;;
    
    "new")
        if [ -z "$2" ]; then
            echo "Usage: $0 new [ea_name] [template]"
            echo "Available templates:"
            ls "$TEMPLATES_DIR"/*.mq4 2>/dev/null | sed 's/.*\//  /'
            exit 1
        fi
        
        EA_NAME="$2"
        TEMPLATE="${3:-SimpleMA_Template.mq4}"
        
        if [ ! -f "$TEMPLATES_DIR/$TEMPLATE" ]; then
            echo "Template $TEMPLATE not found!"
            exit 1
        fi
        
        cp "$TEMPLATES_DIR/$TEMPLATE" "$ACTIVE_DIR/${EA_NAME}.mq4"
        echo "Created new EA: ${EA_NAME}.mq4 from template $TEMPLATE"
        echo "Edit the file at: $ACTIVE_DIR/${EA_NAME}.mq4"
        ;;
    
    "edit")
        if [ -z "$2" ]; then
            echo "Usage: $0 edit [ea_name]"
            exit 1
        fi
        
        EA_FILE="$ACTIVE_DIR/$2.mq4"
        if [ ! -f "$EA_FILE" ]; then
            echo "EA $2.mq4 not found in active folder!"
            exit 1
        fi
        
        echo "Opening $EA_FILE for editing..."
        ${EDITOR:-nano} "$EA_FILE"
        ;;
    
    "log")
        if [ -z "$2" ]; then
            echo "Latest compilation logs:"
            ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -3 | while read log; do
                echo "=== $(basename "$log") ==="
                tail -10 "$log"
                echo
            done
        else
            LOG_FILE="$LOGS_DIR/$2.log"
            if [ -f "$LOG_FILE" ]; then
                cat "$LOG_FILE"
            else
                echo "Log file $2.log not found!"
            fi
        fi
        ;;
    
    "sync")
        if [ -z "$2" ]; then
            echo "Usage: $0 sync [ea_name]"
            exit 1
        fi
        
        EA_NAME="$2"
        EA_FILE="$ACTIVE_DIR/${EA_NAME}.mq4"
        
        if [ ! -f "$EA_FILE" ]; then
            echo "EA $EA_NAME.mq4 not found in active folder!"
            exit 1
        fi
        
        echo "Syncing $EA_NAME to MT4..."
        echo "Reading EA content..."
        
        # Note: This is a placeholder for MCP sync functionality
        # The actual sync would be done through Claude Code MCP tools
        echo "File: $EA_FILE"
        echo "Size: $(wc -c < "$EA_FILE") bytes"
        echo "Lines: $(wc -l < "$EA_FILE") lines"
        echo
        echo "Ready for MCP sync! Use Claude Code to run:"
        echo "  sync_ea with ea_name: $EA_NAME"
        echo "  and ea_content from: $EA_FILE"
        ;;
    
    "compile")
        if [ -z "$2" ]; then
            echo "Usage: $0 compile [ea_name]"
            exit 1
        fi
        
        EA_NAME="$2"
        echo "Requesting compilation of $EA_NAME on MT4..."
        echo
        echo "Use Claude Code to run:"
        echo "  compile_ea with ea_name: $EA_NAME"
        echo
        echo "Check compilation results with:"
        echo "  $0 log $EA_NAME"
        ;;
    
    "deploy")
        if [ -z "$2" ]; then
            echo "Usage: $0 deploy [ea_name]"
            exit 1
        fi
        
        EA_NAME="$2"
        EA_FILE="$ACTIVE_DIR/${EA_NAME}.mq4"
        
        if [ ! -f "$EA_FILE" ]; then
            echo "EA $EA_NAME.mq4 not found in active folder!"
            exit 1
        fi
        
        echo "=== Full Deployment Workflow for $EA_NAME ==="
        echo
        echo "1. Syncing EA to MT4..."
        $0 sync "$EA_NAME"
        echo
        echo "2. Next steps in Claude Code:"
        echo "   a) Run: sync_ea with ea_name: $EA_NAME"
        echo "   b) Run: compile_ea with ea_name: $EA_NAME"
        echo "   c) Check results: $0 log $EA_NAME"
        echo
        echo "3. If compilation successful, EA will be ready for:"
        echo "   - Backtesting in Strategy Tester"
        echo "   - Live trading deployment"
        ;;
    
    "clean")
        echo "Cleaning old logs and temporary files..."
        find "$LOGS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
        echo "Done."
        ;;
    
    *)
        echo "EA Development Helper"
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  list          - Show all EAs and their status"
        echo "  new [name] [template] - Create new EA from template"
        echo "  edit [name]   - Edit EA in active folder"
        echo "  sync [name]   - Prepare EA for MCP sync to MT4"
        echo "  compile [name] - Request compilation via MCP"
        echo "  deploy [name] - Full deployment workflow"
        echo "  log [name]    - Show compilation log (or recent logs)"
        echo "  clean         - Clean old log files"
        echo
        echo "Workflow:"
        echo "  1. $0 new MyStrategy SimpleMA_Template.mq4"
        echo "  2. $0 edit MyStrategy"
        echo "  3. $0 deploy MyStrategy"
        echo "  4. Use Claude Code MCP tools as prompted"
        echo "  5. $0 log MyStrategy"
        ;;
esac