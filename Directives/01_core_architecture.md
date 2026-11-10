# 01 — Core Architecture & Landmark Pipeline Specification

## 1. Motor, Render ve Donanım Erişilebilirliği ("Potato-to-Flagship")

OpenVetAtlas Android, 7–8 yıllık giriş seviyesi ("potato") Android telefon ve tabletlerden güncel amiral gemisi cihazlara kadar tüm donanımlarda akıcı ve pil dostu çalışacak şekilde tasarlanmıştır.

### 1.1 Temel Motor Ayarları ve Sürüm Sistemi (`project.godot`)
* **Motor Sürümü:** Godot Engine 4.3+ (MIT Lisansı).
* **Sürümleme (Versioning Standardı):** Semantik sürümleme (`v0.2.0` -> `v0.3.0` -> `v0.4.0`...) uygulanır. Her yeni APK çıktısı kök dizinde `OpenVetAtlas_vX.Y.Z.apk` (mevcut: `OpenVetAtlas_v0.4.0.apk`, `config/version="0.4.0"`, `version/code=4`) olarak adlandırılır.
* **Kurumsal Kimlik (Branding):** `res://Assets/branding/` altında uygulama ikonu (`icon_192.png`, `icon_432_fg.png`, `icon_432_bg.png`), açılış ekranı (`ova_splash.png`) ve üst bar logosu (`ova_header_logo.png`) yer alır.
* **Render Motoru:** `gl_compatibility` (OpenGL ES 3.0) — Eski Android GPU sürücülerinde Vulkan çökmelerini önlemek için evrensel taban olarak kilitlenmiştir.
* **Pil Tasarrufu (On-Demand Rendering):** `application/run/low_processor_usage_mode = true`. Kullanıcı ekrana dokunmadığında veya aktif bir kamera hareketi olmadığında motor yeni kare çizimini duraklatır; öğrenci anatomik yapıları incelerken GPU kullanımı ~%0 seviyesine iner ve cihaz ısınmaz.
* **Varsayılan Görselleştirme (MatCap + Opsiyonel Albedo Doku):** Düşük seviye mobil GPU'larda maliyetli gerçek zamanlı PBR ışıklandırma ve gölge haritaları (shadow maps) yerine kemik/organ yüzey derinliğini sıfıra yakın GPU maliyetiyle veren **MatCap (Material Capture)** shader'ı (`Assets/materials/bone_matcap.gdshader`) kullanılır. Dokusu olmayan kemiklerde çalışma zamanı 256×256 prosedürel `ImageTexture` fildişi (`ivory`) MatCap kullanılırken, `horse_cranium.png` gibi fotogrametri/albedo dokusuna sahip modellerde Albedo Doku + MatCap hibrit aydınlatması uygulanır.

### 1.2 Dinamik Kalite Katmanları (`QualityManager`)
| Özellik | Low Tier (Giriş Seviyesi Cihazlar) | High Tier (Amiral Gemisi Cihazlar) |
| :--- | :--- | :--- |
| **3D Çözünürlük Ölçeği (`scaling_3d_scale`)** | `0.75` | `1.0` |
| **Kenar Yumuşatma (MSAA 3D)** | Kapalı (`Disabled`) | `2x` veya `4x MSAA` |
| **Kemik Yüzey Shader'ı** | Saf MatCap (+ Albedo) | MatCap (+ Albedo) + Rim-Lighting |
| **Arayüz Geçişleri** | Anlık / Basitleştirilmiş | Akıcı geçişler |

### 1.3 Bellek Disiplini ve Android Dosya Sistemi Hassasiyeti
* **Büyük/Küçük Harf Duyarlılığı (Case-Sensitivity):** Android dosya sistemi (`APK` / `PCK` içi) büyük/küçük harfe duyarlıdır. Diskteki gerçek klasör ve dosya adları (`res://Assets/Models/Bones/Dog_Radius.fbx`, `res://Assets/Models/Bones/Dog_humerus.fbx`, `res://Assets/Models/Bones/Dog_scapula.fbx`, `res://Assets/Models/Bones/Dog_ulna.fbx`, `res://Assets/Models/Bones/horse_cranium.fbx`, `res://Assets/Models/Bones/horse_cranium.png`, `res://Assets/data/landmark_dictionary.json`) tüm `res://` yollarında birebir korunmak zorundadır.
* **Headless FBX İçe Aktarma Zorunluluğu:** Herhangi bir CLI denetim veya doğrulama betiği çalıştırılmadan önce `godot --headless --import` komutu çalıştırılarak `.fbx` modellerinin Godot `ufbx` içe aktarıcısı tarafından `.godot/imported/` altına işlenmesi sağlanır.
* Dokular **ETC2 / ASTC** sıkıştırması ile içe aktarılır.
* Yeni bir anatomik model yüklenmeden önce mevcut aktif model `queue_free()` ile RAM ve VRAM'den tamamen temizlenir.

