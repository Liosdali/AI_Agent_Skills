# Proje Mimarisi

Bu yapının iki amacı var:

1. Projeye yeni gelen biri, ekranda gördüğü bir satırın kodunu klasör hiyerarşisini izleyerek bulabilsin.
2. Bağımlılıklar tepeden aşağı tek yönde izlenebilsin.

Amaç çok katman açmak değil. Katman, klasör veya sınıf ancak okumayı kolaylaştırıyorsa eklenir.

AI ajanları için bağlayıcı kurallar `AGENTS.md` içindedir. Kuralların bir bölümü `tools/check-architecture.sh` ile otomatik denetlenir.

## 1. Kod nereye yazılır

| Yazılacak kod | Yer |
|---|---|
| Uygulama başlatma, nesne kurulumu | `app/` |
| Ekran listesi ve rota eşleşmesi | `app/Routes` |
| Pencere, ortak bölgeler, ekran değiştirme | `shell/` |
| Ekran iskeleti | `screens/<menü-bölümü>/<ekran>/XScreen` |
| Ekranda görünen veriler | `XData` |
| Tıklama ve girdi işlemleri | `XActions` |
| Ekran bölümleri ve satırlar | `<ekran>/sections/` |
| Sekmeler ve açılır pencereler | `<ekran>/tabs/`, `<ekran>/dialogs/` |
| Birkaç ekrandaki iş parçası | `screens/common/` |
| Hesap, kural, iş akışı | `business/<konu>/` |
| Veri okuma ve yazma | `business/<konu>/XStore` |
| Ekranlar arası ortak iş durumu | `business/session/` |
| Ekransız arka plan işi | `jobs/` |
| İş bilgisi içermeyen bileşen | `shared/ui/` |
| Para, tarih, sayı biçimi | `shared/format/` |
| Veritabanı, HTTP, oturum, log, ayar | `platform/` |
| Ekran metni | `resources/text/` |
| Test | `tests/` altında aynı yol |

## 2. Dosya yapısı

Sipariş ekranları yalnızca örnektir. Yazım biçimi (`order-detail`, `orderdetail`) kullanılan dilin standardına uyar.

```text
proje/
├─ AGENTS.md                      # AI ajanları için kurallar
├─ docs/
│  └─ ARCHITECTURE.md             # Bu dosya
├─ tools/                         # Mimari kontrol
├─ src/
│  ├─ app/
│  │  ├─ Main                     # Giriş noktası
│  │  ├─ Wiring                   # Nesnelerin kurulduğu tek yer
│  │  └─ Routes                   # Tüm ekranların listesi
│  │
│  ├─ shell/                      # Bütün ekranları saran kabuk
│  │  ├─ AppFrame                 # Pencere ve bölgelerin yerleşimi
│  │  ├─ ScreenHost               # Orta alan, aktif ekranı değiştirir
│  │  ├─ ShellState               # Sidebar açık mı, aktif sekme ne
│  │  ├─ input/
│  │  │  └─ GlobalShortcuts       # Uygulama geneli kısayollar
│  │  └─ regions/                 # Her ekranda görünen bölgeler
│  │     ├─ header/
│  │     │  ├─ HeaderRegion
│  │     │  └─ HeaderData
│  │     ├─ sidebar/
│  │     └─ status-bar/
│  │
│  ├─ screens/                    # Kullanıcının gördüğü ekranlar
│  │  ├─ orders/                  # Menü bölümü
│  │  │  ├─ order-list/           # Ekran: Siparişler
│  │  │  └─ order-detail/         # Ekran: Sipariş Detayı
│  │  │     ├─ OrderDetailScreen  # İskelet: hangi bölüm nerede
│  │  │     ├─ OrderDetailData    # Ekranda görünen tüm veriler
│  │  │     ├─ OrderDetailActions # Tıklama ve girdi işlemleri
│  │  │     ├─ sections/
│  │  │     │  ├─ summary/        # Bölüm: Özet
│  │  │     │  │  ├─ SummarySection
│  │  │     │  │  ├─ TotalAmountRow   # Satır: Toplam Tutar
│  │  │     │  │  └─ DeliveryDateRow  # Satır: Teslim Tarihi
│  │  │     │  └─ items/          # Bölüm: Ürünler
│  │  │     ├─ tabs/              # Ekranda sekme varsa
│  │  │     └─ dialogs/           # Bu ekrandan açılan pencereler
│  │  ├─ editor/
│  │  │  └─ drawing/              # Karmaşık ekran örneği
│  │  │     ├─ DrawingScreen
│  │  │     ├─ DrawingData
│  │  │     └─ sections/canvas/
│  │  │        ├─ CanvasSection
│  │  │        ├─ input/          # Fare ve klavye
│  │  │        └─ render/         # Çizim
│  │  └─ common/                  # Birkaç ekrandaki iş parçaları
│  │
│  ├─ business/                   # İş konuları, ekranları bilmez
│  │  ├─ orders/
│  │  │  ├─ Order                 # Model
│  │  │  ├─ OrderTotal            # Hesap kuralı
│  │  │  ├─ OrderService          # İşlemler: oluştur, iptal et
│  │  │  └─ OrderStore            # Okuma ve yazma
│  │  ├─ customers/
│  │  └─ session/                 # Ekranlar arası ortak iş durumu
│  │     ├─ CurrentUser
│  │     └─ ActiveCustomer
│  │
│  ├─ jobs/                       # Ekransız işler: zamanlayıcı, senkronizasyon
│  ├─ shared/                     # İş bilgisi içermeyen ortak parçalar
│  │  ├─ ui/                      # Düğme, tablo, tema
│  │  ├─ format/                  # Para, tarih, sayı biçimi
│  │  ├─ navigation/
│  │  │  ├─ Route                 # Ekranların kimlikleri
│  │  │  └─ Navigator             # Ekran açma arayüzü
│  │  └─ feedback/
│  │     └─ Feedback              # Kullanıcıya mesaj gösterme arayüzü
│  └─ platform/                   # Dış dünya
│     ├─ database/
│     ├─ http/
│     ├─ auth/
│     ├─ logging/
│     └─ config/
├─ resources/
│  └─ text/                       # Ekran metinleri
└─ tests/                         # src ile aynı hiyerarşi
```

