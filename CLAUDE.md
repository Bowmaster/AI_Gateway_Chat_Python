# CLAUDE.md - AI Gateway Chat Developer Guide

**Purpose**: Optimize Claude AI assistance for developing, extending, and maintaining the AI Gateway Chat client.

---

## Quick Context

**What is this?**
- A feature-rich CLI chat client for AI Lab servers (llama.cpp backend)
- Connects to a FastAPI server that wraps llama-server for inference
- Designed for power users who want advanced input handling and conversation persistence
- Cross-platform: Windows, macOS, Linux

**Architecture**:
```
User Input (prompt_toolkit)
        ↓
ChatClient (chat.py)
        ↓ HTTP/REST
AI Lab Server :8080
        ↓
LlamaServerManager
        ↓
llama-server :8081
        ↓
GGUF Model
```

**Key Features**:
- Multiline input with Alt+Enter/Ctrl+J
- Tab completion for slash commands
- Conversation persistence (~/.conversations/)
- Streaming responses (token-by-token)
- Model selection and switching
- Working directory context for file operations
- Export to text, JSON, JSONL (fine-tuning)

---

## Code Organization

### File Structure

| File | Lines | Role |
|------|-------|------|
| `chat.py` | ~1700 | Main client: ChatClient class, command handlers, UI |
| `config.py` | ~85 | Configuration loading (env var, YAML, defaults) |
| `conversation_manager.py` | ~290 | Conversation persistence (save/load/list/delete) |
| `config.example.yaml` | ~25 | Example configuration template |
| `requirements.txt` | ~12 | Python dependencies |
| `setup.ps1` | ~100 | Windows setup script |
| `setup.sh` | ~90 | Linux/macOS setup script |

### Dependency Graph

```
chat.py
  ├─ imports: config, conversation_manager
  ├─ imports: requests, rich, prompt_toolkit
  └─ defines: SlashCommandCompleter, ChatClient

config.py
  ├─ imports: os, pathlib, yaml (optional)
  └─ exports: load_config(), get_server_url(), get_history_file()

conversation_manager.py
  ├─ imports: json, pathlib, datetime
  └─ exports: ConversationManager class
```

---

## Core Classes

### ChatClient (chat.py)

The main client class that orchestrates everything.

**Key Attributes**:
```python
self.server_url: str              # AI Lab server URL
self.conversation_history: list   # Message history [{role, content}, ...]
self.system_prompt: str           # Custom system prompt (optional)
self.streaming_enabled: bool      # Token-by-token output (default: True)
self.raw_output: bool             # Plain text vs panels (default: False)
self.working_directory: Path      # Context for file operations
self.input_session: PromptSession # prompt_toolkit session

# Conversation persistence
self.conversation_manager: ConversationManager
self.current_conversation_id: str      # e.g., "my-flask-tutorial"
self.current_conversation_title: str   # e.g., "My Flask Tutorial"
```

**Key Methods**:
```python
# Core messaging
send_message(message, temperature, max_tokens) -> dict
send_message_streaming(message, temperature, max_tokens) -> dict

# Server interaction
check_server_health() -> bool
get_models_list() -> dict
switch_model(model_key) -> dict
send_command(command, value) -> dict

# Conversation management
reset_conversation()
_auto_save_conversation()
_handle_save_command(value)
_handle_resume_command(value)
_handle_list_conversations()
_handle_delete_command(value)

# UI
handle_slash_command(command) -> bool  # Returns False to exit
show_help()
show_status()
show_models_and_select() -> bool
run()  # Main loop
```

### ConversationManager (conversation_manager.py)

Handles all conversation persistence to `~/.conversations/`.

**Storage Structure**:
```
~/.conversations/
├── index.json                    # Quick lookup index
├── my-flask-tutorial.json        # Conversation files
├── code-review-session.json
└── debugging-api-errors.json
```

