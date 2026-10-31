"""Genera las texturas caricaturizadas de fachada: game/assets/facade.png

Atlas de 4x2 módulos de 128x128 px. Cada módulo es un vano de fachada
(~3,5 m de ancho por una planta de alto):

  fila 0 (plantas altas): 0 persianas abiertas + balcón, 1 ropa tendida,
                           2 persianas cerradas + macetas, 3 ventana con aire acondicionado
  fila 1 (planta baja):   0 persiana metálica con grafitis, 1 tienda con toldo,
                           2 portal, 3 bar

Codificación del canal alfa (la interpreta building.gdshader):
  alfa 0   -> pared: se tiñe con el color del edificio; R = luminosidad (128 = 1.0)
  alfa 128 -> cristal: se ilumina de noche
  alfa 255 -> detalle opaco con su propio color

Uso: python tools/make_textures.py
"""
import pathlib
import random

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "facade.png"
M = 128  # tamaño de cada módulo

rng = random.Random(7)

WALL = (128, 128, 128, 0)
SHUTTER_GREEN = (58, 110, 70, 255)
SHUTTER_DARK = (36, 76, 48, 255)
GLASS = (52, 70, 92, 128)
IRON = (28, 28, 32, 255)
OUTLINE = (24, 20, 20, 255)


def wall_noise(d: ImageDraw.ImageDraw, ox: int, oy: int, ground: bool) -> None:
    """Pared con manchas de humedad y una cornisa: solo varía la luminosidad (canal R)."""
    for _ in range(260):
        x, y = ox + rng.randrange(M), oy + rng.randrange(M)
        v = rng.randint(112, 140)
        d.point((x, y), fill=(v, v, v, 0))
    for _ in range(3):  # manchas de humedad
        x, y = ox + rng.randrange(M - 30), oy + rng.randrange(60, M - 10)
        d.ellipse([x, y, x + rng.randint(14, 30), y + rng.randint(8, 18)], fill=(112, 112, 112, 0))
    # cornisa / línea de forjado arriba del módulo
    d.rectangle([ox, oy, ox + M - 1, oy + 5], fill=(150, 150, 150, 0))
    d.line([ox, oy + 6, ox + M - 1, oy + 6], fill=(96, 96, 96, 0), width=2)
    if ground:  # zócalo
        d.rectangle([ox, oy + M - 14, ox + M - 1, oy + M - 1], fill=(100, 100, 100, 0))


