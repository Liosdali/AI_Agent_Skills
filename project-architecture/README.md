# Proje Mimarisi Kiti

Bu kit bir projeye ortak bir mimari kurar ve hem takımın hem AI ajanlarının bu yapının dışına çıkmasını engeller.

İki amacı var:

- **Bulunabilirlik:** Projeye yeni gelen biri, ekranda gördüğü bir satırın kodunu klasörleri izleyerek bulabilir.
- **İzlenebilirlik:** Bağımlılıklar tepeden aşağı tek yönde okunur.

Yapının tamamı [template/docs/ARCHITECTURE.md](template/docs/ARCHITECTURE.md) dosyasındadır.

## Nasıl korur

| Koruma | Dosya | Etkisi |
|---|---|---|
| Kural | `docs/ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md` | Takım ve AI yapıyı buradan öğrenir. Uyulması garanti değildir. |
| Anlık uyarı | `.claude/settings.json` | Claude Code her düzenlemeden sonra kontrolü çalıştırır ve ihlali ajana bildirir. Dosyayı geri almaz. Mimari dosyalarını düzenlemeyi de yasaklar. |
| Commit engeli | `.githooks/pre-commit` | Hangi araç kullanılırsa kullanılsın yeni ihlal commit'lenemez. `--no-verify` ile atlanabilir. |
| Birleştirme engeli | `.github/workflows/architecture.yml`, `.github/CODEOWNERS` | Kanca atlansa bile ihlalli PR birleştirilemez. Mimari dosyalarındaki değişiklikler kod sahibinin onayını ister. |

Kontrol kuralları `tools/check-architecture.sh` içindedir. Mevcut projelerde eski ihlaller kaydedilir, yalnızca yeni ihlaller engellenir. Eski klasörlerdeki dosyalar düzenlenebilir, ama oraya yeni dosya eklenemez.

## Gereksinimler

- **Git:** Windows'ta [Git for Windows](https://git-scm.com/download/win), Git Bash ile birlikte gelir.
- **Git deposu:** Kitin kurulacağı proje bir Git deposu olmalıdır.
- **GitHub:** Yalnızca birleştirme engeli için gerekir. Ana dal kuralı GitHub Free'de özel depolarda bulunmaz.
- **Dil:** Import kontrolleri Java, Kotlin, Dart, JavaScript, TypeScript ve Python için çalışır.

## Kurulum yolu seç

İki yol da projeye aynı dosyaları kurar.

