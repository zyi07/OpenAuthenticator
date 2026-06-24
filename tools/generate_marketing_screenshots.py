from __future__ import annotations

import math
import os
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_PHONE = ROOT / "marketing_assets" / "app_store_screenshots" / "phone"
OUT_DESKTOP = ROOT / "marketing_assets" / "app_store_screenshots" / "desktop"
LOGO = Path("/Users/mroble/app_icon_black@3x.png")
ICON_MANUAL = Path("/Users/mroble/manual_input@3x.png")
ICON_SCAN = Path("/Users/mroble/scan@3x.png")
ICON_IMPORT = Path("/Users/mroble/import@3x.png")

YELLOW = "#EBC500"
YELLOW_SOFT = "#F7D84C"
BLACK = "#050505"
INK = "#111111"
TEXT = "#1A1A1A"
MUTED = "#858585"
LIGHT_BG = "#F2F3F5"
CARD = "#FFFFFF"
DARK_BG = "#050505"
DARK_CARD = "#181818"
DARK_CARD_2 = "#222222"

ZH_FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
ZH_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"
EN_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
EN_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"


def font(size: int, bold: bool = False, english: bool = False) -> ImageFont.FreeTypeFont:
    path = EN_BLACK if english and bold else EN_BOLD if english else ZH_FONT if bold else ZH_LIGHT
    return ImageFont.truetype(path, size=size)


def hex_to_rgb(color: str) -> tuple[int, int, int]:
    color = color.lstrip("#")
    return tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))


def rgba(color: str, alpha: int) -> tuple[int, int, int, int]:
    r, g, b = hex_to_rgb(color)
    return r, g, b, alpha


def add_shadow(
    base: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    blur: int = 28,
    alpha: int = 50,
    offset: tuple[int, int] = (0, 12),
) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x1, y1, x2, y2 = box
    dx, dy = offset
    draw.rounded_rectangle((x1 + dx, y1 + dy, x2 + dx, y2 + dy), radius=radius, fill=(0, 0, 0, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def rounded_rect(
    base: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: str | tuple[int, int, int, int],
    outline: str | None = None,
    width: int = 1,
    shadow: bool = False,
) -> None:
    if shadow:
      add_shadow(base, box, radius)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0], box[3] - box[1]


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
    fnt: ImageFont.FreeTypeFont,
    fill: str,
    spacing: int = 8,
) -> None:
    lines = text.split("\n")
    sizes = [text_size(draw, line, fnt) for line in lines]
    total_h = sum(h for _, h in sizes) + spacing * (len(lines) - 1)
    y = box[1] + (box[3] - box[1] - total_h) // 2
    for line, (w, h) in zip(lines, sizes):
        x = box[0] + (box[2] - box[0] - w) // 2
        draw.text((x, y), line, font=fnt, fill=fill)
        y += h + spacing


