#!/bin/bash
#
# AI Gateway Chat - Setup Script
#
# Creates a virtual environment, installs dependencies, and optionally starts the client.
#
# Usage:
#   ./setup.sh              # Setup only
#   ./setup.sh --start      # Setup and start client
#   ./setup.sh --start --server http://192.168.1.100:8080  # With custom server
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
START_CLIENT=false
SERVER_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --start|-s)
            START_CLIENT=true
            shift
            ;;
        --server|-u)
            SERVER_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--start] [--server URL]"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}======================================"
echo -e "  AI Gateway Chat - Setup Script"
echo -e "======================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Python installation
echo -e "${YELLOW}[1/4] Checking Python installation...${NC}"
PYTHON_CMD=""

for cmd in python3 python; do
    if command -v $cmd &> /dev/null; then
        VERSION=$($cmd --version 2>&1)
        if [[ $VERSION == *"Python 3."* ]]; then
            PYTHON_CMD=$cmd
            echo -e "  ${GREEN}Found: $VERSION${NC}"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "  ${RED}ERROR: Python 3 not found!${NC}"
    echo -e "  ${YELLOW}Please install Python 3.8 or later${NC}"
    exit 1
fi

# Create virtual environment
VENV_PATH="$SCRIPT_DIR/venv"
echo ""
echo -e "${YELLOW}[2/4] Setting up virtual environment...${NC}"

if [ -d "$VENV_PATH" ]; then
    echo -e "  ${GREEN}Virtual environment already exists at: $VENV_PATH${NC}"
else
    echo "  Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_PATH"
    echo -e "  ${GREEN}Created: $VENV_PATH${NC}"
fi

# Activate virtual environment
echo ""
echo -e "${YELLOW}[3/4] Activating virtual environment...${NC}"
source "$VENV_PATH/bin/activate"
echo -e "  ${GREEN}Activated${NC}"

# Install dependencies
echo ""
echo -e "${YELLOW}[4/4] Installing dependencies...${NC}"
REQUIREMENTS_PATH="$SCRIPT_DIR/requirements.txt"

if [ -f "$REQUIREMENTS_PATH" ]; then
    pip install -r "$REQUIREMENTS_PATH" --quiet
    echo -e "  ${GREEN}Dependencies installed${NC}"
else
    echo -e "  ${YELLOW}WARNING: requirements.txt not found, skipping...${NC}"
fi

# Setup complete
echo ""
echo -e "${GREEN}======================================"
echo -e "  Setup Complete!"
echo -e "======================================${NC}"
echo ""
echo -e "${CYAN}To start the chat client manually:${NC}"
echo -e "  source venv/bin/activate"
echo -e "  python chat.py"
echo ""

# Set server URL if provided
if [ -n "$SERVER_URL" ]; then
    export AI_SERVER_URL="$SERVER_URL"
    echo -e "${CYAN}Server URL set to: $SERVER_URL${NC}"
    echo ""
fi

# Start client if requested
if [ "$START_CLIENT" = true ]; then
    echo -e "${CYAN}Starting AI Gateway Chat...${NC}"
    echo ""
    python "$SCRIPT_DIR/chat.py"
fi
