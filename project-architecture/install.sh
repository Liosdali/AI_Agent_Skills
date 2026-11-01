#!/bin/sh
# Installs the architecture kit into a Git project. Never overwrites existing files.

set -u
PATH="/usr/bin:/bin:$PATH"
LC_ALL=C
export PATH LC_ALL

usage() {
  cat <<'EOF'
Usage:
  sh install.sh <project-path> --src-root <path> [options]

Required:
  <project-path>            Git project to install the kit into
  --src-root <path>         Source root, relative to the project root. Example: src, lib, src/main/java/com/acme/app

Options:
  --import-prefix <prefix>  Project import prefix. Example: com.acme.app, package:app, @
                            Required for Java and Kotlin projects.
  --extra-dirs "<names>"    Top-level folders the language or framework requires. Example: "l10n generated"
  --owner <user>            GitHub user or team for CODEOWNERS. Example: @username, @org/team
  --scaffold                Creates the source root and layer folders (for a new project)
  -h, --help                Shows this help
EOF
}

fail() {
  echo "Error: $1" >&2
  exit 1
}

TARGET=""
SRC_ROOT=""
IMPORT_PREFIX=""
EXTRA_DIRS=""
OWNER=""
SCAFFOLD=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --scaffold) SCAFFOLD=1; shift ;;
    --src-root|--import-prefix|--extra-dirs|--owner)
      [ $# -ge 2 ] || fail "$1 needs a value."
      case "$1" in
        --src-root) SRC_ROOT=$2 ;;
        --import-prefix) IMPORT_PREFIX=$2 ;;
        --extra-dirs) EXTRA_DIRS=$2 ;;
        --owner) OWNER=$2 ;;
      esac
      shift 2
      ;;
    -*) fail "Unknown option: $1" ;;
    *)
      [ -z "$TARGET" ] || fail "Only one project path can be given."
      TARGET=$1
      shift
      ;;
  esac
done

if [ -z "$TARGET" ] || [ -z "$SRC_ROOT" ]; then
  usage >&2
  exit 1
fi

KIT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
TEMPLATE="$KIT_DIR/template"
[ -d "$TEMPLATE" ] || fail "Template folder not found: $TEMPLATE"
command -v git > /dev/null 2>&1 || fail "Git not found."
[ -d "$TARGET" ] || fail "Project folder not found: $TARGET"
ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2> /dev/null) ||
  fail "$TARGET is not a Git repository. Run git init in the project folder first."

SRC_ROOT=$(printf '%s' "$SRC_ROOT" | tr '\\' '/')
SRC_ROOT=${SRC_ROOT%/}
SRC_ROOT=${SRC_ROOT#./}
case "$SRC_ROOT" in
  ""|/*|*:*|..|../*|*/../*|*/..) fail "--src-root must be relative to the project root: $SRC_ROOT" ;;
esac

case "$OWNER" in
  ""|@*) ;;
  *) OWNER="@$OWNER" ;;
esac

if [ ! -d "$ROOT/$SRC_ROOT" ] && [ "$SCAFFOLD" -eq 0 ]; then
  fail "Source root not found: $ROOT/$SRC_ROOT. Add --scaffold for a new project."
fi

