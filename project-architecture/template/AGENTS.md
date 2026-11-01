# AGENTS.md

Bu dosya projede çalışan tüm AI ajanları için bağlayıcıdır. Kuralların gerekçesi ve örnekleri `docs/ARCHITECTURE.md` içindedir. Kod yazmadan önce o dosyayı oku.

## Bu proje

- Kaynak kökü: `src/`
- Derleme: `<derleme komutu>`
- Test: `<test komutu>`
- Mimari kontrol: `sh tools/check-architecture.sh`
- Windows PowerShell'de mimari kontrol: `& "$env:ProgramFiles\Git\bin\sh.exe" tools/check-architecture.sh`

## Temel kurallar

### 1. Think Before Coding

- Don't assume. If something is unclear, stop and ask.
- Don't hide confusion. Name what's confusing.
- Surface tradeoffs before you make the call.
- Restate the assumption back so we know we agree.

### 2. Simplicity First

- Minimum code that solves the problem.
- No speculative features. No flexibility nobody asked for.
- No abstractions for single-use code.
- No error handling for impossible scenarios.
- Test: would a senior engineer call this overcomplicated? If yes, simplify.

### 3. Surgical Changes

- Touch only what you must to satisfy the request.
- Don't reformat, refactor, or "improve" adjacent code.
- Match the existing style even if you would do it differently.
- If you notice unrelated dead code, mention it. Do not delete it.
- Test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

- Transform tasks into verifiable goals before you write any code.
- "Add validation" becomes "write tests for invalid inputs, then make them pass."
- "Fix the bug" becomes "write a test that reproduces it, then make it pass."
- For multi-step tasks, write the plan first. Attach a check to each step.
- Loop until the goal is verified. Do not declare done until it is.

## Kod yazmadan önce

1. Değişikliğin yerini `docs/ARCHITECTURE.md` Bölüm 1'den belirle.
2. Aynı klasördeki benzer dosyaları oku ve aynı kalıbı kullan.
3. Görevin dosya yapısına uymadığını görürsen dur ve kullanıcıya sor.

## Kesin kurallar

1. **Yerleşim:** Kaynak kökünde yalnızca `app`, `shell`, `screens`, `business`, `jobs`, `shared` ve `platform` bulunur. Yeni üst seviye klasör açma.
2. **Bağımlılık yönü:** `app → shell, screens, jobs → business → platform`. `shell` ile `screens` birbirini import etmez. Bu iki katman ve `jobs`, `platform` içinden yalnızca `logging` ve `config` kullanır.
3. **İsimler:** Klasör ve dosya adları görünen ekran, bölüm ve satırla eşleşir. Aynı veri her katmanda aynı adı taşır.
4. **Veri kapısı:** Bölüm ve satırlar `Store` veya `Service` kullanmaz, veriyi `XData` üzerinden alır.
5. **İş kuralı:** Hesap ve karar kodu `business/` içine yazılır, ekrana yazılmaz.
6. **Kabuk:** `AppFrame` veya eşdeğeri yalnızca pencereyi ve bölgeleri kurar. Statik erişim ve genel event bus kullanma.
7. **Adlandırma:** `Manager`, `Helper` ve `Utils` adlı dosya veya sınıf oluşturma.
8. **Soyutlama:** Interface, servis, mapper veya `shared/` kodunu yalnızca `docs/ARCHITECTURE.md` Bölüm 11'deki koşul sağlanıyorsa ekle.
9. **Tasarım:** Projede tasarımı tanımlayan bir md dosyası varsa (ör. `DESIGN.md`), arayüz kodu yazmadan önce oku ve dışına çıkma. Dosyada olmayan renk, yazı tipi, ölçü, bileşen veya etkileşim ekleme. Görev dosyayla çelişiyorsa ya da dosya görevi kapsamıyorsa dur ve kullanıcıya sor. Dosyayı kullanıcı istemeden değiştirme.

## Kullanıcıya sormadan yapma

- Yeni katman veya üst seviye klasör açma.
- Yeni bağımlılık veya çatı ekleme.
- Görev dışındaki kodu taşıma, yeniden adlandırma veya düzenleme.
- Şu dosyaları değiştirme: `AGENTS.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `.claude/settings.json`, `.githooks/`, `.github/CODEOWNERS`, `.github/workflows/architecture.yml`, `tools/check-architecture.*`, `tools/architecture-baseline.txt`.
- `--update-baseline` veya `--no-verify` kullanma.

## Eski kod

Proje bu yapıya geçiş aşamasında olabilir.

- Yeni kodu yeni yapıya yaz. Eski klasörlerdeki mevcut dosyaları düzenleyebilirsin, ama oraya yeni dosya ekleme.
- Görevin gerektirmediği eski kodu taşıma.
- Taşıma görevi verildiyse davranışı değiştirme ve taşımayı ayrı commit'te yap.

## Kontrol başarısız olursa

Kodu kurala uyacak şekilde düzelt. Kontrolü, baseline'ı veya kuralı değiştirerek geçmeye çalışma. Kurala uymak mümkün değilse dur ve nedenini kullanıcıya bildir.

## Bitirmeden önce

1. `sh tools/check-architecture.sh` çalıştır.
2. Projenin testlerini çalıştır.
3. Kullanıcıya şunları bildir: eklenen dosyalar, kontrol sonucu, test sonucu ve varsa yapıya uymayan nokta.