def draw_text_block(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    title: str,
    subtitle: str,
    dark: bool = False,
    center: bool = False,
    max_width: int | None = None,
    title_size: int = 74,
) -> int:
    title_f = font(title_size, bold=True)
    sub_f = font(30)
    title_fill = CARD if dark else INK
    sub_fill = "#B7B7B7" if dark else "#5F6368"
    if center and max_width:
        for i, line in enumerate(title.split("\n")):
            w, h = text_size(draw, line, title_f)
            draw.text((x + (max_width - w) // 2, y + i * (h + 8)), line, font=title_f, fill=title_fill)
        title_h = len(title.split("\n")) * (text_size(draw, "国", title_f)[1] + 8)
        sw, sh = text_size(draw, subtitle, sub_f)
        draw.text((x + (max_width - sw) // 2, y + title_h + 22), subtitle, font=sub_f, fill=sub_fill)
        return y + title_h + 22 + sh
    draw.multiline_text((x, y), title, font=title_f, fill=title_fill, spacing=8)
    h = len(title.split("\n")) * (text_size(draw, "国", title_f)[1] + 8)
    draw.text((x, y + h + 20), subtitle, font=sub_f, fill=sub_fill)
    return y + h + 58


def draw_logo(base: Image.Image, x: int, y: int, size: int, outline: bool = False) -> None:
    logo = Image.open(LOGO).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=size // 5, fill=255)
    if outline:
        draw = ImageDraw.Draw(base)
        draw.rounded_rectangle((x - 3, y - 3, x + size + 3, y + size + 3), radius=size // 5 + 3, outline="#FFFFFF", width=3)
    base.paste(logo, (x, y), mask)


def draw_search_icon(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, color: str) -> None:
    stroke = max(2, size // 9)
    r = int(size * 0.34)
    cx = x + r + stroke
    cy = y + r + stroke
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=stroke)
    draw.line((cx + int(r * 0.65), cy + int(r * 0.65), x + size - stroke, y + size - stroke), fill=color, width=stroke)


def draw_png_icon(base: Image.Image, path: Path, center: tuple[int, int], size: int) -> None:
    if not path.exists():
        return
    icon = Image.open(path).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    x = center[0] - size // 2
    y = center[1] - size // 2
    base.alpha_composite(icon, (x, y))


def draw_token_card(
    base: Image.Image,
    x: int,
    y: int,
    w: int,
    h: int,
    name: str,
    code: str,
    next_code: str = "",
    seconds: int = 24,
    dark: bool = False,
    small: bool = False,
) -> None:
    card_fill = DARK_CARD if dark else CARD
    rounded_rect(base, (x, y, x + w, y + h), 28, card_fill, shadow=not dark)
    draw = ImageDraw.Draw(base)
    title_f = font(28 if not small else 22, bold=True)
    code_f = font(44 if not small else 34, bold=True, english=True)
    next_f = font(26 if not small else 20, bold=True, english=True)
    draw.text((x + 34, y + 26), name, font=title_f, fill=("#E7E7E7" if dark else TEXT))
    draw.text((x + 34, y + h - 66), code, font=code_f, fill=YELLOW)
    if next_code:
        aw, _ = text_size(draw, "←", font(30))
        draw.text((x + 245, y + h - 57), "←", font=font(30), fill="#D5D5D5")
        draw.text((x + 285, y + h - 60), next_code, font=next_f, fill="#858585")
    cx = x + w - 70
    cy = y + h // 2 + 4
    r = 30 if not small else 24
    draw.arc((cx - r, cy - r, cx + r, cy + r), -88, int(272 - seconds / 30 * 360), fill=YELLOW if seconds <= 5 else "#D5D5D5", width=7)
    sw, sh = text_size(draw, str(seconds), font(24 if not small else 18, bold=True, english=True))
    draw.text((cx - sw // 2, cy - sh // 2 - 2), str(seconds), font=font(24 if not small else 18, bold=True, english=True), fill=("#F8F8F8" if dark else TEXT))


def draw_phone_frame(base: Image.Image, x: int, y: int, w: int, h: int, dark_ui: bool = False, content: str = "list") -> None:
    add_shadow(base, (x, y, x + w, y + h), 56, blur=34, alpha=80, offset=(0, 22))
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((x, y, x + w, y + h), radius=58, fill="#0B0B0B")
    draw.rounded_rectangle((x + 10, y + 10, x + w - 10, y + h - 10), radius=50, fill=(DARK_BG if dark_ui else LIGHT_BG))
    draw.ellipse((x + w // 2 - 18, y + 24, x + w // 2 + 18, y + 60), fill="#020202")
    inset = 34
    sx = x + inset
    sy = y + 86
    sw = w - inset * 2
    if content == "list":
        draw.text((sx, sy), "令牌", font=font(38, bold=True), fill=("#EAEAEA" if dark_ui else INK))
        rounded_rect(base, (sx, sy + 70, sx + sw, sy + 126), 28, (rgba("#FFFFFF", 40) if dark_ui else CARD), outline=(rgba("#FFFFFF", 40) if dark_ui else "#FFFFFF"), shadow=not dark_ui)
        draw_search_icon(draw, sx + 34, sy + 88, 24, "#9A9A9A" if dark_ui else MUTED)
        draw.text((sx + 74, sy + 84), "Search", font=font(23), fill=("#9A9A9A" if dark_ui else MUTED))
        names = ["GitCode（mroble）", "Huawei Cloud", "OpenAI", "Steam"]
        codes = ["896 898", "240 771", "572 009", "A7D3K"]
        for i in range(4):
            draw_token_card(base, sx, sy + 154 + i * 128, sw, 104, names[i], codes[i], "438 026" if i == 0 else "", 24 - i * 5, dark_ui, small=True)
    elif content == "sheet":
        draw.text((sx, sy), "令牌", font=font(38, bold=True), fill=("#EAEAEA" if dark_ui else INK))
        for i in range(5):
            draw_token_card(base, sx, sy + 74 + i * 108, sw, 86, f"验证令牌{i + 1}", "896 898", "", 20, dark_ui, small=True)
        overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.rounded_rectangle((x + 10, y + 10, x + w - 10, y + h - 10), radius=50, fill=(255, 255, 255, 185) if not dark_ui else (0, 0, 0, 150))
        overlay = overlay.filter(ImageFilter.GaussianBlur(1))
        base.alpha_composite(overlay)
        panel = (x + 40, y + h - 410, x + w - 40, y + h - 58)
        rounded_rect(base, panel, 46, CARD if not dark_ui else DARK_CARD_2, shadow=True)
        labels = ["录入", "扫码", "导入"]
        icons = [ICON_MANUAL, ICON_SCAN, ICON_IMPORT]
        for i in range(3):
            cx = panel[0] + 110 + i * ((panel[2] - panel[0] - 220) // 2)
            cy = panel[1] + 120
            draw.ellipse((cx - 48, cy - 48, cx + 48, cy + 48), fill=YELLOW)
            draw_png_icon(base, icons[i], (cx, cy), 44)
            tw, _ = text_size(draw, labels[i], font(26, bold=True))
            draw.text((cx - tw // 2, cy + 76), labels[i], font=font(26, bold=True), fill=(CARD if dark_ui else INK))
    elif content == "settings":
        draw.text((sx, sy), "我的", font=font(38, bold=True), fill=("#EAEAEA" if dark_ui else INK))
        rounded_rect(base, (sx, sy + 74, sx + sw, sy + 166), 28, DARK_CARD if dark_ui else CARD, shadow=not dark_ui)
        draw_logo(base, sx + 26, sy + 94, 54, outline=dark_ui)
        draw.text((sx + 98, sy + 92), "Authenticator", font=font(26, bold=True), fill=("#EAEAEA" if dark_ui else INK))
        draw.text((sx + 98, sy + 126), "本地优先，安全同步", font=font(20), fill=("#AFAFAF" if dark_ui else MUTED))
        rows = ["应用锁定", "深色模式", "主题色", "备份导出"]
        for i, row in enumerate(rows):
            top = sy + 196 + i * 80
            rounded_rect(base, (sx, top, sx + sw, top + 64), 22, DARK_CARD if dark_ui else CARD, shadow=False)
            draw.text((sx + 28, top + 17), row, font=font(23, bold=True), fill=("#EAEAEA" if dark_ui else INK))
            if row == "主题色":
                draw.ellipse((sx + sw - 74, top + 21, sx + sw - 48, top + 47), fill=YELLOW)
            else:
                draw.rounded_rectangle((sx + sw - 86, top + 18, sx + sw - 30, top + 46), radius=14, fill=YELLOW if i == 0 else "#D7D7D7")
                draw.ellipse((sx + sw - 54, top + 20, sx + sw - 30, top + 44), fill=CARD)


def draw_laptop(base: Image.Image, x: int, y: int, w: int, h: int, dark_ui: bool = False, content: str = "grid") -> None:
    screen_h = int(h * 0.78)
    add_shadow(base, (x, y, x + w, y + screen_h), 30, blur=40, alpha=70, offset=(0, 22))
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((x, y, x + w, y + screen_h), radius=34, fill="#0A0A0A")
    draw.rounded_rectangle((x + 12, y + 12, x + w - 12, y + screen_h - 12), radius=24, fill=(DARK_BG if dark_ui else LIGHT_BG))
    draw.rounded_rectangle((x + w // 2 - 220, y + screen_h, x + w // 2 + 220, y + h), radius=34, fill="#D9D9D9")
    draw.rounded_rectangle((x - 90, y + h - 18, x + w + 90, y + h + 16), radius=18, fill="#CFCFCF")
    sx, sy = x + 58, y + 58
    sw = w - 116
    draw.text((sx, sy), "令牌", font=font(42, bold=True), fill=("#EDEDED" if dark_ui else INK))
    rounded_rect(base, (sx, sy + 66, sx + sw, sy + 122), 28, rgba("#FFFFFF", 36) if dark_ui else CARD, outline=rgba("#FFFFFF", 34) if dark_ui else "#FFFFFF")
    draw.text((sx + 28, sy + 82), "⌕ Search", font=font(23), fill=("#9A9A9A" if dark_ui else MUTED))
    cols = 3 if content != "wide" else 4
    gap = 22
    card_w = (sw - gap * (cols - 1)) // cols
    card_h = 122
    for i in range(8 if cols == 4 else 6):
        cx = sx + (i % cols) * (card_w + gap)
        cy = sy + 154 + (i // cols) * (card_h + gap)
        draw_token_card(base, cx, cy, card_w, card_h, ["GitCode", "Cloud", "OpenAI", "Steam", "HOTP", "Work", "Bank", "Email"][i], ["896 898", "240 771", "572 009", "A7D3K", "004 922", "776 219", "305 241", "088 640"][i], "", 24 - i, dark_ui, small=True)


def radial_glow(base: Image.Image, center: tuple[int, int], color: str, radius: int, alpha: int) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = center
    for r in range(radius, 0, -8):
        a = int(alpha * (1 - r / radius) ** 2)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgba(color, a))
    base.alpha_composite(layer)


def phone_canvas(bg: str) -> Image.Image:
    return Image.new("RGBA", (1242, 2688), bg)


def desktop_canvas(bg: str) -> Image.Image:
    return Image.new("RGBA", (1920, 1080), bg)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(path, quality=96, optimize=True)


def phone_1() -> None:
    img = phone_canvas("#EFEFEF")
    draw = ImageDraw.Draw(img)
    radial_glow(img, (1040, 260), YELLOW, 260, 100)
    draw_logo(img, 90, 110, 72)
    draw.text((180, 122), "Authenticator", font=font(34, bold=True, english=True), fill=INK)
    draw_text_block(draw, 90, 250, "验证码，\n一屏掌控", "TOTP / HOTP / Steam 动态令牌", title_size=86)
    draw_phone_frame(img, 290, 735, 660, 1420, dark_ui=False, content="list")
    draw.rounded_rectangle((90, 2286, 430, 2352), radius=33, fill=BLACK)
    draw.text((128, 2303), "本地优先", font=font(28, bold=True), fill=CARD)
    draw.text((90, 2392), "无需复杂设置，打开即可查看常用验证码。", font=font(28), fill="#555555")
    save(img, OUT_PHONE / "phone_01_token_overview.png")


def phone_2() -> None:
    img = phone_canvas(BLACK)
    draw = ImageDraw.Draw(img)
    radial_glow(img, (330, 450), YELLOW, 300, 130)
    draw_text_block(draw, 90, 140, "扫码、导入、\n录入", "迁移码、二维码、文件导入都在一个入口", dark=True, title_size=84)
    draw_phone_frame(img, 290, 720, 660, 1420, dark_ui=True, content="sheet")
    draw.text((90, 2315), "Google Authenticator 迁移码可解析", font=font(30, bold=True), fill=CARD)
    draw.text((90, 2370), "批量导入时会校验密钥格式，避免无效令牌。", font=font(25), fill="#AFAFAF")
    save(img, OUT_PHONE / "phone_02_add_import_scan.png")


def phone_3() -> None:
    img = phone_canvas(YELLOW)
    draw = ImageDraw.Draw(img)
    draw_text_block(draw, 90, 150, "服务卡片，\n桌面直达", "1×2、2×2、2×4、4×4 多尺寸显示", title_size=82)
    y = 720
    sizes = [(470, 260), (470, 470), (1000, 440)]
    labels = ["1×2", "2×2", "2×4"]
    for idx, (w, h) in enumerate(sizes):
        x = 90 if idx < 2 else 120
        yy = y + idx * 350 if idx < 2 else 1450
        if idx == 1:
            x = 680
            yy = y
        rounded_rect(img, (x, yy, x + w, yy + h), 42, "#111111", shadow=True)
        draw.text((x + 34, yy + 30), labels[idx], font=font(30, bold=True, english=True), fill=YELLOW)
        draw.text((x + 34, yy + 80), "Authenticator", font=font(24, bold=True, english=True), fill=CARD)
        draw.text((x + 34, yy + h - 92), "896 898", font=font(48, bold=True, english=True), fill=YELLOW)
        draw.arc((x + w - 96, yy + h - 105, x + w - 40, yy + h - 49), -90, 180, fill="#D5D5D5", width=7)
    draw.rounded_rectangle((90, 2206, 890, 2290), radius=42, fill=BLACK)
    draw.text((130, 2225), "无需打开应用，也能看见令牌", font=font(34, bold=True), fill=CARD)
    save(img, OUT_PHONE / "phone_03_widgets.png")


def phone_4() -> None:
    img = phone_canvas("#F8F6EF")
    draw = ImageDraw.Draw(img)
    radial_glow(img, (1020, 610), YELLOW, 260, 90)
    draw_text_block(draw, 90, 130, "手机、平板、\n电脑都好用", "响应式多列布局，窗口变化也优雅", title_size=78)
    draw_laptop(img, 115, 770, 1010, 700, dark_ui=False, content="wide")
    draw_phone_frame(img, 650, 1400, 430, 920, dark_ui=False, content="list")
    draw.rounded_rectangle((90, 2260, 575, 2335), radius=38, fill=YELLOW)
    draw.text((130, 2279), "多端自适应", font=font(32, bold=True), fill=INK)
    draw.text((90, 2390), "折叠屏、平板、鸿蒙电脑，列表自动变成多列。", font=font(27), fill="#555555")
    save(img, OUT_PHONE / "phone_04_responsive.png")


def phone_5() -> None:
    img = phone_canvas(BLACK)
    draw = ImageDraw.Draw(img)
    radial_glow(img, (180, 580), YELLOW, 300, 120)
    draw_text_block(draw, 90, 150, "隐私优先，\n安心使用", "本地存储、应用锁定、深色模式与主题色", dark=True, title_size=82)
    draw_logo(img, 470, 620, 300, outline=True)
    draw_phone_frame(img, 290, 1050, 660, 1120, dark_ui=True, content="settings")
    draw.text((90, 2305), "你的密钥，只由你掌控", font=font(34, bold=True), fill=CARD)
    draw.text((90, 2365), "备份、导出、云空间同步均可按需开启。", font=font(26), fill="#AFAFAF")
    save(img, OUT_PHONE / "phone_05_privacy_theme.png")


def desktop_1() -> None:
    img = desktop_canvas("#EFEFEF")
    draw = ImageDraw.Draw(img)
    radial_glow(img, (1520, 170), YELLOW, 350, 90)
    draw_logo(img, 110, 90, 84)
    draw.text((215, 105), "Authenticator", font=font(44, bold=True, english=True), fill=INK)
    draw.text((110, 210), "专业的动态令牌管理器", font=font(70, bold=True), fill=INK)
    draw.text((112, 305), "把常用验证码、导入、备份与桌面卡片放进同一个简洁体验。", font=font(30), fill="#5F6368")
    draw_laptop(img, 490, 385, 1250, 560, dark_ui=False, content="grid")
    save(img, OUT_DESKTOP / "desktop_01_overview.png")


def desktop_2() -> None:
    img = desktop_canvas(BLACK)
    draw = ImageDraw.Draw(img)
    radial_glow(img, (300, 240), YELLOW, 300, 110)
    draw.text((110, 100), "多列令牌，快速搜索", font=font(68, bold=True), fill=CARD)
    draw.text((112, 190), "窗口越大，信息越清晰；搜索框始终轻盈克制。", font=font(30), fill="#AFAFAF")
    draw_laptop(img, 280, 300, 1360, 610, dark_ui=True, content="wide")
    save(img, OUT_DESKTOP / "desktop_02_multicolumn_search.png")


def desktop_3() -> None:
    img = desktop_canvas("#F5F6F8")
    draw = ImageDraw.Draw(img)
    draw.text((110, 95), "云空间同步与备份导出", font=font(66, bold=True), fill=INK)
    draw.text((112, 185), "按需同步、手动推送、JSON 与二维码备份，迁移更轻松。", font=font(30), fill="#5F6368")
    for i, title in enumerate(["华为云空间", "备份导出", "同步状态"]):
        x = 125 + i * 560
        y = 350
        rounded_rect(img, (x, y, x + 470, y + 430), 46, CARD, shadow=True)
        draw.ellipse((x + 48, y + 56, x + 128, y + 136), fill=YELLOW)
        draw.text((x + 70, y + 70), ["☁", "↑", "✓"][i], font=font(42, bold=True), fill=INK)
        draw.text((x + 48, y + 175), title, font=font(42, bold=True), fill=INK)
        draw.text((x + 48, y + 245), ["自动同步常用令牌", "导出 JSON 或二维码", "记录最近同步结果"][i], font=font(27), fill=MUTED)
        draw.rounded_rectangle((x + 48, y + 330, x + 300, y + 382), radius=26, fill="#F2F3F5")
        draw.text((x + 80, y + 343), ["已开启", "选择令牌", "同步成功"][i], font=font(24, bold=True), fill=INK)
    save(img, OUT_DESKTOP / "desktop_03_cloud_backup.png")


def desktop_4() -> None:
    img = desktop_canvas(YELLOW)
    draw = ImageDraw.Draw(img)
    draw.text((110, 90), "服务卡片，多尺寸显示", font=font(68, bold=True), fill=INK)
    draw.text((112, 180), "从最小卡片到大尺寸卡片，桌面快速查看常用验证码。", font=font(30), fill="#3D3D3D")
    specs = [(125, 340, 330, 180, "1×2"), (510, 340, 330, 330, "2×2"), (895, 340, 470, 330, "2×4"), (1420, 250, 360, 560, "4×4")]
    for x, y, w, h, label in specs:
        rounded_rect(img, (x, y, x + w, y + h), 36, BLACK, shadow=True)
        draw.text((x + 28, y + 28), label, font=font(26, bold=True, english=True), fill=YELLOW)
        draw.text((x + 28, y + 72), "Authenticator", font=font(22, bold=True, english=True), fill=CARD)
        slots = 1 if label == "1×2" else 2 if label == "2×2" else 4 if label == "2×4" else 8
        for i in range(slots):
            yy = y + 115 + i * 50
            if yy > y + h - 55:
                break
            draw.text((x + 28, yy), ["896 898", "240 771", "572 009", "305 241", "776 219", "088 640", "004 922", "671 803"][i], font=font(34, bold=True, english=True), fill=YELLOW)
            draw.text((x + w - 74, yy + 5), str(24 - i * 2), font=font(22, bold=True, english=True), fill="#D5D5D5")
    save(img, OUT_DESKTOP / "desktop_04_widgets.png")


def desktop_5() -> None:
    img = desktop_canvas("#EDEDED")
    draw = ImageDraw.Draw(img)
    draw.text((110, 90), "深色 / 浅色，主题随心", font=font(68, bold=True), fill=INK)
    draw.text((112, 180), "六款主题色，配合系统深浅色模式，保持清晰和克制。", font=font(30), fill="#5F6368")
    draw_laptop(img, 110, 330, 820, 520, dark_ui=False, content="grid")
    draw_laptop(img, 980, 330, 820, 520, dark_ui=True, content="grid")
    colors = ["#EBC500", "#D6B75D", "#72A28B", "#6F98AE", "#CE96A4", "#292C30"]
    for i, color in enumerate(colors):
        draw.ellipse((750 + i * 70, 900, 800 + i * 70, 950), fill=color)
    save(img, OUT_DESKTOP / "desktop_05_theme_modes.png")


def main() -> None:
    for directory in (OUT_PHONE, OUT_DESKTOP):
        directory.mkdir(parents=True, exist_ok=True)
    phone_1()
    phone_2()
    phone_3()
    phone_4()
    phone_5()
    desktop_1()
    desktop_2()
    desktop_3()
    desktop_4()
    desktop_5()


if __name__ == "__main__":
    main()
