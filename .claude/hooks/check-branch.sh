#!/bin/bash
# Claude Code Hook: Block git commit when on the main branch
# Runs as PreToolUse on Bash tool calls
# Reads tool input JSON from stdin

INPUT=$(cat)

# Extract the bash command being run
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only intercept git commit commands
if echo "$COMMAND" | grep -qE "git.*commit"; then
    # Get current branch (works from project root working directory)
    BRANCH=$(git branch --show-current 2>/dev/null)

    if [ "$BRANCH" = "main" ]; then
        echo ""
        echo "BLOCKED: You are on the 'main' branch."
        echo "All development work must go through 'dev' first."
        echo ""
        echo "Switch branches and try again:"
        echo "  git checkout dev"
        echo ""
        exit 2
    fi
fi

exit 0
