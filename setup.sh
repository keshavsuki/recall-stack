#!/bin/bash
# One-command setup for the 5-layer Claude Code memory architecture
# Usage: bash setup.sh [--obsidian /path/to/vault]

set -e

OBSIDIAN_VAULT=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --obsidian) OBSIDIAN_VAULT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Setting up 5-layer Claude Code memory architecture..."

# --- Layer 1: CLAUDE.md ---
mkdir -p ~/.claude
if [ ! -f ~/.claude/CLAUDE.md ]; then
  cp CLAUDE.md ~/.claude/CLAUDE.md
  echo "[+] Layer 1: CLAUDE.md installed"
else
  echo "[=] Layer 1: CLAUDE.md already exists (not overwriting)"
fi

# --- Layer 2: primer.md ---
if [ ! -f ~/.claude/primer.md ]; then
  cp primer.md ~/.claude/primer.md
  echo "[+] Layer 2: primer.md installed"
else
  echo "[=] Layer 2: primer.md already exists (not overwriting)"
fi

# --- Layer 3+4: Hooks ---
mkdir -p ~/.claude/hooks
cp hooks/session-start.sh ~/.claude/hooks/session-start.sh
cp hooks/session-end.sh ~/.claude/hooks/session-end.sh
chmod +x ~/.claude/hooks/session-start.sh ~/.claude/hooks/session-end.sh
echo "[+] Layer 3+4: Hooks installed"

# Merge hooks into settings.json
if [ -f ~/.claude/settings.json ]; then
  # Check if hooks already configured
  if grep -q "SessionStart" ~/.claude/settings.json 2>/dev/null; then
    echo "[=] Hooks already in settings.json (not overwriting)"
  else
    echo "[!] settings.json exists but has no hooks. Merge manually from settings.json in this repo."
  fi
else
  cp settings.json ~/.claude/settings.json
  echo "[+] settings.json installed with hook configuration"
fi

# --- Layer 4: Hindsight ---
if command -v docker &> /dev/null; then
  if docker info > /dev/null 2>&1; then
    if ! docker ps -a --format '{{.Names}}' | grep -q '^hindsight$'; then
      if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "[!] Layer 4: Set ANTHROPIC_API_KEY env var, then run:"
        echo "    docker run -d --name hindsight --restart unless-stopped \\"
        echo "      -p 8888:8888 -p 9999:9999 \\"
        echo "      -e HINDSIGHT_API_LLM_PROVIDER=anthropic \\"
        echo "      -e HINDSIGHT_API_LLM_API_KEY=\$ANTHROPIC_API_KEY \\"
        echo "      -v hindsight-data:/home/hindsight/.pg0 \\"
        echo "      ghcr.io/vectorize-io/hindsight:latest"
      else
        docker run -d \
          --name hindsight \
          --restart unless-stopped \
          -p 8888:8888 \
          -p 9999:9999 \
          -e HINDSIGHT_API_LLM_PROVIDER=anthropic \
          -e "HINDSIGHT_API_LLM_API_KEY=$ANTHROPIC_API_KEY" \
          -v hindsight-data:/home/hindsight/.pg0 \
          ghcr.io/vectorize-io/hindsight:latest

        # Wait for startup
        echo -n "    Waiting for Hindsight..."
        for i in $(seq 1 30); do
          if curl -sf http://localhost:8888/health > /dev/null 2>&1; then
            echo " ready"
            break
          fi
          sleep 2
          echo -n "."
        done

        # Create memory bank
        curl -sf -X PUT http://localhost:8888/v1/default/banks/claude-sessions \
          -H 'Content-Type: application/json' \
          -d '{"name": "claude-sessions"}' > /dev/null 2>&1

        echo "[+] Layer 4: Hindsight running (API: localhost:8888, UI: localhost:9999)"
      fi
    else
      echo "[=] Layer 4: Hindsight container already exists"
    fi
  else
    echo "[!] Layer 4: Docker installed but not running. Start Docker Desktop first."
  fi
else
  echo "[!] Layer 4: Docker not found. Install Docker Desktop for Hindsight."
  echo "    Layers 1-3 and 5 work without it."
fi

# --- Layer 5: Obsidian ---
if [ -n "$OBSIDIAN_VAULT" ]; then
  SHELL_RC="$HOME/.bashrc"
  [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

  if grep -q 'alias claude=' "$SHELL_RC" 2>/dev/null; then
    echo "[=] Layer 5: Claude alias already exists in $SHELL_RC"
  else
    echo "" >> "$SHELL_RC"
    echo "# Claude Code with Obsidian vault (Layer 5)" >> "$SHELL_RC"
    echo "alias claude='claude --add-dir \"$OBSIDIAN_VAULT\"'" >> "$SHELL_RC"
    echo "[+] Layer 5: Obsidian alias added to $SHELL_RC"
  fi
else
  echo "[=] Layer 5: No Obsidian vault specified (use --obsidian /path/to/vault)"
fi

echo ""
echo "Done. Open a new terminal and run 'claude' in any git repo to verify."
