# 🦴 3. Adding New Bones & Blender Workflow / Yeni Kemik ve Pin Ekleme Rehberi

**OpenVetAtlas Android (oVa)** uses a non-destructive pipeline where source `.fbx` files inside `Assets/Models/Bones/` are treated as strictly **READ-ONLY**. Anatomical landmarks are read directly from child `Node3D` (Blender Empty) objects inside the `.fbx` hierarchy at runtime.

---

## 🎨 1. Preparing a Bone & Landmarks in Blender / Blender İş Akışı

1. Open your 3D bone mesh in **Blender** and center/orient its origin cleanly.
2. For each anatomical landmark, create an **Empty (`Plain Axes`)** parented to the main bone mesh object.
3. Name each Empty with its Latin anatomical term (e.g., `caput humeri`, `tuberculum majus`, `foramen infraorbitale`).
   * *Paired / Duplicate Structures:* If an anatomical structure appears at two points on the same bone (such as cranial and caudal `facies serrata` on the scapula, or left and right `condylus occipitalis` on the cranium), both Empties are preserved as separate 3D spheres and automatically grouped under a single canonical term (`Facies serrata (×2)`).
4. Export the model as `.fbx` (and its optional texture `.png`) into:
   ```text
   Assets/Models/Bones/
   ```

---

## 📖 2. Registering Terms in `landmark_dictionary.json` / Latince Sözlük Eşleştirmesi

All raw node names from Blender are resolved through `Assets/data/landmark_dictionary.json` into canonical *Nomina Anatomica Veterinaria* (NAV) Latin terms:

```json
{
  "version": "2.1",
  "aliases_and_typos": {
    "tubeculum majoris": "tuberculum_majus",
    "condylus  occipitalis": "condylus_occipitalis"
  },
  "landmarks": {
    "caput_humeri": {
      "latin": "Caput humeri"
    },
    "condylus_occipitalis": {
      "latin": "Condylus occipitalis"
    }
  }
}
```

To verify that every landmark in your new `.fbx` file maps cleanly with zero unmapped nodes, run:
```bash
godot --headless --import
godot --headless --quit -s res://scripts/dump_fbx_landmarks.gd
```

---

## 🐾 3. Adding a New Taxon or Bone to `TAXON_CATALOG` / Kataloğa Yeni Tür veya Kemik Ekleme

Open `src/ui/atlas_main_controller.gd` and add your new bone (or a new animal taxon such as `Ruminantia`) to `TAXON_CATALOG`:

```gdscript
const TAXON_CATALOG: Array[Dictionary] = [
	{
		"taxon_id": "canidae",
		"latin_title": "Canidae",
		"specimens": [
			{
				"id": "dog_humerus",
				"latin_title": "Humerus",
				"path": "res://Assets/Models/Bones/Dog_humerus.fbx",
				"texture_path": ""
			},
			# Add new Canidae bones here...
		]
	},
	{
		"taxon_id": "equidae",
		"latin_title": "Equidae",
		"specimens": [
			{
				"id": "horse_cranium",
				"latin_title": "Cranium",
				"path": "res://Assets/Models/Bones/horse_cranium.fbx",
				"texture_path": "res://Assets/Models/Bones/horse_cranium.png"
			}
		]
	}
]
```

The TopBar `TaxonSelector`, `BoneSelector`, 3D surface sphere spawner, camera auto-framing, and Quiz Mode will automatically include the new entry without any scene or UI code changes!
