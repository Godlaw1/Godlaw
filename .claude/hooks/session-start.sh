#!/bin/bash
set -euo pipefail

# Alleen uitvoeren in remote omgeving (Claude Code op het web)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-onbekend}"
SOURCE="${CLAUDE_SOURCE:-startup}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSIONS_LOG="$PROJECT_DIR/sessions-log.md"

# --- Sessie registreren ---
if [ ! -f "$SESSIONS_LOG" ]; then
  printf '# Sessie-register\n\nOverzicht van alle Claude Code sessies.\n\n| Tijdstip | Session ID | Bron | Branch |\n|----------|-----------|------|--------|\n' > "$SESSIONS_LOG"
fi

# --- Git context ophalen ---
cd "$PROJECT_DIR"
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "geen git")
GIT_LOG=$(git log --oneline -5 2>/dev/null || echo "geen commits")
GIT_STATUS=$(git status --short 2>/dev/null || echo "")
GIT_DIFF_STAT=$(git diff --stat HEAD 2>/dev/null | tail -1 || echo "")

echo "| $TIMESTAMP | \`$SESSION_ID\` | $SOURCE | \`$GIT_BRANCH\` |" >> "$SESSIONS_LOG"

# --- Volledig context-overzicht ---
echo "========================================"
echo "  GODLAW — Sessie gestart: $TIMESTAMP"
echo "========================================"
echo ""

# 1. Geheugen
if [ -f "$PROJECT_DIR/memory.md" ]; then
  echo "## GEHEUGEN"
  cat "$PROJECT_DIR/memory.md"
  echo ""
fi

# 2. Git-context
echo "## GIT-CONTEXT"
echo "Branch : $GIT_BRANCH"
echo ""
echo "Laatste 5 commits:"
echo "$GIT_LOG"
echo ""

if [ -n "$GIT_STATUS" ]; then
  echo "Gewijzigde bestanden:"
  echo "$GIT_STATUS"
  echo ""
fi

if [ -n "$GIT_DIFF_STAT" ]; then
  echo "Wijzigingen: $GIT_DIFF_STAT"
  echo ""
fi

# 3. Agent coördinatie
AGENTS_SHARED="$PROJECT_DIR/.claude/agents/_shared"
if [ -f "$AGENTS_SHARED/coordinatie.md" ]; then
  echo "## AGENT COÖRDINATIE"
  cat "$AGENTS_SHARED/coordinatie.md"
  echo ""
fi

if [ -f "$AGENTS_SHARED/taken.md" ]; then
  echo "## OPEN TAKEN"
  cat "$AGENTS_SHARED/taken.md"
  echo ""
fi

if [ -f "$AGENTS_SHARED/communicatie.md" ]; then
  COMMS=$(grep -v '^#' "$AGENTS_SHARED/communicatie.md" | grep -v '^$' | tail -5 || true)
  if [ -n "$COMMS" ]; then
    echo "## RECENTE BERICHTEN"
    echo "$COMMS"
    echo ""
  fi
fi

# 4. Actieve notities (notes.md of aantekeningen.md)
for NOTES_FILE in "$PROJECT_DIR/notes.md" "$PROJECT_DIR/aantekeningen.md"; do
  if [ -f "$NOTES_FILE" ]; then
    echo "## NOTITIES ($(basename "$NOTES_FILE"))"
    tail -30 "$NOTES_FILE"
    echo ""
    break
  fi
done

# 5. Geplande jobs controleren
SCHEDULER="$PROJECT_DIR/.claude/hooks/job-scheduler.py"
if [ -f "$SCHEDULER" ]; then
  echo ""
  CLAUDE_PROJECT_DIR="$PROJECT_DIR" python3 "$SCHEDULER"
  echo ""
fi

echo "========================================"
echo "  Context geladen. Sessie klaar."
echo "========================================"