**Key Methods**:
```python
save(messages, title, conv_id, system_prompt, working_directory, model_key) -> str
load(conv_id) -> dict
list_all() -> list[dict]  # Sorted by updated_at, newest first
delete(conv_id) -> bool
get_by_number(number) -> dict  # 1-indexed for /resume 1
rebuild_index()  # Regenerate index from files
```

**Conversation File Format**:
```json
{
  "id": "my-flask-tutorial",
  "title": "My Flask Tutorial",
  "created_at": "2026-01-21T10:30:00",
  "updated_at": "2026-01-21T11:45:00",
  "model_key": "qwen2.5-7b-q4",
  "system_prompt": null,
  "working_directory": "C:\\Projects\\FlaskApp",
  "message_count": 12,
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

### SlashCommandCompleter (chat.py)

prompt_toolkit completer for slash commands with subcommand support.

**COMMANDS dict structure**:
```python
COMMANDS = {
    "/model": {
        "_desc": "Show and select models",  # Main command description
        "info": "Show detailed model info",  # Subcommand
    },
    "/stream": {
        "_desc": "Toggle streaming mode",
        "on": "Enable streaming",
        "off": "Disable streaming",
    },
    # ... more commands
}
```

---

## Data Flows

### Message Flow (Streaming)

```
User types message + Enter
        ↓
ChatClient.send_message_streaming()
        ↓
Add user message to conversation_history
        ↓
Build payload with messages, temperature, max_tokens
        ↓
POST /chat/stream (SSE)
        ↓
Parse SSE chunks, accumulate response
        ↓
Update Live panel with each token
        ↓
On stream_end: extract metadata (tokens, timing)
        ↓
Add assistant message to conversation_history
        ↓
_auto_save_conversation() if title exists
        ↓
Display final panel + stats
```

### Conversation Resume Flow

```
User: /resume 1
        ↓
_handle_resume_command("1")
        ↓
Parse as number → get_by_number(1)
        ↓
Load conversation from ~/.conversations/my-tutorial.json
        ↓
Auto-save current conversation (if any)
        ↓
Restore state:
  - conversation_history = saved messages
  - current_conversation_id = saved id
  - current_conversation_title = saved title
  - system_prompt = saved prompt (if any)
  - working_directory = saved path (if exists)
        ↓
Display summary + last exchange
```

### Command Handling Flow

```
User input starts with "/"
        ↓
handle_slash_command(input)
        ↓
Split into cmd + value
        ↓
Match cmd in if/elif chain
        ↓
Execute handler
        ↓
Return True (continue) or False (exit)
```

---

## Configuration System

### Priority Order (highest to lowest)

1. `AI_SERVER_URL` environment variable
2. `config.yaml` in current directory
3. `config.yaml` in script directory
4. Default: `http://localhost:8080`

### Config Structure

```python
{
    "server_url": "http://localhost:8080",
    "history_file": "~/.ai_chat_history",  # prompt_toolkit history
    "streaming_enabled": True,
}
```

### Loading Logic (config.py)

```python
def load_config() -> dict:
    config = { defaults }

    # 1. Check environment variable
    if env_url := os.environ.get("AI_SERVER_URL"):
        config["server_url"] = env_url
        return config  # Env var takes full priority

    # 2. Check config.yaml in CWD
    # 3. Check config.yaml in script dir

    return config
```

---

## Command Reference

### Adding a New Command

1. **Add to COMMANDS dict** (for autocomplete):
```python
COMMANDS = {
    # ... existing commands ...
    "/mycommand": {
        "_desc": "Description for autocomplete",
        "subarg": "Description for subarg",
    },
}
```

2. **Add handler in handle_slash_command()**:
```python
elif cmd == "mycommand":
    if value is None:
        # No argument provided
        console.print("[cyan]Current value: ...[/cyan]")
    else:
        # Argument provided
        self._handle_mycommand(value)
    return True
```

3. **Implement handler method** (if complex):
```python
def _handle_mycommand(self, value: str):
    """Handle the /mycommand command."""
    # Implementation
    console.print(f"[green]Done: {value}[/green]")
```

