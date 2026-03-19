#!/bin/bash
# Circuit breaker: blokkeert runaway loops vóór ze tokens verspillen.
# Werkt als PreToolUse hook — ontvangt JSON via stdin, output beslissing.
set -euo pipefail

# --- Configuratie ---
MAX_CALLS=50          # Max tool-aanroepen per sessie
MAX_IDENTICAL=5       # Max identieke opeenvolgende aanroepen
STATE_DIR="${TMPDIR:-/tmp}/claude-loop-guard"

# --- Input lezen ---
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo "{}")

SESSION_DIR="$STATE_DIR/$SESSION_ID"
mkdir -p "$SESSION_DIR"

COUNTER_FILE="$SESSION_DIR/count"
LAST_CALL_FILE="$SESSION_DIR/last_call"
IDENTICAL_FILE="$SESSION_DIR/identical_count"

# --- Totaal aantal aanroepen bijhouden ---
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# --- Hard limiet: te veel aanroepen totaal ---
if [ "$COUNT" -gt "$MAX_CALLS" ]; then
  echo "{\"decision\": \"block\", \"reason\": \"Loop guard: sessie heeft $COUNT tool-aanroepen bereikt (max $MAX_CALLS). Mogelijke runaway loop. Stop en evalueer wat er mis gaat.\"}"
  exit 0
fi

# --- Detecteer identieke opeenvolgende aanroepen ---
CALL_FINGERPRINT="${TOOL_NAME}:${TOOL_INPUT}"
IDENTICAL=1

if [ -f "$LAST_CALL_FILE" ]; then
  LAST=$(cat "$LAST_CALL_FILE")
  if [ "$LAST" = "$CALL_FINGERPRINT" ]; then
    if [ -f "$IDENTICAL_FILE" ]; then
      IDENTICAL=$(cat "$IDENTICAL_FILE")
    fi
    IDENTICAL=$((IDENTICAL + 1))
  fi
fi

echo "$IDENTICAL" > "$IDENTICAL_FILE"
echo "$CALL_FINGERPRINT" > "$LAST_CALL_FILE"

if [ "$IDENTICAL" -gt "$MAX_IDENTICAL" ]; then
  echo "{\"decision\": \"block\", \"reason\": \"Loop guard: '$TOOL_NAME' is $IDENTICAL keer achter elkaar identiek aangeroepen (max $MAX_IDENTICAL). Mogelijke loop. Analyseer de situatie opnieuw.\"}"
  exit 0
fi

# --- Waarschuwing bij hoog gebruik (80%) ---
WARN_AT=$((MAX_CALLS * 80 / 100))
if [ "$COUNT" -eq "$WARN_AT" ]; then
  # Niet blokkeren, wel loggen naar stderr (zichtbaar in Claude's console)
  echo "[loop-guard] Waarschuwing: $COUNT/$MAX_CALLS aanroepen gebruikt in deze sessie." >&2
fi

# Toestaan
exit 0
