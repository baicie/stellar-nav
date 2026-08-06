#!/usr/bin/env python3
"""Generate deterministic AstroNav launcher icons for Flutter platforms."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER_SIZE = 2048

BG = "#05080C"
SURFACE = "#0E1923"
LINE = "#38505F"
CYAN = "#5EEAD4"
CYAN_STRONG = "#22C7BD"
AMBER = "#FFC857"
TEXT = "#EEF7F7"


def _scaled_box(box: tuple[float, float, float, float], scale: float) -> tuple[int, ...]:
    center = MASTER_SIZE / 2
    return tuple(round(center + (value - center) * scale) for value in box)


def _rotated_orbit(
    box: tuple[int, int, int, int],
    angle: float,
    color: str,
    width: int,
    *,
    arc: tuple[int, int] | None = None,
) -> Image.Image:
    layer = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    if arc is None:
        draw.ellipse(box, outline=color, width=width)
    else:
        draw.arc(box, start=arc[0], end=arc[1], fill=color, width=width)
    return layer.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        center=(MASTER_SIZE / 2, MASTER_SIZE / 2),
    )


def _orbit_point(
    box: tuple[int, int, int, int], angle: float, phase: float
) -> tuple[float, float]:
    left, top, right, bottom = box
    cx = (left + right) / 2
    cy = (top + bottom) / 2
    x = (right - left) / 2 * math.cos(phase)
    y = (bottom - top) / 2 * math.sin(phase)
    radians = math.radians(-angle)
    return (
        cx + x * math.cos(radians) - y * math.sin(radians),
        cy + x * math.sin(radians) + y * math.cos(radians),
    )


def _draw_node(
    draw: ImageDraw.ImageDraw,
    point: tuple[float, float],
    radius: int,
    color: str,
) -> None:
    x, y = point
    draw.ellipse(
        (x - radius * 2, y - radius * 2, x + radius * 2, y + radius * 2),
        fill=f"{color}26",
    )
    draw.ellipse(
        (x - radius, y - radius, x + radius, y + radius),
        fill=color,
        outline=TEXT,
        width=max(4, radius // 5),
    )


def render_icon(*, maskable: bool = False) -> Image.Image:
    mark_scale = 0.72 if maskable else 0.88
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), BG)
    draw = ImageDraw.Draw(canvas)

    outer = _scaled_box((328, 328, 1720, 1720), mark_scale)
    draw.ellipse(outer, fill=SURFACE, outline=LINE, width=18)

    primary_box = _scaled_box((360, 630, 1688, 1418), mark_scale)
    secondary_box = _scaled_box((660, 300, 1388, 1748), mark_scale)
    primary_angle = -28
    secondary_angle = 34

    canvas = Image.alpha_composite(
        canvas,
        _rotated_orbit(
            primary_box,
            primary_angle,
            LINE,
            round(28 * mark_scale),
        ),
    )
    canvas = Image.alpha_composite(
        canvas,
        _rotated_orbit(
            secondary_box,
            secondary_angle,
            CYAN_STRONG,
            round(18 * mark_scale),
        ),
    )
    canvas = Image.alpha_composite(
        canvas,
        _rotated_orbit(
            primary_box,
            primary_angle,
            CYAN,
            round(38 * mark_scale),
            arc=(205, 336),
        ),
    )

    draw = ImageDraw.Draw(canvas)
    node_radius = round(40 * mark_scale)
    _draw_node(
        draw,
        _orbit_point(primary_box, primary_angle, math.radians(215)),
        node_radius,
        AMBER,
    )
    _draw_node(
        draw,
        _orbit_point(primary_box, primary_angle, math.radians(330)),
        node_radius,
        CYAN,
    )

    center = MASTER_SIZE / 2
    hub_radius = round(166 * mark_scale)
    draw.ellipse(
        (
            center - hub_radius,
            center - hub_radius,
            center + hub_radius,
            center + hub_radius,
        ),
        fill=BG,
        outline=CYAN,
        width=round(20 * mark_scale),
    )

    outer_radius = 125 * mark_scale
    inner_radius = 43 * mark_scale
    star = []
    for index in range(8):
        radius = outer_radius if index % 2 == 0 else inner_radius
        angle = math.radians(-90 + index * 45)
        star.append(
            (center + radius * math.cos(angle), center + radius * math.sin(angle))
        )
    draw.polygon(star, fill=TEXT)
    draw.ellipse(
        (
            center - 22 * mark_scale,
            center - 22 * mark_scale,
            center + 22 * mark_scale,
            center + 22 * mark_scale,
        ),
        fill=CYAN_STRONG,
    )

    return canvas.convert("RGB")


def _save(image: Image.Image, relative_path: str, size: int) -> None:
    path = ROOT / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(path, format="PNG", optimize=True)


def main() -> None:
    regular = render_icon()
    maskable = render_icon(maskable=True)

    for size in (192, 512):
        _save(regular, f"web/icons/Icon-{size}.png", size)
        _save(maskable, f"web/icons/Icon-maskable-{size}.png", size)
    _save(regular, "web/favicon.png", 32)

    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in android_sizes.items():
        _save(
            maskable,
            f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
            size,
        )

    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, size in ios_sizes.items():
        _save(
            regular,
            f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{filename}",
            size,
        )


if __name__ == "__main__":
    main()
