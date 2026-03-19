# Recall Stack

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-compatible-blueviolet?style=flat&logo=anthropic)](https://docs.anthropic.com/en/docs/claude-code)
[![Hindsight](https://img.shields.io/badge/Hindsight-v0.4.19-00ADD8?style=flat)](https://github.com/vectorize-io/hindsight)
![Shell](https://img.shields.io/badge/-Shell-4EAA25?logo=gnu-bash&logoColor=white)
![Docker](https://img.shields.io/badge/-Docker-2496ED?logo=docker&logoColor=white)

> **Most people set up CLAUDE.md and call it done.** CLAUDE.md is a rules file. It does not remember what you did yesterday, what went wrong last week, or what patterns work best.

A 5-layer memory system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that gives your agent persistent context, behavioral learning, and a full knowledge base -- all wired in through hooks so it works automatically in every session.

---

## How It Works

```
[You type "claude"]
  |
  v
Layer 1  CLAUDE.md loads             --> "how should I behave?"
Layer 2  primer.md loads             --> "where did we leave off?"
Layer 3  SessionStart hook fires     --> "what changed in the codebase?"
Layer 4  Hindsight recall fires      --> "what patterns should I follow?"
Layer 5  Obsidian vault mounts       --> "what's in the knowledge base?"
  |
  v
Claude sees everything before you type a word.
  ...you work...
  ...primer.md auto-rewrites after each completed task...
  ...post-commit hook logs every commit...
  |
  v
[Session ends]
  |
Layer 4  Hindsight retain fires      --> extracts behavioral patterns
                                     --> stored for next session
```

---

## The 5 Layers

| # | Layer | What it does | How it loads | Updates |
|---|-------|-------------|--------------|---------|
| 1 | **CLAUDE.md** | Permanent rules, preferences, agent behavior | Auto, every session | You edit manually |
| 2 | **primer.md** | Active project, last task, next step, blockers | Auto (imported by CLAUDE.md) | Overwrites after each task |
| 3 | **Git Context** | Branch, commits, modified files, commit log | `SessionStart` hook | Fresh every launch |
| 4 | **Hindsight** | Behavioral learning from past sessions | `SessionStart` + `SessionEnd` hooks | Learns automatically |
| 5 | **Obsidian** | Full knowledge base as context | Shell alias | You add notes |

> **Why not just CLAUDE.md + primer.md?** Layers 1-2 handle rules and state. But Claude still can't see what changed in your repo since yesterday (Layer 3), doesn't learn from corrections across sessions (Layer 4), and can't access your notes (Layer 5). Each layer fills a gap the others can't.

---

## Quick Start

### One-command install

```bash
git clone https://github.com/ksukirya/recall-stack.git
cd recall-stack
bash setup.sh --obsidian ~/path/to/your/vault
```

This installs layers 1-3 and 5 immediately. Layer 4 (Hindsight) requires Docker -- the script will guide you.

### Or set up manually:

<details>
<summary><b>Layer 1+2: CLAUDE.md + primer.md</b> (5 minutes)</summary>

Copy the template files:
```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp primer.md ~/.claude/primer.md
```

The key rule in CLAUDE.md:
```
After completing any task (not just session end), silently overwrite
~/.claude/primer.md with: active project, what's been completed,
exact next step, open blockers. Keep under 100 lines.
```

After your first session, primer.md populates itself. After every task, it rewrites itself. If you kill the terminal mid-session, the last completed task's state is already saved.

</details>

<details>
<summary><b>Layer 3+4: Hooks</b> (5 minutes)</summary>

Copy hooks and make them executable:
```bash
mkdir -p ~/.claude/hooks
cp hooks/session-start.sh hooks/session-end.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/session-start.sh ~/.claude/hooks/session-end.sh
```

Add to `~/.claude/settings.json` (or merge with existing):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/session-start.sh\"",
            "timeout": 15
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/session-end.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Optional:** Add the post-commit hook to any repo for a running commit log:
```bash
cp hooks/post-commit your-repo/.git/hooks/post-commit
chmod +x your-repo/.git/hooks/post-commit
```

</details>

<details>
<summary><b>Layer 4: Hindsight</b> (10 minutes)</summary>

[Hindsight](https://github.com/vectorize-io/hindsight) extracts behavioral patterns from past sessions and injects them into future ones. Not retrieval -- adaptation.

> **Why Docker?** The Hindsight server requires `uvloop`, which only runs on Linux. Docker runs a Linux VM under the hood, so it works on any OS (Windows, Mac, Linux).

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), then:

```bash
export ANTHROPIC_API_KEY=your-key-here

docker run -d \
  --name hindsight \
  --restart unless-stopped \
  -p 8888:8888 \
  -p 9999:9999 \
  -e HINDSIGHT_API_LLM_PROVIDER=anthropic \
  -e HINDSIGHT_API_LLM_API_KEY=$ANTHROPIC_API_KEY \
  -v hindsight-data:/home/hindsight/.pg0 \
  ghcr.io/vectorize-io/hindsight:latest
```

Create the memory bank (one-time):
```bash
curl -s -X PUT http://localhost:8888/v1/default/banks/claude-sessions \
  -H 'Content-Type: application/json' \
  -d '{"description": "Claude Code session behavioral patterns"}'
```

| Resource | URL |
|----------|-----|
| Hindsight API | `http://localhost:8888` |
| Hindsight UI | `http://localhost:9999` |

**Supported LLM providers:** `anthropic`, `openai`, `gemini`, `groq`, `ollama`, `lmstudio`

The hooks handle retain/recall automatically. No extra wiring needed.

</details>

<details>
<summary><b>Layer 5: Obsidian</b> (2 minutes)</summary>

Add a shell alias so your vault is always mounted:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias claude='claude --add-dir "$HOME/path/to/your/obsidian/vault"'
```

Every note in the vault becomes context Claude can read. Syncs to mobile via iCloud/Obsidian Sync. No plugin needed.

</details>

---

## File Structure

```
~/.claude/
  CLAUDE.md                # Layer 1: Rules (imports primer.md)
  primer.md                # Layer 2: Auto-rewriting session state
  settings.json            # Hook configuration
  hooks/
    session-start.sh       # Layer 3+4: Git context + Hindsight recall
    session-end.sh         # Layer 4: Hindsight retain

your-repo/.git/hooks/
  post-commit              # Logs commits to .claude-memory.md
```

---

## Without Hindsight

Don't want to run Docker? The hooks gracefully skip Layer 4 if Hindsight isn't running. You still get:

- **Layer 1+2:** Rules + auto-rewriting session state
- **Layer 3:** Git context injection every launch
- **Layer 5:** Obsidian vault as context

That's already better than what most setups have.

---

## Requirements

| Requirement | Required for | Notes |
|------------|-------------|-------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Everything | The CLI this is built for |
| Git | Layer 3 | Git context injection |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Layer 4 only | Runs Hindsight server |
| Python 3.x | Layer 4 only | Parses Hindsight JSON in hook |
| Obsidian | Layer 5 only | Any vault, any sync method |

---

## FAQ

<details>
<summary><b>What if I close the terminal without ending the session properly?</b></summary>

primer.md rewrites after every completed task, not just at session end. If you kill the terminal, the state from the last completed task is already saved. The SessionEnd hook (Hindsight retain) won't fire, but the next session still has everything from primer.md + git context.

</details>

<details>
<summary><b>Does primer.md grow forever?</b></summary>

No. It's a single file that gets overwritten (not appended to) every time. Capped at 100 lines by the CLAUDE.md rule. Always ~2-3KB.

</details>

<details>
<summary><b>Can I use this with Cursor / Codex / other tools?</b></summary>

Layers 1 and 2 (CLAUDE.md + primer.md) are Claude Code specific. Layers 3-5 are generic shell scripts that could be adapted for any tool that supports hooks or launch scripts.

</details>

<details>
<summary><b>How much does Hindsight cost?</b></summary>

Hindsight is free and open source. It uses your LLM API key to process memories. Each retain/recall is a small API call (a few thousand tokens). At Anthropic's Haiku pricing, this is fractions of a cent per session.

</details>

---

## Credits

Built by [@keshavsuki](https://github.com/ksukirya). Powered by [Hindsight](https://github.com/vectorize-io/hindsight) for behavioral learning.

---

<div align="center">

**If this helped you, give it a star.**

</div>
