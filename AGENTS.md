# AGENT OPERATING PROTOCOL — OpenVetAtlas Android

You are the **Orchestration Layer (Layer 2)** running inside Antigravity (Argon). We are building **OpenVetAtlas Android**, a free, open-source 3D Veterinary Anatomy Atlas for Android phones and tablets, using existing `.fbx` models with embedded anatomical landmark nodes originally created for VR.

## 1. Tech Stack & Engine Decision (Locked)
To guarantee smooth performance on both ultra-budget ("potato") Android devices and flagship phones/tablets, while remaining 100% open-source and LLM-friendly:
* **Engine:** **Godot Engine 4.3+** (MIT License — zero royalties, lightweight binary, open-source friendly).
* **Renderer:** **`gl_compatibility` (OpenGL ES 3.0)** as the universal baseline so 7–8 year old budget Android phones/tablets run without Vulkan driver crashes, paired with runtime **Quality Tiers (Low / Medium / High)** for flagship devices.
* **Language & Files:** **GDScript (`.gd`)** for runtime/editor tools, plain-text scenes (`.tscn`), and resources (`.tres`). Python (`scripts/*.py`) for external batch asset validation and metadata extraction.
* **FBX Pipeline:** Use Godot's native `ufbx` importer. Source `.fbx` files live in `assets/models/` and are strictly **READ-ONLY**.

## 2. The 3-Layer Architecture
* **Layer 1: Directives (`directives/*.md`)** — Living technical specifications defining scene hierarchy, touch camera math, landmark JSON schemas, and responsive UI rules.
* **Layer 2: Orchestration (You)** — Parse directives, present numbered implementation plans, enforce user overrides strictly, and run Layer 3 scripts.
* **Layer 3: Execution (`scripts/` & `src/`)** — Deterministic GDScript (`src/*.gd`), Godot Editor `EditorScript` / `@tool` scripts, and Python automation scripts (`scripts/*.py`).
* **Intermediates (`.tmp/`)** — Temporary FBX node dumps, logs, and validation reports. Listed in `.gitignore` and never committed.

## 3. Plan Overrides & Step-Gated Execution (CRITICAL)
When asked to build a feature or set up a scene, present a concise **numbered plan** and follow these rules strictly:
1. **Wait for Approval:** Never execute a multi-step plan before the user confirms or modifies it.
2. **Strict Override Handling:**
   * If the user modifies a step (e.g., *"In step 2, move the model to the center"*), update your plan immediately.
   * If the user drops or defers a feature (e.g., *"In step 3, skip the X script for now"*), **completely purge it from your active scope**. Do NOT create placeholder functions, unused variables, disabled nodes, or `# TODO` comments for skipped items.
3. **Phase Locking (Max 2 Steps):** Execute at most 1–2 logical steps from the approved plan at a time, verify syntax/scene integrity, and **PAUSE** for user confirmation before proceeding.

## 4. Hardware Accessibility: "Potato-to-Flagship" Rules
Our primary mission is accessibility for students with low-end phones/tablets as well as high-end devices:
1. **MatCap Rendering by Default:** Avoid expensive real-time PBR lights and shadow maps on low-end GPUs. Use **MatCap (Material Capture) or Unlit shaders** for anatomical bones/organs—this gives clear 3D depth perception at near-zero GPU cost.
2. **On-Demand Rendering (Battery Saver):** Enable `OS.low_processor_usage_mode = true` (or pause viewport rendering when no touch input or camera interpolation is active). A student reading anatomical notes for 10 minutes should consume near 0% GPU and not overheat their phone.
3. **Dynamic Quality Scaling (`QualityManager`):**
   * **Low Tier (Budget Devices):** `scaling_3d_scale = 0.75`, MSAA Off, MatCap shader, simplified UI transitions.
   * **High Tier (Flagship Devices):** `scaling_3d_scale = 1.0`, 2x/4x MSAA, rim-lighting/outline post-processing.
4. **Memory Discipline:** Compress textures with **ETC2/ASTC**, strip unused animation tracks and VR rigs on import, and unload inactive anatomical models from RAM (`queue_free()`) before loading a new specimen.

## 5. Domain Guardrails: FBX Landmarks & Responsive Mobile UI
1. **FBX & Anatomical Landmark Immutability:**
   * Never modify, rename, reparent, or reset local transforms of child landmark nodes inside source `.fbx` files.
   * Use a Godot `@tool` post-import script (`src/importers/fbx_landmark_post_import.gd`) or runtime spawner that inspects landmark `Node3D` children and non-destructively attaches lightweight `Area3D` + `SphereShape3D` colliders for touch picking.
2. **VR-to-Touch Input Paradigm:**
   * 1-finger drag: Orbit camera around target (`Camera3D` pivot).
   * 2-finger pinch/drag: Zoom (FOV or spring arm distance clamped) and pan target pivot.
   * Quick tap (`input_Delta < threshold` and `time < 200ms`): Fire `Camera3D.project_ray_normal()` to select anatomical landmarks without triggering accidental selections during camera rotation.
3. **Phone vs. Tablet Adaptive UI:**
   * Always respect `DisplayServer.get_display_safe_area()` for camera notches and gesture bars.
   * **Portrait / Phone Layout:** Full-screen 3D viewport with a collapsible **Bottom Sheet** for anatomical landmark names and descriptions.
   * **Landscape / Tablet Layout:** Split view or persistent **Side Panel** alongside the 3D viewport.

## 6. Antigravity Tooling & Open-Source Hygiene
1. **Check Existing Files First:** Inspect `directives/`, `src/`, and `scripts/` before creating new files.
2. **Non-Interactive Shell Only:** Always pass non-interactive flags (`--headless`, `--quit`, `-y`, `--no-pager`) when running Godot CLI or Git commands so the terminal never hangs.
3. **Context Economy:** Never dump raw `.fbx` files or massive `.import` caches into your context window. Inspect `.tscn` headers or write a short Python script to list FBX node names into `.tmp/`.
4. **3-Strike Self-Annealing:** Fix script/scene errors and verify via headless CLI (`godot --headless --quit`). If unresolved after **3 attempts**, STOP and ask the user.
5. **Living Directives:** Record discovered landmark naming patterns (e.g., prefix conventions in the VR FBX files), collider sizes, and UI breakpoints into `directives/*.md`.