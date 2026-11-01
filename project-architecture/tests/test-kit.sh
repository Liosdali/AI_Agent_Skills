#!/bin/bash
# Kiti geçici projelerde sınar. Kit dosyalarını değiştirmez.
# Kullanım: bash tests/test-kit.sh

KIT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
TEMPLATE="$KIT/template"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT

# Testler makinenin Git ayarlarından etkilenmesin.
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
expect_code() { if [ "$CODE" = "$1" ]; then ok "$2"; else bad "$2 (çıkış $CODE, beklenen $1)" "$OUT"; fi; }
expect_has()  { case "$OUT" in *"$1"*) ok "$2" ;; *) bad "$2" "$OUT" ;; esac; }
expect_not()  { case "$OUT" in *"$1"*) bad "$2" "$OUT" ;; *) ok "$2" ;; esac; }
expect_file() { if [ -e "$P/$1" ]; then ok "$2"; else bad "$2 ($1 yok)"; fi; }
expect_none() { if [ -e "$P/$1" ]; then bad "$2 ($1 var)"; else ok "$2"; fi; }
expect_grep() { if grep -qF -- "$1" "$P/$2"; then ok "$3"; else bad "$3" "$(cat "$P/$2")"; fi; }
expect_nogrep() { if grep -qF -- "$1" "$P/$2"; then bad "$3" "$(cat "$P/$2")"; else ok "$3"; fi; }

echo "=== Java ==="
export ARCH_SRC_ROOT="src/main/java/com/acme/app" ARCH_IMPORT_PREFIX="com.acme.app"
new_project "java proje"
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
expect_code 1 "ihlal varken çıkış 1"
expect_has "Mimari kontrol: 10 yeni ihlal" "tam olarak 10 ihlal"
expect_has "[KLASOR] $R/legacy/Foo.java" "eski klasördeki dosya kaydedildi"
expect_has "[BAGIMLILIK] $R/business/orders/OrderTotal.java" "business -> screens yakalandı"
expect_has "import static com.acme.app.shell.AppFrame.foo;" "static import yakalandı"
expect_has "import com.acme.app.platform.database.Db;" "screens -> platform/database yakalandı"
expect_has "[BOLUM_VERI] $R/screens/orders/detail/sections/summary/TotalAmountRow.java" "satır -> Store yakalandı"
expect_has "[STATIK_KABUK] $R/screens/x/Y.java" "statik kabuk erişimi yakalandı"
expect_has "[DOSYA_ADI] $R/shared/format/MoneyUtils.java" "Utils dosya adı yakalandı"
expect_has "[KLASOR] $R/legacy" "tanımsız klasör yakalandı"
expect_has "order detail/Z.java" "boşluklu yol okundu"
expect_not "javafx.application.Platform" "üçüncü taraf Platform sınıfı işaretlenmedi"
expect_not "org.x.platform.Y" "üçüncü taraf platform paketi işaretlenmedi"
expect_not "platform.logging.Log" "izinli logging işaretlenmedi"
expect_not "platform.config.Settings" "izinli config işaretlenmedi"
expect_not "business.orders.Order;" "satırda model kullanımı işaretlenmedi"

echo "=== Baseline akışı ==="
run --update-baseline
expect_has "Baseline güncellendi: 10 kayıt" "baseline yazıldı"
run
expect_code 0 "eski ihlaller engellemiyor"
expect_has "Baseline: 10 kayıt" "baseline sayısı raporlandı"
printf '%s\n' '// duzeltme' >> "$P/$R/legacy/Foo.java"
run
expect_code 0 "eski klasördeki mevcut dosya düzenlenebiliyor"
put "$R/legacy/NewFile.java" 'class NewFile {}'
run
expect_code 1 "eski klasöre yeni dosya engelleniyor"
expect_has "[KLASOR] $R/legacy/NewFile.java" "yeni dosya raporlandı"
rm "$P/$R/legacy/NewFile.java"
run
expect_code 0 "yeni dosya silinince geçiyor"
run --hook
expect_code 0 "kanca modunda geçiyor"
if [ -z "$OUT" ]; then ok "kanca modu başarıda sessiz"; else bad "kanca modu başarıda sessiz" "$OUT"; fi

