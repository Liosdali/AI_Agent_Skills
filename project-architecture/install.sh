#!/bin/sh
# Mimari kitini bir Git projesine kurar. Var olan dosyaların üzerine yazmaz.

set -u
PATH="/usr/bin:/bin:$PATH"
LC_ALL=C
export PATH LC_ALL

usage() {
  cat <<'EOF'
Kullanım:
  sh install.sh <proje-yolu> --src-root <yol> [seçenekler]

Zorunlu:
  <proje-yolu>             Kitin kurulacağı Git projesi
  --src-root <yol>         Kaynak kökü, proje köküne göre. Örnek: src, lib, src/main/java/com/acme/app

Seçenekler:
  --import-prefix <önek>   Proje içi import öneki. Örnek: com.acme.app, package:uygulama, @
                           Java ve Kotlin projelerinde zorunludur.
  --extra-dirs "<adlar>"   Dilin veya çatının zorunlu kıldığı üst klasörler. Örnek: "l10n generated"
  --owner <kullanıcı>      CODEOWNERS için GitHub kullanıcısı veya ekibi. Örnek: @kullanici, @kurum/ekip
  --scaffold               Kaynak kökünü ve katman klasörlerini oluşturur (yeni proje için)
  -h, --help               Bu yardımı gösterir
EOF
}

fail() {
  echo "Hata: $1" >&2
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
      [ $# -ge 2 ] || fail "$1 için değer gerekli."
      case "$1" in
        --src-root) SRC_ROOT=$2 ;;
        --import-prefix) IMPORT_PREFIX=$2 ;;
        --extra-dirs) EXTRA_DIRS=$2 ;;
        --owner) OWNER=$2 ;;
      esac
      shift 2
      ;;
    -*) fail "Bilinmeyen seçenek: $1" ;;
    *)
      [ -z "$TARGET" ] || fail "Yalnızca bir proje yolu verilebilir."
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
[ -d "$TEMPLATE" ] || fail "Şablon klasörü bulunamadı: $TEMPLATE"
command -v git > /dev/null 2>&1 || fail "Git bulunamadı."
[ -d "$TARGET" ] || fail "Proje klasörü bulunamadı: $TARGET"
ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2> /dev/null) ||
  fail "$TARGET bir Git deposu değil. Önce proje klasöründe git init çalıştır."

SRC_ROOT=$(printf '%s' "$SRC_ROOT" | tr '\\' '/')
SRC_ROOT=${SRC_ROOT%/}
SRC_ROOT=${SRC_ROOT#./}
case "$SRC_ROOT" in
  ""|/*|*:*|..|../*|*/../*|*/..) fail "--src-root proje köküne göre göreli olmalı: $SRC_ROOT" ;;
esac

case "$OWNER" in
  ""|@*) ;;
  *) OWNER="@$OWNER" ;;
esac

if [ ! -d "$ROOT/$SRC_ROOT" ] && [ "$SCAFFOLD" -eq 0 ]; then
  fail "Kaynak kökü bulunamadı: $ROOT/$SRC_ROOT. Yeni proje için --scaffold ekle."
fi

