#!/bin/bash
# Tests the kit in temporary projects. Does not change the kit files.
# Usage: bash tests/test-kit.sh

KIT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
TEMPLATE="$KIT/template"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT

# Keep the tests independent of the machine's Git settings.
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
: > "$GIT_CONFIG_GLOBAL"

PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

new_project() {
  P="$WORK/$1"
  mkdir -p "$P/tools"
  cp "$TEMPLATE"/tools/check-architecture.* "$P/tools/"
}
new_repo() {
  P="$WORK/$1"
  mkdir -p "$P"
  git -C "$P" init -q
  git -C "$P" config user.name test
  git -C "$P" config user.email test@example.invalid
}
put() {
  mkdir -p "$P/$(dirname "$1")"
  printf '%s\n' "$2" > "$P/$1"
}
edit_file() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
to_crlf() { awk '{ printf "%s\r\n", $0 }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
run() { OUT=$(sh "$P/tools/check-architecture.sh" "$@" 2>&1); CODE=$?; }
install() { OUT=$(sh "$KIT/install.sh" "$@" 2>&1); CODE=$?; }
expect_code() { if [ "$CODE" = "$1" ]; then ok "$2"; else bad "$2 (exit $CODE, expected $1)" "$OUT"; fi; }
expect_has()  { case "$OUT" in *"$1"*) ok "$2" ;; *) bad "$2" "$OUT" ;; esac; }
expect_not()  { case "$OUT" in *"$1"*) bad "$2" "$OUT" ;; *) ok "$2" ;; esac; }
expect_file() { if [ -e "$P/$1" ]; then ok "$2"; else bad "$2 ($1 missing)"; fi; }
expect_none() { if [ -e "$P/$1" ]; then bad "$2 ($1 exists)"; else ok "$2"; fi; }
expect_grep() { if grep -qF -- "$1" "$P/$2"; then ok "$3"; else bad "$3" "$(cat "$P/$2")"; fi; }
expect_nogrep() { if grep -qF -- "$1" "$P/$2"; then bad "$3" "$(cat "$P/$2")"; else ok "$3"; fi; }

echo "=== Java ==="
export ARCH_SRC_ROOT="src/main/java/com/acme/app" ARCH_IMPORT_PREFIX="com.acme.app"
new_project "java project"
R="$ARCH_SRC_ROOT"
put "$R/app/Main.java" 'import com.acme.app.shell.AppFrame;
import com.acme.app.screens.orders.OrderScreen;
import com.acme.app.platform.database.Db;'
put "$R/business/orders/OrderTotal.java" 'package com.acme.app.business.orders;
import java.util.List;
import javafx.application.Platform;
import org.x.platform.Y;
import com.acme.app.platform.database.Db;
import com.acme.app.shared.format.Money;
import com.acme.app.screens.orders.OrderScreen;
import static com.acme.app.shell.AppFrame.foo;'
put "$R/screens/orders/detail/OrderDetailData.java" 'import com.acme.app.business.orders.OrderStore;
import com.acme.app.platform.logging.Log;
import com.acme.app.platform.config.Settings;
import com.acme.app.platform.database.Db;
import com.acme.app.shell.AppFrame;'
put "$R/screens/orders/detail/sections/summary/TotalAmountRow.java" 'import com.acme.app.business.orders.OrderStore;
import com.acme.app.business.orders.Order;'
put "$R/screens/x/Y.java" 'class Y { void a() { AppFrame.getInstance().foo(); } }'
put "$R/screens/orders/order detail/Z.java" 'import com.acme.app.shell.Bar;'
put "$R/shared/format/MoneyUtils.java" 'class MoneyUtils {}'
put "$R/legacy/Foo.java" 'import com.acme.app.screens.orders.OrderScreen;'
run
expect_code 1 "exit 1 when there are violations"
expect_has "Architecture check: 10 new violation(s)" "exactly 10 violations"
expect_has "[FOLDER] $R/legacy/Foo.java" "file in a legacy folder recorded"
expect_has "[DEPENDENCY] $R/business/orders/OrderTotal.java" "business -> screens caught"
expect_has "import static com.acme.app.shell.AppFrame.foo;" "static import caught"
expect_has "import com.acme.app.platform.database.Db;" "screens -> platform/database caught"
expect_has "[SECTION_DATA] $R/screens/orders/detail/sections/summary/TotalAmountRow.java" "row -> Store caught"
expect_has "[STATIC_SHELL] $R/screens/x/Y.java" "static shell access caught"
expect_has "[FILE_NAME] $R/shared/format/MoneyUtils.java" "Utils file name caught"
expect_has "[FOLDER] $R/legacy" "undefined folder caught"
expect_has "order detail/Z.java" "path with a space read"
expect_not "javafx.application.Platform" "third-party Platform class not flagged"
expect_not "org.x.platform.Y" "third-party platform package not flagged"
expect_not "platform.logging.Log" "allowed logging not flagged"
expect_not "platform.config.Settings" "allowed config not flagged"
expect_not "business.orders.Order;" "model use in a row not flagged"