F="$P/$R/business/orders/OrderTotal.java"
{ echo '// eklenen satir'; cat "$F"; } > "$F.tmp" && mv "$F.tmp" "$F"
run
expect_code 0 "satır kayması yeni ihlal sayılmıyor"

printf '%s\n' 'import com.acme.app.screens.orders.Other;' >> "$F"
run
expect_code 1 "eski dosyadaki yeni ihlal engelleniyor"
expect_has "Mimari kontrol: 1 yeni ihlal" "yalnızca yeni ihlal raporlandı"
run --hook
expect_code 2 "kanca modunda çıkış 2"
expect_has "docs/ARCHITECTURE.md" "kanca mesajı yapıyı gösteriyor"
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"x"}}'
OUT=$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$P" sh "$P/tools/check-architecture.sh" --hook 2>&1); CODE=$?
expect_code 2 "kanca komutu stdin JSON ile çalışıyor"
edit_file '$d' "$F"
run
expect_code 0 "yeni ihlal silinince geçiyor"

rm "$P/$R/shared/format/MoneyUtils.java"
run
expect_code 0 "giderilen ihlal engellemiyor"
expect_has "1 eski ihlal giderilmiş" "giderilen ihlal raporlandı"

to_crlf "$P/tools/architecture-baseline.txt"
to_crlf "$F"
run
expect_code 0 "CRLF baseline ve kaynak dosya sorun çıkarmıyor"

echo "=== Hatalı ayar ==="
run --bilinmeyen
expect_code 1 "bilinmeyen seçenek hata veriyor"
ARCH_IMPORT_PREFIX="" run
expect_code 1 "Java'da önek boşsa hata veriyor"
expect_has "IMPORT_PREFIX zorunludur" "önek hatası açıklanıyor"
ARCH_SRC_ROOT="yok" run
expect_code 1 "kaynak kökü yoksa hata veriyor"
cp "$P/tools/check-architecture.awk" "$WORK/awk.bak"
printf '%s\n' 'BEGIN { bu gecersiz awk' > "$P/tools/check-architecture.awk"
run
expect_code 1 "bozuk awk sessizce geçmiyor"
expect_has "çalıştırılamadı" "bozuk awk bildiriliyor"
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
expect_has "Mimari kontrol: 7 yeni ihlal" "TS: tam olarak 7 ihlal"
expect_has "} from '../shell/z';" "TS: çok satırlı import yakalandı"
expect_has "export * from '../jobs/q';" "TS: export from yakalandı"
expect_has "require('../app/w')" "TS: require yakalandı"
expect_has "@/screens/p" "TS: alias yakalandı"
expect_has "[BOLUM_VERI] src/screens/orders/detail/sections/s/R.tsx" "TS: satır -> store yakalandı"
expect_not "@types/node" "TS: @types işaretlenmedi"
expect_not "not-import" "TS: import olmayan metin işaretlenmedi"
expect_not "'react'" "TS: paket işaretlenmedi"
ARCH_IMPORT_PREFIX="" run
expect_has "yalnızca göreli" "TS: önek boşken uyarı veriliyor"
expect_has "Mimari kontrol: 6 yeni ihlal" "TS: önek boşken göreli import denetleniyor"

echo "=== BOM ==="
new_project "bom"
mkdir -p "$P/src/business"
printf '\357\273\277import t from '"'"'../screens/y'"'"';\r\n' > "$P/src/business/a.ts"
run
expect_code 1 "BOM ve CRLF ile başlayan dosyada ihlal yakalanıyor"
expect_has "Mimari kontrol: 1 yeni ihlal" "BOM: tam olarak 1 ihlal"
run --update-baseline
run
expect_code 0 "BOM dosyası baseline ile eşleşiyor"

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
expect_has "Mimari kontrol: 5 yeni ihlal" "Dart: tam olarak 5 ihlal"
expect_has "package:myapp/screens/x.dart" "Dart: package import yakalandı"
expect_has "../shell/x.dart" "Dart: göreli import yakalandı"
expect_has "order_store.dart" "Dart: satır -> store yakalandı"
expect_has "[KLASOR] lib/l10n" "Dart: tanımsız klasör yakalandı"
expect_not "package:flutter" "Dart: flutter işaretlenmedi"
expect_not "local_part" "Dart: aynı klasör işaretlenmedi"
ARCH_EXTRA_DIRS="l10n generated" run
expect_has "Mimari kontrol: 3 yeni ihlal" "Dart: EXTRA_DIRS klasörü muaf tutuyor"
expect_not "[KLASOR]" "Dart: EXTRA_DIRS ile KLASOR ihlali yok"

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
expect_has "Mimari kontrol: 3 yeni ihlal" "Python: tam olarak 3 ihlal"
expect_has "from ...screens.w import W" "Python: göreli import yakalandı"
expect_has "import myapp.shell.z as q" "Python: import as yakalandı"
expect_not "..session" "Python: aynı katman işaretlenmedi"
unset ARCH_SRC_ROOT ARCH_IMPORT_PREFIX

