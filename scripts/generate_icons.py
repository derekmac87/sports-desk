#!/usr/bin/env python3
"""Generate placeholder app icons: iOS AppIcon and the tvOS layered brand assets (pip install pillow)."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ASSETS = Path(__file__).resolve().parent.parent / "Apps/SportsDesk/Resources/Assets.xcassets"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
INFO = {"author": "xcode", "version": 1}


def background(width, height):
    top, bottom = (16, 36, 86), (5, 7, 13)
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(height - 1, 1)
        draw.line([(0, y), (width, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    glow = Image.new("L", (width, height), 0)
    radius = int(min(width, height) * 0.55)
    ImageDraw.Draw(glow).ellipse([width - radius, -radius // 2, width + radius, radius + radius // 2], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    image.paste(Image.new("RGB", (width, height), (255, 59, 61)), (0, 0), glow)
    return image


def glyph(width, height, scale=1.0, title=None):
    """Scoreboard outline, 'SD' monogram and a red live dot on a transparent layer."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    side = min(width, height) * 0.62 * scale
    box_w, box_h = side * 1.25, side * 0.82
    cx = width / 2 if title is None else width * 0.3
    cy = height / 2
    rect = [cx - box_w / 2, cy - box_h / 2, cx + box_w / 2, cy + box_h / 2]
    draw.rounded_rectangle(rect, radius=box_h * 0.22, outline=(255, 255, 255, 255), width=max(int(side * 0.06), 2))
    font = ImageFont.truetype(FONT, int(box_h * 0.48))
    draw.text((cx, cy), "SD", font=font, fill=(255, 255, 255, 255), anchor="mm")
    dot = side * 0.09
    dx, dy = rect[2] - box_h * 0.2, rect[1] + box_h * 0.2
    draw.ellipse([dx - dot, dy - dot, dx + dot, dy + dot], fill=(255, 59, 61, 255))
    if title:
        title_font = ImageFont.truetype(FONT, int(height * 0.16))
        draw.text((width * 0.52, cy), title, font=title_font, fill=(255, 255, 255, 255), anchor="lm")
    return layer


def write_json(path, payload):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(payload, indent=2) + "\n")


def image_set(path, base_name, sizes, render):
    images = []
    for scale, (w, h) in sizes.items():
        name = f"{base_name}{'' if scale == 1 else f'@{scale}x'}.png"
        path.mkdir(parents=True, exist_ok=True)
        render(w, h).save(path / name)
        images.append({"filename": name, "idiom": "tv", "scale": f"{scale}x"})
    write_json(path, {"images": images, "info": INFO})


def image_stack(path, sizes):
    layers = [
        ("Front", lambda w, h: glyph(w, h, scale=0.9)),
        ("Back", lambda w, h: background(w, h)),
    ]
    for name, render in layers:
        layer = path / f"{name}.imagestacklayer"
        write_json(layer, {"info": INFO})
        image_set(layer / "Content.imageset", name.lower(), sizes, render)
    write_json(path, {"info": INFO, "layers": [{"filename": f"{name}.imagestacklayer"} for name, _ in layers]})


def main():
    ios = ASSETS / "AppIcon.appiconset"
    for old in ios.glob("*.png"):
        old.unlink()
    icon = background(1024, 1024)
    icon.paste(glyph(1024, 1024), (0, 0), glyph(1024, 1024))
    icon.save(ios / "AppIcon.png")
    write_json(ios, {"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": INFO})

    brand = ASSETS / "App Icon & Top Shelf Image.brandassets"
    image_stack(brand / "App Icon.imagestack", {1: (400, 240), 2: (800, 480)})
    image_stack(brand / "App Icon - App Store.imagestack", {1: (1280, 768)})

    def shelf(w, h):
        base = background(w, h)
        mark = glyph(w, h, scale=0.8, title="Sports Desk")
        base.paste(mark, (0, 0), mark)
        return base

    image_set(brand / "Top Shelf Image.imageset", "top-shelf", {1: (1920, 720), 2: (3840, 1440)}, shelf)
    image_set(brand / "Top Shelf Image Wide.imageset", "top-shelf-wide", {1: (2320, 720), 2: (4640, 1440)}, shelf)
    write_json(brand, {
        "assets": [
            {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
            {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
            {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
            {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
        ],
        "info": INFO,
    })


if __name__ == "__main__":
    main()