echo "=== Baseline flow ==="
run --update-baseline
expect_has "Baseline updated: 10 entries" "baseline written"
run
expect_code 0 "old violations do not block"
expect_has "Baseline: 10 entries" "baseline count reported"
printf '%s\n' '// fix' >> "$P/$R/legacy/Foo.java"
run
expect_code 0 "existing file in a legacy folder can be edited"
put "$R/legacy/NewFile.java" 'class NewFile {}'
run
expect_code 1 "new file in a legacy folder blocked"
expect_has "[FOLDER] $R/legacy/NewFile.java" "new file reported"
rm "$P/$R/legacy/NewFile.java"
run
expect_code 0 "passes once the new file is deleted"
run --hook
expect_code 0 "passes in hook mode"
if [ -z "$OUT" ]; then ok "hook mode is silent on success"; else bad "hook mode is silent on success" "$OUT"; fi

F="$P/$R/business/orders/OrderTotal.java"
{ echo '// added line'; cat "$F"; } > "$F.tmp" && mv "$F.tmp" "$F"
run
expect_code 0 "line shift is not a new violation"

printf '%s\n' 'import com.acme.app.screens.orders.Other;' >> "$F"
run
expect_code 1 "new violation in an old file blocked"
expect_has "Architecture check: 1 new violation(s)" "only the new violation reported"
run --hook
expect_code 2 "exit 2 in hook mode"
expect_has "docs/ARCHITECTURE.md" "hook message points to the structure"
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"x"}}'
OUT=$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$P" sh "$P/tools/check-architecture.sh" --hook 2>&1); CODE=$?
expect_code 2 "hook command works with JSON on stdin"
edit_file '$d' "$F"
run
expect_code 0 "passes once the new violation is deleted"

rm "$P/$R/shared/format/MoneyUtils.java"
run
expect_code 0 "fixed violation does not block"
expect_has "1 old violation(s) fixed" "fixed violation reported"

to_crlf "$P/tools/architecture-baseline.txt"
to_crlf "$F"
run
expect_code 0 "CRLF baseline and source file cause no problem"

echo "=== Bad settings ==="
run --unknown
expect_code 1 "unknown option fails"
ARCH_IMPORT_PREFIX="" run
expect_code 1 "empty prefix fails for Java"
expect_has "IMPORT_PREFIX is required" "prefix error explained"
ARCH_SRC_ROOT="missing" run
expect_code 1 "missing source root fails"
cp "$P/tools/check-architecture.awk" "$WORK/awk.bak"
printf '%s\n' 'BEGIN { this is invalid awk' > "$P/tools/check-architecture.awk"
run
expect_code 1 "broken awk does not pass silently"
expect_has "Could not run" "broken awk reported"
cp "$WORK/awk.bak" "$P/tools/check-architecture.awk"

echo "=== TypeScript ==="
export ARCH_SRC_ROOT="src" ARCH_IMPORT_PREFIX="@"
new_project "ts"
put "src/business/a.ts" "import React from 'react';
import s from '../shared/z';
import t from '../screens/y';
import {
  q,
} from '../shell/z';
export * from '../jobs/q';
const w = require('../app/w');
import n from '@types/node';
import p from '@/screens/p';
export const label = \"../screens/not-import\";"
put "src/screens/orders/detail/D.ts" "import o from '../../../business/orders/o';
import x from '../../../shell/x';
import l from './sections/x';"
put "src/screens/orders/detail/sections/s/R.tsx" "import st from '../../../../../business/orders/order-store';
import m from '../../../../../business/orders/order';"
run
expect_has "Architecture check: 7 new violation(s)" "TS: exactly 7 violations"
expect_has "} from '../shell/z';" "TS: multi-line import caught"
expect_has "export * from '../jobs/q';" "TS: export from caught"
expect_has "require('../app/w')" "TS: require caught"
expect_has "@/screens/p" "TS: alias caught"
expect_has "[SECTION_DATA] src/screens/orders/detail/sections/s/R.tsx" "TS: row -> store caught"
expect_not "@types/node" "TS: @types not flagged"
expect_not "not-import" "TS: non-import text not flagged"
expect_not "'react'" "TS: package not flagged"
ARCH_IMPORT_PREFIX="" run
expect_has "only relative" "TS: warning when the prefix is empty"
expect_has "Architecture check: 6 new violation(s)" "TS: relative imports checked when the prefix is empty"

