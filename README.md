# 3play

> Hayatın göremediğimiz boyutları vardır.

3play, gerçek afetleri iki farklı gözden yaşatan bir afet farkındalığı oyunu. Önce rolünü seçiyorsun: **Devlet** ya da **Vatandaş**. Dünya küresi dönüyor ve seni geçmişte gerçekten yaşanmış bir afetin içine bırakıyor. Her tur o olayın gerçek rakamları ve "neler işe yarardı" bilgisiyle biter.

Civil Game Jam 2026 (ODTÜ KALTEV) için 48 saatte yapıldı. Tema: afet farkındalığı.

## Oynanış

Bir tur = bir afet = bir mini oyun. Akış:

1. **Rol seçimi:** Devlet ya da Vatandaş.
2. **Küre (4B, zaman):** Dünya döner, yer ve yıl kilitlenir. Tıklayarak veya Space ile atlanabilir.
3. **Diorama (3B):** Kısa tanıtım. Yer, tarih ve iki satır bağlam.
4. **Mini oyun:** Afetin kendisi. Kimi afet uyarı vermez, kimi hazırlık süresi tanır.
5. **Sonuç kartı:** Skor, gerçek rakamlar, rozet. Bilgi panelinde olayla ilgili gerçek bilgi ve neyin yardımcı olacağı. Ardından ortak afeti oynama seçeneği.

### Afetler

| Afet | Yer, tarih | Rol | Mini oyun |
|---|---|---|---|
| Hint Okyanusu tsunamisi | Endonezya, 26 Aralık 2004 | Devlet | **Connect:** boruları döndür, gelen suyu her köyün kendi havuzuna yönlendir. Dalga vurduğunda her tamamlanan hat bir köyü kurtarır. |
| Kahramanmaraş depremi | Türkiye, 6 Şubat 2023 | Vatandaş | **Fener:** 04:17 depreminden sonra karlı, elektriksiz gece. Fenerle aileni ve komşularını bul, enkaz altındakileri kurtarma ekibine bildir, herkesi toplanma alanına götür. |
| Kara Cumartesi orman yangını | Victoria, Avustralya, 7 Şubat 2009 | Vatandaş | **Yangın (birinci şahıs):** kanguru çiftliğinde çiti kes, kaçış yolundaki ateşi söndür, zamanında çık. Ders: erken ayrıl. |
| Güneş patlaması | 14 Mart 3026 | Devlet | **Işın Ağı (Beam):** uyduları 45° adımlarla çevir, ışını toplayıcılara yönlendir. Işının değdiği her şehir karanlığa gömülür. 4 dalga, 44 şehir. |

Afetler iki sabit yol olarak eşleşir: Hint Okyanusu + Kahramanmaraş, Güneş patlaması + Kara Cumartesi. Sonuç kartı oynanmamış ortağı önerir.

### Easter egg

Küre bir kez takılır ve 1000 yıl ileri sıçrar: 3026, Güneş patlaması. Yanmış bir Dünya ve "Gerçek Senaryo" ile "Devam et" arasında bir seçim.

### Boyutlar

Küre = 4B (zaman), diorama ve oyuncu = 3B, mini oyunlar = 2B / 2.5B.

## Kontroller

| Nerede | Tuşlar |
|---|---|
| Menüler | Fare. Enter ana düğmeye basar. |
| Duraklatma | Esc: Devam, Ayarlar, Ana menü, Çık |
| Hint Okyanusu | Boruya tıkla: 90° döner. Soldaki girişi sağdaki aynı sıradaki havuza bağla. |
| Güneş patlaması | Uyduya sol tık: +45°, sağ tık: geri, tekerlek: iki yön. Klavye: Tab / oklar seçer, E / Space / Enter çevirir, Q geri, F ateşler. |
| Kara Cumartesi | W A S D / oklar yürür, fare bakar, Shift koşar, Space zıplar, E / F / Enter etkileşim. |
| Kahramanmaraş | W A S D / oklar yürür, fare feneri tutar, sol tuş basılıyken fareye yürür, Space / F feneri açar, kapatır. |
| Ayarlar | Dil (TR / EN), genel ses, müzik, efekt, fare hassasiyeti, Y ekseni ters, tam ekran. |

## Kurulum

### Hazır sürüm (Windows)

1. ZIP dosyasını indir, bir klasöre çıkar.
2. `3play.exe` dosyasına çift tıkla. Kurulum ve internet gerekmez.

Gereksinim: Windows 10 / 11 (64 bit), OpenGL 3.3 destekleyen ekran kartı, fare ve klavye. Sesin açık olması önerilir. Oyun Türkçe açılır; Ayarlar'dan İngilizce'ye geçilebilir.

Ayrıntılı talimat: [`docs/submission/run-instructions.md`](docs/submission/run-instructions.md).

### Kaynaktan çalıştırma

