# Client-Side Tooling Implementation Plan

**Branch**: `claude/ai-client-tooling-A3XUL`
**Scope**: 9 new client-side features + 1 passive enhancement
**Principle**: All features are local-only (no server changes required). Security-first design throughout.

---

## Feature 1: `/temp <value>` — Runtime Temperature Control

**Priority**: High | **Effort**: Low | **Risk**: None

### What
Expose the temperature parameter as a runtime-adjustable command. Currently hardcoded at `0.7` in both `send_message()` and `send_message_streaming()`.

### Implementation
- Add `self.temperature: float = 0.7` to `ChatClient.__init__`
- Add `/temp` to `COMMANDS` dict and `handle_slash_command()`
- Pass `self.temperature` in `send_message()` and `send_message_streaming()` calls
- Display current temperature in `/status`

### Security Considerations
- **Input validation**: Clamp to `[0.0, 2.0]` range (OpenAI-compatible range). Reject non-numeric input.
- **No server risk**: Temperature is already a server-side payload field; we're just letting the user set it.

### Command Spec
```
/temp            → Show current temperature
/temp 0.3        → Set temperature to 0.3
/temp default    → Reset to 0.7
```

---

## Feature 2: `/maxtokens <value>` — Runtime Max Tokens Control

**Priority**: High | **Effort**: Low | **Risk**: None

### What
Expose max_tokens as a runtime-adjustable command. Currently hardcoded at `8192`.

### Implementation
- Add `self.max_tokens: int = 8192` to `ChatClient.__init__`
- Add `/maxtokens` to `COMMANDS` dict and `handle_slash_command()`
- Pass `self.max_tokens` in `send_message()` and `send_message_streaming()` calls
- Display current max_tokens in `/status`

### Security Considerations
- **Input validation**: Clamp to `[1, 131072]` range. Must be a positive integer. Reject non-integer input.
- **No resource risk**: The server already enforces its own max_tokens limit; we're just setting the request parameter.

### Command Spec
```
/maxtokens           → Show current max tokens
/maxtokens 4096      → Set max tokens to 4096
/maxtokens default   → Reset to 8192
```

---

## Feature 3: `/stats` — Session Statistics

**Priority**: High | **Effort**: Low | **Risk**: None

### What
Track and display cumulative session statistics: total tokens consumed, total generation time, average speed, message count.

### Implementation
- Add session stats dict to `ChatClient.__init__`:
  ```python
  self.session_stats = {
      "messages_sent": 0,
      "total_tokens_in": 0,
      "total_tokens_out": 0,
      "total_generation_time": 0.0,
      "session_start": datetime.now(),
  }
  ```
- After each successful `send_message()` / `send_message_streaming()`, accumulate stats from the result dict
- `/stats` command renders a Rich table with all accumulated values + derived values (avg speed, session duration)

### Security Considerations
- **None**: Pure in-memory accounting. No file I/O, no user input parsing beyond the command itself.

### Command Spec
```
/stats    → Display session statistics table
```

---

## Feature 4: `/tail [n]` — Show Recent Messages

**Priority**: Medium | **Effort**: Low | **Risk**: None

### What
Display the last N messages from the current conversation for re-orientation context.

### Implementation
- Default to last 6 messages (3 exchanges) if no argument given
- Truncate long messages to 300 chars with `...` suffix
- Show role labels and message numbers

### Security Considerations
- **Input validation**: Clamp N to `[1, 50]`. Reject non-integer input.
- **No data exposure risk**: Only shows data already in `self.conversation_history` (already in memory).

### Command Spec
```
/tail        → Show last 6 messages (3 exchanges)
/tail 10     → Show last 10 messages
```

---

## Feature 5: `/retry` — Retry/Rephrase Last Message

**Priority**: High | **Effort**: Medium | **Risk**: Low

### What
Pop the last assistant+user message pair and re-send (or let the user edit before re-sending). The rollback plumbing already exists in error handlers.

### Implementation
- `/retry` with no argument: pop last exchange, re-send the same user message
- `/retry <new message>`: pop last exchange, send the new message instead
- Must have at least 1 user+assistant pair in history
- Auto-save after successful retry (same as normal messages)