echo "=== BOM ==="
new_project "bom"
mkdir -p "$P/src/business"
printf '\357\273\277import t from '"'"'../screens/y'"'"';\r\n' > "$P/src/business/a.ts"
run
expect_code 1 "violation caught in a file starting with BOM and CRLF"
expect_has "Architecture check: 1 new violation(s)" "BOM: exactly 1 violation"
run --update-baseline
run
expect_code 0 "BOM file matches the baseline"

echo "=== Dart ==="
export ARCH_SRC_ROOT="lib" ARCH_IMPORT_PREFIX="package:myapp"
new_project "dart"
put "lib/main.dart" "import 'package:myapp/app/main_app.dart';"
put "lib/business/a.dart" "import 'dart:io';
import 'package:flutter/material.dart';
import 'package:myapp/platform/db.dart';
import 'local_part.dart';
import 'package:myapp/screens/x.dart';
import '../shell/x.dart';"
put "lib/screens/a/sections/b/c.dart" "import 'package:myapp/business/orders/order_store.dart';
import 'package:myapp/business/orders/order.dart';"
put "lib/l10n/app_en.dart" "class En {}"
run
expect_has "Architecture check: 5 new violation(s)" "Dart: exactly 5 violations"
expect_has "package:myapp/screens/x.dart" "Dart: package import caught"
expect_has "../shell/x.dart" "Dart: relative import caught"
expect_has "order_store.dart" "Dart: row -> store caught"
expect_has "[FOLDER] lib/l10n" "Dart: undefined folder caught"
expect_not "package:flutter" "Dart: flutter not flagged"
expect_not "local_part" "Dart: same folder not flagged"
ARCH_EXTRA_DIRS="l10n generated" run
expect_has "Architecture check: 3 new violation(s)" "Dart: EXTRA_DIRS exempts the folder"
expect_not "[FOLDER]" "Dart: no FOLDER violation with EXTRA_DIRS"

echo "=== Python ==="
export ARCH_SRC_ROOT="src/myapp" ARCH_IMPORT_PREFIX="myapp"
new_project "python"
put "src/myapp/business/orders/a.py" "import os
from myapp.screens.x import Y
import myapp.shell.z as q
from ...screens.w import W
from ..session import z
from myapp.platform.database import d"
run
expect_has "Architecture check: 3 new violation(s)" "Python: exactly 3 violations"
expect_has "from ...screens.w import W" "Python: relative import caught"
expect_has "import myapp.shell.z as q" "Python: import as caught"
expect_not "..session" "Python: same layer not flagged"
unset ARCH_SRC_ROOT ARCH_IMPORT_PREFIX

echo "=== Install: bad usage ==="
install
expect_code 1 "install with no arguments fails"
expect_has "Usage:" "usage shown"
install --help
expect_code 0 "help works"
mkdir -p "$WORK/not-git"
install "$WORK/not-git" --src-root src
expect_code 1 "target that is not a Git repository rejected"
expect_has "git init" "git init suggested"
install "$WORK/missing" --src-root src
expect_code 1 "missing target rejected"
new_repo "no-root"
install "$P" --src-root src
expect_code 1 "missing source root rejected"
expect_has "--scaffold" "scaffold suggested"
expect_none "AGENTS.md" "no files copied on error"
install "$P" --src-root /src
expect_code 1 "absolute source root rejected"
install "$P" --src-root ../src
expect_code 1 "source root outside the project rejected"
install "$P" --unknown
expect_code 1 "unknown install option rejected"
install "$P" extra --src-root src
expect_code 1 "two project paths rejected"
new_repo "java-no-prefix"
put "src/app/Main.java" "class Main {}"
install "$P" --src-root src
expect_code 1 "install rejected for Java with no prefix"
expect_none "AGENTS.md" "no files copied on a prefix error"

