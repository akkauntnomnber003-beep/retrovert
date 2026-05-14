#!/usr/bin/env python3
"""
RatRovert texture generator.

Creates every PNG asset the project needs as a valid, fully-formed PNG file.
All textures are drawn programmatically in an author-inspired dark cartoon
style (palette inspired by The Binding of Isaac but NOT copied — drawn from
scratch). All shapes are mathematical so the output is deterministic and
re-runnable.

Run from project root:
    python3 tools/generate_textures.py
"""
from __future__ import annotations

import math
import os
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "sprites"

# Deterministic generation
random.seed(20260514)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def new_img(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)


def outlined_circle(img: Image.Image, cx: float, cy: float, r: float,
                    fill, outline=(0, 0, 0, 255), width: int = 1) -> None:
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline,
              width=width)


def filled_rect(img: Image.Image, x0, y0, x1, y1, fill, outline=None) -> None:
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


# Color palette (author-inspired, not copied)
SKIN = (236, 220, 198, 255)
SKIN_DK = (190, 160, 130, 255)
BLOOD = (180, 25, 25, 255)
BLOOD_DK = (110, 10, 10, 255)
EYE_W = (250, 250, 240, 255)
PUPIL = (35, 25, 30, 255)
OUTLINE = (20, 10, 12, 255)
WALL_DK = (62, 44, 32, 255)
WALL_LT = (110, 80, 58, 255)
FLOOR_DK = (98, 70, 50, 255)
FLOOR_LT = (140, 102, 76, 255)
COIN_Y = (240, 200, 60, 255)
COIN_DK = (170, 120, 30, 255)
KEY_Y = (240, 215, 110, 255)
BOMB_DK = (28, 24, 30, 255)
BOMB_LT = (80, 70, 76, 255)
TEAR_BLUE = (140, 195, 240, 255)
TEAR_BLUE_DK = (60, 110, 175, 255)
SOUL = (180, 200, 240, 255)
SOUL_DK = (70, 110, 200, 255)
ROCK_DK = (62, 52, 46, 255)
ROCK_LT = (130, 110, 96, 255)
POOP_DK = (78, 50, 22, 255)
POOP_LT = (135, 90, 40, 255)
ENEMY_FLY = (110, 120, 130, 255)
ENEMY_POOTER = (180, 165, 140, 255)
ENEMY_GAPER = SKIN
ENEMY_LEAPER = (160, 170, 180, 255)
ENEMY_SPIDER = (60, 50, 70, 255)
MONSTRO = (230, 110, 110, 255)
MONSTRO_DK = (140, 35, 35, 255)
LARRY = (200, 90, 90, 255)


# ---------------------------------------------------------------------------
# Player head (4 directions, 32x32)
# ---------------------------------------------------------------------------
def draw_head(direction: str) -> Image.Image:
    img = new_img(32, 32)
    # body of head
    outlined_circle(img, 16, 17, 12, SKIN, OUTLINE, 2)
    # eye placement depends on direction
    if direction == "down":
        outlined_circle(img, 11, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 21, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 11, 18, 1.2, PUPIL)
        outlined_circle(img, 21, 18, 1.2, PUPIL)
        # tear
        outlined_circle(img, 11, 22, 1.2, TEAR_BLUE)
    elif direction == "up":
        outlined_circle(img, 11, 16, 2.5, EYE_W, OUTLINE, 1)
        outlined_circle(img, 21, 16, 2.5, EYE_W, OUTLINE, 1)
        outlined_circle(img, 11, 15, 1.0, PUPIL)
        outlined_circle(img, 21, 15, 1.0, PUPIL)
    elif direction == "left":
        outlined_circle(img, 9, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 17, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 7, 18, 1.2, PUPIL)
        outlined_circle(img, 15, 18, 1.2, PUPIL)
    else:  # right
        outlined_circle(img, 15, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 23, 17, 3, EYE_W, OUTLINE, 1)
        outlined_circle(img, 17, 18, 1.2, PUPIL)
        outlined_circle(img, 25, 18, 1.2, PUPIL)
    # hair tuft
    d = ImageDraw.Draw(img)
    d.line([(12, 6), (16, 4), (20, 6)], fill=OUTLINE, width=2)
    return img