def window(d, ox, oy, shutters: str, balcony: bool, laundry: bool, pots: bool, ac: bool) -> None:
    x0, x1 = ox + 40, ox + 88
    y0, y1 = oy + 22, oy + 100
    if ac:
        x0, x1, y1 = ox + 44, ox + 84, oy + 76
    d.rectangle([x0 - 3, y0 - 3, x1 + 3, y1 + 3], fill=OUTLINE)
    if shutters == "closed":
        d.rectangle([x0, y0, x1, y1], fill=SHUTTER_GREEN)
        for y in range(y0 + 4, y1, 6):
            d.line([x0, y, x1, y], fill=SHUTTER_DARK, width=2)
        d.line([(x0 + x1) // 2, y0, (x0 + x1) // 2, y1], fill=OUTLINE, width=2)
    else:
        d.rectangle([x0, y0, x1, y1], fill=GLASS)
        d.line([(x0 + x1) // 2, y0, (x0 + x1) // 2, y1], fill=OUTLINE, width=3)
        d.line([x0, y0 + 26, x1, y0 + 26], fill=OUTLINE, width=2)
        if shutters == "open":  # hojas de persiana abiertas a los lados
            for sx in (x0 - 22, x1 + 4):
                d.rectangle([sx, y0, sx + 18, y1], fill=SHUTTER_GREEN, outline=OUTLINE, width=2)
                for y in range(y0 + 4, y1, 6):
                    d.line([sx + 2, y, sx + 16, y], fill=SHUTTER_DARK, width=1)
    if ac:
        d.rectangle([ox + 50, oy + 82, ox + 80, oy + 102], fill=(214, 214, 206, 255), outline=OUTLINE, width=2)
        d.ellipse([ox + 54, oy + 85, ox + 68, oy + 99], fill=(120, 120, 116, 255))
        d.line([ox + 64, oy + 102, ox + 64, oy + 126], fill=(40, 40, 40, 255), width=2)  # goteo
    if balcony:
        d.rectangle([ox + 22, oy + 100, ox + 106, oy + 106], fill=(150, 146, 140, 255), outline=OUTLINE)
        d.line([ox + 24, oy + 76, ox + 104, oy + 76], fill=IRON, width=3)
        for x in range(ox + 26, ox + 104, 7):
            d.line([x, oy + 76, x, oy + 100], fill=IRON, width=2)
    if laundry:
        d.line([ox + 18, oy + 50, ox + 110, oy + 50], fill=(220, 220, 220, 255), width=1)
        x = ox + 22
        for _ in range(5):
            w = rng.randint(10, 16)
            color = rng.choice([(220, 60, 60), (240, 240, 230), (60, 90, 200), (240, 200, 40), (90, 160, 90), (230, 120, 170)])
            d.rectangle([x, oy + 50, x + w, oy + 50 + rng.randint(14, 26)], fill=color + (255,), outline=OUTLINE)
            x += w + 3
    if pots:
        for x in (ox + 28, ox + 58, ox + 88):
            d.rectangle([x, oy + 90, x + 14, oy + 100], fill=(176, 92, 60, 255), outline=OUTLINE)
            d.ellipse([x - 4, oy + 78, x + 18, oy + 94], fill=(70, 140, 60, 255), outline=OUTLINE)
            d.point((x + 6, oy + 82), fill=(230, 60, 80, 255))


def graffiti(d, x0, y0, x1, y1) -> None:
    for _ in range(3):
        color = rng.choice([(230, 50, 140), (40, 200, 220), (250, 220, 40), (40, 40, 40), (120, 230, 80), (240, 240, 240)])
        pts = [(rng.randint(x0, x1), rng.randint(y0, y1)) for _ in range(5)]
        d.line(pts, fill=color + (255,), width=rng.randint(3, 6), joint="curve")


def ground_floor(d, ox, oy, kind: int) -> None:
    x0, x1 = ox + 14, ox + 114
    y0, y1 = oy + 24, oy + M - 14
    if kind == 0:  # persiana metálica con grafitis
        d.rectangle([x0 - 3, y0 - 3, x1 + 3, y1], fill=OUTLINE)
        d.rectangle([x0, y0, x1, y1], fill=(150, 152, 156, 255))
        for y in range(y0 + 3, y1, 5):
            d.line([x0, y, x1, y], fill=(118, 120, 124, 255), width=1)
        d.rectangle([x0, y0, x1, y0 + 8], fill=(90, 92, 96, 255))
        graffiti(d, x0 + 4, y0 + 14, x1 - 4, y1 - 6)
    elif kind == 1:  # tienda con toldo a rayas
        d.rectangle([x0 - 3, y0 + 10, x1 + 3, y1], fill=OUTLINE)
        d.rectangle([x0, y0 + 13, x1, y1], fill=GLASS)
        d.rectangle([x0 + 40, y0 + 13, x0 + 62, y1], fill=(110, 80, 60, 255), outline=OUTLINE, width=2)
        color = rng.choice([(200, 50, 50), (50, 120, 60), (40, 80, 160)])
        for i, x in enumerate(range(ox + 4, ox + M - 4, 12)):
            c = color if i % 2 == 0 else (240, 236, 220)
            d.polygon([(x, y0 - 8), (x + 12, y0 - 8), (x + 14, y0 + 16), (x + 2, y0 + 16)], fill=c + (255,))
        d.line([ox + 4, y0 + 16, ox + M - 4, y0 + 16], fill=OUTLINE, width=3)
    elif kind == 2:  # portal de vecinos
        d.rectangle([ox + 34, y0 - 6, ox + 94, y1], fill=OUTLINE)
        d.rectangle([ox + 38, y0 - 2, ox + 90, y1], fill=(96, 62, 40, 255))
        d.line([ox + 64, y0 - 2, ox + 64, y1], fill=OUTLINE, width=3)
        d.rectangle([ox + 44, y0 + 6, ox + 58, y0 + 40], fill=GLASS)
        d.rectangle([ox + 70, y0 + 6, ox + 84, y0 + 40], fill=GLASS)
        d.ellipse([ox + 58, y0 + 56, ox + 62, y0 + 60], fill=(220, 190, 80, 255))
        graffiti(d, ox + 40, y0 + 60, ox + 88, y1 - 4)
    else:  # bar: rótulo y cristalera
        d.rectangle([x0 - 3, y0 - 6, x1 + 3, y1], fill=OUTLINE)
        sign = rng.choice([(140, 30, 30), (30, 60, 110), (40, 90, 50)])
        d.rectangle([x0, y0 - 3, x1, y0 + 14], fill=sign + (255,))
        for x in range(x0 + 10, x1 - 10, 14):  # letras ilegibles de rótulo
            d.rectangle([x, y0 + 2, x + 8, y0 + 10], fill=(240, 220, 160, 255))
        d.rectangle([x0, y0 + 18, x1, y1], fill=(70, 60, 40, 128))
        d.line([(x0 + x1) // 2, y0 + 18, (x0 + x1) // 2, y1], fill=OUTLINE, width=3)


def main() -> None:
    img = Image.new("RGBA", (4 * M, 2 * M), WALL)
    d = ImageDraw.Draw(img)
    for i in range(4):
        wall_noise(d, i * M, 0, False)
        wall_noise(d, i * M, M, True)
    window(d, 0, 0, "open", balcony=True, laundry=False, pots=False, ac=False)
    window(d, M, 0, "open", balcony=True, laundry=True, pots=False, ac=False)
    window(d, 2 * M, 0, "closed", balcony=True, laundry=False, pots=True, ac=False)
    window(d, 3 * M, 0, "none", balcony=False, laundry=False, pots=False, ac=True)
    for i in range(4):
        ground_floor(d, i * M, M, i)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"Guardado {OUT}")


if __name__ == "__main__":
    main()