echo "=== Install: existing Java project ==="
new_repo "java install"
R="src/main/java/com/acme/app"
put "$R/business/orders/OrderTotal.java" 'import com.acme.app.screens.orders.OrderScreen;'
put "$R/legacy/Foo.java" 'class Foo {}'
git -C "$P" add -A
git -C "$P" commit -q -m first
install "$P" --src-root "$R" --import-prefix com.acme.app --extra-dirs "gen l10n" --owner acme/architecture
expect_code 0 "install succeeds"
expect_has "Remaining steps:" "remaining steps printed"
expect_has "Fill in the build" "build step listed"
expect_not "@YOUR_USERNAME" "no reminder when an owner is given"
for file in AGENTS.md CLAUDE.md .gitattributes docs/ARCHITECTURE.md .claude/settings.json .githooks/pre-commit \
  .github/CODEOWNERS .github/workflows/architecture.yml tools/check-architecture.sh tools/check-architecture.awk \
  tools/architecture-baseline.txt; do
  expect_file "$file" "installed: $file"
done
expect_none "README.md" "kit README not copied into the project"
expect_none "install.sh" "install script not copied into the project"
expect_grep "ARCH_SRC_ROOT:-$R}" tools/check-architecture.sh "source root set"
expect_grep "ARCH_IMPORT_PREFIX:-com.acme.app}" tools/check-architecture.sh "prefix set"
expect_grep "ARCH_EXTRA_DIRS:-gen l10n}" tools/check-architecture.sh "extra folders set"
expect_grep "Source root: \`$R/\`" AGENTS.md "AGENTS.md source root set"
expect_grep "@acme/architecture" .github/CODEOWNERS "CODEOWNERS user set"
expect_nogrep "@YOUR_USERNAME" .github/CODEOWNERS "no CODEOWNERS placeholder left"
expect_grep "FOLDER|$R/legacy/Foo.java|" tools/architecture-baseline.txt "old file written to the baseline"
expect_grep "DEPENDENCY|$R/business/orders/OrderTotal.java|" tools/architecture-baseline.txt "old violation written to the baseline"
if [ "$(git -C "$P" config core.hooksPath)" = ".githooks" ]; then ok "core.hooksPath set"; else bad "core.hooksPath set"; fi
run
expect_code 0 "check passes after install with no extra settings"
if git -C "$P" ls-files -s .githooks/pre-commit | grep -q '^100755'; then ok "pre-commit recorded as executable"; else bad "pre-commit recorded as executable" "$(git -C "$P" ls-files -s .githooks/pre-commit)"; fi
git -C "$P" add -A
if git -C "$P" commit -q -m kit > "$WORK/c1.log" 2>&1; then ok "install commit passes"; else bad "install commit passes" "$(cat "$WORK/c1.log")"; fi
put "$R/business/orders/New.java" 'import com.acme.app.shell.Bar;'
git -C "$P" add -A
if git -C "$P" commit -q -m violation > "$WORK/c2.log" 2>&1; then bad "commit with a violation blocked" "the commit passed"; else ok "commit with a violation blocked"; fi
if grep -q 'DEPENDENCY' "$WORK/c2.log"; then ok "commit error shows the violation"; else bad "commit error shows the violation" "$(cat "$WORK/c2.log")"; fi
git -C "$P" reset -q HEAD -- "$R/business/orders/New.java"

echo "=== Install: running again ==="
cp "$P/tools/architecture-baseline.txt" "$WORK/baseline.bak"
install "$P" --src-root "$R" --import-prefix com.acme.app
expect_code 1 "reinstall does not hide a new violation"
expect_has "[DEPENDENCY] $R/business/orders/New.java" "new violation reported"
expect_has "Existing baseline kept" "kept baseline reported"
if cmp -s "$P/tools/architecture-baseline.txt" "$WORK/baseline.bak"; then ok "baseline unchanged"; else bad "baseline unchanged"; fi
rm "$P/$R/business/orders/New.java"