def gen_player_heads() -> None:
    for d in ("down", "up", "left", "right"):
        save(draw_head(d), ASSETS / "player" / f"head_{d}.png")


# ---------------------------------------------------------------------------
# Player body sheet (4 rows × 4 frames, 32×32 frame, sheet 128×128)
# ---------------------------------------------------------------------------
def draw_body_frame(walk_phase: int, direction: str) -> Image.Image:
    img = new_img(32, 32)
    leg_y = 22 + (walk_phase % 2) * 2
    body_w = 9
    body_h = 9
    # body
    filled_rect(img, 16 - body_w, 12, 16 + body_w, 12 + body_h,
                SKIN, OUTLINE)
    # legs depending on direction
    if direction in ("down", "up"):
        filled_rect(img, 11, leg_y, 14, leg_y + 5, SKIN_DK, OUTLINE)
        filled_rect(img, 18, leg_y - (walk_phase % 2) * 2,
                    21, leg_y + 5 - (walk_phase % 2) * 2, SKIN_DK, OUTLINE)
    elif direction == "left":
        filled_rect(img, 12, leg_y, 15, leg_y + 5, SKIN_DK, OUTLINE)
        filled_rect(img, 17, leg_y + (walk_phase % 2),
                    20, leg_y + 5 + (walk_phase % 2), SKIN_DK, OUTLINE)
    else:  # right
        filled_rect(img, 12, leg_y - (walk_phase % 2),
                    15, leg_y + 5 - (walk_phase % 2), SKIN_DK, OUTLINE)
        filled_rect(img, 17, leg_y, 20, leg_y + 5, SKIN_DK, OUTLINE)
    return img


def gen_body_sheet() -> None:
    sheet = new_img(128, 128)
    for row, direction in enumerate(("down", "up", "right", "left")):
        for col in range(4):
            frame = draw_body_frame(col, direction)
            if direction == "left":
                frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(frame, (col * 32, row * 32), frame)
    save(sheet, ASSETS / "player" / "body_sheet.png")


# ---------------------------------------------------------------------------
# Tears
# ---------------------------------------------------------------------------
def gen_tear() -> None:
    img = new_img(8, 8)
    outlined_circle(img, 4, 4, 3, TEAR_BLUE, OUTLINE, 1)
    save(img, ASSETS / "player" / "tear_blue.png")
    img2 = new_img(8, 8)
    outlined_circle(img2, 4, 4, 3, (255, 90, 80, 255), OUTLINE, 1)
    save(img2, ASSETS / "player" / "tear_red.png")


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
def draw_fly(frame: int) -> Image.Image:
    img = new_img(32, 32)
    # body
    outlined_circle(img, 16, 18, 7, ENEMY_FLY, OUTLINE, 2)
    # wings (frame-dependent)
    w_y = 11 + (frame % 2) * 2
    outlined_circle(img, 9, w_y, 4, (200, 220, 240, 200), OUTLINE, 1)
    outlined_circle(img, 23, w_y, 4, (200, 220, 240, 200), OUTLINE, 1)
    # eye
    outlined_circle(img, 16, 17, 2, EYE_W, OUTLINE, 1)
    outlined_circle(img, 16, 17, 0.9, PUPIL)
    return img


def gen_fly_sheet() -> None:
    sheet = new_img(64, 32)
    for col in range(2):
        sheet.paste(draw_fly(col), (col * 32, 0), draw_fly(col))
    save(sheet, ASSETS / "enemies" / "fly_sheet.png")


def draw_pooter(frame: int) -> Image.Image:
    img = new_img(32, 32)
    # body
    outlined_circle(img, 16, 19, 8, ENEMY_POOTER, OUTLINE, 2)
    # wings
    w_y = 11 + (frame % 2)
    outlined_circle(img, 8, w_y, 4, (220, 220, 220, 200), OUTLINE, 1)
    outlined_circle(img, 24, w_y, 4, (220, 220, 220, 200), OUTLINE, 1)
    # eyes
    outlined_circle(img, 13, 19, 2, EYE_W, OUTLINE, 1)
    outlined_circle(img, 19, 19, 2, EYE_W, OUTLINE, 1)
    outlined_circle(img, 13, 19, 0.8, PUPIL)
    outlined_circle(img, 19, 19, 0.8, PUPIL)
    return img


