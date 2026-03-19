#!/bin/bash
# Layer 3+4: Fires on every Claude Code session start
# Injects git context + Hindsight behavioral patterns

HINDSIGHT_URL="${HINDSIGHT_URL:-http://localhost:8888}"

echo "## Live Context (auto-injected)"
echo ""

# --- Layer 3: Git context ---
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "### Git Status"
  echo "**Branch:** $(git branch --show-current 2>/dev/null)"
  echo "**Last 5 commits:**"
  git log --oneline -5 2>/dev/null
  echo ""
  MODIFIED=$(git status --short 2>/dev/null)
  if [ -n "$MODIFIED" ]; then
    echo "**Modified files:**"
    echo "$MODIFIED"
    echo ""
  fi
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -f "$REPO_ROOT/.claude-memory.md" ]; then
    echo "**Recent commit log:**"
    tail -10 "$REPO_ROOT/.claude-memory.md"
    echo ""
  fi
fi

# --- Layer 4: Hindsight recall ---
RECALL_JSON=$(curl -sf -X POST "$HINDSIGHT_URL/v1/default/banks/claude-sessions/memories/recall" \
  -H 'Content-Type: application/json' \
  -d '{"query": "behavioral patterns, corrections, and preferences for Claude Code sessions"}' \
  2>/dev/null)

if [ -n "$RECALL_JSON" ] && [ "$RECALL_JSON" != "null" ]; then
  PATTERNS=$(python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    seen = set()
    for r in data.get('results', []):
        t = r.get('text', '')
        if t and t not in seen:
            seen.add(t)
            print(f'- {t}')
except: pass
" "$RECALL_JSON" 2>/dev/null)

  if [ -n "$PATTERNS" ]; then
    echo "### Hindsight Behavioral Patterns"
    echo "$PATTERNS"
    echo ""
  fi
fi

exit 0