echo "=== Install: existing files ==="
new_repo "existing"
put "src/app/a.ts" "export const a = 1;"
put "AGENTS.md" "# My rules"
put "CLAUDE.md" "# My instructions"
put ".gitattributes" "*.png binary"
put ".claude/settings.json" '{ "model": "opus" }'
put ".github/CODEOWNERS" "* @someone"
put "docs/ARCHITECTURE.md" "# My architecture"
install "$P" --src-root src
expect_code 0 "install with existing files succeeds"
expect_grep "# My rules" AGENTS.md "AGENTS.md kept"
expect_nogrep "Strict rules" AGENTS.md "AGENTS.md not overwritten"
expect_grep "# My architecture" docs/ARCHITECTURE.md "ARCHITECTURE.md kept"
expect_grep "* @someone" .github/CODEOWNERS "CODEOWNERS kept"
expect_grep '"model": "opus"' .claude/settings.json "settings.json kept"
expect_nogrep "check-architecture" .claude/settings.json "settings.json not overwritten"
expect_has "existing .claude/settings.json" "settings.json merge step requested"
expect_has "existing AGENTS.md" "AGENTS.md merge step requested"
expect_grep "# My instructions" CLAUDE.md "CLAUDE.md content kept"
expect_grep "@AGENTS.md" CLAUDE.md "CLAUDE.md pointer added"
expect_grep "*.png binary" .gitattributes ".gitattributes content kept"
expect_grep "*.sh text eol=lf" .gitattributes ".gitattributes lines added"
install "$P" --src-root src
expect_code 0 "second install succeeds"
COUNT=$(grep -c '@AGENTS.md' "$P/CLAUDE.md")
if [ "$COUNT" = "1" ]; then ok "CLAUDE.md pointer not added twice"; else bad "CLAUDE.md pointer not added twice" "$COUNT"; fi
COUNT=$(grep -c 'eol=lf' "$P/.gitattributes")
if [ "$COUNT" = "3" ]; then ok ".gitattributes lines not added twice"; else bad ".gitattributes lines not added twice" "$COUNT"; fi

echo "=== Install: existing hooks ==="
new_repo "husky"
put "src/app/a.ts" "export const a = 1;"
git -C "$P" config core.hooksPath .husky
install "$P" --src-root src
expect_code 0 "install with a custom hooksPath succeeds"
expect_has "core.hooksPath was left unchanged because it is .husky" "custom hooksPath reported"
if [ "$(git -C "$P" config core.hooksPath)" = ".husky" ]; then ok "custom hooksPath unchanged"; else bad "custom hooksPath unchanged"; fi
new_repo "old-hook"
put "src/app/a.ts" "export const a = 1;"
HOOK="$(cd "$P" && git rev-parse --git-path hooks/pre-commit)"
mkdir -p "$P/$(dirname "$HOOK")"
printf '#!/bin/sh\nexit 0\n' > "$P/$HOOK"
install "$P" --src-root src
expect_code 0 "install with an existing hook succeeds"
expect_has "hook keeps working" "existing hook reported"
if [ -z "$(git -C "$P" config core.hooksPath)" ]; then ok "hooksPath not set, existing hook kept"; else bad "hooksPath not set, existing hook kept"; fi

echo "=== Install: new project and special values ==="
new_repo "new"
install "$P" --src-root src --scaffold
expect_code 0 "install into an empty project succeeds"
for layer in app shell screens business jobs shared platform; do
  expect_file "src/$layer/.gitkeep" "layer created: $layer"
done
expect_has "@YOUR_USERNAME" "reminder when no owner is given"
run
expect_code 0 "check passes on an empty project"
git -C "$P" add -A
if git -C "$P" commit -q -m kit > "$WORK/c3.log" 2>&1; then ok "new project commit passes"; else bad "new project commit passes" "$(cat "$WORK/c3.log")"; fi
new_repo "backslash"
put "src/app/a.ts" "export const a = 1;"
install "$P" --src-root 'src\'
expect_code 0 "source root with a backslash accepted"
expect_grep "ARCH_SRC_ROOT:-src}" tools/check-architecture.sh "backslash fixed"
new_repo "special-chars"
put "src/app/a.ts" "export const a = 1;"
install "$P" --src-root src --import-prefix 'a&b|c'
expect_code 0 "install with a special-character prefix succeeds"
expect_grep 'ARCH_IMPORT_PREFIX:-a&b|c}' tools/check-architecture.sh "special characters intact"