Dilin veya çatının zorunlu kıldığı dosyalar (ör. kökteki giriş dosyası) yerinde kalır ve doğrudan `app/` içine geçer.

## 3. Bağımlılık yönü

```text
app → shell, screens, jobs → business → platform
```

- `app/` her şeyi bilir ve parçaları birbirine bağlar.
- `shell/` ile `screens/` birbirini tanımaz. İkisi de `shared/navigation` ve `shared/feedback` arayüzlerini kullanır.
- `business/` ekranları, `platform/` iş konularını bilmez.
- `shared/` her yerden kullanılabilir, ama iş konularını bilmez.
- `shell/`, `screens/` ve `jobs/` katmanları `platform/` içinden yalnızca `logging` ve `config` kullanır.
- Bir iş konusu başka bir konunun iç dosyasına değil, dışa açtığı sınıfa bağlanır. İki konu birbirine muhtaçsa ortak parça ayrılır.

Bağımlılıklar constructor'dan verilir ve `app/Wiring` içinde kurulur. Böylece bir sınıfın neye bağlı olduğu ilk bakışta görülür.

## 4. Zorunlu kurallar

1. **İsimler ekranı takip eder:** Klasör ve dosyalar görünen ekran, bölüm ve satırla eşleşir. Aynı veri her katmanda aynı adı taşır (`totalAmount`).
2. **Her ekranın tek veri kapısı vardır:** Bölüm ve satırlar veri çekmez, `XData` üzerinden alır.
3. **İş kuralı ekranda yazılmaz:** Hesap ve kararlar `business/` içinde durur.
4. **Bağımlılık aşağı iner:** Bölüm 3'teki yön dışına çıkılmaz, döngü oluşturulmaz.
5. **Gizli erişim yoktur:** `AppFrame.getInstance()` gibi statik erişim ve genel event bus kullanılmaz.
6. **Tasarım dosyasının dışına çıkılmaz:** Projede tasarımı tanımlayan bir md dosyası varsa (ör. `DESIGN.md`), arayüz bu dosyaya uyar. Dosyada olmayan bir şey gerekiyorsa önce dosya insan kararıyla güncellenir.

## 5. Ekrandaki veriyi bulma