def gen_pooter_sheet() -> None:
    sheet = new_img(64, 32)
    for col in range(2):
        sheet.paste(draw_pooter(col), (col * 32, 0), draw_pooter(col))
    save(sheet, ASSETS / "enemies" / "pooter_sheet.png")


def draw_gaper_frame(direction: str, walk_phase: int) -> Image.Image:
    img = new_img(32, 32)
    outlined_circle(img, 16, 16, 10, SKIN, OUTLINE, 2)
    if direction == "down":
        outlined_circle(img, 12, 14, 2.5, EYE_W, OUTLINE, 1)
        outlined_circle(img, 20, 14, 2.5, EYE_W, OUTLINE, 1)
        outlined_circle(img, 12, 14, 1.0, PUPIL)
        outlined_circle(img, 20, 14, 1.0, PUPIL)
        # mouth: gaping
        d = ImageDraw.Draw(img)
        d.ellipse([13, 18 + (walk_phase % 2), 19, 23 + (walk_phase % 2)],
                  fill=BLOOD_DK, outline=OUTLINE, width=1)
    elif direction == "up":
        outlined_circle(img, 12, 13, 2, EYE_W, OUTLINE, 1)
        outlined_circle(img, 20, 13, 2, EYE_W, OUTLINE, 1)
    else:  # left / right
        offset = -2 if direction == "left" else 2
        outlined_circle(img, 16 + offset, 14, 2.5, EYE_W, OUTLINE, 1)
        outlined_circle(img, 16 + offset, 14, 1.0, PUPIL)
        d = ImageDraw.Draw(img)
        d.ellipse([14, 19, 18, 23], fill=BLOOD_DK, outline=OUTLINE, width=1)
    return img


def gen_gaper_sheet() -> None:
    sheet = new_img(128, 64)
    dirs = ("down", "up", "right", "left")
    for r, d in enumerate(dirs[:2]):
        for c in range(4):
            f = draw_gaper_frame(d, c)
            sheet.paste(f, (c * 32, r * 32), f)
    save(sheet, ASSETS / "enemies" / "gaper_sheet.png")


def draw_leaper(frame: int) -> Image.Image:
    img = new_img(32, 32)
    sq = (frame % 2) * 2
    outlined_circle(img, 16, 18 - sq, 9 + sq, ENEMY_LEAPER, OUTLINE, 2)
    outlined_circle(img, 13, 17 - sq, 2, EYE_W, OUTLINE, 1)
    outlined_circle(img, 19, 17 - sq, 2, EYE_W, OUTLINE, 1)
    outlined_circle(img, 13, 17 - sq, 0.8, PUPIL)
    outlined_circle(img, 19, 17 - sq, 0.8, PUPIL)
    return img


def gen_leaper_sheet() -> None:
    sheet = new_img(64, 32)
    for c in range(2):
        f = draw_leaper(c)
        sheet.paste(f, (c * 32, 0), f)
    save(sheet, ASSETS / "enemies" / "leaper_sheet.png")


def draw_spider(frame: int) -> Image.Image:
    img = new_img(32, 32)
    leg_phase = (frame % 2) * 2 - 1
    d = ImageDraw.Draw(img)
    # legs
    for i in range(-2, 3):
        if i == 0:
            continue
        x_off = i * 4
        y_off = 4 + leg_phase * (i % 2)
        d.line([(16, 18), (16 + x_off, 18 + y_off)], fill=OUTLINE, width=2)
    outlined_circle(img, 16, 18, 7, ENEMY_SPIDER, OUTLINE, 2)
    outlined_circle(img, 13, 17, 1.6, EYE_W, OUTLINE, 1)
    outlined_circle(img, 19, 17, 1.6, EYE_W, OUTLINE, 1)
    return img


def gen_spider_sheet() -> None:
    sheet = new_img(64, 32)
    for c in range(2):
        f = draw_spider(c)
        sheet.paste(f, (c * 32, 0), f)
    save(sheet, ASSETS / "enemies" / "spider_sheet.png")