echo "=== Install: line endings ==="
new_repo "crlf"
git -C "$P" config core.autocrlf true
put "src/business/a.ts" "import s from '../shared/z';"
install "$P" --src-root src
expect_code 0 "install succeeds with autocrlf on"
git -C "$P" add -A > /dev/null 2>&1
git -C "$P" commit -q -m kit > /dev/null 2>&1
git -c core.autocrlf=true clone -q "$P" "$WORK/crlf-copy" 2> /dev/null
P="$WORK/crlf-copy"
run
expect_code 0 "project cloned with autocrlf works"
if [ "$(tr -cd '\r' < "$P/tools/check-architecture.sh" | wc -c | tr -d ' ')" = "0" ]; then ok "script stays LF in the clone"; else bad "script stays LF in the clone"; fi
if [ "$(tr -cd '\r' < "$P/.githooks/pre-commit" | wc -c | tr -d ' ')" = "0" ]; then ok "hook stays LF in the clone"; else bad "hook stays LF in the clone"; fi

echo "=== settings.json ==="
if command -v jq > /dev/null 2>&1; then
  CMD=$(jq -e -r '.hooks.PostToolUse[] | select(.matcher == "Write|Edit") | .hooks[] | select(.type == "command") | .command' "$TEMPLATE/.claude/settings.json")
  if [ $? -eq 0 ]; then ok "hook command read: $CMD"; else bad "hook command read"; fi
elif command -v node > /dev/null 2>&1; then
  if (cd "$TEMPLATE" && node -e "const s=JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));if(!s.hooks.PostToolUse[0].hooks[0].command)process.exit(1)"); then ok "JSON valid"; else bad "JSON valid"; fi
else
  echo "skipped - jq or node missing"
fi

echo "=== Plugin ==="
REPO=$(cd "$KIT/.." && pwd)
SKILL="$KIT/skills/install/SKILL.md"
if [ -f "$SKILL" ]; then ok "install command exists"; else bad "install command exists"; fi
if grep -q '^disable-model-invocation: true' "$SKILL"; then ok "install starts only when the user asks"; else bad "install starts only when the user asks"; fi
if grep -q 'CLAUDE_PLUGIN_ROOT}/install.sh' "$SKILL"; then ok "command points to the install script"; else bad "command points to the install script"; fi
PLUGIN_CHECK='const fs=require("fs");
const m=JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json","utf8"));
const e=m.plugins.find(p=>p.name==="project-architecture");
if(!e)throw new Error("marketplace entry missing");
const p=JSON.parse(fs.readFileSync(e.source+"/.claude-plugin/plugin.json","utf8"));
if(p.name!==e.name)throw new Error("name mismatch");
if(!/^\d+\.\d+\.\d+$/.test(p.version))throw new Error("invalid version");'
if command -v node > /dev/null 2>&1; then
  if ERR=$(cd "$REPO" && node -e "$PLUGIN_CHECK" 2>&1); then ok "marketplace and plugin definitions consistent"; else bad "marketplace and plugin definitions consistent" "$ERR"; fi
else
  echo "skipped - node missing"
fi
cp -r "$KIT" "$WORK/plugin copy"
new_repo "plugin-target"
install_from_copy() { OUT=$(sh "$WORK/plugin copy/install.sh" "$@" 2>&1); CODE=$?; }
install_from_copy "$P" --src-root src --scaffold
expect_code 0 "kit installs when copied to another folder"
expect_file ".githooks/pre-commit" "hook installed from the copy"
expect_file ".github/workflows/architecture.yml" "workflow installed from the copy"
expect_file ".claude/settings.json" "Claude settings installed from the copy"
expect_none "skills" "plugin command not copied into the project"
expect_none ".claude-plugin" "plugin definition not copied into the project"

echo "=== Performance ==="
export ARCH_SRC_ROOT="src" ARCH_IMPORT_PREFIX=""
new_project "big"
mkdir -p "$P/src/business/orders" "$P/src/screens/orders"
awk -v dir="$P/src" 'BEGIN {
  for (i = 0; i < 2000; i++) {
    layer = (i % 2) ? "business/orders" : "screens/orders"
    file = dir "/" layer "/File" i ".ts"
    for (j = 0; j < 40; j++) print "import a" j " from \"./File" j "\";" > file
    close(file)
  }
}'
START=$(date +%s)
run
END=$(date +%s)
expect_code 0 "project with 2000 files passes clean"
echo "     time: about $((END - START)) s"
unset ARCH_SRC_ROOT ARCH_IMPORT_PREFIX

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