---

## 2. Taksonomik Katalog (`TAXON_CATALOG`) ve Proje Dizin Yapısı

Anatomik modeller hayvan taksonlarına (`Canidae`, `Equidae` ve gelecekte eklenecek yeni takson grupları) göre veri güdümlü (`TAXON_CATALOG`) olarak gruplandırılır. Üst bardaki **Takson Seçici (`TaxonSelector`)** değiştirildiğinde **Kemik Seçici (`BoneSelector`)** otomatik olarak ilgili taksonun kemiklerini listeler.

```text
OpenVetAtlasAndroid/
├── AGENTS.md                         # Çalışma protokolü ve mimari kısıtlar
├── project.godot                     # Godot 4.x proje yapılandırması (gl_compatibility, v0.3.0)
├── directives/                       # [KATMAN 1] Teknik spesifikasyonlar ve şemalar
│   └── 01_core_architecture.md       # Temel mimari, takson kataloğu, FBX pin ve Quiz standardı
├── Assets/                           # Salt okunur kaynak varlıklar
│   ├── Models/
│   │   └── Bones/                    # Blender'dan dışa aktarılmış READ-ONLY .fbx kemik modelleri ve dokuları
│   │       ├── Dog_humerus.fbx       # [Canidae] Humerus
│   │       ├── Dog_Radius.fbx        # [Canidae] Radius
│   │       ├── Dog_scapula.fbx       # [Canidae] Scapula
│   │       ├── Dog_ulna.fbx          # [Canidae] Ulna
│   │       ├── horse_cranium.fbx     # [Equidae] Cranium
│   │       └── horse_cranium.png     # [Equidae] Cranium Albedo Texture
│   ├── data/                         # Latince JSON sözlük ve yazım düzeltme dosyası
│   │   └── landmark_dictionary.json
│   └── materials/                    # MatCap + Albedo shader
├── src/                              # [KATMAN 3] Deterministik GDScript çalışma zamanı kodları
│   ├── core/                         # QualityManager, MatCapGenerator
│   ├── camera/                       # TouchOrbitCamera (AABB Auto-Framing & Coalesced Pinch)
│   ├── landmarks/                    # LandmarkSpawner, LandmarkDictionary
│   └── ui/                           # AtlasMainController (Klinik UI, Takson/Kemik Seçici & Quiz)
├── scenes/                           # Düz metin (.tscn) sahne dosyaları
├── scripts/                          # [KATMAN 3] Headless doğrulama ve FBX denetim betikleri
└── .tmp/                             # Geçici FBX düğüm dökümleri ve doğrulama raporları (.gitignore)
```

---

## 3. FBX Hiyerarşisi ve Tahribatsız (Non-Destructive) Landmark Pin Mimarisi

### 3.1 Kaynak FBX Hiyerarşi Kuralları (Keşfedilen Standart)
1. **Salt Okunur Kaynaklar:** `Assets/Models/Bones/` altındaki `.fbx` dosyaları kesinlikle değiştirilmez, yeniden adlandırılmaz ve içlerindeki düğümlerin yerel dönüşümleri (`Transform3D`) sıfırlanmaz.
2. **Ana Kemik Düğümü (Gerçek FBX Verisi):** FBX kök sahnesinin altındaki ana kemik modeli bir `MeshInstance3D` objesidir:
   * **Canidae:**
     * `res://Assets/Models/Bones/Dog_humerus.fbx` -> Root: `Dog_humerus` -> Mesh: `Dog_humerus` (**18 landmark / 18 kanonik terim**)
     * `res://Assets/Models/Bones/Dog_Radius.fbx` -> Root: `Dog_Radius` -> Mesh: `dog_radius` (**7 landmark / 7 kanonik terim**)
     * `res://Assets/Models/Bones/Dog_scapula.fbx` -> Root: `Dog_scapula` -> Mesh: `dog_scapula` (**13 landmark / 12 kanonik terim**)
     * `res://Assets/Models/Bones/Dog_ulna.fbx` -> Root: `Dog_ulna` -> Mesh: `dog_ulna` (**9 landmark / 9 kanonik terim**)
   * **Equidae:**
     * `res://Assets/Models/Bones/horse_cranium.fbx` (+ `horse_cranium.png`) -> Root: `RootNode` -> Mesh: `model_41` (**29 landmark / 26 kanonik terim**)
