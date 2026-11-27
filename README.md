# RelicGrid: Mystic Block Odyssey

**RelicGrid: Mystic Block Odyssey**, Godot 4 (GDScript) ile geliştirilmiş mobil öncelikli taktiksel bir 8×8 / 9×9 blok bulmaca oyunudur.

## Özellikler
- **Taktiksel Izgara Oynanışı:** Klasik 8×8 ve değişken tapınak mimarileri (`ACTIVE` / `VOID` hücreler), hayalet önizleme, 2 hamlelik Combo Grace ve dalga patlama efektleri.
- **Dinamik Engel & Özel Bloklar:** Çatlak Taş (1–2 can, doğrudan + bitişik hasar), Buz Mühürlü Blok (`*2 / 1` aşamalı), Geri Sayımlı Bomba / Antik Mühür ve dolu hücre üzerine bile bırakılabilen Joker (`+`).
- **500 Bölümlük Kampanya:** Deterministik seed tabanlı 500 bölüm ve 10 tapınak biyomu.
- **Günlük Mozaik Serisi:** Sistem tarihine bağlı günlük bulmacalar ve 7 günlük rün mozaik tablosu.
- **İkili Sonsuz Mod:** Klasik **Normal Sonsuz** ve dinamik engelli/özel rünlü **Özel Sonsuz** (ayrı puanlama ve ayrı en iyi skor kayıtları).
- **Haftalık Ligler (Kohort):** Bronz, Gümüş, Altın, Zümrüt ve Mistik lig kademeleri.
- **Pazar, Güçlendiriciler & Temalar:** Çekiç, Döndür (simetri korumalı), Yenile ve Bomba güçlendiricileri, No Ads seçeneği ve anlık değişen 3 tema (`Zümrüt Tapınak`, `Obsidyen Altın`, `Buzul Rünü`).
- **Otomatik Kayıt & Sıfır Harici Varlık Bağımlılığı:** `user://saved_run.json` ile kaldığın yerden devam, prosedürel `AudioManager` ses/haptic sentezleyici ve `JuicyEffectsManager` parçacık/sarsıntı efektleri.

## Gereksinimler
- **Godot Engine 4.3+** *(proje Godot **4.7** `GL Compatibility` profiliyle yapılandırılmıştır)*

## Kurulum ve Çalıştırma
1. **Godot 4** Proje Yöneticisi'ni açın ve **Import (İçe Aktar)** seçeneğine tıklayın.
2. Proje kök dizinindeki `project.godot` dosyasını seçip **Import & Edit** butonuna basın.
3. Editör açıldığında **`F5`** tuşuna (veya sağ üstteki **Run Project ▶** simgesine) basarak doğrudan Ana Menüden oyunu başlatın.

## Proje Yapısı
```text
├── project.godot          # Godot 4 proje ayarları ve Autoload tanımları
├── autoload/              # GameState, ThemeManager, AudioManager, JuicyEffectsManager, BoardSaveManager
├── scripts/               # PieceLibrary, LevelGenerator, GridBoard, PieceTray
├── scenes/                # MainMenu, CampaignMap, GameScene, WeeklyCohort, ShopScene (.tscn + .gd)
└── archive/web-prototype/ # Arşivlenmiş eski React/Vite web prototipi (.gdignore ile izole)
```
