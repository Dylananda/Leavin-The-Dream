"""Convierte los datos crudos de OSM del Raval en el mapa del juego.

Entrada:  data/raw/raval_osm.json   (tools/fetch_osm.py)
          tools/clubs_cannabicos.json  asociaciones cannábicas (no están en OSM)
Salida:   game/data/raval_map.json  cuadrícula de navegación + geometría 3D
          game/assets/ground.png    suelo pintado (calles, aceras, plazas)
          data/preview_map.png      vista de control, no la usa el juego

Sistema de coordenadas: el plano se rota para alinear las calles dominantes con
los ejes. Las posiciones en metros (x, z) tienen el origen en la esquina de la
cuadrícula; la casilla (cx, cy) cubre [cx*CELL_M, (cx+1)*CELL_M) en x y lo mismo en z.

Uso: python tools/build_map.py
"""
import colorsys
import json
import math
import pathlib
from collections import Counter, defaultdict

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "raw" / "raval_osm.json"
OUT = ROOT / "game" / "data" / "raval_map.json"
GROUND = ROOT / "game" / "assets" / "ground.png"
PREVIEW = ROOT / "data" / "preview_map.png"
CLUBS = ROOT / "tools" / "clubs_cannabicos.json"  # sitios que OSM no tiene: las asociaciones cannábicas

CELL_M = 2.0  # metros por casilla de navegación
MARGIN_M = 30.0  # franja alrededor del contorno que también es jugable
MAX_WIDTH_M = 1600.0  # recorte por el este: el contorno oficial incluye el muelle del puerto
GROUND_PX_PER_M = 3  # resolución del suelo pintado
FLOOR_H = 3.3  # metros por planta

# Tipos de casilla (deben coincidir con CityMap.Cell en el juego)
VOID, BUILDING, ROAD, STREET, PLAZA, FILLER = 0, 1, 2, 3, 4, 5
WALKABLE = {ROAD, STREET, PLAZA}

# Ancho en metros de cada clase de vía
ROAD_WIDTH = {
    "trunk": 20, "trunk_link": 10, "primary": 16, "secondary": 12,
    "tertiary": 10, "unclassified": 7, "service": 4,
}
STREET_WIDTH = {
    "residential": 6, "living_street": 6, "pedestrian": 8, "footway": 3,
    "steps": 3, "cycleway": 3,
}

# Estilos de fachada (deben coincidir con building.gdshader)
S_NORMAL, S_PLAIN, S_GLASS, S_LATTICE = 0, 1, 2, 3

# Edificios emblemáticos: fragmento del nombre en OSM -> cómo se dibujan.
# "extra" activa un modelo adicional en landmarks.gd.
LANDMARKS = {
    "Museu d'Art Contemporani": {"label": "MACBA", "style": S_PLAIN, "color": (244, 244, 238)},
    "Barceló Raval": {"label": "Hotel Barceló Raval", "style": S_LATTICE, "color": (58, 58, 64), "height": 48},
    "Gran Teatre del Liceu": {"label": "Liceu", "style": S_PLAIN, "color": (196, 128, 96)},
    "Palau Güell": {"label": "Palau Güell", "style": S_PLAIN, "color": (128, 112, 100), "extra": "chimneys"},
    "Filmoteca de Catalunya": {"label": "Filmoteca", "style": S_PLAIN, "color": (160, 160, 152)},
    "Mercat de Sant Josep": {"label": "La Boqueria", "style": S_PLAIN, "color": (110, 150, 110), "height": 12, "extra": "market"},
    "Centre de Cultura Contemporània": {"label": "CCCB", "style": S_GLASS, "color": (90, 120, 150)},
    "Monument a Colom": {"label": "Colom", "extra": "colom", "skip": True},
    "Torre Colom": {"label": "", "style": S_GLASS, "color": (80, 100, 120), "height": 40},
    "Museu Marítim": {"label": "Drassanes", "style": S_PLAIN, "color": (176, 156, 124), "height": 14},
    "Palau de la Virreina": {"label": "Virreina", "style": S_PLAIN, "color": (200, 180, 150)},
    "Casa Bruno Cuadros": {"label": "Casa dels Paraigües", "style": S_NORMAL, "color": (220, 200, 160)},
    "Mercat de Sant Antoni": {"label": "Mercat de Sant Antoni", "style": S_PLAIN, "color": (150, 110, 80), "extra": "market"},
    "Seu del Districte de Ciutat Vella": {"label": "Districte", "style": S_PLAIN, "color": (210, 200, 180)},
    "Casa de la Misericòrdia": {"label": "Casa de la Misericòrdia", "style": S_PLAIN, "color": (196, 180, 150)},
    "Reial Acadèmia de Medicina": {"label": "Antic Hospital", "style": S_PLAIN, "color": (178, 160, 130)},
}
CHURCH_COLOR = (178, 162, 134)