4. **Update help text** in show_help():
```python
[bold cyan]My Section:[/bold cyan]
  /mycommand      Description here
```

### Command Categories

| Category | Commands |
|----------|----------|
| Client | /help, /exit, /reset, /status, /stream, /raw, /copy |
| Models | /model, /models, /models info |
| Export | /export, /export-json, /export-ft |
| Conversations | /save, /new, /conversations, /resume, /delete |
| Working Dir | /cd, /pwd, /ls |
| Server | /system, /layers, /tools, /mem, /hardware, /stop-server |

---

## Server API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Check server status, get model info |
| `/models` | GET | List available models |
| `/model/switch` | POST | Switch to different model |
| `/chat` | POST | Send message (batch mode) |
| `/chat/stream` | POST | Send message (streaming SSE) |
| `/chat/approve` | POST | Approve/deny tool calls |
| `/command` | POST | Server commands (system, layers, etc.) |
| `/hardware` | GET | Hardware configuration |
| `/shutdown` | POST | Shutdown server |

### Request/Response Patterns

**Chat Request**:
```python
{
    "messages": [{"role": "user", "content": "..."}],
    "temperature": 0.7,
    "max_tokens": 8192,
    "system_prompt": "optional custom prompt"
}
```

**Chat Response**:
```python
{
    "response": "Assistant's response text",
    "tokens_input": 42,
    "tokens_generated": 150,
    "tokens_total": 192,
    "generation_time": 2.5,
    "tokens_per_second": 60.0,
    "device": "GPU (all layers)",
    "tools_used": ["lookup_hostname(google.com)"]
}
```

**Streaming (SSE)**:
```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":" world"}}]}
data: {"type":"stream_end","tokens_input":42,...}
data: [DONE]
```

---

## Extension Points

### Adding a New Export Format

```python
def export_my_format(self, filepath: str):
    """Export conversation to my format."""
    if not self.conversation_history:
        console.print("[yellow]No conversation to export.[/yellow]")
        return

    try:
        path = Path(filepath)
        # Ensure correct extension
        if path.suffix.lower() != ".myext":
            path = path.with_suffix(".myext")

        path.parent.mkdir(parents=True, exist_ok=True)

        # Build export data
        data = {
            "format_version": "1.0",
            "messages": self.conversation_history,
            # ... custom fields
        }

        # Write file
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")
        console.print(f"[green]Exported to: {path.absolute()}[/green]")

    except Exception as e:
        console.print(f"[red]Export error: {e}[/red]")
```

### Adding Server Command Support

If the server adds a new `/command` type:

```python
elif cmd == "newcmd":
    if value is None:
        result = self.send_command("newcmd")
        if result:
            console.print(f"[cyan]{result['current_value']}[/cyan]")
    else:
        result = self.send_command("newcmd", value)
        if result:
            console.print(f"[green]{result['message']}[/green]")
    return True
```

### Custom Key Bindings

In `_create_input_session()`:

```python
@bindings.add("c-x")  # Ctrl+X
def my_custom_binding(event):
    """Custom action on Ctrl+X."""
    # Access buffer: event.current_buffer
    # Insert text: event.current_buffer.insert_text("...")
    pass
```

---

## UI Patterns

### Console Output

```python
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich import box

console = Console()

# Simple colored text
console.print("[green]Success![/green]")
console.print("[red]Error: {message}[/red]")
console.print("[yellow]Warning...[/yellow]")
console.print("[cyan]Info[/cyan]")
console.print("[dim]Subtle text[/dim]")

# Panel (boxed content)
console.print(Panel(content, title="Title", border_style="cyan"))

# Table
table = Table(title="My Table", box=box.ROUNDED)
table.add_column("Col1", style="cyan")
table.add_column("Col2", justify="right")
table.add_row("value1", "value2")
console.print(table)
```

### User Prompts

