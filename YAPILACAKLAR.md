# Yapılacaklar

Son güncelleme: 28 Kasım 2026. Oyunun taslak hali oynanabilir durumda.
Bu dosyada yayından önce yapılacak işler, bilinen hatalar ve eklenecek
özellikler var. Yapay zekâ ajanı (ör. Antigravity) bu dosyayı okuyup sırayla
çalışabilsin diye yazıldı.

---

## 0. Önce bunu oku (kurallar)

**Proje bilgisi**
- Godot 4.7.2, GDScript, GL Compatibility, dikey ekran 720x1280.
- Autoload'lar sırayla: GameState, ThemeManager, AudioManager, AdManager,
  BattlePass, DailyQuests, JuicyEffectsManager, BoardSaveManager.
- Arayüzün büyük kısmı koddan kuruluyor (`ThemeManager.make_button`,
  `make_label`, `make_card_panel` vb.). Yeni ekran yaparken bunları kullan,
  görünüm aynı kalsın.
- Fontlar: Rubik (gövde, ağırlık 500) ve Cinzel (başlık, 900), `assets/fonts/`.

**Değiştirilmeyecek kararlar**
1. **Reklam sıklığı sabit aralıklı ya da oyun sayısına bağlı olmayacak.**
   Bir oyun 40-45 dakika sürüyor. Sistem "reklam baskısı" ile çalışıyor:
   oynama süresi, biten tepsiler ve temizlenen satırlar baskıyı artırıyor.
   Eşik her reklamdan sonra rastgele değişiyor. Ayarlar `autoload/AdManager.gd`
   başındaki `AYAR TABLOSU` bölümünde. Mantığı değiştirme, sadece sayıları ayarla.
2. **Oyuncu ödüllü reklamı reddettikten hemen sonra zorunlu reklam çıkmaz.**
   (`on_game_end_continue(..., declined_rewarded)` ve `AFTER_DECLINE_SECONDS`.)
3. **Önemli anlarda reklam çıkmaz** (rekor bölgesi, büyük kombo). `protected_moment`.
4. **Revive (devam et) sadece ödüllü reklamla.** VIP / No Ads alan da izler,
   oyun içi altınla revive alınamaz.
5. **Oyuncuyu gizlice zora sokan hile yok.** Ör. kaybettirmek için kasıtlı
   imkânsız parça vermek. Parça üretimi adil kalacak.
6. **"Güçlendirici kullan" diye takılan ekran geri getirilmeyecek.** Bilerek kaldırıldı.
7. **Günlük görevlerde reklam izleme görevi olmayacak.**

**Çalışma şekli**
- Her iş için ayrı commit at, mesajı ne yaptığını anlatsın.
- Bir şeyi değiştirdikten sonra oyunu aç: ana menü, normal oyun, günlük oyun,
  kampanya ve mağaza açılıyor mu, hata var mı bak.
- Testsiz denemek için Godot'u başsız çalıştırabilirsin:
  `godot --headless --path . --script test.gd` (`extends SceneTree` ile).
  Not: başsız modda ekran görüntüsü ve pano çalışmaz. Testler arasında
  `user://` içindeki `.json` kayıtlarını ve `settings.cfg` dosyasını sil,
  yoksa eski kayıt yüzünden yanlış sonuç çıkar.
- Emin olmadığın bir oyun tasarımı kararı varsa yapma, bu dosyaya not düş.

---

## 1. Oyunu bozan hatalar (önce bunlar)

- [ ] **Günlük oyunda altın kasma.** Günlük oyunu kazandıktan sonra çıkan
  "Tekrar" butonuyla aynı gün tekrar tekrar oynanıp her seferinde altın
  alınabiliyor. Çözüm: günlük ödül (altın, seri artışı) günde bir kez verilsin.
  Tekrar oynamaya izin verilebilir ama ödülsüz olmalı ve ekranda "Bugünün
  ödülü alındı" gibi yazmalı. İlgili yer: `scenes/GameScene.gd` içinde
  `_trigger_stage_clear` ve `GameState`'teki günlük oyun kayıtları.
  Günlük görev ("Günlük oyunu tamamla") zaten günde bir kez sayılıyor.
- [ ] **Kampanya kayıt çakışması.** Bir kampanya bölümü yarıdayken başka bir
  bölüme girilirse önceki bölümün yarım kaydı siliniyor, çünkü kampanyanın
  tek kayıt yeri var (`autoload/BoardSaveManager.gd`). Çözüm: başka bölüme
  girerken "Yarım kalan bölüm X silinecek, emin misin?" diye sor, ya da kaydı
  bölüm numarasıyla ayrı tut.

## 2. Yayından önce şart

- [ ] **Gerçek reklam ağı.** Şu an reklamlar 1,5 saniyelik sahte ekran
  (`autoload/AdManager.gd` → `_play_test_ad`). AdMob ya da AppLovin MAX
  bağlanacak. Sadece bu fonksiyon değişecek, oyunun geri kalanı hazır.
  Reklam yüklenemezse oyun takılmamalı, normal devam etmeli.
- [ ] **Reklam izni ekranı.** Avrupa'da GDPR, Türkiye'de KVKK, iOS'ta Apple'ın
  takip izni (ATT). Reklam ağıyla birlikte eklenecek (ör. Google UMP).