# ---------------------------------------------------------------------------
# Bosses
# ---------------------------------------------------------------------------
def draw_monstro(frame: int) -> Image.Image:
    img = new_img(64, 64)
    sq = (frame % 2) * 3
    outlined_circle(img, 32, 36 - sq, 22 + sq, MONSTRO, OUTLINE, 3)
    outlined_circle(img, 24, 30 - sq, 5, EYE_W, OUTLINE, 2)
    outlined_circle(img, 40, 30 - sq, 5, EYE_W, OUTLINE, 2)
    outlined_circle(img, 24, 30 - sq, 2, PUPIL)
    outlined_circle(img, 40, 30 - sq, 2, PUPIL)
    d = ImageDraw.Draw(img)
    d.ellipse([20, 40 - sq, 44, 52 - sq], fill=MONSTRO_DK, outline=OUTLINE,
              width=2)
    # tooth
    d.polygon([(26, 40 - sq), (28, 46 - sq), (30, 40 - sq)], fill=EYE_W,
              outline=OUTLINE)
    d.polygon([(34, 40 - sq), (36, 46 - sq), (38, 40 - sq)], fill=EYE_W,
              outline=OUTLINE)
    return img


def gen_monstro_sheet() -> None:
    sheet = new_img(192, 64)
    for c in range(3):
        f = draw_monstro(c)
        sheet.paste(f, (c * 64, 0), f)
    save(sheet, ASSETS / "enemies" / "bosses" / "monstro_sheet.png")


def draw_larry_seg(frame: int) -> Image.Image:
    img = new_img(32, 32)
    sq = (frame % 2) * 1
    outlined_circle(img, 16, 16, 11 + sq, LARRY, OUTLINE, 2)
    outlined_circle(img, 12, 14, 2.5, EYE_W, OUTLINE, 1)
    outlined_circle(img, 20, 14, 2.5, EYE_W, OUTLINE, 1)
    outlined_circle(img, 12, 14, 1.0, PUPIL)
    outlined_circle(img, 20, 14, 1.0, PUPIL)
    return img


def gen_larry_sheet() -> None:
    sheet = new_img(64, 32)
    for c in range(2):
        f = draw_larry_seg(c)
        sheet.paste(f, (c * 32, 0), f)
    save(sheet, ASSETS / "enemies" / "bosses" / "larry_sheet.png")


# ---------------------------------------------------------------------------
# Rooms (tiles)
# ---------------------------------------------------------------------------
def gen_floor() -> None:
    # 4x4 tileset, 16px each → 64x64 sheet, but we just supply a single 16x16
    img = new_img(16, 16)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=FLOOR_DK)
    # subtle grid
    for x in range(0, 16, 4):
        d.line([(x, 0), (x, 15)], fill=(60, 42, 28, 50))
    for y in range(0, 16, 4):
        d.line([(0, y), (15, y)], fill=(60, 42, 28, 50))
    # speckles
    rnd = random.Random(1)
    for _ in range(6):
        x = rnd.randint(1, 14)
        y = rnd.randint(1, 14)
        img.putpixel((x, y), (155, 115, 85, 255))
    save(img, ASSETS / "rooms" / "floor_basement.png")


def gen_wall_top() -> None:
    img = new_img(16, 16)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=WALL_DK)
    d.rectangle([0, 0, 15, 4], fill=WALL_LT)
    d.line([(0, 4), (15, 4)], fill=OUTLINE)
    save(img, ASSETS / "rooms" / "wall_top.png")


def gen_wall_side() -> None:
    img = new_img(16, 16)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=WALL_DK)
    d.line([(8, 0), (8, 15)], fill=OUTLINE)
    save(img, ASSETS / "rooms" / "wall_side.png")


def _door_base(img: Image.Image, locked: bool, open_: bool) -> None:
    d = ImageDraw.Draw(img)
    # frame
    d.rectangle([0, 0, 31, 47], fill=WALL_DK, outline=OUTLINE)
    if open_:
        d.rectangle([6, 6, 25, 41], fill=(0, 0, 0, 0))
    else:
        col = (60, 40, 30, 255) if not locked else (40, 25, 15, 255)
        d.rectangle([6, 6, 25, 41], fill=col, outline=OUTLINE)
        d.line([(15, 6), (15, 41)], fill=OUTLINE)
        if locked:
            outlined_circle(img, 15, 24, 4, COIN_Y, OUTLINE)


