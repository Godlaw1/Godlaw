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
MEMORY_FILE="$PROJECT_DIR/memory.md"

# --- Sessie registreren ---
if [ ! -f "$SESSIONS_LOG" ]; then
  cat > "$SESSIONS_LOG" << 'HEADER'
# Sessie-register

Overzicht van alle Claude Code sessies. Bijgewerkt bij elke sessiestart.

| Tijdstip | Session ID | Bron | Map |
|----------|-----------|------|-----|
HEADER
fi

echo "| $TIMESTAMP | \`$SESSION_ID\` | $SOURCE | \`$PROJECT_DIR\` |" >> "$SESSIONS_LOG"

# --- Context tonen aan het begin van de sessie ---
echo "========================================"
echo "  GODLAW — Sessie gestart"
echo "========================================"
echo "  Tijd      : $TIMESTAMP"
echo "  Session ID: $SESSION_ID"
echo "  Bron      : $SOURCE"
echo "  Map       : $PROJECT_DIR"
echo "========================================"
echo ""

if [ -f "$MEMORY_FILE" ]; then
  echo "--- GEHEUGEN (memory.md) ---"
  cat "$MEMORY_FILE"
  echo ""
  echo "--- EINDE GEHEUGEN ---"
else
  echo "[!] Geen memory.md gevonden in $PROJECT_DIR"
fi

echo ""
echo "Sessie-log bijgewerkt: $SESSIONS_LOG"
echo "========================================"
