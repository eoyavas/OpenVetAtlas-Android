# 📦 4. APK Build & Android Installation / APK Derleme ve Cihaza Kurulum

This page explains how to run the automated headless integration test suite, export a signed Android `.apk` from **Godot Engine 4.3+**, and install it onto an Android phone or tablet.

---

## 🧪 1. Automated Headless Verification / Otomatik Headless Doğrulama

Before exporting an APK, run `scripts/verify_main_atlas.gd` in headless mode. It instantiates `scenes/main_atlas.tscn`, iterates through every taxon (`Canidae`, `Equidae`) and specimen (`Humerus`, `Scapula`, `Radius`, `Ulna`, `Cranium`), and verifies:
* All 3D surface spheres (`PinMarker3D`) and `StaticBody3D` trimesh colliders are created and world-scale normalized.
* Procedural MatCap (`256×256` ivory) and optional photogrammetry Albedo textures (`horse_cranium.png`) are bound.
* Clicking a landmark from the UI list centers the bone, zooms out, and rotates the camera to face the landmark.
* Drawer collapse/expand works in both Portrait and Landscape modes.
* Interactive Quiz Mode (`✔` / `×`) completes full question queues and exits cleanly.

```bash
godot --headless --import
godot --headless -s res://scripts/verify_main_atlas.gd
```
A detailed JSON report is written to `.tmp/atlas_verification_report.json` (`"all_passed": true`).

---

## 🛠️ 2. Exporting a Signed Android APK / İmzalı Android APK Üretimi

### Requirements / Gereksinimler:
* **Godot Engine 4.3+** (with matching Android Export Templates installed)
* **OpenJDK 17 or 21**
* **Android SDK** (`platform-tools` & `build-tools` with `apksigner`)

### Command-Line Export (Headless):
```bash
godot --headless --export-debug "Android" "OpenVetAtlas_v0.4.0.apk"
```

### Versioning Convention / Sürümleme Standardı:
Each release increments semantic versioning across `project.godot` (`config/version="0.4.0"`) and `export_presets.cfg` (`version/code=4`, `version/name="0.4.0"`, `export_path="OpenVetAtlas_v0.4.0.apk"`).

---

## 📲 3. Installing onto an Android Phone or Tablet / Android Cihaza Kurulum

### Method A: Direct File Transfer
1. Copy `OpenVetAtlas_v0.4.0.apk` to your Android phone or tablet (via USB cable, Google Drive, or local share).
2. Tap the `.apk` file in your device's File Manager and allow installation from unknown sources if prompted.

### Method B: Install via ADB (USB Debugging)
```bash
adb install -r OpenVetAtlas_v0.4.0.apk
```