# Rótulos de comercios sobre la puerta: (fondo, letras). Las marcas conocidas llevan sus colores.
BRAND_STYLE = {
    "McDonald's": ("da291c", "ffc72c"), "Burger King": ("f5ebdc", "d62300"), "KFC": ("a3080c", "ffffff"),
    "Starbucks": ("00704a", "ffffff"), "Dunkin'": ("ff671f", "ffffff"), "Telepizza": ("e30613", "ffffff"),
    "Domino's": ("006491", "ffffff"), "Subway": ("008c15", "ffc20e"), "100 Montaditos": ("3b2416", "f5e6c8"),
    "Pans & Company": ("7a0019", "ffffff"), "Wok to Walk": ("111111", "ffd200"), "Viena": ("c8102e", "ffffff"),
    "Dia": ("e30613", "ffffff"), "Caprabo": ("e2001a", "ffe600"), "Condis": ("e2001a", "ffffff"),
    "Carrefour": ("004e9f", "ffffff"), "Aldi": ("00205b", "ffd200"), "Lidl": ("0050aa", "fff000"),
    "Mercadona": ("00843d", "ffffff"), "Bonpreu": ("e30613", "ffffff"), "Spar": ("e30613", "ffffff"),
    "Coviran": ("e30613", "ffffff"), "Covirán": ("e30613", "ffffff"), "Consum": ("f39200", "ffffff"),
    "La Sirena": ("0072bc", "ffffff"), "Auchan": ("e30613", "ffffff"), "365": ("c8102e", "ffffff"),
    "Caixabank": ("009fe3", "ffffff"), "CaixaBank": ("009fe3", "ffffff"), "Banco Sabadell": ("006dff", "ffffff"),
    "BBVA": ("004481", "ffffff"), "Santander": ("ec0000", "ffffff"), "Bankinter": ("ff6200", "ffffff"),
    "Western Union": ("ffdd00", "111111"), "Euronet": ("004b87", "ffffff"), "Correos": ("ffcc00", "003366"),
    "Zara": ("111111", "ffffff"), "Pull & Bear": ("1a1a1a", "ffffff"), "Lefties": ("111111", "ffffff"),
    "Humana": ("e2001a", "ffffff"), "Orange": ("ff7900", "111111"), "Vodafone": ("e60000", "ffffff"),
    "Movistar": ("019df4", "ffffff"), "Phone House": ("e30613", "ffffff"), "Druni": ("e5007d", "ffffff"),
    "Primor": ("111111", "ffffff"), "Natura": ("4a3b2a", "f5e6c8"), "ALE-HOP": ("ffd200", "111111"),
}
CATEGORY_STYLE = {  # categoría -> (fondo, letras, toldo)
    "restaurant": ("7a2a20", "fff0d0", True), "bar": ("3a2a1a", "f0c060", True), "pub": ("2a1a10", "f0c060", True),
    "cafe": ("5a3a28", "f5e6c8", True), "ice_cream": ("e890b0", "ffffff", True), "fast_food": ("c0452f", "ffffff", False),
    "nightclub": ("4a1060", "ff90ff", False), "pharmacy": ("1fae5a", "ffffff", False),
    "bank": ("2f5fae", "ffffff", False), "bureau_de_change": ("2f5fae", "ffe080", False),
    "money_transfer": ("2f5fae", "ffe080", False), "hotel": ("222222", "e8d8a8", False),
    "hostel": ("2a3a4a", "e8e0c8", False), "supermarket": ("2f8f4f", "ffffff", False),
    "convenience": ("2f7f3f", "ffffff", False), "greengrocer": ("5a8a2a", "ffffff", True),
    "bakery": ("b07a3a", "fff6e0", True), "pastry": ("c08a9a", "ffffff", True), "butcher": ("8a1a1a", "ffffff", False),
    "clothes": ("1a1a1a", "f0f0f0", False), "shoes": ("1a1a1a", "f0f0f0", False),
    "theatre": ("6a0a1a", "ffd890", False), "cinema": ("6a0a1a", "ffd890", False),
}
STOREFRONT_AMENITIES = {
    "restaurant", "bar", "pub", "cafe", "fast_food", "ice_cream", "nightclub", "pharmacy", "bank",
    "bureau_de_change", "money_transfer", "theatre", "cinema", "post_office", "library", "clinic",
}