def gen_doors() -> None:
    for name, locked, open_ in (
        ("door_closed", False, False),
        ("door_open", False, True),
        ("door_locked", True, False),
    ):
        img = new_img(32, 48)
        _door_base(img, locked, open_)
        save(img, ASSETS / "rooms" / f"{name}.png")


def gen_rock() -> None:
    img = new_img(16, 16)
    outlined_circle(img, 8, 9, 7, ROCK_LT, OUTLINE, 1)
    outlined_circle(img, 8, 11, 4, ROCK_DK, None)
    save(img, ASSETS / "rooms" / "rock.png")


def gen_poop_frames() -> None:
    sheet = new_img(64, 16)
    for c in range(4):
        f = new_img(16, 16)
        h = 14 - c * 3
        outlined_circle(f, 8, 12, 6, POOP_LT, OUTLINE, 1)
        if h > 4:
            outlined_circle(f, 8, 10, 4, POOP_DK, OUTLINE, 1)
        if h > 8:
            outlined_circle(f, 8, 7, 3, POOP_LT, OUTLINE, 1)
        sheet.paste(f, (c * 16, 0), f)
    save(sheet, ASSETS / "rooms" / "poop.png")


def gen_pit() -> None:
    img = new_img(16, 16)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=(0, 0, 0, 0))
    outlined_circle(img, 8, 8, 7, (15, 10, 8, 255), OUTLINE, 1)
    save(img, ASSETS / "rooms" / "pit.png")


# ---------------------------------------------------------------------------
# Pickups
# ---------------------------------------------------------------------------
def gen_coin() -> None:
    img = new_img(16, 16)
    outlined_circle(img, 8, 8, 6, COIN_Y, OUTLINE, 1)
    outlined_circle(img, 8, 8, 3, COIN_DK, OUTLINE, 1)
    save(img, ASSETS / "pickups" / "coin.png")
    img2 = new_img(16, 16)
    outlined_circle(img2, 6, 8, 5, COIN_Y, OUTLINE, 1)
    outlined_circle(img2, 10, 8, 5, COIN_Y, OUTLINE, 1)
    save(img2, ASSETS / "pickups" / "coin_double.png")


def gen_heart(name: str, color: tuple, dk: tuple, half: bool = False) -> None:
    img = new_img(16, 16)
    d = ImageDraw.Draw(img)
    if half:
        # left half full, right empty-ish
        # right half outline only
        d.ellipse([1, 3, 8, 10], fill=color, outline=OUTLINE)
        d.ellipse([7, 3, 14, 10], fill=(40, 25, 25, 255), outline=OUTLINE)
        d.polygon([(2, 6), (14, 6), (8, 14)], fill=color, outline=OUTLINE)
        d.line([(8, 4), (8, 14)], fill=OUTLINE)
    else:
        d.ellipse([1, 3, 8, 10], fill=color, outline=OUTLINE)
        d.ellipse([7, 3, 14, 10], fill=color, outline=OUTLINE)
        d.polygon([(2, 6), (14, 6), (8, 14)], fill=color, outline=OUTLINE)
        # highlight
        outlined_circle(img, 5, 6, 1.2, (255, 200, 200, 220), None)
    save(img, ASSETS / "pickups" / f"{name}.png")


def gen_hearts() -> None:
    gen_heart("heart_red", (220, 40, 40, 255), BLOOD_DK)
    gen_heart("heart_half", (220, 40, 40, 255), BLOOD_DK, half=True)
    gen_heart("heart_soul", SOUL, SOUL_DK)


def gen_bomb() -> None:
    img = new_img(16, 16)
    outlined_circle(img, 8, 10, 6, BOMB_DK, OUTLINE, 1)
    outlined_circle(img, 9, 9, 1.5, BOMB_LT, None)
    d = ImageDraw.Draw(img)
    d.line([(8, 4), (10, 1)], fill=OUTLINE, width=2)
    outlined_circle(img, 11, 1, 1.4, (255, 200, 80, 255), None)
    save(img, ASSETS / "pickups" / "bomb.png")


