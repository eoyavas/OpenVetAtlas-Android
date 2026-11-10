# 📱 1. User Guide & Touch Controls / Kullanıcı Rehberi ve Kontroller

This guide explains all touch interactions, navigation menus, 3D landmark inspection tools, and the Universal Latin Quiz Mode in **OpenVetAtlas Android (oVa)**.

Bu rehber, **OpenVetAtlas Android (oVa)** içerisindeki dokunmatik kamera kontrollerini, taksonomik menü yapısını, 3B anatomik nokta inceleme araçlarını ve Evrensel Latince Quiz Modunu açıklar.

---

## 🖐️ 1. Touch & Camera Controls / Dokunmatik Kamera Kontrolleri

The 3D viewport is powered by `TouchOrbitCamera`, which automatically frames each bone based on its world-space bounding box (`AABB`) and filters out two-finger pinch jitter.

| Touch Gesture / Button | Desktop Equivalent | Description (EN) | Açıklama (TR) |
| :--- | :--- | :--- | :--- |
| **1-Finger Drag** | Left Mouse Drag | Orbits the camera 360° around the specimen | Kemiğin etrafında 360° kamera dönüşü sağlar |
| **2-Finger Pinch** | Mouse Wheel | Zooms in and out smoothly | Yakınlaştırma ve uzaklaştırma yapar |
| **2-Finger Drag** | Right Mouse Drag | Pans the camera target pivot | Kameranın odak merkezini kaydırır |
| **Quick Tap (`< 220 ms`)** | Left Click on Sphere | Selects a 3D landmark sphere on the bone | Kemik üzerindeki 3B anatomik noktayı seçer |
| **`⟲` Reset Button** | Click `⟲` | Resets camera angle, pivot, and zoom to default | Kamerayı başlangıç açısına ve mesafesine sıfırlar |

---

## 🧭 2. Taxonomic Navigation & Adaptive Top Bar / Taksonomik Seçim ve Üst Bar

* **Taxon Selector (`Canidae`, `Equidae`):** Located in the top navigation bar next to the `OVA` logo. Selecting an animal taxon automatically updates the adjacent **Bone Selector** dropdown with the specimens belonging to that group.
* **Portrait vs. Landscape Adaptive Layout:**
  * On **Portrait Phones**, the top bar automatically arranges into a 2-row layout (`Row 1: OVA | Taxon › Bone`, `Row 2: ● Pins | Quiz | Quality | ⟲`) so no control is ever clipped off the screen edges.
  * On **Landscape Tablets & Phones**, the top bar merges into a single sleek horizontal bar, and the anatomical terms list docks to the right side of the screen.
* **Collapsible Info Drawer (`▲` / `▼`):** Both in Portrait and Landscape modes, tapping the `▲` / `▼` button in the drawer header collapses the list into a compact title bar, giving you an unobstructed view of the 3D bone.

---

## 🔵 3. 3D Surface Landmarks & Auto-Centering / 3B Yüzey Küreleri ve Otomatik Odaklama

* **Pure 3D Surface Spheres (`PinMarker3D`):** Instead of cluttering the screen with 2D numbered badges, landmarks are represented by compact, world-scale normalized 3D spheres placed directly on the anatomical structures:
  * **Azure Blue:** Default unselected anatomical landmark.
  * **Amber Orange:** Currently selected anatomical landmark (supports multi-point structures such as `Facies serrata (×2)` and `Condylus occipitalis (×2)`).
* **Click-to-Focus from Menu List:** Tapping any Latin anatomical name in the scrollable list automatically:
  1. Highlights the corresponding 3D sphere(s) on the bone in orange.
  2. Centers the bone horizontally (`X/Z` locked to the bone's `AABB` center), zooms out slightly (`1.18×`), and smoothly rotates the bone so the selected landmark faces directly toward you.
* **Pin Toggle (`● Pins` / `○ Pins`):** Hides or reveals all 3D spheres so you can inspect delicate sulci, foramina, and articular surfaces without visual markers.

---

## 🎯 4. Universal Latin Quiz Mode (`✔` / `×`) / Evrensel Latince Quiz Modu

1. Tap **`Quiz`** in the top bar to start an interactive self-test on the currently loaded bone.
2. The terminology list is hidden and a target Latin term is displayed in the header (e.g., `1 / 18 — Tuberositas deltoidea`).
3. Rotate/zoom the bone freely and tap the 3D sphere corresponding to the requested structure:
   * **Correct (`✔`):** Displays an emerald-green **`✔`** card with the confirmed Latin name and highlights the 3D sphere in green. Tap **`→`** (or tap the next target sphere directly) to advance.
   * **Incorrect (`×`):** Displays a crimson-red **`×`** card showing the Latin name of the point you tapped, allowing you to learn from the mistake and try again.
4. You can restart the quiz (`↻`) or exit back to normal inspection mode (`×` or `× Quiz`) at any time.