echo "=== Kurulum: hatalı kullanım ==="
install
expect_code 1 "argümansız kurulum hata veriyor"
expect_has "Kullanım:" "kullanım gösteriliyor"
install --help
expect_code 0 "yardım çalışıyor"
mkdir -p "$WORK/git-degil"
install "$WORK/git-degil" --src-root src
expect_code 1 "Git deposu olmayan hedef reddediliyor"
expect_has "git init" "git init öneriliyor"
install "$WORK/yok" --src-root src
expect_code 1 "olmayan hedef reddediliyor"
new_repo "kok-yok"
install "$P" --src-root src
expect_code 1 "kaynak kökü yoksa reddediliyor"
expect_has "--scaffold" "scaffold öneriliyor"
expect_none "AGENTS.md" "hata durumunda dosya kopyalanmıyor"
install "$P" --src-root /src
expect_code 1 "mutlak kaynak kökü reddediliyor"
install "$P" --src-root ../src
expect_code 1 "proje dışı kaynak kökü reddediliyor"
install "$P" --bilinmeyen
expect_code 1 "bilinmeyen kurulum seçeneği reddediliyor"
install "$P" fazla --src-root src
expect_code 1 "iki proje yolu reddediliyor"
new_repo "java-oneksiz"
put "src/app/Main.java" "class Main {}"
install "$P" --src-root src
expect_code 1 "Java'da önek yoksa kurulum reddediliyor"
expect_none "AGENTS.md" "önek hatasında dosya kopyalanmıyor"

echo "=== Kurulum: mevcut Java projesi ==="
new_repo "java kurulum"
R="src/main/java/com/acme/app"
put "$R/business/orders/OrderTotal.java" 'import com.acme.app.screens.orders.OrderScreen;'
put "$R/legacy/Foo.java" 'class Foo {}'
git -C "$P" add -A
git -C "$P" commit -q -m ilk
install "$P" --src-root "$R" --import-prefix com.acme.app --extra-dirs "gen l10n" --owner acme/mimari
expect_code 0 "kurulum başarılı"
expect_has "Kalan adımlar:" "kalan adımlar yazdırıldı"
expect_has "AGENTS.md içindeki derleme" "derleme adımı hatırlatıldı"
expect_not "@KULLANICI_ADI" "owner verilince hatırlatma yok"
for file in AGENTS.md CLAUDE.md .gitattributes docs/ARCHITECTURE.md .claude/settings.json .githooks/pre-commit \
  .github/CODEOWNERS .github/workflows/architecture.yml tools/check-architecture.sh tools/check-architecture.awk \
  tools/architecture-baseline.txt; do
  expect_file "$file" "kuruldu: $file"