Örnek soru: "Sipariş Detayı ekranındaki Toplam Tutar neden yanlış?"

| Adım | Soru | Konum | Orada görülen |
|---|---|---|---|
| 1 | Hangi ekran? | `screens/orders/order-detail/` | Ekran adı, gerekirse `app/Routes` |
| 2 | Hangi bölüm? | `sections/summary/` | Özet bölümü |
| 3 | Hangi satır? | `TotalAmountRow` | `data.totalAmount` gösterilir |
| 4 | Değer nereden geliyor? | `OrderDetailData` | `totalAmount = OrderTotal.of(order)` |
| 5 | Nasıl hesaplanıyor? | `business/orders/OrderTotal` | Hesap kuralı |
| 6 | Ham veri nereden geliyor? | `business/orders/OrderStore` | Sorgu |

Kestirme yol metin dosyasıdır. Ekrandaki yazı aratılır, anahtar konumu söyler:

```text
orderDetail.summary.totalAmount = "Toplam Tutar"
   ekran      bölüm     satır

shell.header.userName = "Kullanıcı"
kabuk bölge  satır
```

Soruna göre bakılacak yer:

| Sorun | Konum |
|---|---|
| Görünüm veya yerleşim yanlış | `screens/.../sections/` |
| Ekrana yanlış değer geliyor | `XData` |
| Hesap veya iş kuralı yanlış | `business/<konu>/` |
| Kayıt gelmiyor veya yazılmıyor | `business/<konu>/XStore` |
| Tıklayınca yanlış iş yapılıyor | `XActions` |
| Üst bar, menü veya durum çubuğu yanlış | `shell/regions/` |
| Yazı yanlış | `resources/text/` |
| Para veya tarih biçimi yanlış | `shared/format/` |
| Bağlantı veya oturum hatası | `platform/` |

## 6. Dosya adları

| Ek | Görevi |
|---|---|
| `XScreen` | Ekran iskeleti |
| `XData` | Ekrana veya bölgeye verilen veriler |
| `XActions` | Kullanıcı eylemleri |
| `XSection` | Ekran bölümü |
| `XRow` | Tek satır |
| `XRegion` | Kabuktaki ortak bölge |
| `XDialog` | Açılır pencere |
| `XService` | İş işlemleri |
| `XStore` | Veri okuma ve yazma |
| `XTool` | Fare modu gibi değişebilir davranış |

`Manager`, `Helper` ve `Utils` adları kullanılmaz. İşi tek cümleyle anlatan bir ad seçilir.

## 7. Ortak alanlar

| Ortak alan | Örnek | Yer |
|---|---|---|
| Her ekranda görünen bölge | Üst bar, sidebar, durum çubuğu | `shell/regions/` |
| Birkaç ekrandaki iş parçası | Müşteri kartı | `screens/common/` |
| İş bilgisi içermeyen bileşen | Düğme, tablo | `shared/ui/` |
| Ekranlar arası iş durumu | Aktif kullanıcı, seçili müşteri | `business/session/` |
| Kabuğun görünüm durumu | Sidebar açık mı | `shell/ShellState` |
| Tek ekrana ait durum | Filtre, sıralama | `XData` |
| Ortam ayarı | Sunucu adresi | `platform/config/` |
| Tema | Renk, yazı tipi | `shared/ui/theme/` |

`business/session/` içinde her konu ayrı küçük sınıf olur. Birçok alanı olan tek bir `AppState` sınıfı açılmaz. Bir ekran dışında kimse kullanmıyorsa veri ekranda kalır.

## 8. Kabuk ve AppFrame

`AppFrame` yalnızca pencereyi kurar ve bölgeleri yerleştirir. İçinde iş kuralı, ekran adı ve `getInstance()` bulunmaz. Web'de `AppLayout`, mobilde `HomeShell` aynı role karşılık gelir.

```java
public final class AppFrame extends JFrame {
    public AppFrame(HeaderRegion header, SidebarRegion sidebar,
                    ScreenHost screenHost, StatusBarRegion statusBar) {
        add(header, BorderLayout.NORTH);
        add(sidebar, BorderLayout.WEST);
        add(screenHost, BorderLayout.CENTER);
        add(statusBar, BorderLayout.SOUTH);
    }
}
```