if [ -z "$IMPORT_PREFIX" ] && [ -d "$ROOT/$SRC_ROOT" ]; then
  if [ -n "$(find "$ROOT/$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' \) | head -n 1)" ]; then
    fail "--import-prefix is required for Java and Kotlin. Example: --import-prefix com.acme.app"
  fi
fi

NL='
'
ADDED=""
UPDATED=""
KEPT=""
TODO=""

add_todo() {
  TODO="$TODO  - $1$NL"
}

# Copies the file and returns 0 if it does not exist. Otherwise leaves it alone and returns 1.
copy_new() {
  if [ -e "$ROOT/$1" ]; then
    KEPT="$KEPT  - $1$NL"
    return 1
  fi
  mkdir -p "$ROOT/$(dirname "$1")" && cp "$TEMPLATE/$1" "$ROOT/$1" || fail "Could not copy: $1"
  ADDED="$ADDED  - $1$NL"
  return 0
}

escape_sed() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

replace_in_file() {
  temp=$(mktemp) || fail "Could not create a temporary file."
  sed "$2" "$ROOT/$1" > "$temp" && cat "$temp" > "$ROOT/$1" || fail "Could not update: $1"
  rm -f "$temp"
}

append_line() {
  if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
    echo >> "$1"
  fi
  printf '%s\n' "$2" >> "$1"
}

if [ "$SCAFFOLD" -eq 1 ]; then
  for layer in app shell screens business jobs shared platform; do
    if [ ! -d "$ROOT/$SRC_ROOT/$layer" ]; then
      mkdir -p "$ROOT/$SRC_ROOT/$layer" || fail "Could not create folder: $SRC_ROOT/$layer"
      : > "$ROOT/$SRC_ROOT/$layer/.gitkeep"
      ADDED="$ADDED  - $SRC_ROOT/$layer/$NL"
    fi
  done
fi

for file in docs/ARCHITECTURE.md .github/workflows/architecture.yml tools/check-architecture.awk; do
  copy_new "$file"
done

if copy_new tools/check-architecture.sh; then
  replace_in_file tools/check-architecture.sh "s|ARCH_SRC_ROOT:-src}|ARCH_SRC_ROOT:-$(escape_sed "$SRC_ROOT")}|"
  replace_in_file tools/check-architecture.sh "s|ARCH_IMPORT_PREFIX:-}|ARCH_IMPORT_PREFIX:-$(escape_sed "$IMPORT_PREFIX")}|"
  replace_in_file tools/check-architecture.sh "s|ARCH_EXTRA_DIRS:-}|ARCH_EXTRA_DIRS:-$(escape_sed "$EXTRA_DIRS")}|"
  chmod +x "$ROOT/tools/check-architecture.sh"
fi

if copy_new AGENTS.md; then
  replace_in_file AGENTS.md "s|Source root: \`src/\`|Source root: \`$(escape_sed "$SRC_ROOT")/\`|"
fi
if grep -qE '<build command>|<test command>' "$ROOT/AGENTS.md"; then
  add_todo "Fill in the build and test commands in AGENTS.md."
elif ! grep -q 'tools/check-architecture.sh' "$ROOT/AGENTS.md"; then
  add_todo "Add the rules from this file to the existing AGENTS.md: $TEMPLATE/AGENTS.md"
fi

if copy_new .github/CODEOWNERS && [ -n "$OWNER" ]; then
  replace_in_file .github/CODEOWNERS "/^# Replace @YOUR_USERNAME/d"
  replace_in_file .github/CODEOWNERS "s|@YOUR_USERNAME|$(escape_sed "$OWNER")|g"
fi
if grep -q '@YOUR_USERNAME' "$ROOT/.github/CODEOWNERS"; then
  add_todo "Replace @YOUR_USERNAME in .github/CODEOWNERS with your own user."
fi

if [ -e "$ROOT/CLAUDE.md" ]; then
  if grep -q '@AGENTS.md' "$ROOT/CLAUDE.md"; then
    KEPT="$KEPT  - CLAUDE.md$NL"
  else
    append_line "$ROOT/CLAUDE.md" '@AGENTS.md'
    UPDATED="$UPDATED  - CLAUDE.md (added @AGENTS.md)$NL"
  fi
else
  copy_new CLAUDE.md
fi

if [ -e "$ROOT/.gitattributes" ]; then
  changed=0
  while IFS= read -r line; do
    if ! grep -qxF "$line" "$ROOT/.gitattributes"; then
      append_line "$ROOT/.gitattributes" "$line"
      changed=1
    fi
  done < "$TEMPLATE/.gitattributes"
  if [ "$changed" -eq 1 ]; then
    UPDATED="$UPDATED  - .gitattributes (added missing lines)$NL"
  else
    KEPT="$KEPT  - .gitattributes$NL"
  fi
else
  copy_new .gitattributes
fi

if ! copy_new .claude/settings.json; then
  if ! grep -q 'check-architecture.sh' "$ROOT/.claude/settings.json"; then
    add_todo "Add the hooks and permissions sections from this file to the existing .claude/settings.json: $TEMPLATE/.claude/settings.json"
  fi
fi

if copy_new .githooks/pre-commit; then
  chmod +x "$ROOT/.githooks/pre-commit"
  git -C "$ROOT" add --chmod=+x -- .githooks/pre-commit 2> /dev/null ||
    add_todo "Add .githooks/pre-commit as executable: git add --chmod=+x .githooks/pre-commit"
fi

CURRENT_HOOKS=$(git -C "$ROOT" config --get core.hooksPath 2> /dev/null || true)
OLD_HOOK=$(git -C "$ROOT" rev-parse --git-path hooks/pre-commit 2> /dev/null)
if [ "$CURRENT_HOOKS" = ".githooks" ]; then
  :
elif [ -n "$CURRENT_HOOKS" ]; then
  add_todo "core.hooksPath was left unchanged because it is $CURRENT_HOOKS. Add this line to the pre-commit hook in that folder: sh tools/check-architecture.sh"
elif (cd "$ROOT" && [ -e "$OLD_HOOK" ]); then
  add_todo "core.hooksPath was not set so the existing $OLD_HOOK hook keeps working. Add this line to that hook: sh tools/check-architecture.sh"
else
  git -C "$ROOT" config core.hooksPath .githooks || fail "Could not set core.hooksPath."
fi

BASELINE_NOTE="Existing baseline kept."
if [ ! -f "$ROOT/tools/architecture-baseline.txt" ]; then
  BASELINE_NOTE=$(sh "$ROOT/tools/check-architecture.sh" --update-baseline 2>&1) ||
    fail "Could not create the baseline: $BASELINE_NOTE"
  ADDED="$ADDED  - tools/architecture-baseline.txt$NL"
fi

CHECK_OUTPUT=$(sh "$ROOT/tools/check-architecture.sh" 2>&1)
CHECK_CODE=$?

add_todo "Review the files, commit and push."
add_todo "Turn on the main branch rule on GitHub: require the architecture check and code owner approval."
add_todo "Each team member runs this once in their copy: git config core.hooksPath .githooks"

echo "Project: $ROOT"
[ -n "$ADDED" ] && printf '\nAdded:\n%s' "$ADDED"
[ -n "$UPDATED" ] && printf '\nUpdated:\n%s' "$UPDATED"
[ -n "$KEPT" ] && printf '\nLeft alone because they already exist:\n%s' "$KEPT"
printf '\nBaseline:\n  %s\n' "$BASELINE_NOTE"
printf '\nCheck:\n%s\n' "$CHECK_OUTPUT"
printf '\nRemaining steps:\n%s' "$TODO"

if [ "$CHECK_CODE" -ne 0 ]; then
  echo
  echo "The kit is installed, but the architecture check failed. Review the result above."
  exit "$CHECK_CODE"
fi
exit 0