- [ ] **Gerçek satın alma.** No Ads (`GameState.purchase_no_ads`) ve Premium
  sezon kartı (`BattlePass.purchase_premium`) şu an bedava açılıyor.
  Google Play Billing ve App Store ödeme sistemi bağlanacak. "Satın alımları
  geri yükle" butonu da gerekiyor (iOS bunu zorunlu tutuyor).
- [ ] **Telefonun paylaş menüsü.** Günlük oyundaki "Sonucu paylaş" şu an metni
  panoya kopyalıyor (`GameScene.gd` → `_make_share_button`). Telefonda doğrudan
  WhatsApp/Instagram paylaş menüsü açılması için Android/iOS paylaşım eklentisi
  gerekiyor. Eklenti yoksa pano kopyalama kalsın.
- [ ] **Gizlilik politikası ve ayarlarda link.** Mağazalar istiyor.

## 3. Temizlik

- [ ] **Kullanılmayan eski kod.** Rescue ve joker sistemlerinden kalan,
  hiçbir yerden çağrılmayan kodlar silinecek. Silmeden önce gerçekten
  kullanılmadığını ara (grep).
- [ ] **`godot_project/` klasörü.** Eski kopya. Godot çift `project.godot`
  uyarısı veriyor. Silinecek.
- [ ] **Lig rakipleri sahte.** Haftalık ligdeki rakipler simülasyon. Şimdilik
  kalsın, ama koda "ileride sunucuya taşınacak" notu düş ve rakip isimleri
  gerçek oyuncu gibi görünmesin (ör. "Oyuncu 4821" yerine takma ad listesi olabilir,
  ama "gerçek kişi" izlenimi verilmemeli).

## 4. Küçük eklemeler

- [ ] **Renk körü modu.** Ayarlarda aç/kapa. Açıkken bloklar sadece renkle değil,
  üstlerindeki küçük şekille de ayırt edilsin (daire, üçgen, kare, yıldız vb.).
  Ayar `settings.cfg`'ye kaydedilsin.
- [ ] **Sonsuz modları birleştir.** Birbirine çok benzeyen sonsuz modlar tek
  modda toplanabilir (menü sadeleşsin). Rekorlar kaybolmasın: eski rekorların
  en yükseği yeni moda taşınsın.
- [ ] **Rün şeridinin yeri.** Oyun ekranındaki rün şeridi tahtaya ve tepsiye
  yakın, dikkat dağıtıyor. Üst bilgi alanına taşı ya da küçült.
- [ ] **Reklam çubuğunun yeri.** Oyun içindeki reklam/ödül çubuğu parçaları
  sürüklerken parmağın altına denk gelmesin. Ekranın en üstüne ya da
  oyun bitti ekranına taşı.

## 5. Büyük özellikler (her biri ayrı iş)

- [ ] **Kalıntı (relic) koleksiyonu.** Oyunun adı RelicGrid ama toplanan bir
  şey yok. Oynadıkça kalıntı parçaları düşsün, menüde bir koleksiyon ekranında
  görünsün, set tamamlanınca küçük kalıcı bonus versin (ör. +%5 altın).
  Para ile satılmasın, sadece oynayarak gelsin.
- [ ] **Öğretici (tutorial).** İlk açılışta 3-4 adımlık kısa anlatım:
  parçayı sürükle, satır temizle, kombo, güçlendirici. Atlanabilir olsun,
  bir kez görülünce bir daha çıkmasın.
- [ ] **Bildirimler.** Günlük oyun ve görevler yenilenince yerel bildirim
  ("Bugünün görevleri hazır"). Günde en fazla bir tane, ayarlardan kapatılabilir.
- [ ] **Bulut kayıt.** Google Play Games / Game Center ile kayıt yedekleme,
  telefon değişince ilerleme kaybolmasın.
- [ ] **Kampanyayı 100 bölüme indir.** Bölüm sayısı çok fazla ve sonlara doğru
  birbirine benziyor. En iyi 100 bölüm kalsın, zorluk düzgün artsın.
  Oyuncunun mevcut ilerlemesi bozulmasın.

## 6. Ayar ve deneme

- [ ] **Sayılar tahmini.** Reklam sıklığı (`AdManager.gd` → AYAR TABLOSU),
  sezon XP'si, çark ödülleri, görev ödülleri ve fiyatlar gerçek oyuncu
  verisiyle A/B testiyle ayarlanacak. Sadece reklam gelirine değil, oyuncunun
  ertesi gün ve 7. gün geri gelip gelmediğine bakılacak. Şu anki tahmin:
  45 dakikalık oyunda yeni oyuncuya ~9-10, eski oyuncuya ~15 reklam.
- [ ] **Gerçek telefonda deneme.** Her şey bilgisayarda test edildi.
  Telefonda dokunmatik his, farklı ekran boyutları (çentikli ekranlar dahil)
  ve performans denenmeli.

---

## Son yapılanlar (bilgi için)

- Fontlar (Rubik + Cinzel) eklendi, başlıklar kalınlaştı.
- Reklam sistemi süre ve baskı tabanlı hale getirildi (yukarıdaki kurallar).
- Revive sadece ödüllü reklamla, sezon kartı (battle pass) eklendi.
- Günlük görevler: her gün 3 görev (kolay/orta/zor), ödül sezon XP'si ve altın,
  üçü bitince +1 Bomba. `autoload/DailyQuests.gd`, `scripts/QuestsPanel.gd`.
- Günlük oyun sonucu Wordle gibi paylaşılabilir metin olarak kopyalanıyor.