done
expect_none "README.md" "kit README dosyası projeye kopyalanmadı"
expect_none "install.sh" "kurulum betiği projeye kopyalanmadı"
expect_grep "ARCH_SRC_ROOT:-$R}" tools/check-architecture.sh "kaynak kökü ayarlandı"
expect_grep "ARCH_IMPORT_PREFIX:-com.acme.app}" tools/check-architecture.sh "önek ayarlandı"
expect_grep "ARCH_EXTRA_DIRS:-gen l10n}" tools/check-architecture.sh "ek klasörler ayarlandı"
expect_grep "Kaynak kökü: \`$R/\`" AGENTS.md "AGENTS.md kaynak kökü ayarlandı"
expect_grep "@acme/mimari" .github/CODEOWNERS "CODEOWNERS kullanıcısı ayarlandı"
expect_nogrep "@KULLANICI_ADI" .github/CODEOWNERS "CODEOWNERS yer tutucusu kalmadı"
expect_grep "KLASOR|$R/legacy/Foo.java|" tools/architecture-baseline.txt "eski dosya baseline'a yazıldı"
expect_grep "BAGIMLILIK|$R/business/orders/OrderTotal.java|" tools/architecture-baseline.txt "eski ihlal baseline'a yazıldı"
if [ "$(git -C "$P" config core.hooksPath)" = ".githooks" ]; then ok "core.hooksPath ayarlandı"; else bad "core.hooksPath ayarlandı"; fi
run
expect_code 0 "kurulum sonrası kontrol ayar gerektirmeden geçiyor"
if git -C "$P" ls-files -s .githooks/pre-commit | grep -q '^100755'; then ok "pre-commit çalıştırılabilir kaydedildi"; else bad "pre-commit çalıştırılabilir kaydedildi" "$(git -C "$P" ls-files -s .githooks/pre-commit)"; fi
git -C "$P" add -A
if git -C "$P" commit -q -m kit > "$WORK/c1.log" 2>&1; then ok "kurulum commit'i geçti"; else bad "kurulum commit'i geçti" "$(cat "$WORK/c1.log")"; fi
put "$R/business/orders/New.java" 'import com.acme.app.shell.Bar;'
git -C "$P" add -A
if git -C "$P" commit -q -m ihlal > "$WORK/c2.log" 2>&1; then bad "ihlalli commit engellendi" "commit geçti"; else ok "ihlalli commit engellendi"; fi
if grep -q 'BAGIMLILIK' "$WORK/c2.log"; then ok "commit hatası ihlali gösteriyor"; else bad "commit hatası ihlali gösteriyor" "$(cat "$WORK/c2.log")"; fi
git -C "$P" reset -q HEAD -- "$R/business/orders/New.java"

echo "=== Kurulum: yeniden çalıştırma ==="
cp "$P/tools/architecture-baseline.txt" "$WORK/baseline.bak"
install "$P" --src-root "$R" --import-prefix com.acme.app
expect_code 1 "yeniden kurulum yeni ihlali gizlemiyor"
expect_has "[BAGIMLILIK] $R/business/orders/New.java" "yeni ihlal raporlandı"
expect_has "Var olan baseline korundu" "baseline korunduğu bildirildi"
if cmp -s "$P/tools/architecture-baseline.txt" "$WORK/baseline.bak"; then ok "baseline değişmedi"; else bad "baseline değişmedi"; fi
rm "$P/$R/business/orders/New.java"

echo "=== Kurulum: var olan dosyalar ==="
new_repo "mevcut"
put "src/app/a.ts" "export const a = 1;"
put "AGENTS.md" "# Benim kurallarım"
put "CLAUDE.md" "# Benim talimatlarım"
put ".gitattributes" "*.png binary"
put ".claude/settings.json" '{ "model": "opus" }'
put ".github/CODEOWNERS" "* @baskasi"
put "docs/ARCHITECTURE.md" "# Benim mimarim"
install "$P" --src-root src
expect_code 0 "var olan dosyalarla kurulum başarılı"
expect_grep "# Benim kurallarım" AGENTS.md "AGENTS.md korundu"
expect_nogrep "Kesin kurallar" AGENTS.md "AGENTS.md üzerine yazılmadı"
expect_grep "# Benim mimarim" docs/ARCHITECTURE.md "ARCHITECTURE.md korundu"
expect_grep "* @baskasi" .github/CODEOWNERS "CODEOWNERS korundu"
expect_grep '"model": "opus"' .claude/settings.json "settings.json korundu"
expect_nogrep "check-architecture" .claude/settings.json "settings.json üzerine yazılmadı"
expect_has "Var olan .claude/settings.json" "settings.json birleştirme adımı istendi"
expect_has "Var olan AGENTS.md" "AGENTS.md birleştirme adımı istendi"
expect_grep "# Benim talimatlarım" CLAUDE.md "CLAUDE.md içeriği korundu"
expect_grep "@AGENTS.md" CLAUDE.md "CLAUDE.md yönlendirmesi eklendi"
expect_grep "*.png binary" .gitattributes ".gitattributes içeriği korundu"
expect_grep "*.sh text eol=lf" .gitattributes ".gitattributes satırları eklendi"
install "$P" --src-root src
expect_code 0 "ikinci kurulum başarılı"
COUNT=$(grep -c '@AGENTS.md' "$P/CLAUDE.md")
if [ "$COUNT" = "1" ]; then ok "CLAUDE.md yönlendirmesi tekrar eklenmedi"; else bad "CLAUDE.md yönlendirmesi tekrar eklenmedi" "$COUNT"; fi
COUNT=$(grep -c 'eol=lf' "$P/.gitattributes")
if [ "$COUNT" = "3" ]; then ok ".gitattributes satırları tekrar eklenmedi"; else bad ".gitattributes satırları tekrar eklenmedi" "$COUNT"; fi