Paneller birbirini doğrudan çağırmaz:

| İhtiyaç | Kullanılacak yol |
|---|---|
| Başka ekrana geçmek | `navigator.open(Route.ORDER_DETAIL)` |
| Ortak veri değişince diğer yerleri güncellemek | `business/session/` sınıfını dinlemek |
| Mesaj göstermek | `feedback.show(...)` |

```java
// Yanlış: sınıf AppFrame'e ve tüm panellere bağlı
AppFrame.getInstance().getHeader().setCustomer(customer);
AppFrame.getInstance().getOrdersPanel().reload();

// Doğru: sınıf yalnızca ihtiyacını bilir
activeCustomer.set(customer);       // Header ve sipariş ekranı bunu dinler
feedback.show("Müşteri seçildi");   // Durum çubuğu gösterir
```

Genel event bus kullanılmaz, çünkü olayın nereden çıkıp nereye gittiği izlenemez. `ActiveCustomer` gibi adı belli sınıflarda dinleyiciler "Find Usages" ile bulunur.

## 9. Birden fazla giriş noktası

- Her gerçek giriş noktası `app/` içinde ayrı dosyadır (`EditorMain`, `ViewerMain`).
- Giriş noktası yalnızca nesneleri kurar ve uygulamayı açar.
- Deneme amaçlı giriş noktaları `tests/manual/` altına taşınır, kullanılmayanlar silinir.
- Ayrı derleme modülüne yalnızca uygulamalar farklı bağımlılıklarla ayrı ürün olarak dağıtılıyorsa geçilir.

## 10. Karmaşık ekranlar

Fare, klavye ve çizim gibi teknik katmanlar üst seviyede durmaz, ait oldukları bölümün içine iner.

```text
Fare → input/CanvasMouseHandler → aktif Tool → state veya model değişir
     → yenileme istenir → render/CanvasRenderer çizer
```

- Fare kodu çizim yapmaz, çizim kodu veri değiştirmez.
- `Tool` arayüzü en az iki fare modu varsa açılır.
- Uzun çizim kodu `render/`, uzun girdi kodu `input/` altına alınır.

## 11. Soyutlama ne zaman eklenir

| Eklenecek şey | Koşul |
|---|---|
| Servis | Gerçek bir kural veya birden fazla veri kaynağı varsa |
| Interface | İki gerçek uygulama varsa ya da dış sistem testte sahtesiyle değiştirilecekse |
| `shared/` | Kod üçüncü kez kullanıldığında ve iş bilgisi içermiyorsa |
| DTO veya mapper | Veri şekilleri gerçekten farklıysa |
| `domain/` alt klasörü | Yalnızca kuralları çok ağır olan iş konusunda |

Hesaplama ve karar kodu mümkün olduğunca saf fonksiyon olarak yazılır, böylece veritabanı veya ağ olmadan test edilir.

## 12. Dosya sayısını sınırlama

- Satırın kendi mantığı veya özel görünümü yoksa ayrı dosya açılmaz, bölüm dosyasında durur.
- Küçük ekranda `Screen`, `Data` ve `Actions` tek dosyada kalabilir.
- `sections/`, `tabs/` ve `dialogs/` yalnızca ekranda karşılığı varsa açılır.
- Alt klasör, bir klasördeki dosya sayısı 7-8'i geçince düşünülür.
- 400 satırı geçen dosya ve 40 satırı geçen fonksiyon gözden geçirilir. Bunlar sinyaldir, kesin sınır değildir.

## 13. Gereksiz kodu tespit etme

| Belirti | Kontrol | Yapılacak |
|---|---|---|
| Aracı sınıf | Metotları yalnızca başka bir sınıfa mı yönlendiriyor? | Çağıranla birleştir, sınıfı sil |
| Tek uygulamalı interface | Testte de sahtesi yok mu? | Interface'i sil |
| Kullanılmayan kod | Araç ve arama referans bulamıyor mu? Reflection, DI ve rota kullanımını da kontrol et. | Sil |
| Tek yerden çağrılan helper | Tek bir kullanıcısı mı var? | Kullanıldığı yere taşı |
| Belirsiz sınıf | İşini tek cümleyle anlatamıyor musun? | Sorumluluklarına göre böl |
| Tekrarlanan kod | Aynı kural mı, yoksa benzerlik tesadüf mü? | Aynı kuralsa birleştir, değilse bırak |
| Kullanılmayan esneklik | Parametre veya flag hep aynı değeri mi alıyor? | Kaldır |