1. [Godot 4.7](https://godotengine.org/download) (standart sürüm, .NET gerekmez) kur.
2. Depoyu klonla:
   ```sh
   git clone https://github.com/memoksin/3play.git
   cd 3play
   ```
3. Varlıkları içe aktar (ilk açılışta, ya da varlık / `locale/strings.csv` değişince):
   ```sh
   godot --headless --path . --import
   ```
4. Oyunu başlat: `godot --path .` ya da Godot'ta projeyi açıp F5.

Tek sahneyi denemek için sahneyi açıp F6. Sahne kendi afetini `Game.ensure_disaster()` ile kurar.

### Dışa aktarma (build)

`export_presets.cfg` içinde Windows ve macOS hazır ayarları var. Godot'ta export şablonlarını kurduktan sonra:

```sh
godot --headless --path . --export-release "Windows" export/windows/3play.exe
godot --headless --path . --export-release "macOS" export/macos/3play.zip
```

## Teknoloji

| Alan | Kullanılan |
|---|---|
| Motor | Godot 4.7, GL Compatibility renderer |
| Dil | GDScript |
| Veri | Godot Resource (`.tres`): afet verisi `data/disasters/`, mini oyun kuralları ve görselleri skin dosyalarında. Yeni görsel = skin alanı, kod değişmez. |
| 3B modeller | Headless Blender + Python (`tools/models/`, `python3 tools/models/build.py`). Karakterler: Meshy (görselden 3B) + Quaternius UAL animasyonları, yeniden rig Blender'da. |
| 2B sprite | Kodla çizilen piksel sanat (Python / GDScript, `tools/sprites/`) |
| Ses | Freesound ve OpenGameArt'tan CC0 sesler, ffmpeg ile kesilip `.ogg` |
| Yerelleştirme | `locale/strings.csv` (TR / EN), denetim: `tools/audit_strings.gd` |
| Sanat stili | 2.5B: kamera, ışık, palet kuralları `docs/art/style-2.5d.md` |
| Geliştirme | Claude Code (kod ve araçlar), GitHub Issues, `feat/*` → `dev` → `main` |

### Mimari

- **Autoload'lar:** `Game` (akış, afet seçimi, yükleme), `Audio` (ses), `Voice` (anlatım satırları).
- **Akış sözleşmesi:** sahneler `Game.next()` ile, mini oyunlar `Game.finish_minigame(saved, total, extra)` ile biter.
- **Yükleme:** küre açılışta bir kez ısınır; diorama ve mini oyun kürenin perdesi arkasında, yükleme kapağı altında hazırlanır, takılma olmaz.
- **Ortam:** bir yerin hava ve saati `Disaster.atmosphere` (`scripts/atmosphere.gd`). Küredeki güneş olayın gerçek saatinden (`Disaster.utc`) gelir.

## Proje yapısı

```
assets/     ses, font, 3B model, sprite, video; CREDITS.md
data/       afet ve skin kaynakları (.tres)
docs/       tasarım, mini oyun spekleri, sanat stili, teslim belgeleri
locale/     çeviri tablosu (TR / EN)
scenes/     sahneler: küre, diorama, mini oyunlar, sonuç kartı, arayüz
scripts/    autoload'lar ve ortak betikler
tests/      headless testler
tools/      model, sprite, ekran görüntüsü, video ve denetim araçları
ui/         tema (tools/build_theme.gd üretir)
```

## Testler

Testler headless çalışır, hata durumunda çıkış kodu 1 döner:

```sh
godot --headless --path . -s tests/test_flow.gd
```

Düzenlediğin bir testte önce sözdizimi kontrolü yap. Ayrıştırma hatası olan test 0 ile çıkar:

```sh
godot --headless --path . --check-only -s tests/test_flow.gd
```

`tools/*_shots.gd` betikleri ekran görüntüsü alır ve ekran ister (headless çalışmaz).

## Ekip

| Kişi | Alan |
|---|---|
| [memoksin](https://github.com/memoksin) | Çekirdek kod, akış, küre, Güneş patlaması ve yangın mini oyunları, build |
| [iremaltunsgt](https://github.com/iremaltunsgt) | Arayüz, tema, sonuç kartı, Hint Okyanusu mini oyunu |
| [sudeimete](https://github.com/sudeimete) | Karakterler, diorama, ses entegrasyonu, Kahramanmaraş mini oyunu |
| [burcubaran22](https://github.com/burcubaran22) | Oyun tasarımı, metinler, ses seçimi, kaynak ve teslim belgeleri, Kahramanmaraş mini oyunu |

## Katkı

- `main` her zaman oynanabilir. `dev` entegrasyon dalı. İş `feat/*` dalında yapılır, PR `dev`'e açılır.
- `main` ve `dev`'e doğrudan push yok.
- Görevler GitHub Issues'ta (`status:*`, `role:*` etiketleri).

## Kaynaklar ve lisanslar

Yalnızca CC0 veya jam'e uygun lisanslı varlıklar kullanıldı. Her hazır varlık ve her yapay zekâ kullanımı (görsel, ses, kod, metin, diğer) kaynağı, yazarı ve lisansıyla [`assets/CREDITS.md`](assets/CREDITS.md) dosyasında listelenir.