def storefront_style(tags: dict) -> tuple[str, str, str, bool] | None:
    """Comercio de OSM -> (texto, fondo, letras, toldo) para su rótulo, o None si no lleva."""
    a, s, tourism = tags.get("amenity"), tags.get("shop"), tags.get("tourism")
    if a not in STOREFRONT_AMENITIES and not s and tourism not in ("hotel", "hostel"):
        return None
    brand = tags.get("brand", "")
    text = brand or tags.get("name", "")
    if not text:
        return None
    category = tourism if tourism in ("hotel", "hostel") else (s if s and s in CATEGORY_STYLE else a)
    bg, fg, awning = CATEGORY_STYLE.get(category, (None, "ffffff", False))
    for key, colors in BRAND_STYLE.items():
        if key.lower() in brand.lower() or (not brand and text.lower().startswith(key.lower())):
            bg, fg = colors
            text = brand or text
            break
    if a == "pharmacy":
        text = "✚ " + text
    if bg is None:
        # resto de tiendas: un color apagado distinto para cada nombre
        hue = (sum(map(ord, text)) * 37 % 360) / 360.0
        bg = "".join(f"{round(c * 255):02x}" for c in colorsys.hsv_to_rgb(hue, 0.55, 0.45))
    if len(text) > 24:
        text = text[:23].rstrip() + "…"
    return text, bg, fg, awning


def poi_kind(tags: dict) -> str | None:
    """Puntos de interés de OSM -> tipo de lugar del juego."""
    a = tags.get("amenity")
    s = tags.get("shop")
    name = tags.get("name", "")
    if "Baluard" in name:
        return "cas"
    if a == "police":
        return "comisaria"
    if a == "pharmacy":
        return "farmacia"
    if a in ("bar", "pub", "nightclub"):
        return "bar"
    if a == "fast_food":
        return "kebab"
    if a in ("atm", "bank"):
        return "cajero"
    if a == "place_of_worship":
        return "iglesia"
    if a == "bench":
        return "banco"
    if a in ("social_facility", "shelter", "social_centre"):
        return "albergue"
    if a in ("clinic", "doctors", "hospital"):
        return "cap"
    if s in ("supermarket", "convenience", "alcohol"):
        return "super"
    if s in ("second_hand", "pawnbroker", "mobile_phone", "electronics"):
        return "compraventa"
    return None


def join_rings(ways: list[list[tuple[float, float]]]) -> list[list[tuple[float, float]]]:
    """Encadena tramos de contorno por sus extremos hasta cerrar anillos."""
    pending = [list(w) for w in ways]
    rings = []
    while pending:
        ring = pending.pop(0)
        changed = True
        while ring[0] != ring[-1] and changed:
            changed = False
            for i, w in enumerate(pending):
                if w[0] == ring[-1]:
                    ring += w[1:]
                elif w[-1] == ring[-1]:
                    ring += list(reversed(w))[1:]
                elif w[-1] == ring[0]:
                    ring = w[:-1] + ring
                elif w[0] == ring[0]:
                    ring = list(reversed(w))[:-1] + ring
                else:
                    continue
                pending.pop(i)
                changed = True
                break
        rings.append(ring)
    return rings


def parse_float(v, default: float) -> float:
    try:
        return float(str(v).replace("m", "").strip())
    except (TypeError, ValueError):
        return default


def polygon_area(pts: list[tuple[float, float]]) -> float:
    return 0.5 * sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]))


def landmark_for(name: str) -> dict | None:
    for key, spec in LANDMARKS.items():
        if key in name:
            return spec
    return None


def sample_polyline(pts: list[tuple[float, float]], step: float) -> list[tuple[float, float, float, float]]:
    """Puntos cada `step` metros a lo largo de una línea, con su dirección (x, y, dx, dy)."""
    out = []
    carry = 0.0
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        seg = math.hypot(x2 - x1, y2 - y1)
        if seg == 0:
            continue
        dx, dy = (x2 - x1) / seg, (y2 - y1) / seg
        d = carry
        while d < seg:
            out.append((x1 + dx * d, y1 + dy * d, dx, dy))
            d += step
        carry = d - seg
    return out


