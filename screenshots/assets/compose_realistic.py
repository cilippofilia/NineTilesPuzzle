#!/usr/bin/env python3
"""
App Store Screenshot Composer — realistic device frame variant.
Same layout logic as the aso-appstore-screenshots skill's compose.py, but uses a
photorealistic iPhone mockup (screen area cut transparent) supplied by the user
instead of the skill's flat device_frame.png.

Canvas size is parametrized (--canvas-w/--canvas-h) so the same layout can target
any App Store Connect display class — all layout constants are defined for the
iPhone 6.7" baseline (1290×2796) and scaled uniformly to whatever canvas is requested.
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFont, ImageChops

# ── Baseline (iPhone 6.7") — all other constants scale relative to this ────
BASE_CANVAS_W = 1290
BASE_CANVAS_H = 2796
BASE_DEVICE_W = 1030
BASE_DEVICE_Y = 720
BASE_TEXT_TOP = 200
BASE_VERB_SIZE_MAX = 256
BASE_VERB_SIZE_MIN = 150
BASE_DESC_SIZE = 124
BASE_VERB_DESC_GAP = 20
BASE_DESC_LINE_GAP = 24

FRAME_PATH = os.path.join(os.path.dirname(__file__), "device_frame_realistic.png")
MASK_PATH = os.path.join(os.path.dirname(__file__), "screen_mask.png")
FRAME_W, FRAME_H = 1082, 2207
# Screen (transparent hole) rect in the frame's own local pixel coordinates.
SCREEN_L = (24, 18, 1057, 2187)

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
    for size in range(size_max, size_min - 1, -2):
        font = ImageFont.truetype(FONT_PATH, size)
        bbox = dummy.textbbox((0, 0), text, font=font)
        if (bbox[2] - bbox[0]) <= max_w:
            return font
    return ImageFont.truetype(FONT_PATH, size_min)


def draw_centered(draw, canvas_w, y, text, font, line_gap, max_w=None):
    lines = word_wrap(draw, text, font, max_w) if max_w else [text]
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        h = bbox[3] - bbox[1]
        draw.text((canvas_w // 2, y - bbox[1]), line, fill="white", font=font, anchor="mt")
        y += h + line_gap
    return y


def compose(bg_hex, verb, desc, screenshot_path, output_path, canvas_w, canvas_h):
    scale_c = canvas_w / BASE_CANVAS_W

    device_w = round(BASE_DEVICE_W * scale_c)
    device_y = round(BASE_DEVICE_Y * scale_c)
    text_top = round(BASE_TEXT_TOP * scale_c)
    verb_size_max = round(BASE_VERB_SIZE_MAX * scale_c)
    verb_size_min = round(BASE_VERB_SIZE_MIN * scale_c)
    desc_size = round(BASE_DESC_SIZE * scale_c)
    verb_desc_gap = round(BASE_VERB_DESC_GAP * scale_c)
    desc_line_gap = round(BASE_DESC_LINE_GAP * scale_c)
    max_text_w = int(canvas_w * 0.92)

    bg = hex_to_rgb(bg_hex)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (*bg, 255))
    draw = ImageDraw.Draw(canvas)

    verb_font = fit_font(verb.upper(), max_text_w, verb_size_max, verb_size_min)
    desc_font = ImageFont.truetype(FONT_PATH, desc_size)

    y = text_top
    y = draw_centered(draw, canvas_w, y, verb.upper(), verb_font, desc_line_gap)
    y += verb_desc_gap
    draw_centered(draw, canvas_w, y, desc.upper(), desc_font, desc_line_gap, max_w=max_text_w)

    scale = device_w / FRAME_W
    device_h = round(FRAME_H * scale)
    device_x = (canvas_w - device_w) // 2

    sx0, sy0, sx1, sy1 = SCREEN_L
    screen_x = device_x + round(sx0 * scale)
    screen_y = device_y + round(sy0 * scale)
    screen_w = round((sx1 - sx0) * scale)
    screen_h = round((sy1 - sy0) * scale)

    # ── Screenshot, scaled to fill screen width, top-aligned ─────────
    shot = Image.open(screenshot_path).convert("RGBA")
    fill_scale = screen_w / shot.width
    sc_w = screen_w
    sc_h = round(shot.height * fill_scale)
    shot = shot.resize((sc_w, sc_h), Image.LANCZOS)

    shot_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    # Solid black backdrop behind the screenshot in case it's shorter than the hole
    backdrop = Image.new("RGBA", (screen_w, screen_h), (0, 0, 0, 255))
    backdrop.paste(shot, (0, 0), shot)
    shot_layer.paste(backdrop, (screen_x, screen_y))

    # Clip to the frame's *actual* screen-hole shape (not just a rectangle) so the
    # screenshot's square corners never poke out past the phone's rounded silhouette,
    # including near the top corners where the device body itself is still narrow.
    mask = Image.open(MASK_PATH).convert("L").resize((device_w, device_h), Image.LANCZOS)
    full_mask = Image.new("L", canvas.size, 0)
    full_mask.paste(mask, (device_x, device_y))
    shot_layer.putalpha(ImageChops.multiply(shot_layer.getchannel("A"), full_mask))

    canvas = Image.alpha_composite(canvas, shot_layer)

    # ── Device frame on top — its transparent screen hole clips the shot ──
    frame = Image.open(FRAME_PATH).convert("RGBA").resize((device_w, device_h), Image.LANCZOS)
    frame_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    frame_layer.paste(frame, (device_x, device_y))
    canvas = Image.alpha_composite(canvas, frame_layer)

    canvas.convert("RGB").save(output_path, "PNG")
    print(f"✓ {output_path} ({canvas_w}×{canvas_h})")


def main():
    p = argparse.ArgumentParser(description="Compose App Store screenshot (realistic frame)")
    p.add_argument("--bg", required=True)
    p.add_argument("--verb", required=True)
    p.add_argument("--desc", required=True)
    p.add_argument("--screenshot", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--canvas-w", type=int, default=BASE_CANVAS_W)
    p.add_argument("--canvas-h", type=int, default=BASE_CANVAS_H)
    args = p.parse_args()
    compose(
        args.bg, args.verb, args.desc, args.screenshot, args.output,
        args.canvas_w, args.canvas_h,
    )


if __name__ == "__main__":
    main()