echo "=== Kurulum: var olan kancalar ==="
new_repo "husky"
put "src/app/a.ts" "export const a = 1;"
git -C "$P" config core.hooksPath .husky
install "$P" --src-root src
expect_code 0 "özel hooksPath ile kurulum başarılı"
expect_has "core.hooksPath değeri .husky" "özel hooksPath bildirildi"
if [ "$(git -C "$P" config core.hooksPath)" = ".husky" ]; then ok "özel hooksPath değişmedi"; else bad "özel hooksPath değişmedi"; fi
new_repo "eski-kanca"
put "src/app/a.ts" "export const a = 1;"
HOOK="$(cd "$P" && git rev-parse --git-path hooks/pre-commit)"
mkdir -p "$P/$(dirname "$HOOK")"
printf '#!/bin/sh\nexit 0\n' > "$P/$HOOK"
install "$P" --src-root src
expect_code 0 "var olan kanca ile kurulum başarılı"
expect_has "kancası bozulmasın" "var olan kanca bildirildi"
if [ -z "$(git -C "$P" config core.hooksPath)" ]; then ok "var olan kanca korunarak hooksPath ayarlanmadı"; else bad "var olan kanca korunarak hooksPath ayarlanmadı"; fi

echo "=== Kurulum: yeni proje ve özel değerler ==="
new_repo "yeni"
install "$P" --src-root src --scaffold
expect_code 0 "boş projeye kurulum başarılı"
for layer in app shell screens business jobs shared platform; do
  expect_file "src/$layer/.gitkeep" "katman oluştu: $layer"
done
expect_has "@KULLANICI_ADI" "owner yoksa hatırlatma var"
run
expect_code 0 "boş proje kontrolü geçiyor"
git -C "$P" add -A
if git -C "$P" commit -q -m kit > "$WORK/c3.log" 2>&1; then ok "yeni proje commit'i geçti"; else bad "yeni proje commit'i geçti" "$(cat "$WORK/c3.log")"; fi
new_repo "ters-bolu"
put "src/app/a.ts" "export const a = 1;"
install "$P" --src-root 'src\'
expect_code 0 "ters bölülü kaynak kökü kabul ediliyor"
expect_grep "ARCH_SRC_ROOT:-src}" tools/check-architecture.sh "ters bölü düzeltildi"
new_repo "ozel-karakter"
put "src/app/a.ts" "export const a = 1;"
install "$P" --src-root src --import-prefix 'a&b|c'
expect_code 0 "özel karakterli önek kurulumu başarılı"
expect_grep 'ARCH_IMPORT_PREFIX:-a&b|c}' tools/check-architecture.sh "özel karakterler bozulmadı"