### Security Considerations
- **History integrity**: Only pop if there's a complete exchange to pop. Never pop below empty.
- **No double-send risk**: The pop happens before the send, so if send fails the rollback in send_message/send_message_streaming handles it correctly (one more pop bringing us back to pre-retry state — but we need to be careful here). Actually, we need to save the popped messages so we can restore them if the retry fails.
- **Implementation detail**: Store popped messages in a local variable. If the retry send fails, restore them.

### Command Spec
```
/retry                → Re-send last user message (get a different response)
/retry new message    → Replace last exchange with this new message
```

---

## Feature 6: `/code [n]` — Extract Code Blocks

**Priority**: Medium | **Effort**: Low | **Risk**: None

### What
Parse fenced code blocks from the last assistant response. List them, copy a specific one, or copy all.

### Implementation
- Use regex to extract ` ```lang\n...\n``` ` blocks from `self.last_response`
- `/code` with no argument: list all code blocks with index, language, and first line preview
- `/code <n>`: copy the nth code block to clipboard (or print if pyperclip unavailable)
- `/code all`: concatenate all code blocks and copy

### Security Considerations
- **Regex safety**: Use a non-greedy regex with `re.DOTALL` flag. The pattern is simple and not vulnerable to ReDoS:
  ```python
  re.findall(r'```(\w*)\n(.*?)```', text, re.DOTALL)
  ```
- **No execution risk**: We extract and display/copy text only. We never execute extracted code.
- **Clipboard only**: Output goes to clipboard or stdout — no file writes.

### Command Spec
```
/code        → List all code blocks in last response
/code 1      → Copy code block #1 to clipboard
/code all    → Copy all code blocks to clipboard
```

---

## Feature 7: `/search <term>` — Search Saved Conversations

**Priority**: High | **Effort**: Medium | **Risk**: Low

### What
Search across all saved conversations in `~/.conversations/` for matching text.

### Implementation
- Load each conversation JSON file and search message content
- Case-insensitive substring match (not regex, to avoid ReDoS from user input)
- Show matching conversations with context snippets
- Limit results to 20 matches to prevent terminal flooding
- Limit files scanned (skip files > 10MB as a safety measure)

### Security Considerations
- **No regex from user input**: Use `str.lower()` + `in` operator for searching, NOT `re.search()` with user-provided patterns. This prevents ReDoS attacks.
- **File size guard**: Skip conversation files larger than 10MB to prevent memory issues from corrupted/malicious files.
- **Path traversal**: Not a risk since we only scan `self.conversation_manager.storage_dir` using the existing `glob("*.json")` pattern — no user-controlled paths.
- **Rate limiting**: Cap at 20 results displayed to prevent terminal flooding.

### Command Spec
```
/search flask        → Search all conversations for "flask"
/search "error 404"  → Search for exact phrase
```

---

## Feature 8: `/prompt` — System Prompt Template Management

**Priority**: Medium | **Effort**: Medium | **Risk**: Low

### What
Save and load named system prompt templates from `~/.prompt_templates/`.

### Implementation
- Storage directory: `~/.prompt_templates/` (plain text files, one per template)
- `/prompt list` — list available templates
- `/prompt save <name>` — save current system prompt as a named template
- `/prompt load <name>` — load a named template as the system prompt
- `/prompt show <name>` — display a template without loading it
- `/prompt delete <name>` — delete a template

