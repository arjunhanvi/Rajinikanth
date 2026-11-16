"""Minimal binary glTF writer: skinned meshes with morph targets and vertex colours."""
import json, struct, numpy as np

class Glb:
    def __init__(self):
        self.bin = bytearray(); self.views = []; self.acc = []; self.meshes = []; self.nodes = []; self.skins = []
    def _view(self, data, target=None):
        while len(self.bin) % 4: self.bin.append(0)
        off = len(self.bin); self.bin += data
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target: v["target"] = target
        self.views.append(v); return len(self.views) - 1
    def accessor(self, arr, ctype, atype, target=None, minmax=False, normalized=False):
        arr = np.ascontiguousarray(arr)
        a = {"bufferView": self._view(arr.tobytes(), target), "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        if normalized: a["normalized"] = True
        if minmax:
            a["min"] = [float(x) for x in arr.reshape(arr.shape[0], -1).min(0)]; a["max"] = [float(x) for x in arr.reshape(arr.shape[0], -1).max(0)]
        self.acc.append(a); return len(self.acc) - 1
    def add_mesh(self, name, P, N, UV, J, W, I, C=None, morphs=None, skin=0):
        prim = {"attributes": {
            "POSITION": self.accessor(P.astype(np.float32), 5126, "VEC3", 34962, True),
            "NORMAL": self.accessor(N.astype(np.float32), 5126, "VEC3", 34962),
            "TEXCOORD_0": self.accessor(UV.astype(np.float32), 5126, "VEC2", 34962),
            "JOINTS_0": self.accessor(J.astype(np.uint16), 5123, "VEC4", 34962),
            "WEIGHTS_0": self.accessor(W.astype(np.float32), 5126, "VEC4", 34962)},
            "indices": self.accessor(I.astype(np.uint32).reshape(-1), 5125, "SCALAR", 34963), "mode": 4}
        if C is not None:
            prim["attributes"]["COLOR_0"] = self.accessor((np.clip(C, 0, 1) * 255).astype(np.uint8), 5121, "VEC4", 34962, normalized=True)
        m = {"name": name, "primitives": [prim]}
        if morphs:
            prim["targets"] = [{"POSITION": self.accessor(d.astype(np.float32), 5126, "VEC3", 34962, True)} for _, d in morphs]
            m["extras"] = {"targetNames": [n for n, _ in morphs]}; m["weights"] = [0.0] * len(morphs)
        self.meshes.append(m)
        self.nodes.append({"name": name, "mesh": len(self.meshes) - 1, "skin": skin})
        return len(self.nodes) - 1
    def add_skeleton(self, names, parents, heads):
        """bones are translation-only joints: rest orientation is identity"""
        base = len(self.nodes); idx = {n: base + i for i, n in enumerate(names)}
        for n in names:
            p = parents[n]; t = heads[n] - (heads[p] if p else 0)
            self.nodes.append({"name": n, "translation": [float(x) for x in t]})
        for n in names:
            ch = [idx[c] for c in names if parents[c] == n]
            if ch: self.nodes[idx[n]]["children"] = ch
        ibm = np.tile(np.eye(4, dtype=np.float32), (len(names), 1, 1))
        for i, n in enumerate(names): ibm[i, 3, :3] = -heads[n]
        self.skins.append({"joints": [idx[n] for n in names], "inverseBindMatrices": self.accessor(ibm.reshape(-1, 16), 5126, "MAT4"), "skeleton": idx[names[0]]})
        self.roots = [idx[n] for n in names if not parents[n]]
    def save(self, path):
        mesh_nodes = [i for i, n in enumerate(self.nodes) if "mesh" in n]
        g = {"asset": {"version": "2.0", "generator": "rajinikanth-humans"}, "scene": 0, "scenes": [{"nodes": self.roots + mesh_nodes}],
             "nodes": self.nodes, "meshes": self.meshes, "skins": self.skins, "accessors": self.acc, "bufferViews": self.views, "buffers": [{"byteLength": len(self.bin)}]}
        js = json.dumps(g, separators=(",", ":")).encode()
        while len(js) % 4: js += b" "
        while len(self.bin) % 4: self.bin.append(0)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942)); f.write(self.bin)