def gen_key() -> None:
    img = new_img(16, 16)
    outlined_circle(img, 6, 6, 4, KEY_Y, OUTLINE, 1)
    outlined_circle(img, 6, 6, 1.5, (0, 0, 0, 0), OUTLINE, 1)
    d = ImageDraw.Draw(img)
    d.line([(9, 7), (14, 12)], fill=KEY_Y, width=3)
    d.line([(9, 7), (14, 12)], fill=OUTLINE, width=1)
    d.line([(12, 11), (12, 14)], fill=OUTLINE, width=1)
    save(img, ASSETS / "pickups" / "key.png")


# ---------------------------------------------------------------------------
# Items (icons) — 12 distinct passive/active items
# ---------------------------------------------------------------------------
ITEM_DEFS = [
    ("rat_speed", (90, 220, 140, 255)),
    ("blood_tear", (220, 40, 40, 255)),
    ("double_shot", (130, 130, 230, 255)),
    ("hard_aim", (240, 200, 80, 255)),
    ("rat_nose", (210, 160, 130, 255)),
    ("rusty_heart", (160, 30, 30, 255)),
    ("abyss_shadow", (40, 30, 80, 255)),
    ("flex_aim", (200, 180, 70, 255)),
    ("sinner_barrier", (200, 220, 240, 255)),
    ("hellish_charge", (250, 100, 30, 255)),
    ("abyss_fan", (110, 60, 200, 255)),
    ("rotten_milk", (240, 240, 230, 255)),
]


def gen_items() -> None:
    for idx, (name, color) in enumerate(ITEM_DEFS):
        img = new_img(32, 32)
        outlined_circle(img, 16, 16, 13, color, OUTLINE, 2)
        # decoration: small inner pattern from index
        if idx % 3 == 0:
            outlined_circle(img, 16, 16, 5, (255, 255, 255, 90), None)
        elif idx % 3 == 1:
            d = ImageDraw.Draw(img)
            d.rectangle([12, 12, 20, 20], fill=(0, 0, 0, 80))
        else:
            d = ImageDraw.Draw(img)
            d.polygon([(16, 8), (24, 22), (8, 22)], fill=(255, 255, 255, 100))
        # tiny crosshair
        outlined_circle(img, 16, 16, 1.5, OUTLINE, None)
        save(img, ASSETS / "items" / f"{name}.png")


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
def gen_ui_hearts() -> None:
    # full / half / empty / soul_full / soul_empty (32x32)
    def heart(filled: int, color: tuple) -> Image.Image:
        # filled: 2=full, 1=half, 0=empty
        img = new_img(32, 32)
        d = ImageDraw.Draw(img)
        empty_col = (60, 30, 30, 255)
        if filled == 2:
            d.ellipse([2, 6, 16, 20], fill=color, outline=OUTLINE, width=2)
            d.ellipse([14, 6, 28, 20], fill=color, outline=OUTLINE, width=2)
            d.polygon([(4, 12), (28, 12), (16, 30)], fill=color,
                      outline=OUTLINE)
        elif filled == 1:
            d.ellipse([2, 6, 16, 20], fill=color, outline=OUTLINE, width=2)
            d.ellipse([14, 6, 28, 20], fill=empty_col, outline=OUTLINE,
                      width=2)
            d.polygon([(4, 12), (16, 12), (16, 30)], fill=color,
                      outline=OUTLINE)
            d.polygon([(16, 12), (28, 12), (16, 30)], fill=empty_col,
                      outline=OUTLINE)
            d.line([(16, 8), (16, 30)], fill=OUTLINE, width=1)
        else:
            d.ellipse([2, 6, 16, 20], fill=empty_col, outline=OUTLINE,
                      width=2)
            d.ellipse([14, 6, 28, 20], fill=empty_col, outline=OUTLINE,
                      width=2)
            d.polygon([(4, 12), (28, 12), (16, 30)], fill=empty_col,
                      outline=OUTLINE)
        return img

    save(heart(2, (220, 40, 40, 255)), ASSETS / "ui" / "hud_heart_full.png")
    save(heart(1, (220, 40, 40, 255)), ASSETS / "ui" / "hud_heart_half.png")
    save(heart(0, (220, 40, 40, 255)), ASSETS / "ui" / "hud_heart_empty.png")
    save(heart(2, SOUL), ASSETS / "ui" / "hud_soul_full.png")
    save(heart(0, SOUL), ASSETS / "ui" / "hud_soul_empty.png")