### Security Considerations
- **Filename sanitization**: Template names go through the same `_slugify()` logic used for conversation IDs. No path separators, no special characters, no `..` traversal.
- **Path confinement**: All file operations are confined to `~/.prompt_templates/`. The name is slugified and only `.txt` extension is used. We verify the resolved path starts with the storage directory.
- **File size limit**: Reject templates larger than 100KB on save (system prompts shouldn't be enormous).
- **No execution**: Templates are loaded as plain text strings, never executed or eval'd.

### Command Spec
```
/prompt list              → List saved templates
/prompt save code-review  → Save current system prompt as "code-review"
/prompt load code-review  → Load "code-review" as system prompt
/prompt show code-review  → Display template without loading
/prompt delete code-review → Delete template
```

---

## Feature 9: `/include <path>` — File Content Injection

**Priority**: High | **Effort**: Medium | **Risk**: Medium (highest risk feature)

### What
Read a local file and prepend its content to the next message as context. This is the most security-sensitive feature.

### Implementation
- `/include <path>` reads the file and stores it as pending context
- On the next user message, prepend the file content wrapped in a clear delimiter:
  ```
  [File: filename.py]
  ```file content here```

  User's actual message here
  ```
- Support relative paths resolved against `self.working_directory` (if set) or CWD
- Show file size and line count after including

### Security Considerations
- **File size limit**: Hard cap at 500KB. Reject larger files with a clear error message. This prevents accidental inclusion of huge binary files or logs that would blow up the context window.
- **Binary file detection**: Read first 8192 bytes and check for null bytes. Reject binary files.
- **Path resolution**: Resolve relative paths against `self.working_directory` if set, otherwise CWD. Use `Path.resolve()` to canonicalize. Do NOT allow reading files outside the working directory tree if a working directory is set (verify with `resolved.is_relative_to(self.working_directory)`).
- **No symlink following outside boundary**: If working directory is set, resolve symlinks and verify the final path is still within the boundary.
- **Sensitive file patterns**: Warn (but don't block) when including files matching patterns like `.env`, `*credentials*`, `*secret*`, `*password*`, `*.key`, `*.pem`. The user may legitimately want to discuss these, but a warning is appropriate.
- **Read-only**: This feature only reads files. It never writes, modifies, or executes anything.
- **Encoding**: Use UTF-8 with `errors='replace'` to handle encoding issues gracefully.

### Command Spec
```
/include src/main.py         → Queue file for next message
/include ../config.yaml      → Relative to working directory
/include /etc/hosts          → Absolute path (blocked if working dir set and path is outside it)
/include clear               → Clear any pending file inclusion
```

---

## Enhancement: Context Window Awareness

**Priority**: Medium | **Effort**: Low | **Risk**: None

### What
After each message exchange, check context usage from the server's `/health` endpoint and warn the user when approaching limits.

### Implementation
- After each successful send, call `/health` and check `context_used_percent`
- Display warnings at thresholds:
  - **70%**: `[yellow]Context 70% full ({tokens} tokens). Consider /new to start fresh.[/yellow]`
  - **85%**: `[red]Context 85% full! Responses may be truncated. Use /new or /reset.[/red]`
  - **95%**: `[red bold]Context nearly full (95%)! Start a new conversation with /new.[/red bold]`
- Only show each threshold warning once per session (don't nag)

### Security Considerations
- **None**: Read-only check against an existing endpoint. No user input involved.

---

## Implementation Order

Ordered by dependency and complexity (implement in this sequence):

| Phase | Features | Rationale |
|-------|----------|-----------|
| 1 | `/temp`, `/maxtokens` | Simplest — add attributes + command handlers |
| 2 | `/stats` | Simple accumulator — wire into existing send paths |
| 3 | `/tail` | Simple history slice — no new dependencies |
| 4 | `/retry` | Moderate — needs careful history management |
| 5 | `/code` | Simple regex extraction — no dependencies |
| 6 | `/search` | Moderate — file I/O across conversations |
| 7 | `/prompt` | Moderate — new storage directory + CRUD |
| 8 | `/include` | Most complex security surface — careful implementation |
| 9 | Context warnings | Wire into post-message flow |
| 10 | Update `/help` and `/status` | Final polish — reflects all new features |

---

## Files Modified

| File | Changes |
|------|---------|
| `chat.py` | All new commands, session stats tracking, context awareness |
| `config.py` | No changes needed (all new features use runtime state or `~/` dirs) |
| `conversation_manager.py` | Add `search()` method for `/search` command |

## New Files

None. All logic goes into existing files. The `~/.prompt_templates/` directory is created at runtime only when `/prompt save` is first used.

---

## Testing Checklist

After implementation, verify each feature:

- [ ] `/temp` — set, show, clamp, default
- [ ] `/maxtokens` — set, show, clamp, default
- [ ] `/stats` — accumulates across multiple messages
- [ ] `/tail` — default count, custom count, empty history
- [ ] `/retry` — re-send, rephrase, fail-and-restore, empty history
- [ ] `/code` — list blocks, copy specific, no blocks in response
- [ ] `/search` — match found, no match, large file skip
- [ ] `/prompt` — save, load, list, show, delete, slugify edge cases
- [ ] `/include` — normal file, binary reject, size limit, path traversal blocked, sensitive file warning
- [ ] Context warnings — triggers at 70%, 85%, 95%; each only once
- [ ] `/help` — all new commands listed
- [ ] `/status` — shows temperature, max_tokens, session stats summary
- [ ] Tab completion works for all new commands and subcommands

---

**Last Updated**: 2026-02-06
