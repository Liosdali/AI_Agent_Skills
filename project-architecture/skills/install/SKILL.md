---
name: install
description: Proje Mimarisi kitini açık olan projeye kurar. Dosya yapısı rehberini, AI ajan kurallarını ve otomatik mimari kontrolü ekler.
argument-hint: "[kaynak kökü, import öneki veya kod sahibi]"
disable-model-invocation: true
---

# Proje Mimarisi kitini kur

Kullanıcının verdiği ek bilgi: $ARGUMENTS

Kit dosyaları şu klasördedir: `${CLAUDE_PLUGIN_ROOT}`

## Adımlar

1. `${CLAUDE_PLUGIN_ROOT}/README.md` dosyasını oku.
2. Çalışma klasörünün Git deposu olduğunu doğrula. Değilse dur ve kullanıcıya `git init` çalıştırmak isteyip istemediğini sor.
3. Projeye bakarak `install.sh` seçeneklerini belirle:
   - `--src-root`: Katman klasörlerinin bulunduğu veya bulunacağı klasör.
   - `--import-prefix`: Bu klasörün import'larda görünen adı. Java ve Kotlin'de zorunludur.
   - `--extra-dirs`: Dilin veya çatının zorunlu kıldığı üst klasörler.
   - `--owner`: GitHub kullanıcısı veya ekibi. Kesin bilmiyorsan kullanıcıya sor, tahmin etme.
   - `--scaffold`: Yalnızca kaynak kökü henüz yoksa.
4. Seçtiğin değerleri ve çalıştıracağın komutu göster. Kullanıcının onayını bekle.
5. Onaydan sonra kiti kur:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/install.sh" "<proje kökü>" --src-root <yol> [seçenekler]
   ```

   Windows PowerShell `sh` komutunu tanımıyorsa `README.md` içindeki PowerShell komutunu kullan.
6. Komutun çıktısındaki "Kalan adımlar" listesini kullanıcıya bildir. Derleme ve test komutları projede açıkça görünüyorsa `AGENTS.md` içine yaz, görünmüyorsa kullanıcıya sor.

## Yapma

- Kullanıcıya sormadan commit oluşturma veya push etme.
- Var olan kodu taşıma veya değiştirme.
- `--update-baseline` komutunu çalıştırma. Kurulum betiği bunu ilk kurulumda kendisi yapar.
- Var olan `AGENTS.md` veya `.claude/settings.json` dosyalarını kullanıcıya sormadan değiştirme.

## Sonuç

Kullanıcıya şunları bildir: kullanılan değerler, eklenen dosyalar, kontrol sonucu ve kalan adımlar.

Plugin tek başına korumaz. Takımı ve diğer AI araçlarını bağlayan dosyaların commit'lenmesi ve GitHub kuralının açılması gerektiğini belirt.