def gen_ui_icons() -> None:
    # 24x24 icons for coin/bomb/key (HUD-sized)
    img = new_img(24, 24)
    outlined_circle(img, 12, 12, 9, COIN_Y, OUTLINE, 2)
    outlined_circle(img, 12, 12, 4, COIN_DK, OUTLINE, 1)
    save(img, ASSETS / "ui" / "coin_icon.png")

    img = new_img(24, 24)
    outlined_circle(img, 12, 14, 8, BOMB_DK, OUTLINE, 2)
    d = ImageDraw.Draw(img)
    d.line([(12, 5), (15, 1)], fill=OUTLINE, width=2)
    save(img, ASSETS / "ui" / "bomb_icon.png")

    img = new_img(24, 24)
    outlined_circle(img, 9, 9, 6, KEY_Y, OUTLINE, 2)
    outlined_circle(img, 9, 9, 2, (0, 0, 0, 0), OUTLINE, 1)
    d = ImageDraw.Draw(img)
    d.line([(13, 11), (22, 20)], fill=KEY_Y, width=4)
    d.line([(13, 11), (22, 20)], fill=OUTLINE, width=1)
    save(img, ASSETS / "ui" / "key_icon.png")


def gen_minimap_cells() -> None:
    for name, color in (
        ("minimap_room", (120, 120, 120, 255)),
        ("minimap_current", (240, 240, 240, 255)),
        ("minimap_boss", (200, 50, 50, 255)),
        ("minimap_shop", (60, 180, 60, 255)),
        ("minimap_treasure", (230, 200, 60, 255)),
        ("minimap_secret", (70, 70, 70, 255)),
    ):
        img = new_img(8, 8)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 7, 7], fill=color, outline=OUTLINE)
        save(img, ASSETS / "ui" / f"{name}.png")


def gen_joystick() -> None:
    bg = new_img(160, 160)
    outlined_circle(bg, 80, 80, 78, (255, 255, 255, 90), (255, 255, 255, 180),
                    3)
    outlined_circle(bg, 80, 80, 70, (255, 255, 255, 30), None)
    save(bg, ASSETS / "ui" / "joystick_bg.png")

    knob = new_img(80, 80)
    outlined_circle(knob, 40, 40, 36, (255, 255, 255, 220),
                    (40, 40, 40, 255), 3)
    save(knob, ASSETS / "ui" / "joystick_knob.png")


def gen_button() -> None:
    img = new_img(80, 80)
    outlined_circle(img, 40, 40, 36, (60, 60, 60, 220),
                    (240, 240, 240, 255), 3)
    save(img, ASSETS / "ui" / "btn_round.png")

    img2 = new_img(80, 80)
    outlined_circle(img2, 40, 40, 36, (200, 50, 50, 220),
                    (255, 255, 255, 255), 3)
    save(img2, ASSETS / "ui" / "btn_red.png")


def gen_logo() -> None:
    # Big logo for menu (256x96)
    img = new_img(512, 192)
    d = ImageDraw.Draw(img)
    # rat ear silhouettes
    outlined_circle(img, 60, 96, 50, (40, 30, 30, 255), OUTLINE, 3)
    outlined_circle(img, 40, 50, 22, (40, 30, 30, 255), OUTLINE, 3)
    outlined_circle(img, 80, 50, 22, (40, 30, 30, 255), OUTLINE, 3)
    outlined_circle(img, 50, 90, 6, (255, 200, 50, 255), OUTLINE, 1)
    outlined_circle(img, 70, 90, 6, (255, 200, 50, 255), OUTLINE, 1)
    save(img, ASSETS / "ui" / "logo.png")


