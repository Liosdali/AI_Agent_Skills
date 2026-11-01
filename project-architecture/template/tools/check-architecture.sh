#!/bin/sh
# Mimari kuralları denetler. Yalnızca baseline dışındaki yeni ihlaller hata verir.
#
#   sh tools/check-architecture.sh                    Denetler, ihlalde 1 ile çıkar
#   sh tools/check-architecture.sh --hook             AI kancaları için, ihlalde 2 ile çıkar
#   sh tools/check-architecture.sh --update-baseline  Mevcut ihlalleri kaydeder (yalnızca insan)
#
# Desteklenen diller: Java, Kotlin, Dart, JavaScript, TypeScript, Python.

# --- Projeye göre ayarla ---------------------------------------------------
SRC_ROOT="${ARCH_SRC_ROOT:-src}"         # Örnek: lib, src/main/java/com/acme/app
IMPORT_PREFIX="${ARCH_IMPORT_PREFIX:-}"  # Örnek: com.acme.app, package:myapp, @
EXTRA_DIRS="${ARCH_EXTRA_DIRS:-}"        # Dilin veya çatının zorunlu kıldığı klasörler. Örnek: l10n generated
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
  *) echo "Bilinmeyen seçenek: $1" >&2; exit 1 ;;
esac

if [ ! -d "$SRC_ROOT" ]; then
  echo "Kaynak kökü bulunamadı: $SRC_ROOT. SRC_ROOT değerini ayarlayın." >&2
  exit 1
fi

find_sources() {
  find "$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' -o -name '*.dart' \
    -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' \) "$@"
}

if [ -z "$IMPORT_PREFIX" ]; then
  if [ -n "$(find "$SRC_ROOT" -type f \( -name '*.java' -o -name '*.kt' \) | head -n 1)" ]; then
    echo "Java ve Kotlin için IMPORT_PREFIX zorunludur. Örnek: com.acme.app" >&2
    exit 1
  fi
  if [ "$MODE" != "hook" ]; then
    echo "Uyarı: IMPORT_PREFIX boş, yalnızca göreli import'lar denetleniyor." >&2
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
    *) printf 'KLASOR|%s/%s|\n' "$SRC_ROOT" "$name" >> "$RAW" ;;
  esac
done

if ! find_sources -print0 | xargs -0 awk -v root="$SRC_ROOT" -v prefix="$IMPORT_PREFIX" \
  -v allowed="$LAYERS $EXTRA_DIRS" -f tools/check-architecture.awk >> "$RAW"; then
  echo "Mimari kontrol çalıştırılamadı." >&2
  exit 1
fi

sort -u "$RAW" > "$CURRENT"

if [ "$MODE" = "update" ]; then
  cp "$CURRENT" "$BASELINE"
  echo "Baseline güncellendi: $(wc -l < "$CURRENT" | tr -d ' ') kayıt"
  exit 0
fi

if [ -f "$BASELINE" ]; then
  tr -d '\r' < "$BASELINE" | sort -u > "$KNOWN"
else
  : > "$KNOWN"
fi

explain() {
  case "$1" in
    KLASOR) echo "Yeni klasör ve dosya yalnızca şu klasörlerde olabilir: $LAYERS $EXTRA_DIRS" ;;
    BAGIMLILIK) echo "Bağımlılık yönü: app -> shell, screens, jobs -> business -> platform" ;;
    BOLUM_VERI) echo "Bölüm ve satırlar Store veya Service kullanmaz, veriyi XData üzerinden alır." ;;
    STATIK_KABUK) echo "Kabuğa statik erişim yasak. Navigator, Feedback veya ortak veriyi constructor'dan alın." ;;
    DOSYA_ADI) echo "Manager, Helper ve Util adları kullanılmaz. İşi anlatan bir ad seçin." ;;
    *) echo "Bilinmeyen kural." ;;
  esac
}

report_new() {
  comm -13 "$KNOWN" "$CURRENT" | while IFS='|' read -r rule path text; do
    echo "[$rule] $path"
    [ -n "$text" ] && echo "  $text"
    echo "  $(explain "$rule")"
  done
  echo
  echo "Yapı: docs/ARCHITECTURE.md"
  echo "Kodu kurala uyacak şekilde düzeltin. Kontrolü veya baseline'ı değiştirerek geçmeyin."
}

new_count=$(comm -13 "$KNOWN" "$CURRENT" | wc -l | tr -d ' ')
fixed_count=$(comm -23 "$KNOWN" "$CURRENT" | wc -l | tr -d ' ')

if [ "$new_count" -gt 0 ]; then
  if [ "$MODE" = "hook" ]; then
    { echo "Mimari kontrol: $new_count yeni ihlal"; echo; report_new; } >&2
    exit 2
  fi
  echo "Mimari kontrol: $new_count yeni ihlal"
  echo
  report_new
  exit 1
fi

if [ "$MODE" != "hook" ]; then
  echo "Mimari kontrol geçti. Baseline: $(wc -l < "$KNOWN" | tr -d ' ') kayıt."
  if [ "$fixed_count" -gt 0 ]; then
    echo "$fixed_count eski ihlal giderilmiş. Baseline'ı güncellemek için kod sahibine bildirin."
  fi
fi
exit 0