| Yol | Kim için |
|---|---|
| [Claude Code plugin](#claude-code-plugin-ile-kurulum) | Claude Code kullananlar |
| [Kurulum betiği](#kurulum-betiği-ile-kurulum) | Diğer araçları kullananlar ve kurulumu elle yapmak isteyenler |

Plugin, kitin yerini almaz. Yalnızca onu kuran kişinin Claude Code'unda çalışır. Takımı ve diğer AI araçlarını bağlayan dosyalar yine projeye commit'lenir.

## Claude Code plugin ile kurulum

Claude Code 2.1.275 veya sonrası gerekir. Plugin'i kur:

```text
/plugin install project-architecture --marketplace Liosdali/AI_Agent_Skills
```

Daha eski sürümlerde:

```text
/plugin marketplace add Liosdali/AI_Agent_Skills
/plugin install project-architecture@ai-agent-skills
```

Claude Code'u kitin kurulacağı projede aç ve kurulumu başlat:

```text
/project-architecture:install
```

Claude projeye bakarak ayarları belirler, seçtiği komutu gösterir ve onayını ister. Commit oluşturmaz ve push yapmaz. Kurulum bitince aşağıdaki [4. adımdan](#4-var-olan-dosyaları-kontrol-et) devam et.

## Kurulum betiği ile kurulum

### 1. Kiti indir

```sh
git clone https://github.com/Liosdali/AI_Agent_Skills.git
cd AI_Agent_Skills/project-architecture
```

### 2. Ayarları belirle

`--src-root`, katman klasörlerinin (`app`, `screens`, `business` ...) bulunduğu veya bulunacağı klasördür. `--import-prefix`, bu klasörün import'larda görünen adıdır.

| Proje | `--src-root` | `--import-prefix` |
|---|---|---|
| Java | `src/main/java/com/acme/app` | `com.acme.app` (zorunlu) |
| Kotlin | `src/main/kotlin/com/acme/app` | `com.acme.app` (zorunlu) |
| Flutter | `lib` | `package:uygulama_adi` |
| TypeScript, JavaScript | `src` | Alias varsa `@`, yoksa boş |
| Python | `src/uygulama_adi` | `uygulama_adi` |

Önek boş bırakılırsa yalnızca göreli import'lar denetlenir. Java ve Kotlin'de import'ların tamamı tam ad kullandığı için önek zorunludur.

### 3. Kur

Mevcut bir proje:

```sh
sh install.sh /proje/yolu --src-root src/main/java/com/acme/app --import-prefix com.acme.app --owner @kullanici
```

Yeni ve boş bir proje:

```sh
git init /proje/yolu
sh install.sh /proje/yolu --src-root src --scaffold --owner @kullanici
```

Windows PowerShell `sh` komutunu tanımıyorsa Git Bash aç veya Git'in kabuğunu doğrudan çağır:

```powershell
& "$env:ProgramFiles\Git\bin\sh.exe" install.sh "C:\proje\yolu" --src-root src --owner "@kullanici"
```

Tüm seçenekler `sh install.sh --help` ile görülür.

Betik şunları yapar:

- `template/` içindeki dosyaları proje köküne kopyalar.
- Ayarları `tools/check-architecture.sh`, `AGENTS.md` ve `.github/CODEOWNERS` dosyalarına yazar.
- Eski ihlalleri `tools/architecture-baseline.txt` dosyasına kaydeder.
- `core.hooksPath` değerini `.githooks` yapar.
- `.githooks/pre-commit` dosyasını çalıştırılabilir olarak Git'e ekler.

Commit oluşturmaz, push yapmaz ve kodu taşımaz.

### 4. Var olan dosyaları kontrol et

Betik hiçbir dosyanın üzerine yazmaz. Sonuç ekranındaki "Kalan adımlar" bölümü elle yapılacakları listeler.

| Var olan dosya | Betiğin yaptığı | Senin yapacağın |
|---|---|---|
| `CLAUDE.md` | `@AGENTS.md` satırını ekler | Bir şey gerekmez |
| `.gitattributes` | Eksik satırları ekler | Bir şey gerekmez |
| `AGENTS.md` | Dokunmaz | `template/AGENTS.md` içindeki kuralları ekle |
| `.claude/settings.json` | Dokunmaz | `template/.claude/settings.json` içindeki `hooks` ve `permissions` bölümlerini ekle |
| `core.hooksPath` veya `pre-commit` kancası | Dokunmaz | Var olan kancaya `sh tools/check-architecture.sh` satırını ekle |
| Diğerleri | Dokunmaz | İçeriği kendin birleştir |

### 5. Kalan adımları tamamla

1. **Komutları yaz:** `AGENTS.md` içindeki derleme ve test komutlarını doldur.
2. **Commit'le:** Eklenen dosyaları gözden geçir, commit'le ve push et.
3. **GitHub'da zorunlu kıl:** Workflow bir kez çalıştıktan sonra depo ayarlarında ana dal için bir kural oluştur. `architecture` kontrolünü ve kod sahibi onayını zorunlu yap.

Son adım atlanırsa kancalar yine çalışır, ama `--no-verify` ile atlanabilir.

### 6. Doğrula

`business/` altındaki bir dosyaya `screens/` import'u ekle ve kontrolü çalıştır:

```sh
sh tools/check-architecture.sh
```

Çıktıda `[BAGIMLILIK]` görmelisin. Claude Code kullanıyorsan aynı değişikliği ona yaptır ve kontrol mesajını aldığını doğrula. Proje ayarlarının uygulanması için klasöre güven onayı gerekir, kancaları `/hooks` ile görebilirsin. Sonra değişikliği geri al.

## Takım arkadaşları

Kitin kurulu olduğu bir projeyi klonlayan herkes kendi kopyasında bir kez çalıştırır:

```sh
git config core.hooksPath .githooks
```

## Diğer AI ajanlarına kurdurma

Claude Code dışındaki bir ajanı proje klasöründe başlat ve şunu yapıştır:

```text
https://github.com/Liosdali/AI_Agent_Skills deposunu geçici bir klasöre klonla ve
project-architecture/README.md dosyasını oku. Bu proje için --src-root ve
--import-prefix değerlerini belirle, seçtiğin değerleri bana göster ve onayımı al.
Sonra install.sh ile kiti kur. "Kalan adımlar" listesini uygula, ama commit ve push
yapmadan önce bana sor. Var olan kodu taşıma ve değiştirme.
```

`AGENTS.md` okumayan bir araç kullanılıyorsa o aracın talimat dosyasına `AGENTS.md` dosyasını okumasını söyleyen bir satır ekle.

## Sorun giderme

| Belirti | Neden ve çözüm |
|---|---|
| `sh` tanınmıyor | PowerShell'desin. Git Bash aç veya yukarıdaki PowerShell komutunu kullan. |
| `... bir Git deposu değil` | Proje klasöründe `git init` çalıştır. |
| `Kaynak kökü bulunamadı` | `--src-root` değerini kontrol et. Yeni projede `--scaffold` ekle. |
| `--import-prefix zorunludur` | Java veya Kotlin için paket adını ver. |
| Kontrol ihlal bulmuyor | `--import-prefix` import'larla eşleşmiyor olabilir. Değeri `tools/check-architecture.sh` içinde düzelt. |
| Commit engelleniyor | Çıktıdaki ihlali düzelt. Üretilmiş bir klasörse `EXTRA_DIRS` değerine ekle. |
| Kural gerçekten değişti | Kod sahibi `sh tools/check-architecture.sh --update-baseline` çalıştırır ve sonucu PR ile önerir. |
| Claude Code korunan dosyayı düzenleyemiyor | Bu beklenen davranıştır. Değişikliği elle yap veya `.claude/settings.json` içindeki ilgili `deny` satırını geçici olarak kaldır. |

## Otomatik kontrolün sınırları

- **Denetlenenler:** Klasör yerleşimi, bağımlılık yönü, satırların `Store` veya `Service` kullanımı, kabuğa statik erişim ve `Manager`, `Helper`, `Utils` dosya adları.
- **Denetlenemeyenler:** İsimlerin ekranla eşleşmesi, ekrana yazılmış iş kuralları, gereksiz soyutlamalar ve arayüzün tasarım dosyasına uyumu. Bunlar için `docs/ARCHITECTURE.md` Bölüm 17'deki PR listesi kullanılır.

## Kiti güncelleme

Betik var olan dosyalara dokunmadığı için yeniden çalıştırmak projeyi güncellemez. Yeni sürümü almak için `git pull` çalıştır veya plugin'i güncelle. Sonra değişen `template/` dosyalarını projeye elle kopyala. `tools/check-architecture.sh` içindeki ayar değerlerini ve `tools/architecture-baseline.txt` dosyasını koru.

Plugin'i güncellemek için:

```text
/plugin marketplace update ai-agent-skills
/plugin update project-architecture@ai-agent-skills
```

## Kit üzerinde çalışma

```text
project-architecture/
├─ .claude-plugin/  # Plugin tanımı
├─ README.md        # Bu rehber
├─ install.sh       # Kurulum betiği
├─ skills/          # Plugin'in kurulum komutu
├─ template/        # Projeye kopyalanan dosyalar
└─ tests/           # Kit testleri
```

Testler Ubuntu, macOS ve Windows üzerinde CI'da çalışır. Yerelde çalıştırmak için:

```sh
bash tests/test-kit.sh
claude plugin validate .
```

Kit her değiştiğinde `.claude-plugin/plugin.json` içindeki `version` değerini artır. Artırılmazsa kullanıcılara güncelleme gitmeyebilir.
