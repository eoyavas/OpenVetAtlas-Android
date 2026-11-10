#!/usr/bin/env python3
"""
External Batch Asset Validation & FBX Node Extractor (Layer 3)
Parses binary Kaydara FBX (v7000+) files in Assets/Models/Bones/ without modifying
source files, extracting Model (Mesh & Null/Node3D landmark) nodes and parent-child
hierarchy connections (OO) into .tmp/fbx_landmarks_dump.json.
"""

import json
import os
import struct
import zlib
from pathlib import Path

BONE_FBX_PATHS = [
    "Assets/Models/Bones/Dog_humerus.fbx",
    "Assets/Models/Bones/Dog_Radius.fbx",
    "Assets/Models/Bones/Dog_scapula.fbx",
    "Assets/Models/Bones/Dog_ulna.fbx",
]


def read_fbx_properties(data: bytes, offset: int, count: int):
    props = []
    for _ in range(count):
        if offset >= len(data):
            break
        ptype = chr(data[offset])
        offset += 1
        if ptype == "Y":
            props.append(struct.unpack_from("<h", data, offset)[0])
            offset += 2
        elif ptype == "C":
            props.append(bool(data[offset]))
            offset += 1
        elif ptype == "I":
            props.append(struct.unpack_from("<i", data, offset)[0])
            offset += 4
        elif ptype == "F":
            props.append(struct.unpack_from("<f", data, offset)[0])
            offset += 4
        elif ptype == "D":
            props.append(struct.unpack_from("<d", data, offset)[0])
            offset += 8
        elif ptype == "L":
            props.append(struct.unpack_from("<q", data, offset)[0])
            offset += 8
        elif ptype in ("S", "R"):
            length = struct.unpack_from("<I", data, offset)[0]
            offset += 4
            raw = data[offset : offset + length]
            offset += length
            if ptype == "S":
                props.append(raw.decode("utf-8", errors="replace"))
            else:
                props.append(raw)
        elif ptype in ("f", "d", "l", "i", "b"):
            arr_len, encoding, comp_len = struct.unpack_from("<III", data, offset)
            offset += 12 + comp_len
            props.append(None)
        else:
            break
    return props


def read_fbx_nodes(data: bytes, offset: int, end_limit: int, version: int):
    nodes = []
    is_64 = version >= 7500
    header_fmt = "<QQQI" if is_64 else "<IIII"
    header_size = 25 if is_64 else 13

    while offset + header_size <= end_limit:
        end_offset, num_props, prop_list_len, name_len = struct.unpack_from(
            header_fmt, data, offset
        )
        offset_after_hdr = offset + (24 if is_64 else 12) + 1
        if end_offset == 0:
            break
        name = data[offset_after_hdr : offset_after_hdr + name_len].decode(
            "utf-8", errors="replace"
        )
        prop_start = offset_after_hdr + name_len
        props = read_fbx_properties(data, prop_start, num_props)
        child_start = prop_start + prop_list_len
        children = []
        if child_start < end_offset:
            children = read_fbx_nodes(data, child_start, end_offset, version)
        nodes.append((name, props, children))
        offset = end_offset
    return nodes


def parse_fbx_hierarchy(filepath: Path):
    data = filepath.read_bytes()
    if not data.startswith(b"Kaydara FBX Binary"):
        return {"error": "Not a binary FBX file"}
    version = struct.unpack_from("<I", data, 23)[0]
    top_nodes = read_fbx_nodes(data, 27, len(data), version)

    models = {}
    connections = []

    for nname, _, children in top_nodes:
        if nname == "Objects":
            for cname, cprops, cchildren in children:
                if cname == "Model" and len(cprops) >= 3:
                    obj_id = cprops[0]
                    raw_label = str(cprops[1]).split("\x00")[0]
                    mtype = str(cprops[2])
                    lcl_t = [0.0, 0.0, 0.0]
                    for sc_name, _, sc_children in cchildren:
                        if sc_name == "Properties70":
                            for p_name, p_props, _ in sc_children:
                                if (
                                    p_name == "P"
                                    and len(p_props) >= 7
                                    and p_props[0] == "Lcl Translation"
                                ):
                                    lcl_t = [
                                        round(float(p_props[4]), 4),
                                        round(float(p_props[5]), 4),
                                        round(float(p_props[6]), 4),
                                    ]
                    models[obj_id] = {
                        "name": raw_label,
                        "type": mtype,
                        "local_position": lcl_t,
                        "children": [],
                    }
        elif nname == "Connections":
            for cname, cprops, _ in children:
                if cname == "C" and len(cprops) >= 3 and cprops[0] == "OO":
                    connections.append((cprops[1], cprops[2]))

    for child_id, parent_id in connections:
        if child_id in models and parent_id in models:
            models[parent_id]["children"].append(models[child_id])

    meshes = []
    for m in models.values():
        if m["type"] == "Mesh":
            landmarks = [
                {
                    "name": c["name"],
                    "class": "Node3D",
                    "local_position": c["local_position"],
                }
                for c in m["children"]
                if c["type"] in ("Null", "NodeAttribute", "")
            ]
            meshes.append(
                {
                    "mesh_node_name": m["name"],
                    "landmark_count": len(landmarks),
                    "landmarks": landmarks,
                }
            )
    return meshes


def main():
    root = Path(__file__).resolve().parent.parent
    report = {
        "generated_by": "scripts/parse_fbx_nodes.py",
        "models": {},
        "all_unique_raw_landmarks": [],
    }
    unique = set()
    for rel in BONE_FBX_PATHS:
        res_key = f"res://{rel}"
        full = root / rel
        if not full.exists():
            report["models"][res_key] = {"error": "File not found"}
            continue
        meshes = parse_fbx_hierarchy(full)
        for m in meshes:
            for lm in m["landmarks"]:
                unique.add(lm["name"])
        report["models"][res_key] = {
            "root_name": full.stem,
            "root_class": "Node3D",
            "meshes": meshes,
        }
    report["all_unique_raw_landmarks"] = sorted(unique)
    out = root / ".tmp" / "fbx_landmarks_dump.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {out} ({len(unique)} unique landmarks)")


if __name__ == "__main__":
    main()