def gen_panel() -> None:
    img = new_img(64, 64)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 63], fill=(20, 16, 14, 220), outline=OUTLINE,
                width=2)
    d.rectangle([4, 4, 59, 59], fill=(40, 30, 24, 200))
    save(img, ASSETS / "ui" / "panel.png")


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------
def gen_blood() -> None:
    sheet = new_img(64, 16)
    for c in range(4):
        f = new_img(16, 16)
        rnd = random.Random(c + 99)
        # main splatter shrinks per frame
        rmax = 6 - c * 1.2
        outlined_circle(f, 8, 8, rmax, (170, 25, 25, 220 - c * 30), None)
        for _ in range(4):
            x = 8 + rnd.randint(-5, 5)
            y = 8 + rnd.randint(-5, 5)
            outlined_circle(f, x, y, max(1, rmax * 0.4),
                            (140, 18, 18, 200 - c * 40), None)
        sheet.paste(f, (c * 16, 0), f)
    save(sheet, ASSETS / "effects" / "blood_sheet.png")


def gen_tear_impact() -> None:
    sheet = new_img(32, 8)
    for c in range(4):
        f = new_img(8, 8)
        r = 3 - c * 0.7
        outlined_circle(f, 4, 4, max(0.6, r), (200, 230, 250, 220 - c * 40),
                        None)
        sheet.paste(f, (c * 8, 0), f)
    save(sheet, ASSETS / "effects" / "tear_impact.png")


def gen_dust() -> None:
    sheet = new_img(64, 16)
    for c in range(4):
        f = new_img(16, 16)
        r = 6 - c * 1.5
        outlined_circle(f, 8, 8, max(0.6, r), (200, 180, 150, 180 - c * 40),
                        None)
        sheet.paste(f, (c * 16, 0), f)
    save(sheet, ASSETS / "effects" / "dust_sheet.png")


def gen_explosion() -> None:
    sheet = new_img(192, 32)
    for c in range(6):
        f = new_img(32, 32)
        r = 4 + c * 4
        a = 230 - c * 30
        outlined_circle(f, 16, 16, r, (255, 180, 60, a), None)
        outlined_circle(f, 16, 16, r * 0.6, (255, 240, 200, a), None)
        sheet.paste(f, (c * 32, 0), f)
    save(sheet, ASSETS / "effects" / "explosion_sheet.png")


# ---------------------------------------------------------------------------
# Icon (app)
# ---------------------------------------------------------------------------
def gen_icon() -> None:
    img = new_img(128, 128)
    # background
    outlined_circle(img, 64, 64, 60, (62, 44, 32, 255), OUTLINE, 3)
    # rat head
    outlined_circle(img, 64, 70, 38, SKIN, OUTLINE, 3)
    outlined_circle(img, 40, 38, 16, SKIN, OUTLINE, 3)
    outlined_circle(img, 88, 38, 16, SKIN, OUTLINE, 3)
    outlined_circle(img, 50, 70, 6, EYE_W, OUTLINE, 2)
    outlined_circle(img, 78, 70, 6, EYE_W, OUTLINE, 2)
    outlined_circle(img, 50, 72, 2.5, PUPIL, None)
    outlined_circle(img, 78, 72, 2.5, PUPIL, None)
    outlined_circle(img, 50, 86, 3, TEAR_BLUE, OUTLINE, 1)
    outlined_circle(img, 78, 86, 3, TEAR_BLUE, OUTLINE, 1)
    save(img, ROOT / "icon.png")


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
def main() -> None:
    print("Generating textures into", ASSETS)
    gen_player_heads()
    gen_body_sheet()
    gen_tear()
    gen_fly_sheet()
    gen_pooter_sheet()
    gen_gaper_sheet()
    gen_leaper_sheet()
    gen_spider_sheet()
    gen_monstro_sheet()
    gen_larry_sheet()
    gen_floor()
    gen_wall_top()
    gen_wall_side()
    gen_doors()
    gen_rock()
    gen_poop_frames()
    gen_pit()
    gen_coin()
    gen_hearts()
    gen_bomb()
    gen_key()
    gen_items()
    gen_ui_hearts()
    gen_ui_icons()
    gen_minimap_cells()
    gen_joystick()
    gen_button()
    gen_logo()
    gen_panel()
    gen_blood()
    gen_tear_impact()
    gen_dust()
    gen_explosion()
    gen_icon()
    print("All textures generated.")


if __name__ == "__main__":
    main()
