#!/bin/bash
# Claude Code Hook: Warn when a .pq file is written without the required header comment
# Runs as PostToolUse on Write tool calls
# Reads tool output JSON from stdin

INPUT=$(cat)

# Extract the file path
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only check .pq files
if echo "$FILE_PATH" | grep -qi "\.pq$"; then

    # Extract the content that was written
    CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('content', ''))
except Exception:
    print('')
" 2>/dev/null)

    # Check that the file starts with the /* header comment block
    if ! echo "$CONTENT" | grep -q "^/\*"; then
        echo ""
        echo "WARNING: '$FILE_PATH' is missing the required header comment block."
        echo ""
        echo "All .pq files in this project must begin with a /* ... */ block covering:"
        echo "  - TABLE OVERVIEW: purpose and grain"
        echo "  - BUSINESS USE CASES"
        echo "  - Source dependencies"
        echo ""
        echo "See .claude/templates/TEMPLATE-POWER-QUERY-HEADER.md for the standard format."
        echo ""
    fi

    # Check naming conventions
    FILENAME=$(basename "$FILE_PATH" .pq)

    # Facts should start with Fact_
    if echo "$FILE_PATH" | grep -qi "fact-tables"; then
        if ! echo "$FILENAME" | grep -q "^Fact_"; then
            echo "WARNING: Fact table file '$FILENAME.pq' should be named 'Fact_[Name].pq' (PascalCase after prefix)."
        fi
    fi

    # Dimensions should start with dim_ or lookup_
    if echo "$FILE_PATH" | grep -qi "dimensions"; then
        if ! echo "$FILENAME" | grep -qE "^(dim_|lookup_)"; then
            echo "WARNING: Dimension file '$FILENAME.pq' should be named 'dim_[Name].pq' or 'lookup_[Name].pq'."
        fi
    fi

    # Raw tables should start with Raw_ (in raw-tables folder)
    if echo "$FILE_PATH" | grep -qi "raw-tables"; then
        if ! echo "$FILENAME" | grep -q "^Raw_"; then
            echo "WARNING: Raw table file '$FILENAME.pq' in raw-tables/ should be named 'Raw_[Name].pq'."
        fi
    fi
fi

exit 0
