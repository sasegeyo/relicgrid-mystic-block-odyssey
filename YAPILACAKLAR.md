# Yapılacaklar

Durum: oyun taslak olarak oynanabilir durumda. Aşağıdakiler yayından önce
ya da yayına yakın yapılacaklar. Son güncelleme: 28 Kasım 2026.

## Yayından önce şart

- [ ] **Gerçek reklam ağı.** Şu an reklamlar 1,5 saniyelik sahte ekran
  (`autoload/AdManager.gd` → `_play_test_ad`). AdMob ya da AppLovin MAX
  bağlanacak; sadece bu fonksiyon değişecek, oyunun geri kalanı hazır.
- [ ] **Reklam izni ekranı.** Avrupa'da GDPR, Türkiye'de KVKK, iOS'ta Apple'ın
  takip izni (ATT) penceresi. Reklam ağıyla birlikte eklenecek (ör. Google UMP).
- [ ] **Gerçek satın alma.** No Ads (`GameState.purchase_no_ads`) ve Premium
  sezon kartı (`BattlePass.purchase_premium`) şu an bedava açılıyor.
  Google Play Billing ve App Store ödeme sistemi bağlanacak.

## Oyunu bozan hatalar

- [ ] **Günlük oyun altın kasma.** Günlük oyun tekrar oynanarak sınırsız altın
  alınabiliyor. Günde bir kez ödül verilmeli.
- [ ] **Kampanya kayıt çakışması.** Bir bölüm yarıdayken başka bir bölüme
  girilirse önceki bölümün kaydı siliniyor (kampanya tek kayıt yerini paylaşıyor).

- [ ] **Telefonun paylaş menüsü.** "Sonucu paylaş" şu an metni panoya
  kopyalıyor. Telefonda doğrudan WhatsApp/Instagram paylaş menüsünü açmak için
  Android/iOS paylaşım eklentisi gerekiyor.

## Temizlik

- [ ] **Lig rakipleri sahte.** Haftalık ligdeki rakipler simülasyon. Başlangıç
  için sorun değil, ileride sunucu gerekir.
- [ ] **Kullanılmayan eski kod.** Rescue ve joker sistemlerinden kalan kodlar
  temizlenecek.
- [ ] **`godot_project/` klasörü.** Eski klasör, Godot'da çift `project.godot`
  uyarısı veriyor. Silinebilir.
- [ ] **Eski reklam testi.** Reklam sistemi süre ve baskı tabanlı olduğu için
  oyun sayısını ölçen eski test geçersiz; yeni test onun yerini aldı.

## Ayar ve deneme

- [ ] **Sayılar tahmini.** Reklam sıklığı (`AdManager.gd` başındaki AYAR
  TABLOSU), sezon XP'si, çark ödülleri ve fiyatlar gerçek oyuncu verisiyle
  A/B testiyle ayarlanacak. Sadece reklam gelirine değil, oyuncunun ertesi gün
  ve 7. gün geri gelip gelmediğine bakılacak.
- [ ] **Gerçek telefonda deneme.** Her şey bilgisayarda Godot ile test edildi.
  Telefonda dokunmatik his, farklı ekran boyutları ve performans denenmeli.
