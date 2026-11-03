# Genera los personajes de ejemplo del diseñador en game/data/personajes/.
import json, random, re, colorsys, sys, os, unicodedata

ROOT = sys.argv[1]
G = os.path.join(ROOT, "game")
M = json.load(open(os.path.join(G, "data/raval_map.json"), encoding="utf-8"))
W, H, CELLS = M["width"], M["height"], M["cells"]
NPC = open(os.path.join(G, "scripts/actors/npc.gd"), encoding="utf-8").read()

KINDS = {}
for m in re.finditer(r'\n\t"(\w+)": \{\n(.*?)\n\t\},', NPC, re.S):
    body = m.group(2)
    sp = re.search(r'"speed": ([\d.]+)', body)
    ac = re.search(r'"accessory": "(\w*)"', body)
    sz = re.search(r'"size": ([\d.]+)', body)
    hr = re.search(r'"hours": \[(\d+), (\d+)\]', body)
    zn = re.search(r'"zone": "(\w+)"', body)
    KINDS[m.group(1)] = {"speed": float(sp.group(1)) if sp else 10.0, "acc": ac.group(1) if ac else "",
        "size": float(sz.group(1)) if sz else 1.0, "hours": [int(hr.group(1)), int(hr.group(2))] if hr else [],
        "zone": zn.group(1) if zn else "barrio"}

def walkable(x, y):
    return 0 <= x < W and 0 <= y < H and CELLS[y][x] in "234"

def snap(c):
    x, y = int(c[0]), int(c[1])
    for r in range(0, 30):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) == r and walkable(x + dx, y + dy):
                    return [x + dx, y + dy]
    return [x, y]

def label(text):
    for l in M["labels"]:
        if text in l["text"]:
            return [l["x"] / M["cell_m"], l["z"] / M["cell_m"]]
    raise KeyError(text)

def street(name, frac=0.5):
    pts = sorted(([s["x"], s["y"]] for s in M["streets"] if s["name"] == name), key=lambda p: (p[0], p[1]))
    if not pts:
        raise KeyError(name)
    return pts[min(len(pts) - 1, int(frac * len(pts)))]

def poi(kind, near):
    ps = [p for p in M["pois"] if p["kind"] == kind]
    p = min(ps, key=lambda p: (p["x"] - near[0]) ** 2 + (p["y"] - near[1]) ** 2)
    return [p["x"], p["y"]]

def poly(c, r):
    x, y = int(c[0]), int(c[1])
    return [[x - r, y - r], [x + r, y - r], [x + r, y + r], [x - r, y + r]]

SKINS = ["f0cfb0", "e0b08a", "c68c5e", "8d5a3b", "5a3a26"]
HAIRS = ["1b1410", "3a2418", "5a3a20", "8a5a30", "c8a060", "7a7a7a"]
GREY = ["d8d8d8", "b8b8b8", "f0f0f0"]
STYLES = {"m": ["corto", "rapado", "calvo", "tupe", "rizos", "coleta"], "f": ["melena", "coleta", "moño", "corta", "rizos", "rapado"]}
UNIF = {
    "urbano": {"shirt": "2a3d7a", "pants": "1d2a5a"}, "mosso": {"shirt": "1a2140", "pants": "141a30"},
    "educador": {"shirt": "e07a30"}, "punki": {"shirt": "1a1a1a", "jacket": "101010"},
    "pudiente": {"shirt": "f4f4f0", "pants": "2a2a30"},
}

def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))

