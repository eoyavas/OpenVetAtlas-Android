# ⚙️ 2. Architecture & Mobile Optimization / Yazılım Mimarisi ve Optimizasyon

**OpenVetAtlas Android (oVa)** is engineered under a strict **"Potato-to-Flagship"** philosophy: a 7–8 year old entry-level Android phone or tablet must run the atlas without driver crashes or thermal throttling, while modern high-Refresh-rate tablets benefit from enhanced anti-aliasing and rim-lighting.

---

## 🏗️ 1. Three-Layer Repository Architecture / 3 Katmanlı Mimari

```text
OpenVetAtlasAndroid/
├── directives/                       # [LAYER 1] Technical specifications & schemas
│   └── 01_core_architecture.md
├── Assets/                           # Read-only 3D models, textures, shaders & NAV JSON
│   ├── Models/Bones/                 # Blender .fbx models & photogrammetry textures
│   ├── branding/                     # OVA logos, adaptive icons & boot splash
│   ├── data/landmark_dictionary.json # Canonical NAV Latin dictionary & typo aliases
│   └── materials/bone_matcap.gdshader
├── src/                              # [LAYER 3] Deterministic GDScript runtime modules
│   ├── core/                         # QualityManager, MatCapGenerator
│   ├── camera/                       # TouchOrbitCamera (AABB framing & focus tween)
│   ├── landmarks/                    # LandmarkSpawner, LandmarkDictionary
│   └── ui/                           # AtlasMainController (Fit-to-Screen UI & Quiz)
├── scenes/main_atlas.tscn            # Plain-text main scene
└── scripts/                          # Headless CLI verification & FBX inspection tools
    ├── dump_fbx_landmarks.gd
    └── verify_main_atlas.gd
```

---

## 🔋 2. Battery-Saving & Rendering Pipeline / Pil Dostu Çizim ve Render Mimarisi

1. **Universal OpenGL ES 3.0 Baseline (`gl_compatibility`):**
   * Avoids Vulkan initialization crashes common on older budget Android SoCs (Adreno 5xx / Mali-T8xx / PowerVR).
2. **On-Demand Rendering (`low_processor_usage_mode = true`):**
   * Neither `AtlasMainController`, `TouchOrbitCamera`, nor `LandmarkSpawner` runs an idle `_process()` or `_physics_process()` loop.
   * When the student is reading anatomical terms without touching the screen, Godot sleeps between events—dropping GPU utilization to near **0%**.
3. **Hybrid MatCap + Albedo Shader (`bone_matcap.gdshader` & `MatCapGenerator`):**
   * Instead of costly real-time PBR lights and shadow maps, bone depth perception is rendered via a view-space **MatCap** shader.
   * If no external MatCap texture is present, `MatCapGenerator` procedurally synthesizes a `256×256` ivory spherical gradient `ImageTexture` at startup.
   * For textured specimens like `horse_cranium.fbx`, the shader blends the photogrammetry `albedo_texture` (`horse_cranium.png`) with MatCap lighting.
4. **Dynamic Quality Scaling (`QualityManager`):**
   * **Low:** `scaling_3d_scale = 0.75`, MSAA Off.
   * **Med:** `scaling_3d_scale = 0.90`, 2× MSAA.
   * **High:** `scaling_3d_scale = 1.00`, 4× MSAA.

---

## 📐 3. World-Space Pin Normalization & "Fit-to-Screen" UI

* **World-Space 3D Sphere Normalization (`LandmarkSpawner`):**
  * Different `.fbx` models exported from Blender can carry different root/mesh local scales.
  * `LandmarkSpawner` computes the specimen's world-space `AABB` longest axis (`world_max_extent`) and divides the desired sphere radius (`world_max_extent * 0.00255`) by each landmark node's global basis scale (`inverse scale`), ensuring identical visual sphere proportions across all bones.
* **Ghost-Touch Protection (`TouchOrbitCamera`):**
  * Intercepts `InputEventScreenTouch(pressed = false)` inside `_input()` before GUI controls consume touch release events, and prunes stale touch indices so dragging onto UI panels never freezes the camera.
* **Fit-to-Screen UI Scaling (`AtlasMainController._apply_adaptive_ui_scale`):**
  * Computes an ergonomic DPI scale for Phone vs. Tablet and Portrait vs. Landscape, then clamps it against `max_fit_scale` derived from the actual minimum width of `TopBar` and `InfoDrawer`, guaranteeing zero horizontal or vertical overflow on any screen resolution.
