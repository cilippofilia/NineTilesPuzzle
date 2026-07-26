#!/usr/bin/env python3
"""
App Store Screenshot Composer — realistic device frame variant.
Same layout logic as the aso-appstore-screenshots skill's compose.py, but uses a
photorealistic iPhone mockup (screen area cut transparent) supplied by the user
instead of the skill's flat device_frame.png.
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFont, ImageChops

CANVAS_W = 1290
CANVAS_H = 2796

FRAME_PATH = os.path.join(os.path.dirname(__file__), "device_frame_realistic.png")
MASK_PATH = os.path.join(os.path.dirname(__file__), "screen_mask.png")
FRAME_W, FRAME_H = 1082, 2207
# Screen (transparent hole) rect in the frame's own local pixel coordinates.
SCREEN_L = (24, 18, 1057, 2187)

DEVICE_W = 1030
DEVICE_Y = 720

VERB_SIZE_MAX = 256
VERB_SIZE_MIN = 150
DESC_SIZE = 124
VERB_DESC_GAP = 20
DESC_LINE_GAP = 24
MAX_TEXT_W = int(CANVAS_W * 0.92)
MAX_VERB_W = int(CANVAS_W * 0.92)

FONT_PATH = "/Library/Fonts/SF-Pro-Display-Black.otf"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def word_wrap(draw, text, font, max_w):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        test = f"{cur} {w}".strip()
        if draw.textlength(test, font=font) <= max_w:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def fit_font(text, max_w, size_max, size_min):
    dummy = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    for size in range(size_max, size_min - 1, -4):
        font = ImageFont.truetype(FONT_PATH, size)
        bbox = dummy.textbbox((0, 0), text, font=font)
        if (bbox[2] - bbox[0]) <= max_w:
            return font
    return ImageFont.truetype(FONT_PATH, size_min)


def draw_centered(draw, y, text, font, max_w=None):
    lines = word_wrap(draw, text, font, max_w) if max_w else [text]
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        h = bbox[3] - bbox[1]
        draw.text((CANVAS_W // 2, y - bbox[1]), line, fill="white", font=font, anchor="mt")
        y += h + DESC_LINE_GAP
    return y


def compose(bg_hex, verb, desc, screenshot_path, output_path):
    bg = hex_to_rgb(bg_hex)
    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (*bg, 255))
    draw = ImageDraw.Draw(canvas)

    verb_font = fit_font(verb.upper(), MAX_VERB_W, VERB_SIZE_MAX, VERB_SIZE_MIN)
    desc_font = ImageFont.truetype(FONT_PATH, DESC_SIZE)

    text_top = 200
    y = text_top
    y = draw_centered(draw, y, verb.upper(), verb_font)
    y += VERB_DESC_GAP
    draw_centered(draw, y, desc.upper(), desc_font, max_w=MAX_TEXT_W)

    scale = DEVICE_W / FRAME_W
    device_h = int(FRAME_H * scale)
    device_x = (CANVAS_W - DEVICE_W) // 2
    device_y = DEVICE_Y

    sx0, sy0, sx1, sy1 = SCREEN_L
    screen_x = device_x + int(sx0 * scale)
    screen_y = device_y + int(sy0 * scale)
    screen_w = int((sx1 - sx0) * scale)
    screen_h = int((sy1 - sy0) * scale)

    # ── Screenshot, scaled to fill screen width, top-aligned ─────────
    shot = Image.open(screenshot_path).convert("RGBA")
    fill_scale = screen_w / shot.width
    sc_w = screen_w
    sc_h = int(shot.height * fill_scale)
    shot = shot.resize((sc_w, sc_h), Image.LANCZOS)

    shot_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    # Solid black backdrop behind the screenshot in case it's shorter than the hole
    backdrop = Image.new("RGBA", (screen_w, screen_h), (0, 0, 0, 255))
    backdrop.paste(shot, (0, 0), shot)
    shot_layer.paste(backdrop, (screen_x, screen_y))

    # Clip to the frame's *actual* screen-hole shape (not just a rectangle) so the
    # screenshot's square corners never poke out past the phone's rounded silhouette,
    # including near the top corners where the device body itself is still narrow.
    mask = Image.open(MASK_PATH).convert("L").resize((DEVICE_W, device_h), Image.LANCZOS)
    full_mask = Image.new("L", canvas.size, 0)
    full_mask.paste(mask, (device_x, device_y))
    shot_layer.putalpha(ImageChops.multiply(shot_layer.getchannel("A"), full_mask))

    canvas = Image.alpha_composite(canvas, shot_layer)

    # ── Device frame on top — its transparent screen hole clips the shot ──
    frame = Image.open(FRAME_PATH).convert("RGBA").resize((DEVICE_W, device_h), Image.LANCZOS)
    frame_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    frame_layer.paste(frame, (device_x, device_y))
    canvas = Image.alpha_composite(canvas, frame_layer)

    canvas.convert("RGB").save(output_path, "PNG")
    print(f"✓ {output_path} ({CANVAS_W}×{CANVAS_H})")


def main():
    p = argparse.ArgumentParser(description="Compose App Store screenshot (realistic frame)")
    p.add_argument("--bg", required=True)
    p.add_argument("--verb", required=True)
    p.add_argument("--desc", required=True)
    p.add_argument("--screenshot", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()
    compose(args.bg, args.verb, args.desc, args.screenshot, args.output)


if __name__ == "__main__":
    main()
