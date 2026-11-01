#!/bin/sh
# Checks the architecture rules. Only new violations outside the baseline fail.
#
#   sh tools/check-architecture.sh                    Checks, exits 1 on a violation
#   sh tools/check-architecture.sh --hook             For AI hooks, exits 2 on a violation
#   sh tools/check-architecture.sh --update-baseline  Records current violations (humans only)
#
# Supported languages: Java, Kotlin, Dart, JavaScript, TypeScript, Python.

# --- Set for your project ---------------------------------------------------
SRC_ROOT="${ARCH_SRC_ROOT:-src}"         # Example: lib, src/main/java/com/acme/app
IMPORT_PREFIX="${ARCH_IMPORT_PREFIX:-}"  # Example: com.acme.app, package:myapp, @
EXTRA_DIRS="${ARCH_EXTRA_DIRS:-}"        # Folders the language or framework requires. Example: l10n generated
# ---------------------------------------------------------------------------

LAYERS="app shell screens business jobs shared platform"
BASELINE="tools/architecture-baseline.txt"

PATH="/usr/bin:/bin:$PATH"
LC_ALL=C
export PATH LC_ALL

cd "$(dirname "$0")/.." || exit 1
SRC_ROOT=${SRC_ROOT%/}

MODE="check"
case "${1:-}" in
  "") ;;
  --hook) MODE="hook" ;;
  --update-baseline) MODE="update" ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

if [ ! -d "$SRC_ROOT" ]; then
  echo "Source root not found: $SRC_ROOT. Set SRC_ROOT." >&2
  exit 1
fi

find_sources() {
  find "$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' -o -name '*.dart' \
    -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' \) "$@"
}

if [ -z "$IMPORT_PREFIX" ]; then
  if [ -n "$(find "$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' \) | head -n 1)" ]; then
    echo "IMPORT_PREFIX is required for Java and Kotlin. Example: com.acme.app" >&2
    exit 1
  fi
  if [ "$MODE" != "hook" ]; then
    echo "Warning: IMPORT_PREFIX is empty, only relative imports are checked." >&2
  fi
fi

RAW=$(mktemp) || exit 1
CURRENT=$(mktemp) || exit 1
KNOWN=$(mktemp) || exit 1
trap 'rm -f "$RAW" "$CURRENT" "$KNOWN"' EXIT

for dir in "$SRC_ROOT"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  case " $LAYERS $EXTRA_DIRS " in
    *" $name "*) ;;
    *) printf 'FOLDER|%s/%s|\n' "$SRC_ROOT" "$name" >> "$RAW" ;;
  esac
done

if ! find_sources -print0 | xargs -0 awk -v root="$SRC_ROOT" -v prefix="$IMPORT_PREFIX" \
  -v allowed="$LAYERS $EXTRA_DIRS" -f tools/check-architecture.awk >> "$RAW"; then
  echo "Could not run the architecture check." >&2
  exit 1
fi

sort -u "$RAW" > "$CURRENT"

if [ "$MODE" = "update" ]; then
  cp "$CURRENT" "$BASELINE"
  echo "Baseline updated: $(wc -l < "$CURRENT" | tr -d ' ') entries"
  exit 0
fi

if [ -f "$BASELINE" ]; then
  tr -d '\r' < "$BASELINE" | sort -u > "$KNOWN"
else
  : > "$KNOWN"
fi

explain() {
  case "$1" in
    FOLDER) echo "New folders and files can only be in these folders: $LAYERS $EXTRA_DIRS" ;;
    DEPENDENCY) echo "Dependency direction: app -> shell, screens, jobs -> business -> platform" ;;
    SECTION_DATA) echo "Sections and rows do not use Store or Service. They get data through XData." ;;
    STATIC_SHELL) echo "Static access to the shell is not allowed. Get Navigator, Feedback or shared data through the constructor." ;;
    FILE_NAME) echo "The names Manager, Helper and Util are not used. Choose a name that describes the job." ;;
    *) echo "Unknown rule." ;;
  esac
}

report_new() {
  comm -13 "$KNOWN" "$CURRENT" | while IFS='|' read -r rule path text; do
    echo "[$rule] $path"
    [ -n "$text" ] && echo "  $text"
    echo "  $(explain "$rule")"
  done
  echo
  echo "Structure: docs/ARCHITECTURE.md"
  echo "Fix the code to follow the rule. Do not pass by changing the check or the baseline."
}

new_count=$(comm -13 "$KNOWN" "$CURRENT" | wc -l | tr -d ' ')
fixed_count=$(comm -23 "$KNOWN" "$CURRENT" | wc -l | tr -d ' ')

if [ "$new_count" -gt 0 ]; then
  if [ "$MODE" = "hook" ]; then
    { echo "Architecture check: $new_count new violation(s)"; echo; report_new; } >&2
    exit 2
  fi
  echo "Architecture check: $new_count new violation(s)"
  echo
  report_new
  exit 1
fi

if [ "$MODE" != "hook" ]; then
  echo "Architecture check passed. Baseline: $(wc -l < "$KNOWN" | tr -d ' ') entries."
  if [ "$fixed_count" -gt 0 ]; then
    echo "$fixed_count old violation(s) fixed. Tell the code owner so the baseline can be updated."
  fi
fi
exit 0
