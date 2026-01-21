# AI Gateway Chat

A feature-rich command-line chat client for AI Lab servers (llama.cpp backend). Designed for power users who want advanced input handling, conversation persistence, and seamless interaction with local LLMs.

## Features

- **Multiline Input**: Press Alt+Enter (or Escape+Enter, or Ctrl+J) for newlines
- **Command Autocomplete**: Press Tab to complete slash commands
- **History Search**: Press Ctrl+R to search through command history
- **Conversation Persistence**: Save, list, and resume conversations across sessions
- **Streaming Responses**: Token-by-token output as the model generates
- **Better Copy Support**: `/raw` toggle for plain text output, `/copy` for clipboard
- **Model Selection**: Interactive model switching with detailed info
- **Cross-Platform**: Works on Windows, macOS, and Linux

## Quick Start

### Windows (PowerShell)

```powershell
# Setup and start
.\setup.ps1 -StartClient

# Or setup only, then run manually
.\setup.ps1
.\venv\Scripts\Activate.ps1
python chat.py
```

### Linux/macOS (Bash)

```bash
# Make setup script executable
chmod +x setup.sh

# Setup and start
./setup.sh --start

# Or setup only, then run manually
./setup.sh
source venv/bin/activate
python chat.py
```

### Manual Setup

```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
.\venv\Scripts\Activate.ps1

# Activate (Linux/macOS)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the client
python chat.py
```

## Configuration

### Server URL

Configure the AI Lab server URL in order of priority:

1. **Environment variable** (highest priority):
   ```bash
   export AI_SERVER_URL="http://192.168.1.100:8080"
   ```

2. **Config file**: Copy `config.example.yaml` to `config.yaml`:
   ```yaml
   server_url: "http://localhost:8080"
   ```

3. **Default**: `http://localhost:8080`

## Commands

### Client Commands

| Command | Description |
|---------|-------------|
| `/help` | Show help message |
| `/exit`, `/quit` | Exit the client |
| `/reset` | Clear conversation history |
| `/model`, `/models` | Show and select models |
| `/models info` | Show detailed model information |
| `/export <path>` | Export conversation to text file |
| `/export-json <path>` | Export conversation to JSON |
| `/export-ft <path>` | Export for fine-tuning (JSONL) |
| `/status` | Show server and client status |
| `/hardware` | Show hardware configuration |
| `/stream [on\|off]` | Toggle streaming mode |
| `/raw` | Toggle raw output (for easy copy/paste) |
| `/copy` | Copy last response to clipboard |

### Conversation Commands

| Command | Description |
|---------|-------------|
| `/save [title]` | Save/name current conversation |
| `/new [title]` | Start a new conversation (saves current first) |
| `/conversations` | List all saved conversations |
| `/resume <id>` | Resume a saved conversation (by number or ID) |
| `/delete <id>` | Delete a saved conversation |

### Working Directory Commands

| Command | Description |
|---------|-------------|
| `/cd <path>` | Set working directory for file operations |
| `/cd` | Show current working directory |
| `/pwd` | Show current working directory |
| `/ls` | List files in working directory |

### Server Commands

| Command | Description |
|---------|-------------|
| `/system` | Show current system prompt |
| `/system <prompt>` | Set system prompt |
| `/system reset` | Reset to default system prompt |
| `/layers` | Get GPU layer count |
| `/layers <n>` | Set GPU layers (-1=all, 0=CPU, n=hybrid) |
| `/tools [on\|off]` | Enable/disable tool calling |
| `/mem` | Show memory usage |
| `/stop-server` | Shutdown the server |

## Conversation Persistence

Conversations are stored in `~/.conversations/` and can be saved, listed, and resumed across sessions.

### Saving Conversations

```
You: /save My Flask Tutorial
Conversation saved: My Flask Tutorial
ID: my-flask-tutorial | Messages: 8
```

### Listing Saved Conversations

```
You: /conversations
+---+------------------+----------+--------------+---------------------------+
| # | Title            | Messages | Last Updated | Preview                   |
+---+------------------+----------+--------------+---------------------------+
| 1 | My Flask Tutorial|        8 | 2 hours ago  | Help me create a Flask... |
| 2 | Code Review      |       12 | Yesterday    | Review this Python code...|
+---+------------------+----------+--------------+---------------------------+
```

### Resuming Conversations

```
You: /resume 1
Resumed: My Flask Tutorial
Messages: 8 | ID: my-flask-tutorial

Last exchange:
  You: How do I add authentication?
  Assistant: You can use Flask-Login...
```

### Auto-Save

Once a conversation has a title, it is automatically saved after each message exchange. This prevents data loss even if the client crashes.

## Input Controls

| Key | Action |
|-----|--------|
| `Enter` | Submit message |
| `Alt+Enter` | Insert new line |
| `Escape` then `Enter` | Insert new line (alternative) |
| `Ctrl+J` | Insert new line (alternative) |
| `Tab` | Autocomplete command |
| `Ctrl+R` | Search command history |
| `Ctrl+C` | Cancel current input |

## Requirements

- Python 3.8+
- An AI Lab server running (llama.cpp backend)

### Dependencies

- `prompt-toolkit` - Advanced input handling
- `rich` - Rich console output
- `requests` - HTTP client
- `pyyaml` - Configuration support
- `pyperclip` (optional) - Clipboard support

## File Structure

```
AI_Gateway_Chat/
├── chat.py                 # Main client application
├── config.py               # Configuration loader
├── conversation_manager.py # Conversation persistence
├── config.example.yaml     # Example configuration
├── requirements.txt        # Python dependencies
├── setup.ps1               # Windows setup script
├── setup.sh                # Linux/macOS setup script
└── README.md               # This file
```

## Troubleshooting

### Server Connection Issues

```
Server not responding or model not loaded!
```

- Ensure the AI Lab server is running
- Check the server URL configuration
- Verify the server has a model loaded

### Clipboard Not Working

```
pyperclip not installed
```

Install clipboard support:
```bash
pip install pyperclip
```

### YAML Config Not Loading

If config.yaml isn't being read, install PyYAML:
```bash
pip install pyyaml
```

## License

MIT License - See LICENSE file for details.