def look(tipo, nombre, g, edad, extra):
    r = random.Random(nombre)
    a = {"skin": r.choice(SKINS), "shirt": hsv(r.random(), r.uniform(0.2, 0.7), r.uniform(0.35, 0.85)),
         "pants": hsv(r.random(), 0.2, r.uniform(0.2, 0.5)), "hair": r.choice(GREY if edad >= 65 else HAIRS),
         "jacket": "", "hair_style": r.choice(STYLES[g][:2] if r.random() < 0.5 else STYLES[g]),
         "facial": "", "glasses": r.random() < 0.15, "skirt": g == "f" and r.random() < 0.35,
         "accesorio": KINDS.get(tipo, {}).get("acc", ""), "tamano": KINDS.get(tipo, {}).get("size", 1.0)}
    if g == "m" and edad >= 18:
        x = r.random()
        a["facial"] = "barba" if x < 0.3 else ("bigote" if x < 0.42 else "")
    if r.random() < 0.35 and tipo not in ("urbano", "mosso"):
        a["jacket"] = hsv(r.random(), r.uniform(0.1, 0.5), r.uniform(0.15, 0.45))
    if tipo == "yonki":
        a["shirt"] = hsv(r.random(), r.uniform(0.1, 0.4), r.uniform(0.2, 0.45))
    if tipo in ("turista", "carterista", "urbano_secreta"):
        a["shirt"] = hsv(r.random(), 0.6, 0.95)
    if tipo == "mensajero":
        a["shirt"] = r.choice(["ffc81e", "00c8b4"])
    a.update(UNIF.get(tipo, {}))
    a.update(extra)
    return a

def slug(s):
    s = unicodedata.normalize("NFKD", s.lower()).encode("ascii", "ignore").decode()
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]", "_", s)).strip("_")

FUENTES = {}
MISIONES = {}
exec(open(os.path.join(os.path.dirname(__file__), "personajes_datos.py"), encoding="utf-8").read())

out_dir = os.path.join(G, "data/personajes")
os.makedirs(out_dir, exist_ok=True)
ids = set()
for p in PERSONAJES:
    tipo, nombre, g, edad = p["tipo"], p["nombre"], p["g"], p["edad"]
    d = {
        "version": 1, "id": slug(nombre), "nombre": nombre, "apodo": p.get("apodo", ""), "edad": edad,
        "genero": g, "tipo": tipo, "amo": p.get("amo", ""), "historia": p["historia"],
        "fuentes": p.get("fuentes", FUENTES.get(tipo, "")),
        "aspecto": look(tipo, nombre, g, edad, p.get("look", {})),
        "zona": {"tipo": KINDS.get(tipo, {}).get("zone", "barrio"), "poligono": [], "casa": []},
        "horario": p.get("horario", KINDS.get(tipo, {}).get("hours", [])),
        "lugares": [],
        "stats": {"dinero": p.get("dinero", 10), "velocidad": KINDS.get(tipo, {}).get("speed", 10.0),
                  "fuerza": p.get("fuerza", 5), "valor": p.get("valor", 5), "agresividad": p.get("agresividad", 3),
                  "llama_policia": p.get("llama_policia", False), "quiere": p.get("quiere", []),
                  "lleva": p.get("lleva", {}), "vende": p.get("vende", {}), "le_debes": p.get("le_debes", 0)},
        "ficha": {"quien": "", "habla": "", "sabe": "", "no_sabe": "", "quiere": ""},
        "frases": p.get("frases", []), "misiones": MISIONES.get(slug(nombre), []), "relaciones": [],
        "notas": p.get("notas", ""),
    }
    d["ficha"].update(p.get("ficha", {}))
    if "zona" in p:
        z = p["zona"]
        if isinstance(z, str):
            d["zona"]["tipo"] = z
        else:
            d["zona"]["tipo"] = "poligono"
            d["zona"]["poligono"] = poly(z[0], z[1])
    if "casa" in p:
        d["zona"]["casa"] = snap(p["casa"])
    for l in p.get("lugares", []):
        c = snap(l[1])
        d["lugares"].append({"tipo": l[0], "x": c[0], "y": c[1], "desde": l[2], "hasta": l[3], "nota": l[4] if len(l) > 4 else ""})
    assert d["id"] not in ids, d["id"]
    ids.add(d["id"])
    for n in re.findall(r"«(.+?)»", d["notas"]):
        pass
    json.dump(d, open(os.path.join(out_dir, d["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
print(len(PERSONAJES), "personajes")