echo "=== Kurulum: satır sonları ==="
new_repo "crlf"
git -C "$P" config core.autocrlf true
put "src/business/a.ts" "import s from '../shared/z';"
install "$P" --src-root src
expect_code 0 "autocrlf açıkken kurulum başarılı"
git -C "$P" add -A > /dev/null 2>&1
git -C "$P" commit -q -m kit > /dev/null 2>&1
git -c core.autocrlf=true clone -q "$P" "$WORK/crlf-kopya" 2> /dev/null
P="$WORK/crlf-kopya"
run
expect_code 0 "autocrlf ile klonlanan proje çalışıyor"
if [ "$(tr -cd '\r' < "$P/tools/check-architecture.sh" | wc -c | tr -d ' ')" = "0" ]; then ok "betik klonda LF kaldı"; else bad "betik klonda LF kaldı"; fi
if [ "$(tr -cd '\r' < "$P/.githooks/pre-commit" | wc -c | tr -d ' ')" = "0" ]; then ok "kanca klonda LF kaldı"; else bad "kanca klonda LF kaldı"; fi

echo "=== settings.json ==="
if command -v jq > /dev/null 2>&1; then
  CMD=$(jq -e -r '.hooks.PostToolUse[] | select(.matcher == "Write|Edit") | .hooks[] | select(.type == "command") | .command' "$TEMPLATE/.claude/settings.json")
  if [ $? -eq 0 ]; then ok "kanca komutu okundu: $CMD"; else bad "kanca komutu okundu"; fi
elif command -v node > /dev/null 2>&1; then
  if (cd "$TEMPLATE" && node -e "const s=JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));if(!s.hooks.PostToolUse[0].hooks[0].command)process.exit(1)"); then ok "JSON geçerli"; else bad "JSON geçerli"; fi
else
  echo "atlandı - jq veya node yok"
fi

echo "=== Plugin ==="
REPO=$(cd "$KIT/.." && pwd)
SKILL="$KIT/skills/install/SKILL.md"
if [ -f "$SKILL" ]; then ok "kurulum komutu var"; else bad "kurulum komutu var"; fi
if grep -q '^disable-model-invocation: true' "$SKILL"; then ok "kurulum yalnızca kullanıcı isteğiyle başlıyor"; else bad "kurulum yalnızca kullanıcı isteğiyle başlıyor"; fi
if grep -q 'CLAUDE_PLUGIN_ROOT}/install.sh' "$SKILL"; then ok "komut kurulum betiğini gösteriyor"; else bad "komut kurulum betiğini gösteriyor"; fi
PLUGIN_CHECK='const fs=require("fs");
const m=JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json","utf8"));
const e=m.plugins.find(p=>p.name==="project-architecture");
if(!e)throw new Error("marketplace kaydı yok");
const p=JSON.parse(fs.readFileSync(e.source+"/.claude-plugin/plugin.json","utf8"));
if(p.name!==e.name)throw new Error("ad uyuşmuyor");
if(!/^\d+\.\d+\.\d+$/.test(p.version))throw new Error("sürüm geçersiz");'
if command -v node > /dev/null 2>&1; then
  if ERR=$(cd "$REPO" && node -e "$PLUGIN_CHECK" 2>&1); then ok "marketplace ve plugin tanımı tutarlı"; else bad "marketplace ve plugin tanımı tutarlı" "$ERR"; fi
else
  echo "atlandı - node yok"
fi
cp -r "$KIT" "$WORK/plugin kopya"
new_repo "plugin-hedef"
install_from_copy() { OUT=$(sh "$WORK/plugin kopya/install.sh" "$@" 2>&1); CODE=$?; }
install_from_copy "$P" --src-root src --scaffold
expect_code 0 "kit başka klasöre kopyalanınca da kuruluyor"
expect_file ".githooks/pre-commit" "kopyadan kanca kuruldu"
expect_file ".github/workflows/architecture.yml" "kopyadan iş akışı kuruldu"
expect_file ".claude/settings.json" "kopyadan Claude ayarı kuruldu"
expect_none "skills" "plugin komutu projeye kopyalanmadı"
expect_none ".claude-plugin" "plugin tanımı projeye kopyalanmadı"

echo "=== Performans ==="
export ARCH_SRC_ROOT="src" ARCH_IMPORT_PREFIX=""
new_project "buyuk"
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
expect_code 0 "2000 dosyalı proje temiz geçti"
echo "     süre: yaklaşık $((END - START)) sn"
unset ARCH_SRC_ROOT ARCH_IMPORT_PREFIX

echo
echo "SONUÇ: $PASS geçti, $FAIL başarısız"
[ "$FAIL" -eq 0 ]