## 14. Farklı proje türleri

| Proje türü | `screens/` karşılığı | Alt parçalar |
|---|---|---|
| Web, mobil | Sayfa veya ekran | Bölüm, satır |
| Masaüstü | Pencere | Panel, satır, canvas |
| Backend API | `endpoints/` | Endpoint, yanıt alanı |
| Komut satırı aracı | `commands/` | Komut, çıktı alanı |

`business/` ve `platform/` bu türlerin hepsinde aynı kalır. `screens/` yerine başka bir ad kullanılıyorsa `tools/check-architecture.sh` ve `tools/check-architecture.awk` içindeki katman listeleri de güncellenir.

## 15. Mevcut projeye geçiş

1. **Güvenceye al:** Kritik akışlara birkaç uçtan uca test yaz.
2. **Eski ihlalleri kaydet:** `sh tools/check-architecture.sh --update-baseline` çalıştır. Bundan sonra yalnızca yeni ihlaller engellenir. Eski klasörlerdeki mevcut dosyalar düzenlenebilir, ama oraya yeni dosya eklenemez.
3. **Sil:** Ölü kodu ve aracı sınıfları at.
4. **Giriş noktalarını ayıkla:** Her birini gerçek, deneme veya ölü olarak ayır.
5. **Kurulumu topla:** Statik erişimi constructor'a çevir, kurulumu `app/Wiring` içine al.
6. **AppFrame'i parçala:** Sırayla ekran değiştirmeyi, mesajları ve ortak veriyi ayır. Geçişte eski metotlar yeni sınıflara yönlendirebilir.
7. **Ekranları taşı:** En sık değişen ekrandan başla. Eski klasörler geçiş boyunca yeni yapıyla yan yana durabilir.

İki kural her adımda geçerlidir:

- Yapı ve davranış değişikliği aynı commit'te olmaz.
- Nadiren dokunulan ve çalışan modüller sırf bu yapıya uysun diye taşınmaz.

## 16. Otomatik kontrol ve istisnalar

`tools/check-architecture.sh` şunları denetler:

| Kural kodu | Denetlenen |
|---|---|
| `KLASOR` | Tanımsız üst klasör açılmış mı, eski klasörlere yeni dosya eklenmiş mi |
| `BAGIMLILIK` | Import'lar Bölüm 3'teki yöne uyuyor mu |
| `BOLUM_VERI` | Bölüm ve satırlar `Store` veya `Service` kullanıyor mu |
| `STATIK_KABUK` | Kabuğa statik erişim var mı |
| `DOSYA_ADI` | `Manager`, `Helper` veya `Util` adı kullanılmış mı |

Kontrol Java, Kotlin, Dart, JavaScript, TypeScript ve Python import'larını okur. Tam adla yapılan kullanımı ve iş konuları arasındaki bağımlılığı göremez, bunlar kod incelemesinde kontrol edilir. Diğer dillerde katman kuralları için dilin kendi aracı kullanılır.

İstisna gerekiyorsa:

- Yapıyı değiştiren karar önce bu dosyada PR ile değişir, sonra kod yazılır.
- `tools/architecture-baseline.txt` yalnızca insan kararıyla güncellenir ve kod sahibinin onayından geçer.
- Bir kural değişirse `docs/ARCHITECTURE.md`, `AGENTS.md` ve kontrol betiği birlikte güncellenir.

## 17. PR kontrol listesi

- [ ] Yeni kod Bölüm 1'deki yerinde mi?
- [ ] Görünen ekran, bölüm ve satırdan koda hiyerarşi izlenerek ulaşılabiliyor mu?
- [ ] Yeni sınıf veya interface Bölüm 11'deki koşulu sağlıyor mu?
- [ ] Görevle ilgisi olmayan taşıma veya yeniden adlandırma yok mu?
- [ ] Yapı ve davranış değişikliği ayrı commit'lerde mi?
- [ ] Arayüz değişikliği varsa tasarım md dosyasına uyuyor mu?
- [ ] Mimari kontrol ve testler geçiyor mu?