if [ -z "$IMPORT_PREFIX" ] && [ -d "$ROOT/$SRC_ROOT" ]; then
  if [ -n "$(find "$ROOT/$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' \) | head -n 1)" ]; then
    fail "Java ve Kotlin için --import-prefix zorunludur. Örnek: --import-prefix com.acme.app"
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

# Dosya yoksa kopyalar ve 0 döner, varsa dokunmaz ve 1 döner.
copy_new() {
  if [ -e "$ROOT/$1" ]; then
    KEPT="$KEPT  - $1$NL"
    return 1
  fi
  mkdir -p "$ROOT/$(dirname "$1")" && cp "$TEMPLATE/$1" "$ROOT/$1" || fail "Kopyalanamadı: $1"
  ADDED="$ADDED  - $1$NL"
  return 0
}

escape_sed() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

replace_in_file() {
  temp=$(mktemp) || fail "Geçici dosya oluşturulamadı."
  sed "$2" "$ROOT/$1" > "$temp" && cat "$temp" > "$ROOT/$1" || fail "Güncellenemedi: $1"
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
      mkdir -p "$ROOT/$SRC_ROOT/$layer" || fail "Klasör oluşturulamadı: $SRC_ROOT/$layer"
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
  replace_in_file AGENTS.md "s|Kaynak kökü: \`src/\`|Kaynak kökü: \`$(escape_sed "$SRC_ROOT")/\`|"
fi
if grep -qE '<derleme komutu>|<test komutu>' "$ROOT/AGENTS.md"; then
  add_todo "AGENTS.md içindeki derleme ve test komutlarını yaz."
elif ! grep -q 'tools/check-architecture.sh' "$ROOT/AGENTS.md"; then
  add_todo "Var olan AGENTS.md dosyasına şu dosyadaki kuralları ekle: $TEMPLATE/AGENTS.md"
fi

if copy_new .github/CODEOWNERS && [ -n "$OWNER" ]; then
  replace_in_file .github/CODEOWNERS "/^# @KULLANICI_ADI/d"
  replace_in_file .github/CODEOWNERS "s|@KULLANICI_ADI|$(escape_sed "$OWNER")|g"
fi
if grep -q '@KULLANICI_ADI' "$ROOT/.github/CODEOWNERS"; then
  add_todo ".github/CODEOWNERS içindeki @KULLANICI_ADI değerini kendi kullanıcınla değiştir."
fi

if [ -e "$ROOT/CLAUDE.md" ]; then
  if grep -q '@AGENTS.md' "$ROOT/CLAUDE.md"; then
    KEPT="$KEPT  - CLAUDE.md$NL"
  else
    append_line "$ROOT/CLAUDE.md" '@AGENTS.md'
    UPDATED="$UPDATED  - CLAUDE.md (@AGENTS.md eklendi)$NL"
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
    UPDATED="$UPDATED  - .gitattributes (eksik satırlar eklendi)$NL"
  else
    KEPT="$KEPT  - .gitattributes$NL"
  fi
else
  copy_new .gitattributes
fi

if ! copy_new .claude/settings.json; then
  if ! grep -q 'check-architecture.sh' "$ROOT/.claude/settings.json"; then
    add_todo "Var olan .claude/settings.json dosyasına şu dosyadaki hooks ve permissions bölümlerini ekle: $TEMPLATE/.claude/settings.json"
  fi
fi

if copy_new .githooks/pre-commit; then
  chmod +x "$ROOT/.githooks/pre-commit"
  git -C "$ROOT" add --chmod=+x -- .githooks/pre-commit 2> /dev/null ||
    add_todo ".githooks/pre-commit dosyasını çalıştırılabilir olarak ekle: git add --chmod=+x .githooks/pre-commit"
fi

CURRENT_HOOKS=$(git -C "$ROOT" config --get core.hooksPath 2> /dev/null || true)
OLD_HOOK=$(git -C "$ROOT" rev-parse --git-path hooks/pre-commit 2> /dev/null)
if [ "$CURRENT_HOOKS" = ".githooks" ]; then
  :
elif [ -n "$CURRENT_HOOKS" ]; then
  add_todo "core.hooksPath değeri $CURRENT_HOOKS olduğu için değiştirilmedi. O klasördeki pre-commit kancasına şu satırı ekle: sh tools/check-architecture.sh"
elif (cd "$ROOT" && [ -e "$OLD_HOOK" ]); then
  add_todo "Var olan $OLD_HOOK kancası bozulmasın diye core.hooksPath ayarlanmadı. O kancaya şu satırı ekle: sh tools/check-architecture.sh"
else
  git -C "$ROOT" config core.hooksPath .githooks || fail "core.hooksPath ayarlanamadı."
fi

BASELINE_NOTE="Var olan baseline korundu."
if [ ! -f "$ROOT/tools/architecture-baseline.txt" ]; then
  BASELINE_NOTE=$(sh "$ROOT/tools/check-architecture.sh" --update-baseline 2>&1) ||
    fail "Baseline oluşturulamadı: $BASELINE_NOTE"
  ADDED="$ADDED  - tools/architecture-baseline.txt$NL"
fi

CHECK_OUTPUT=$(sh "$ROOT/tools/check-architecture.sh" 2>&1)
CHECK_CODE=$?

add_todo "Dosyaları gözden geçir, commit'le ve push et."
add_todo "GitHub'da ana dal kuralını aç: architecture kontrolü ve kod sahibi onayı zorunlu olsun."
add_todo "Takım üyeleri kendi kopyalarında bir kez çalıştırsın: git config core.hooksPath .githooks"

echo "Proje: $ROOT"
[ -n "$ADDED" ] && printf '\nEklenen:\n%s' "$ADDED"
[ -n "$UPDATED" ] && printf '\nGüncellenen:\n%s' "$UPDATED"
[ -n "$KEPT" ] && printf '\nVar olduğu için dokunulmayan:\n%s' "$KEPT"
printf '\nBaseline:\n  %s\n' "$BASELINE_NOTE"
printf '\nKontrol:\n%s\n' "$CHECK_OUTPUT"
printf '\nKalan adımlar:\n%s' "$TODO"

if [ "$CHECK_CODE" -ne 0 ]; then
  echo
  echo "Kit kuruldu, ama mimari kontrol geçmedi. Yukarıdaki sonucu incele."
  exit "$CHECK_CODE"
fi
exit 0