def main() -> None:
    data = json.loads(SRC.read_text(encoding="utf-8"))
    elements = data["elements"]
    rel = next(e for e in elements if e["type"] == "relation" and e.get("tags", {}).get("boundary") == "administrative")
    outer = [
        [(p["lon"], p["lat"]) for p in m["geometry"]]
        for m in rel["members"]
        if m["type"] == "way" and m["role"] == "outer"
    ]
    boundary = max(join_rings(outer), key=len)

    lon0 = sum(p[0] for p in boundary) / len(boundary)
    lat0 = sum(p[1] for p in boundary) / len(boundary)
    kx = math.cos(math.radians(lat0)) * 111320.0
    ky = 110540.0

    def to_m(lon: float, lat: float) -> tuple[float, float]:
        return (lon - lon0) * kx, -(lat - lat0) * ky

    ways = [e for e in elements if e["type"] == "way" and "geometry" in e]

    # Ángulo dominante de las calles (módulo 90º, ponderado por longitud)
    hist: Counter[int] = Counter()
    for w in ways:
        if "highway" not in w.get("tags", {}):
            continue
        pts = [to_m(p["lon"], p["lat"]) for p in w["geometry"]]
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            ang = math.degrees(math.atan2(y2 - y1, x2 - x1)) % 90
            hist[int(ang) % 90] += math.hypot(x2 - x1, y2 - y1)
    smooth = {a: sum(hist[(a + d) % 90] for d in (-2, -1, 0, 1, 2)) for a in range(90)}
    rot = math.radians(max(smooth, key=smooth.get))
    cos_r, sin_r = math.cos(-rot), math.sin(-rot)

    def rotm(lon: float, lat: float) -> tuple[float, float]:
        x, y = to_m(lon, lat)
        return x * cos_r - y * sin_r, x * sin_r + y * cos_r

    bpts = [rotm(*p) for p in boundary]
    minx = min(p[0] for p in bpts) - MARGIN_M
    miny = min(p[1] for p in bpts) - MARGIN_M
    w_cells = int(math.ceil((max(p[0] for p in bpts) + MARGIN_M - minx) / CELL_M))
    h_cells = int(math.ceil((max(p[1] for p in bpts) + MARGIN_M - miny) / CELL_M))
    full_w_cells = w_cells

    def meters(lon: float, lat: float) -> tuple[float, float]:
        """Posición en metros dentro del mapa."""
        x, y = rotm(lon, lat)
        return x - minx, y - miny

    def geom_m(geom) -> list[tuple[float, float]]:
        return [meters(p["lon"], p["lat"]) for p in geom]

    def to_cells(pts):
        return [(x / CELL_M, y / CELL_M) for x, y in pts]

    # ------------------------------------------------------------ máscaras
    inside = Image.new("L", (w_cells, h_cells), 0)
    ImageDraw.Draw(inside).polygon(to_cells([(x - minx, y - miny) for x, y in bpts]), fill=255)
    k = int(MARGIN_M / CELL_M) * 2 + 1
    playable = inside.filter(ImageFilter.MaxFilter(k))
    w_cells = min(w_cells, int(MAX_WIDTH_M / CELL_M))
    width_m, height_m = w_cells * CELL_M, h_cells * CELL_M

    def in_map(x: float, y: float) -> bool:
        cx, cy = int(x / CELL_M), int(y / CELL_M)
        return 0 <= cx < w_cells and 0 <= cy < h_cells and playable.getpixel((cx, cy)) > 0

    # ------------------------------------------------------------ edificios
    footprints = []  # (id, tags, [(x, y) metros])
    for w in ways:
        t = w.get("tags", {})
        if "building" in t and t.get("building") != "roof" and len(w["geometry"]) >= 4:
            footprints.append((w["id"], t, geom_m(w["geometry"])))
    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "relation" and "building" in t and t.get("type") == "multipolygon":
            rings = join_rings([
                [(p["lon"], p["lat"]) for p in m["geometry"]]
                for m in e["members"] if m["type"] == "way" and m["role"] == "outer" and "geometry" in m
            ])
            for ring in rings:
                if len(ring) >= 4 and ring[0] == ring[-1]:
                    footprints.append((e["id"], t, [meters(lon, lat) for lon, lat in ring]))

    buildings = []
    labels = []
    statues = []
    for bid, t, pts in footprints:
        pts = pts[:-1] if pts[0] == pts[-1] else pts
        if len(pts) < 3:
            continue
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        if not in_map(cx, cy):
            continue
        name = t.get("name", "")
        lm = landmark_for(name) if name else None
        levels = int(parse_float(t.get("building:levels"), 4 + bid % 3))
        levels = max(1, min(levels, 20))
        height = parse_float(t.get("height"), levels * FLOOR_H + 1.0)
        style, color, extra, label = S_NORMAL, None, "", ""
        is_church = t.get("building") in ("church", "chapel", "cathedral") or t.get("amenity") == "place_of_worship"
        if lm:
            if lm.get("skip"):
                statues.append({"kind": lm["extra"], "x": round(cx, 2), "z": round(cy, 2)})
                labels.append({"text": lm["label"], "x": round(cx, 2), "z": round(cy, 2), "y": 62.0})
                continue
            style = lm.get("style", S_NORMAL)
            color = lm.get("color")
            height = lm.get("height", height)
            extra = lm.get("extra", "")
            label = lm.get("label", "")
        elif is_church:
            style, color, extra, label = S_PLAIN, CHURCH_COLOR, "belltower", name
            height = max(height, 14.0)
        if polygon_area(pts) < 0:
            pts = list(reversed(pts))  # siempre en el mismo sentido de giro
        b = {
            "p": [[round(x, 2), round(y, 2)] for x, y in pts],
            "h": round(height, 1),
            "lv": max(1, round((height - 1.0) / FLOOR_H)),
            "s": style,
            "seed": bid % 997,
        }
        if color:
            b["c"] = list(color)
        if extra:
            b["x"] = extra
        buildings.append(b)
        if label:
            labels.append({"text": label, "x": round(cx, 2), "z": round(cy, 2), "y": round(height + 4, 1)})

    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "node" and t.get("tourism") == "artwork" and "Gat" in t.get("name", "") and "Botero" in t.get("name", ""):
            x, y = meters(e["lon"], e["lat"])
            statues.append({"kind": "gat", "x": round(x, 2), "z": round(y, 2)})
            labels.append({"text": "Gat de Botero", "x": round(x, 2), "z": round(y, 2), "y": 8.0})

    # ------------------------------------------------------------ cuadrícula de navegación
    S = 1.0 / CELL_M
    grid = Image.new("L", (full_w_cells, h_cells), FILLER)
    g = ImageDraw.Draw(grid)
    for b in buildings:
        g.polygon([(x * S, y * S) for x, y in b["p"]], fill=BUILDING)

    def is_area(t: dict) -> bool:
        return (t.get("area") == "yes" or t.get("place") == "square"
                or t.get("leisure") in ("park", "playground") or t.get("name") == "La Rambla")

    area_ways = [w for w in ways if is_area(w.get("tags", {})) and len(w["geometry"]) >= 4 and "building" not in w.get("tags", {})]
    for w in area_ways:
        g.polygon(to_cells(geom_m(w["geometry"])), fill=PLAZA)

    street_ways = []  # (tags, puntos en metros, ancho, tipo)
    for kind, widths in ((STREET, STREET_WIDTH), (ROAD, ROAD_WIDTH)):
        for w in ways:
            t = w.get("tags", {})
            hw = t.get("highway")
            if hw not in widths or t.get("area") == "yes" or t.get("tunnel") == "yes" or t.get("indoor") == "yes":
                continue
            street_ways.append((t, geom_m(w["geometry"]), widths[hw], kind))
    for t, pts, wm, kind in street_ways:
        width = max(1, round(wm / CELL_M))
        cpts = to_cells(pts)
        g.line(cpts, fill=kind, width=width)
        if width > 1:
            for x, y in cpts:
                r = width / 2
                g.ellipse([x - r, y - r, x + r, y + r], fill=kind)
    # Los edificios mandan sobre el ancho estimado de las calles (así nadie anda por dentro
    # de una fachada), pero el eje de cada calle queda libre para no cortar callejones.
    for b in buildings:
        g.polygon([(x * S, y * S) for x, y in b["p"]], fill=BUILDING)
    # casillas bajo un edificio, aunque luego las cruce un pasaje (para no poner rótulos dentro)
    under_building = [c == BUILDING for c in grid.get_flattened_data()]
    for t, pts, wm, kind in street_ways:
        g.line(to_cells(pts), fill=kind, width=1)

    # Fuera del barrio no se puede jugar; en la franja exterior solo cuentan calles y edificios
    void = Image.new("L", grid.size, VOID)
    grid = Image.composite(grid, void, playable)
    margin_fill = grid.point(lambda c: 255 if c == FILLER else 0)
    outside = inside.point(lambda v: 255 - v)
    margin_fill = Image.composite(margin_fill, Image.new("L", grid.size, 0), outside)
    grid = Image.composite(void, grid, margin_fill)
    grid, inside_c = grid.crop((0, 0, w_cells, h_cells)), inside.crop((0, 0, w_cells, h_cells))

    cells = list(grid.get_flattened_data())
    in_raval = list(inside_c.get_flattened_data())
    open_sidewalks(cells, w_cells, h_cells)

    # Las calles estrechas rasterizadas a veces solo se tocan en diagonal, y el juego no deja
    # cortar esquinas: se abre una de las dos casillas ortogonales para unirlas.
    for y in range(h_cells - 1):
        for x in range(w_cells - 1):
            a, b = y * w_cells + x, y * w_cells + x + 1
            c, d = a + w_cells, b + w_cells
            for p, q, o1, o2 in ((a, d, b, c), (b, c, a, d)):
                if cells[p] in WALKABLE and cells[q] in WALKABLE and cells[o1] not in WALKABLE and cells[o2] not in WALKABLE:
                    if cells[o1] != VOID:
                        cells[o1] = STREET
                    elif cells[o2] != VOID:
                        cells[o2] = STREET

    # Solo vale la red de calles principal; las islas sueltas pasan a ser relleno edificado
    comp = [-1] * len(cells)
    best, best_size = -1, 0
    for start in range(len(cells)):
        if cells[start] not in WALKABLE or comp[start] >= 0:
            continue
        comp[start] = start
        stack, size = [start], 0
        while stack:
            i = stack.pop()
            size += 1
            x, y = i % w_cells, i // w_cells
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w_cells and 0 <= ny < h_cells:
                    j = ny * w_cells + nx
                    if cells[j] in WALKABLE and comp[j] < 0:
                        comp[j] = start
                        stack.append(j)
        if size > best_size:
            best, best_size = start, size
    islands = 0
    for i in range(len(cells)):
        if cells[i] in WALKABLE and comp[i] != best:
            cells[i] = FILLER if in_raval[i] else VOID
            islands += 1
    print(f"Red de calles: {best_size} casillas; {islands} casillas aisladas eliminadas")

    def nearest_walkable(cx: int, cy: int, radius: int = 24) -> tuple[int, int] | None:
        for r in range(radius + 1):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    x, y = cx + dx, cy + dy
                    if 0 <= x < w_cells and 0 <= y < h_cells and cells[y * w_cells + x] in WALKABLE:
                        return x, y
        return None

    # ------------------------------------------------------------ lugares
    pois = []
    for e in elements:
        t = e.get("tags", {})
        kind = poi_kind(t)
        if not kind:
            continue
        if e["type"] == "node":
            x, y = meters(e["lon"], e["lat"])
        elif "geometry" in e and e["type"] == "way":
            pts = geom_m(e["geometry"])
            x, y = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
        else:
            continue
        cx, cy = int(x / CELL_M), int(y / CELL_M)
        if not (0 <= cx < w_cells and 0 <= cy < h_cells) or not in_raval[cy * w_cells + cx]:
            continue
        spot = nearest_walkable(cx, cy)
        if spot:
            pois.append({"kind": kind, "name": t.get("name", ""), "x": spot[0], "y": spot[1]})
    # asociaciones cannábicas: son privadas y no salen en OSM; van en su propio archivo
    for c in json.loads(CLUBS.read_text(encoding="utf-8"))["clubs"]:
        x, y = meters(c["lon"], c["lat"])
        cx, cy = int(x / CELL_M), int(y / CELL_M)
        if not (0 <= cx < w_cells and 0 <= cy < h_cells) or not in_raval[cy * w_cells + cx]:
            continue
        spot = nearest_walkable(cx, cy)
        if spot:
            pois.append({"kind": "club", "name": c["nombre"], "x": spot[0], "y": spot[1]})

    # ------------------------------------------------------------ calles con nombre
    streets = []  # muestras para saber en qué calle estás
    seen_samples = set()
    named = defaultdict(list)
    for t, pts, wm, kind in street_ways:
        if t.get("name"):
            named[t["name"]].append((pts, wm))
            for x, y, _, _ in sample_polyline(pts, 8.0):
                cx, cy = int(x / CELL_M), int(y / CELL_M)
                if 0 <= cx < w_cells and 0 <= cy < h_cells and (cx, cy) not in seen_samples:
                    seen_samples.add((cx, cy))
                    streets.append({"name": t["name"], "x": cx, "y": cy})

    # Placas de calle de mármol: en la pared más cercana a puntos de la calle
    BUCKET = 20.0
    edges = defaultdict(list)
    for b in buildings:
        p = b["p"]
        for (x1, y1), (x2, y2) in zip(p, p[1:] + p[:1]):
            for bx in range(int(min(x1, x2) // BUCKET), int(max(x1, x2) // BUCKET) + 1):
                for by in range(int(min(y1, y2) // BUCKET), int(max(y1, y2) // BUCKET) + 1):
                    edges[(bx, by)].append((x1, y1, x2, y2))

    def nearest_wall(px: float, py: float, max_d: float):
        best_hit, best_d = None, max_d
        bx, by = int(px // BUCKET), int(py // BUCKET)
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                for x1, y1, x2, y2 in edges.get((bx + ox, by + oy), ()):
                    ex, ey = x2 - x1, y2 - y1
                    l2 = ex * ex + ey * ey
                    if l2 < 4.0:  # paredes de menos de 2 m: esquinas raras
                        continue
                    t = max(0.1, min(0.9, ((px - x1) * ex + (py - y1) * ey) / l2))
                    qx, qy = x1 + ex * t, y1 + ey * t
                    d = math.hypot(px - qx, py - qy)
                    if d < best_d:
                        best_d, best_hit = d, (qx, qy, ex, ey)
        return best_hit

    signs = []
    for name, parts in named.items():
        placed = []
        for pts, wm in parts:
            total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:]))
            if total < 15:
                continue
            for x, y, dx, dy in sample_polyline(pts, 45.0)[1:] or sample_polyline(pts, total / 2)[1:2]:
                if any(math.hypot(x - sx, y - sy) < 50 for sx, sy in placed):
                    continue
                hit = nearest_wall(x, y, wm / 2 + 8)
                if not hit:
                    continue
                qx, qy, ex, ey = hit
                el = math.hypot(ex, ey)
                nx, ny = -ey / el, ex / el
                if (x - qx) * nx + (y - qy) * ny < 0:
                    nx, ny = -nx, -ny
                placed.append((x, y))
                signs.append({"name": name, "x": round(qx + nx * 0.06, 2), "z": round(qy + ny * 0.06, 2),
                              "nx": round(nx, 3), "nz": round(ny, 3)})

    # ------------------------------------------------------------ rótulos de comercios
    # En la pared más cercana al comercio que dé a una casilla transitable (la puerta a la calle)
    def storefront_wall(px: float, py: float, max_d: float = 14.0):
        best_hit, best_d = None, max_d
        bx, by = int(px // BUCKET), int(py // BUCKET)
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                for x1, y1, x2, y2 in edges.get((bx + ox, by + oy), ()):
                    ex, ey = x2 - x1, y2 - y1
                    el = math.hypot(ex, ey)
                    if el < 2.5:
                        continue
                    t = max(0.15, min(0.85, ((px - x1) * ex + (py - y1) * ey) / (el * el)))
                    qx, qy = x1 + ex * t, y1 + ey * t
                    d = math.hypot(px - qx, py - qy)
                    if d >= best_d:
                        continue
                    for nx, ny in ((-ey / el, ex / el), (ey / el, -ex / el)):
                        cx, cy = int((qx + nx * 1.5) / CELL_M), int((qy + ny * 1.5) / CELL_M)
                        if (0 <= cx < w_cells and 0 <= cy < h_cells and cells[cy * w_cells + cx] in WALKABLE
                                and not under_building[cy * full_w_cells + cx]):
                            best_d, best_hit = d, (qx, qy, nx, ny, el)
                            break
        return best_hit

    storefronts = []
    for e in elements:
        t = e.get("tags", {})
        style = storefront_style(t)
        if not style:
            continue
        if e["type"] == "node":
            x, y = meters(e["lon"], e["lat"])
        elif e["type"] == "way" and "geometry" in e:
            pts = geom_m(e["geometry"])
            x, y = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
        else:
            continue
        if not in_map(x, y) or x >= width_m:
            continue
        hit = storefront_wall(x, y)
        if not hit:
            continue
        qx, qy, nx, ny, el = hit
        if any(math.hypot(qx - s["x"], qy - s["z"]) < 2.5 for s in storefronts):
            continue
        text, bg, fg, awning = style
        width = min(max(1.8, 0.36 * len(text) + 0.6), el * 0.8, 7.0)
        sf = {"t": text, "bg": bg, "fg": fg, "w": round(width, 2),
              "x": round(qx + nx * 0.02, 2), "z": round(qy + ny * 0.02, 2), "nx": round(nx, 3), "nz": round(ny, 3)}
        if awning:
            sf["a"] = 1
        storefronts.append(sf)

    # ------------------------------------------------------------ árboles
    trees = []
    for e in elements:
        t = e.get("tags", {})
        if e["type"] == "node" and t.get("natural") == "tree":
            pts = [meters(e["lon"], e["lat"])]
        elif e["type"] == "way" and t.get("natural") == "tree_row" and "geometry" in e:
            pts = [(x, y) for x, y, _, _ in sample_polyline(geom_m(e["geometry"]), 8.0)]
        else:
            continue
        for x, y in pts:
            if in_map(x, y) and x < width_m:
                palm = "Palmera" in t.get("taxon:es", "") or "Phoenix" in t.get("genus", "") or "Washingtonia" in t.get("genus", "")
                trees.append([round(x, 2), round(y, 2), 1 if palm else 0])

    # ------------------------------------------------------------ suelo pintado
    paint_ground(width_m, height_m, grid, buildings, area_ways, street_ways, geom_m)

    rows = ["".join(str(cells[y * w_cells + x]) for x in range(w_cells)) for y in range(h_cells)]
    out = {
        "name": "el Raval",
        "source": "© OpenStreetMap contributors (ODbL)",
        "cell_m": CELL_M,
        "rotation_deg": round(math.degrees(rot), 1),
        "width": w_cells,
        "height": h_cells,
        "cells": rows,
        "pois": pois,
        "streets": streets,
        "buildings": buildings,
        "labels": labels,
        "statues": statues,
        "signs": signs,
        "storefronts": storefronts,
        "trees": trees,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    palette = {VOID: (15, 15, 20), BUILDING: (170, 110, 80), ROAD: (70, 70, 75),
               STREET: (190, 180, 160), PLAZA: (120, 160, 90), FILLER: (120, 80, 60)}
    img = Image.new("RGB", (w_cells, h_cells))
    img.putdata([palette[c] for c in cells])
    d = ImageDraw.Draw(img)
    for p in pois:
        d.point((p["x"], p["y"]), fill=(255, 0, 255))
    img.resize((w_cells * 3, h_cells * 3), Image.NEAREST).save(PREVIEW)

    counts = Counter(cells)
    print(f"{w_cells}x{h_cells} casillas, rotación {math.degrees(rot):.1f}º")
    print("tipos:", dict(sorted(counts.items())))
    print(f"{len(buildings)} edificios, {len(labels)} rótulos, {len(statues)} estatuas, "
          f"{len(signs)} placas, {len(storefronts)} comercios, {len(trees)} árboles, {len(streets)} muestras de calle, {len(pois)} PDI")
    print("PDI:", dict(Counter(p['kind'] for p in pois)))


def open_sidewalks(cells: list[int], w: int, h: int) -> None:
    """Convierte en acera el relleno que queda entre las calles y las fachadas.

    El ancho estimado de cada calle casi nunca llega hasta las fachadas reales, y lo que
    quedaba en medio era relleno: bloques de edificio de 2 m que salían sobre la acera.
    Solo se abre el relleno que está entre la calle y una fachada real: la suma de las
    distancias a la calle y al edificio de detrás (sin cruzar la calle) no pasa de MAX_GAP.
    Así las manzanas que OSM no tiene dibujadas siguen siendo bloques. La búsqueda desde
    la calle no se cuela por rendijas entre edificios (las casillas pegadas a un edificio
    no dejan pasar), y al final se ensancha DILATE veces junto a las fachadas.
    Los patios de manzana, cerrados por edificios, siguen siendo relleno.
    """
    from collections import deque

    MAX_GAP, DILATE = 8, 2

    def neighbors4(i: int):
        x, y = i % w, i // w
        if x > 0:
            yield i - 1
        if x < w - 1:
            yield i + 1
        if y > 0:
            yield i - w
        if y < h - 1:
            yield i + w

    near_wall = [False] * len(cells)
    for i, c in enumerate(cells):
        if c != FILLER:
            continue
        x, y = i % w, i // w
        near_wall[i] = any(
            cells[ny * w + nx] == BUILDING
            for ny in range(max(0, y - 1), min(h, y + 2))
            for nx in range(max(0, x - 1), min(w, x + 2))
        )

    def distances(sources: set[int], passable) -> list[int]:
        dist = [-1] * len(cells)
        queue = deque()
        for i, c in enumerate(cells):
            if c in sources:
                dist[i] = 0
                queue.append(i)
        while queue:
            i = queue.popleft()
            if dist[i] >= MAX_GAP:
                continue
            for j in neighbors4(i):
                if dist[j] < 0 and passable(j):
                    dist[j] = dist[i] + 1
                    queue.append(j)
        return dist

    to_building = distances({BUILDING}, lambda j: cells[j] == FILLER)
    to_street = distances(WALKABLE, lambda j: cells[j] == FILLER and not near_wall[j])
    opened = [i for i in range(len(cells))
              if to_street[i] > 0 and to_building[i] > 0 and to_street[i] + to_building[i] <= MAX_GAP]
    for i in opened:
        cells[i] = STREET
    for _ in range(DILATE):
        edge = [i for i, c in enumerate(cells)
                if c == FILLER and 0 < to_building[i] <= DILATE and any(cells[j] in WALKABLE for j in neighbors4(i))]
        for i in edge:
            cells[i] = STREET
        opened += edge
    print(f"Aceras: {len(opened)} casillas de relleno abiertas")


def paint_ground(width_m, height_m, grid, buildings, area_ways, street_ways, geom_m) -> None:
    """Pinta el suelo a GROUND_PX_PER_M píxeles por metro: aceras, calles, plazas y parques."""
    K = GROUND_PX_PER_M
    size = (int(width_m * K), int(height_m * K))
    playable = grid.point(lambda c: 0 if c == 0 else 255).resize(size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(K * 3))
    img = Image.new("RGB", size, (24, 22, 28))
    acera = Image.new("RGB", size, (196, 186, 166))
    img = Image.composite(acera, img, playable.point(lambda v: 255 if v > 100 else 0))
    d = ImageDraw.Draw(img)

    def px(pts):
        return [(x * K, y * K) for x, y in pts]

    for w in area_ways:
        t = w.get("tags", {})
        color = (118, 148, 86) if t.get("leisure") in ("park", "playground") else (212, 202, 180)
        d.polygon(px(geom_m(w["geometry"])), fill=color)
    for b in buildings:
        d.polygon(px(b["p"]), fill=(70, 58, 52))
    # calles peatonales y luego calzadas con bordillo y raya central
    for t, pts, wm, kind in street_ways:
        if kind == STREET and t.get("highway") not in ("footway", "steps"):
            d.line(px(pts), fill=(184, 172, 150), width=int(wm * K), joint="curve")
    for t, pts, wm, kind in street_ways:
        if kind == ROAD:
            d.line(px(pts), fill=(150, 146, 140), width=int((wm + 1) * K), joint="curve")
    for t, pts, wm, kind in street_ways:
        if kind == ROAD:
            d.line(px(pts), fill=(66, 66, 72), width=int((wm - 1) * K), joint="curve")
    for t, pts, wm, kind in street_ways:
        if kind == ROAD and wm >= 10:
            for x, y, dx, dy in sample_polyline(pts, 6.0):
                d.line([(x * K, y * K), ((x + dx * 3) * K, (y + dy * 3) * K)], fill=(230, 226, 210), width=K // 2 + 1)
    GROUND.parent.mkdir(parents=True, exist_ok=True)
    img.save(GROUND, optimize=True)
    print(f"Suelo {GROUND.name}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
