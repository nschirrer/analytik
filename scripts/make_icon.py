#!/usr/bin/env python3
"""Génère Resources/AppIcon-1024.png (icône de l'app : carré arrondi bleu, barres blanches).

Usage : python3 scripts/make_icon.py
Dépendance : Pillow
"""
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "Resources" / "AppIcon-1024.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    margin = int(SIZE * 0.10)
    inner = SIZE - 2 * margin
    radius = int(inner * 0.22)

    # Dégradé vertical bleu profond → bleu clair
    gradient = Image.new("RGBA", (inner, inner))
    top, bottom = (24, 62, 140), (46, 132, 230)
    px = gradient.load()
    for y in range(inner):
        color = lerp(top, bottom, y / max(inner - 1, 1))
        for x in range(inner):
            px[x, y] = color + (255,)

    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner - 1, inner - 1], radius=radius, fill=255)
    img.paste(gradient, (margin, margin), mask)

    # Trois barres blanches de hauteurs croissantes + une courbe
    draw = ImageDraw.Draw(img)
    base_y = margin + int(inner * 0.78)
    bar_w = int(inner * 0.14)
    gap = int(inner * 0.08)
    x0 = margin + int(inner * 0.17)
    heights = [0.28, 0.44, 0.60]
    tops = []
    for i, h in enumerate(heights):
        x = x0 + i * (bar_w + gap)
        y = base_y - int(inner * h)
        draw.rounded_rectangle([x, y, x + bar_w, base_y], radius=int(bar_w * 0.25), fill=(255, 255, 255, 235))
        tops.append((x + bar_w // 2, y - int(inner * 0.06)))
    draw.line(tops, fill=(255, 220, 120, 255), width=int(inner * 0.035), joint="curve")
    for cx, cy in tops:
        r = int(inner * 0.03)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 220, 120, 255))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print("Icône écrite :", OUT, img.size)


if __name__ == "__main__":
    main()