3. **Ön Eksiz Latince İsimlendirme ve Tespit Edilen Ham Yazım Sapmaları:** Alt `Node3D` düğümleri doğrudan Latince anatomik terimlerle adlandırılmıştır. Denetimde tespit edilen ve `landmark_dictionary.json` (v2.1) tarafından otomatik düzeltilen gerçek FBX yazım sapmaları:
   * `tubeculum majoris` (`Dog_humerus.fbx`) -> `Tuberculum majus`
   * `incusura radialis` & `incusura trochlearis` (`Dog_ulna.fbx`) -> `Incisura radialis` & `Incisura trochlearis`
   * `circumferantia articularis` (`Dog_Radius.fbx`) & `circumferantia  articularis` (`Dog_ulna.fbx`) -> `Circumferentia articularis`
   * `facies  serrata` & `facies serrata` (`Dog_scapula.fbx`) -> `Facies serrata`
   * `facies m_ infraspinati` & `sulcus m_ brachialis` (`Dog_humerus.fbx`) -> `Facies m. infraspinati` & `Sulcus m. brachialis`
   * `arcus orbita`, `crista fascialis`, `ductus incicivus`, `hamulus pterygoideum` (`horse_cranium.fbx`) -> `Arcus orbitalis`, `Crista facialis`, `Ductus incisivus`, `Hamulus pterygoideus`
   * `condylus  occipitalis`, `fossa  condylaris ventralis`, `tuberculum  musculare` (çift boşluklu sağ/sol eş noktalar, `horse_cranium.fbx`) -> `Condylus occipitalis`, `Fossa condylaris ventralis`, `Tuberculum musculare`

### 3.2 Otomatik Tarama, Ölçek Normalizasyonu ve Çoklu Işın (Multi-Ray) Görünürlük Kontrolü
1. **Dünya Uzayı Pin Boyutu Normalizasyonu:**
   * Hedef 3B küre yarıçapı doğrudan kemiğin dünya uzayı `AABB` en uzun kenarına (`world_max_extent * 0.0095`) göre hesaplanır ve her `landmark_node` düğümünün `global_transform.basis.get_scale()` değerine bölünerek normalize edilir.
   * Dokunmatik seçimi kolaylaştırmak için 3B `SphereShape3D` çarpıştırıcı yarıçapı `pin_radius * 2.65` ve 2B ekran rozetleri `38×38 px` olarak ölçeklenir.
2. **Çoklu Işın (Multi-Ray Sphere-Cap) Görüş Hattı Testi:**
   * Sulkus, foramen veya fossa gibi çukur bölgelerdeki pinlerin kemik döndürülürken yanlışlıkla gizlenmesini önlemek için tek-üçgen normal açısı kontrolü kullanılmaz.
   * Bunun yerine kameradan pin merkezine, kameraya bakan tepe noktasına ve iki yan teğet noktasına toplam 4 adet Raycast atılır; en az bir tepe noktası kemik tarafından kapatılmıyorsa pin görünür kabul edilir. Kemiğin arkasında kalan pinler ise tamamen gizlenir (`visible = false`).
3. **Kare Başına Birleştirilmiş (Frame-Coalesced) İki Parmak Yakınlaştırma:**
   * Android'de iki parmak hareketinde her parmak için ayrı gönderilen `InputEventScreenDrag` olayları `call_deferred` ile kare başına tek seferde işlenir ve ölü bölge (`PINCH_DEADZONE_PX`, `PAN_DEADZONE_PX`) filtresinden geçirilerek yakınlaştırma/uzaklaştırma sırasında pin titremesi engellenir.