```python
from rich.prompt import Prompt

# Simple prompt
value = Prompt.ask("[yellow]Enter value[/yellow]", default="")

# Choice prompt
choice = Prompt.ask(
    "[yellow]Confirm?[/yellow]",
    choices=["y", "n"],
    default="n",
    console=console,
)
```

### Live Updates (Streaming)

```python
from rich.live import Live

with Live(Panel(""), console=console, refresh_per_second=30, transient=True) as live:
    for chunk in stream:
        accumulated += chunk
        live.update(Panel(accumulated, title="Assistant", border_style="green"))
```

---

## Error Handling Patterns

### Request Errors

```python
try:
    response = requests.post(url, json=payload, timeout=300)

    if response.status_code == 200:
        return response.json()
    elif response.status_code == 503:
        console.print("[yellow]Server busy[/yellow]")
        return None
    else:
        error = response.json().get("detail", "Unknown error")
        console.print(f"[red]Error: {error}[/red]")
        return None

except requests.exceptions.Timeout:
    console.print("[red]Request timed out[/red]")
    return None
except requests.exceptions.ConnectionError:
    console.print(f"[red]Cannot connect to {self.server_url}[/red]")
    return None
```

### Conversation History Rollback

On error during message send, remove the user message:

```python
self.conversation_history.append({"role": "user", "content": message})

try:
    # Send request...
    if error:
        self.conversation_history.pop()  # Rollback
        return None

    # Success - add assistant response
    self.conversation_history.append({"role": "assistant", "content": response})
    return result

except Exception:
    self.conversation_history.pop()  # Rollback on exception
    raise
```

---

## Testing Checklist

Before committing changes:

- [ ] Client starts without errors
- [ ] `/help` displays correctly
- [ ] `/status` connects to server
- [ ] Basic chat works (streaming and batch)
- [ ] `/save` creates file in ~/.conversations/
- [ ] `/conversations` lists saved conversations
- [ ] `/resume` restores conversation state
- [ ] `/delete` removes conversation
- [ ] Tab completion works for all commands
- [ ] Ctrl+R history search works
- [ ] Alt+Enter inserts newline

### Manual Test Script

```bash
# Start client
python chat.py

# Test commands
/status
/help
/stream off
Hello, how are you?
/stream on
Tell me a joke
/save Test Conversation
/conversations
/new
/resume 1
/delete 1
/exit
```

---

## Common Issues & Solutions

### Issue: YAML config not loading

**Cause**: PyYAML not installed
**Solution**: `pip install pyyaml` or use environment variable

### Issue: Clipboard not working

**Cause**: pyperclip not installed
**Solution**: `pip install pyperclip`

### Issue: Server timeout on model switch

**Cause**: Model download or loading takes time
**Solution**: Timeout is 5 minutes (300s), check server logs

### Issue: Streaming shows nothing

**Cause**: Server may not support /chat/stream endpoint
**Solution**: Use `/stream off` for batch mode

### Issue: Conversation not auto-saving

**Cause**: No title set
**Solution**: Use `/save "Title"` first, then auto-save activates

---

## Code Style Guidelines

1. **Error messages**: Use Rich markup `[red]Error: ...[/red]`
2. **Success messages**: Use `[green]...[/green]`
3. **Warnings**: Use `[yellow]...[/yellow]`
4. **Info/status**: Use `[cyan]...[/cyan]`
5. **Subtle text**: Use `[dim]...[/dim]`

6. **Method naming**:
   - Public: `send_message()`, `show_status()`
   - Private: `_handle_save_command()`, `_auto_save_conversation()`

7. **Command handlers**: Return `True` to continue, `False` to exit

8. **Type hints**: Use for public method signatures

---

## Dependencies

| Package | Purpose | Required |
|---------|---------|----------|
| prompt-toolkit | Input handling, history, completion | Yes |
| rich | Console output, panels, tables | Yes |
| requests | HTTP client | Yes |
| pyyaml | Config file support | Optional |
| pyperclip | Clipboard support | Optional |

---

**Last Updated**: 2026-01-21
**Scope**: AI Gateway Chat client development and extension
