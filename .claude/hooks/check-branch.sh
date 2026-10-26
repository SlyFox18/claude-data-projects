#!/bin/bash
# Claude Code Hook: Block git commit when on the main branch
# Runs as PreToolUse on Bash tool calls
# Reads tool input JSON from stdin (grep instead of python: ~5x faster on Windows)

INPUT=$(cat)

# Only intercept git commit commands
if echo "$INPUT" | grep -qE '"command"[^}]*git[^"]*commit'; then
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
