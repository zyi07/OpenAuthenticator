from __future__ import annotations

import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_PHONE = ROOT / "marketing_assets" / "app_store_screenshots_svg" / "phone"
OUT_DESKTOP = ROOT / "marketing_assets" / "app_store_screenshots_svg" / "desktop"

YELLOW = "#EBC500"
YELLOW_SOFT = "#F5D748"
BLACK = "#050505"
INK = "#111111"
MUTED = "#858585"
LIGHT_BG = "#F2F3F5"
CARD = "#FFFFFF"
DARK_BG = "#050505"
DARK_CARD = "#181818"
DARK_CARD_2 = "#252525"
GRAY = "#D5D5D5"

FONT = "'HarmonyOS Sans SC', 'PingFang SC', 'Microsoft YaHei', sans-serif"
FONT_EN = "'Arial Black', 'HarmonyOS Sans', sans-serif"


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def arc_path(cx: float, cy: float, r: float, start_deg: float, end_deg: float) -> str:
    start = math.radians(start_deg)
    end = math.radians(end_deg)
    x1 = cx + r * math.cos(start)
    y1 = cy + r * math.sin(start)
    x2 = cx + r * math.cos(end)
    y2 = cy + r * math.sin(end)
    large = 1 if abs(end_deg - start_deg) > 180 else 0
    sweep = 1 if end_deg > start_deg else 0
    return f"M {x1:.2f} {y1:.2f} A {r:.2f} {r:.2f} 0 {large} {sweep} {x2:.2f} {y2:.2f}"


class Svg:
    def __init__(self, width: int, height: int, bg: str):
        self.width = width
        self.height = height
        self.parts: list[str] = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            "<defs>",
            '<filter id="shadow" x="-30%" y="-30%" width="160%" height="170%">'
            '<feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#000000" flood-opacity=".18"/></filter>',
            '<filter id="deepShadow" x="-30%" y="-30%" width="160%" height="170%">'
            '<feDropShadow dx="0" dy="22" stdDeviation="28" flood-color="#000000" flood-opacity=".34"/></filter>',
            '<radialGradient id="yellowGlow" cx="50%" cy="50%" r="50%">'
            f'<stop offset="0%" stop-color="{YELLOW}" stop-opacity=".55"/>'
            f'<stop offset="52%" stop-color="{YELLOW}" stop-opacity=".18"/>'
            f'<stop offset="100%" stop-color="{YELLOW}" stop-opacity="0"/></radialGradient>',
            '<linearGradient id="softCard" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0%" stop-color="#FFFFFF" stop-opacity=".98"/>'
            '<stop offset="100%" stop-color="#FFFFFF" stop-opacity=".74"/></linearGradient>',
            '<linearGradient id="darkPanel" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0%" stop-color="#2C2C2C"/>'
            '<stop offset="100%" stop-color="#171717"/></linearGradient>',
            "</defs>",
            f'<rect width="100%" height="100%" fill="{bg}"/>',
            f'<style>text{{font-family:{FONT};dominant-baseline:hanging}} .en{{font-family:{FONT_EN}}}</style>',
        ]

    def raw(self, value: str) -> None:
        self.parts.append(value)

    def rect(self, x: int, y: int, w: int, h: int, r: int, fill: str, stroke: str = "none", sw: int = 1,
             shadow: bool = False, opacity: float | None = None) -> None:
        extra = ' filter="url(#shadow)"' if shadow else ""
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"{extra}{op}/>'
        )

    def circle(self, cx: int, cy: int, r: int, fill: str, stroke: str = "none", sw: int = 1,
               opacity: float | None = None) -> None:
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{op}/>')

    def text(self, x: int, y: int, value: str, size: int, fill: str, weight: int = 400,
             anchor: str = "start", cls: str = "") -> None:
        klass = f' class="{cls}"' if cls else ""
        self.parts.append(
            f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{klass}>{esc(value)}</text>'
        )

    def multiline(self, x: int, y: int, lines: list[str], size: int, fill: str, weight: int = 800,
                  gap: int = 16, anchor: str = "start") -> None:
        for index, line in enumerate(lines):
            self.text(x, y + index * (size + gap), line, size, fill, weight, anchor)

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.parts.append("</svg>")
        path.write_text("\n".join(self.parts), encoding="utf-8")


def logo(s: Svg, x: int, y: int, size: int) -> None:
    s.rect(x, y, size, size, size // 6, BLACK)
    scale = size / 100
    def p(v: float) -> float:
        return x + v * scale
    def q(v: float) -> float:
        return y + v * scale
    shield = (
        f"M {p(50)} {q(18)} C {p(41)} {q(30)} {p(28)} {q(35)} {p(20)} {q(35)} "
        f"L {p(17)} {q(56)} C {p(17)} {q(73)} {p(30)} {q(85)} {p(50)} {q(94)} "
        f"C {p(70)} {q(85)} {p(83)} {q(73)} {p(83)} {q(56)} L {p(80)} {q(35)} "
        f"C {p(72)} {q(35)} {p(59)} {q(30)} {p(50)} {q(18)} Z"
    )
    s.raw(f'<path d="{shield}" fill="none" stroke="#FFFFFF" stroke-width="{max(5, int(size * .08))}" stroke-linejoin="round"/>')
    s.circle(int(p(50)), int(q(55)), max(8, int(size * .11)), "#FFFFFF")
    s.raw(f'<path d="M {p(50)} {q(68)} C {p(37)} {q(68)} {p(31)} {q(78)} {p(31)} {q(86)} L {p(69)} {q(86)} C {p(69)} {q(78)} {p(63)} {q(68)} {p(50)} {q(68)} Z" fill="#FFFFFF"/>')


def search_icon(s: Svg, x: int, y: int, size: int, color: str) -> None:
    r = size * .32
    cx = x + size * .42
    cy = y + size * .42
    sw = max(3, int(size * .08))
    s.raw(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="none" stroke="{color}" stroke-width="{sw}"/>')
    s.raw(f'<path d="M {cx + r * .72:.1f} {cy + r * .72:.1f} L {x + size * .88:.1f} {y + size * .88:.1f}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>')


def button_icon(s: Svg, kind: str, cx: int, cy: int, color: str = CARD) -> None:
    if kind == "manual":
        s.raw(f'<path d="M {cx-14} {cy+17} L {cx+16} {cy-13} L {cx+24} {cy-5} L {cx-6} {cy+25} L {cx-20} {cy+29} Z" fill="none" stroke="{color}" stroke-width="5" stroke-linejoin="round"/>')
        s.raw(f'<path d="M {cx+11} {cy-18} L {cx+22} {cy-7}" stroke="{color}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "scan":
        for dx, dy, sx, sy in [(-24, -24, 1, 1), (24, -24, -1, 1), (-24, 24, 1, -1), (24, 24, -1, -1)]:
            s.raw(f'<path d="M {cx+dx} {cy+dy+16*sy} L {cx+dx} {cy+dy} L {cx+dx+16*sx} {cy+dy}" fill="none" stroke="{color}" stroke-width="5" stroke-linecap="round"/>')
        s.raw(f'<path d="M {cx-25} {cy} H {cx+25}" stroke="{color}" stroke-width="4" stroke-linecap="round" opacity=".9"/>')
    elif kind == "import":
        s.raw(f'<path d="M {cx} {cy-28} V {cy+8}" stroke="{color}" stroke-width="6" stroke-linecap="round"/>')
        s.raw(f'<path d="M {cx-16} {cy-8} L {cx} {cy+8} L {cx+16} {cy-8}" fill="none" stroke="{color}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')
        s.raw(f'<path d="M {cx-28} {cy+13} V {cy+28} H {cx+28} V {cy+13}" fill="none" stroke="{color}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')
    elif kind == "cloud":
        s.raw(f'<path d="M {cx-32} {cy+9} C {cx-32} {cy-4} {cx-20} {cy-12} {cx-8} {cy-9} C {cx-5} {cy-24} {cx+20} {cy-24} {cx+24} {cy-7} C {cx+36} {cy-7} {cx+44} {cy+1} {cx+44} {cy+12} C {cx+44} {cy+24} {cx+35} {cy+30} {cx+22} {cy+30} H {cx-26} C {cx-39} {cy+30} {cx-48} {cy+22} {cx-48} {cy+12} C {cx-48} {cy+3} {cx-42} {cy-3} {cx-32} {cy+9} Z" fill="none" stroke="{color}" stroke-width="5" stroke-linejoin="round"/>')


def token_card(s: Svg, x: int, y: int, w: int, h: int, name: str, code: str, next_code: str = "",
               seconds: int = 24, dark: bool = False, small: bool = False) -> None:
    fill = DARK_CARD if dark else CARD
    s.rect(x, y, w, h, 28, fill, shadow=not dark)
    s.text(x + 34, y + 24, name, 28 if not small else 22, "#E7E7E7" if dark else INK, 700)
    s.text(x + 34, y + h - 56, code, 44 if not small else 34, YELLOW, 900, cls="en")
    if next_code:
        s.text(x + 250, y + h - 51, "←", 26, GRAY, 400)
        s.text(x + 292, y + h - 54, next_code, 26 if not small else 20, MUTED, 800, cls="en")
    cx, cy = x + w - 70, y + h // 2 + 4
    r = 30 if not small else 24
    end = -90 + max(0.02, min(1, seconds / 30)) * 360
    s.raw(f'<path d="{arc_path(cx, cy, r, -90, end)}" fill="none" stroke="{YELLOW if seconds <= 5 else GRAY}" stroke-width="{7 if not small else 6}" stroke-linecap="round"/>')
    s.text(cx, cy - 13, str(seconds), 24 if not small else 18, "#F8F8F8" if dark else INK, 800, "middle", "en")


def phone_frame(s: Svg, x: int, y: int, w: int, h: int, dark_ui: bool = False, content: str = "list") -> None:
    s.rect(x, y, w, h, 58, "#0B0B0B", shadow=True)
    s.rect(x + 10, y + 10, w - 20, h - 20, 50, DARK_BG if dark_ui else LIGHT_BG)
    s.circle(x + w // 2, y + 42, 18, "#020202")
    sx, sy, sw = x + 34, y + 86, w - 68
    text_color = "#EAEAEA" if dark_ui else INK
    if content == "list":
        s.text(sx, sy, "令牌", 38, text_color, 800)
        s.rect(sx, sy + 70, sw, 56, 28, "rgba(255,255,255,.16)" if dark_ui else CARD, "#FFFFFF", shadow=not dark_ui)
        search_icon(s, sx + 34, sy + 88, 24, "#9A9A9A" if dark_ui else MUTED)
        s.text(sx + 74, sy + 84, "Search", 23, "#9A9A9A" if dark_ui else MUTED)
        for i, (name, code) in enumerate([("GitCode（mroble）", "896 898"), ("Huawei Cloud", "240 771"), ("OpenAI", "572 009"), ("Steam", "A7D3K")]):
            token_card(s, sx, sy + 154 + i * 128, sw, 104, name, code, "438 026" if i == 0 else "", 24 - i * 5, dark_ui, True)
    elif content == "sheet":
        s.text(sx, sy, "令牌", 38, text_color, 800)
        for i in range(5):
            token_card(s, sx, sy + 74 + i * 108, sw, 86, f"验证令牌{i + 1}", "896 898", "", 20, dark_ui, True)
        s.rect(x + 10, y + 10, w - 20, h - 20, 50, "#000000" if dark_ui else "#FFFFFF", opacity=.64)
        panel_x, panel_y, panel_w, panel_h = x + 40, y + h - 410, w - 80, 352
        s.rect(panel_x, panel_y, panel_w, panel_h, 46, "url(#darkPanel)" if dark_ui else CARD, shadow=True)
        for i, (label, kind) in enumerate([("录入", "manual"), ("扫码", "scan"), ("导入", "import")]):
            cx = panel_x + 110 + i * ((panel_w - 220) // 2)
            cy = panel_y + 120
            s.circle(cx, cy, 48, YELLOW)
            button_icon(s, kind, cx, cy)
            s.text(cx, cy + 76, label, 26, CARD if dark_ui else INK, 800, "middle")
    elif content == "settings":
        s.text(sx, sy, "我的", 38, text_color, 800)
        s.rect(sx, sy + 74, sw, 92, 28, DARK_CARD if dark_ui else CARD, shadow=not dark_ui)
        logo(s, sx + 26, sy + 94, 54)
        s.text(sx + 98, sy + 92, "Authenticator", 26, text_color, 800)
        s.text(sx + 98, sy + 126, "本地优先，安全同步", 20, "#AFAFAF" if dark_ui else MUTED)
        for i, row in enumerate(["应用锁定", "深色模式", "主题色", "备份导出"]):
            top = sy + 196 + i * 80
            s.rect(sx, top, sw, 64, 22, DARK_CARD if dark_ui else CARD)
            s.text(sx + 28, top + 17, row, 23, text_color, 800)
            if row == "主题色":
                s.circle(sx + sw - 61, top + 34, 13, YELLOW)
            else:
                s.rect(sx + sw - 86, top + 18, 56, 28, 14, YELLOW if i == 0 else "#D7D7D7")
                s.circle(sx + sw - 42, top + 32, 12, CARD)


def laptop(s: Svg, x: int, y: int, w: int, h: int, dark_ui: bool = False, cols: int = 3) -> None:
    screen_h = int(h * .78)
    s.rect(x, y, w, screen_h, 34, "#0A0A0A", shadow=True)
    s.rect(x + 12, y + 12, w - 24, screen_h - 24, 24, DARK_BG if dark_ui else LIGHT_BG)
    s.rect(x + w // 2 - 220, y + screen_h, 440, h - screen_h, 34, "#D9D9D9")
    s.rect(x - 90, y + h - 18, w + 180, 34, 18, "#CFCFCF")
    sx, sy, sw = x + 58, y + 58, w - 116
    text_color = "#EDEDED" if dark_ui else INK
    s.text(sx, sy, "令牌", 42, text_color, 800)
    s.rect(sx, sy + 66, sw, 56, 28, "rgba(255,255,255,.16)" if dark_ui else CARD, "#FFFFFF")
    search_icon(s, sx + 28, sy + 82, 24, "#9A9A9A" if dark_ui else MUTED)
    s.text(sx + 68, sy + 78, "Search", 23, "#9A9A9A" if dark_ui else MUTED)
    gap = 22
    card_w = (sw - gap * (cols - 1)) // cols
    card_h = 122
    names = ["GitCode", "Cloud", "OpenAI", "Steam", "HOTP", "Work", "Bank", "Email"]
    codes = ["896 898", "240 771", "572 009", "A7D3K", "004 922", "776 219", "305 241", "088 640"]
    for i in range(8 if cols == 4 else 6):
        cx = sx + (i % cols) * (card_w + gap)
        cy = sy + 154 + (i // cols) * (card_h + gap)
        token_card(s, cx, cy, card_w, card_h, names[i], codes[i], "", 24 - i, dark_ui, True)


def title_block(s: Svg, x: int, y: int, lines: list[str], subtitle: str, dark: bool = False, size: int = 84) -> None:
    s.multiline(x, y, lines, size, CARD if dark else INK, 900, 14)
    s.text(x, y + len(lines) * (size + 14) + 22, subtitle, 30, "#B7B7B7" if dark else "#5F6368")


def phone_1() -> None:
    s = Svg(1242, 2688, "#EFEFEF")
    s.raw('<circle cx="1040" cy="260" r="260" fill="url(#yellowGlow)"/>')
    logo(s, 90, 110, 72)
    s.text(180, 122, "Authenticator", 34, INK, 900, cls="en")
    title_block(s, 90, 250, ["验证码，", "一屏掌控"], "TOTP / HOTP / Steam 动态令牌", size=86)
    phone_frame(s, 290, 735, 660, 1420, False, "list")
    s.rect(90, 2286, 340, 66, 33, BLACK)
    s.text(128, 2303, "本地优先", 28, CARD, 800)
    s.text(90, 2392, "无需复杂设置，打开即可查看常用验证码。", 28, "#555555")
    s.save(OUT_PHONE / "phone_01_token_overview.svg")


def phone_2() -> None:
    s = Svg(1242, 2688, BLACK)
    s.raw('<circle cx="330" cy="450" r="300" fill="url(#yellowGlow)"/>')
    title_block(s, 90, 140, ["扫码、导入、", "录入"], "迁移码、二维码、文件导入都在一个入口", True, 84)
    phone_frame(s, 290, 720, 660, 1420, True, "sheet")
    s.text(90, 2315, "Google Authenticator 迁移码可解析", 30, CARD, 800)
    s.text(90, 2370, "批量导入时会校验密钥格式，避免无效令牌。", 25, "#AFAFAF")
    s.save(OUT_PHONE / "phone_02_add_import_scan.svg")


def phone_3() -> None:
    s = Svg(1242, 2688, YELLOW)
    title_block(s, 90, 150, ["服务卡片，", "桌面直达"], "1×2、2×2、2×4、4×4 多尺寸显示", False, 82)
    widgets = [(90, 720, 470, 260, "1×2"), (680, 720, 470, 470, "2×2"), (120, 1450, 1000, 440, "2×4")]
    for x, y, w, h, label in widgets:
        s.rect(x, y, w, h, 42, "#111111", shadow=True)
        s.text(x + 34, y + 30, label, 30, YELLOW, 900, cls="en")
        s.text(x + 34, y + 80, "Authenticator", 24, CARD, 900, cls="en")
        s.text(x + 34, y + h - 92, "896 898", 48, YELLOW, 900, cls="en")
        s.raw(f'<path d="{arc_path(x + w - 68, y + h - 77, 28, -90, 180)}" fill="none" stroke="{GRAY}" stroke-width="7" stroke-linecap="round"/>')
    s.rect(90, 2206, 800, 84, 42, BLACK)
    s.text(130, 2225, "无需打开应用，也能看见令牌", 34, CARD, 800)
    s.save(OUT_PHONE / "phone_03_widgets.svg")


def phone_4() -> None:
    s = Svg(1242, 2688, "#F8F6EF")
    s.raw('<circle cx="1020" cy="610" r="260" fill="url(#yellowGlow)"/>')
    title_block(s, 90, 130, ["手机、平板、", "电脑都好用"], "响应式多列布局，窗口变化也优雅", False, 78)
    laptop(s, 115, 770, 1010, 700, False, 4)
    phone_frame(s, 650, 1400, 430, 920, False, "list")
    s.rect(90, 2260, 485, 75, 38, YELLOW)
    s.text(130, 2279, "多端自适应", 32, INK, 800)
    s.text(90, 2390, "折叠屏、平板、鸿蒙电脑，列表自动变成多列。", 27, "#555555")
    s.save(OUT_PHONE / "phone_04_responsive.svg")


def phone_5() -> None:
    s = Svg(1242, 2688, BLACK)
    s.raw('<circle cx="180" cy="580" r="300" fill="url(#yellowGlow)"/>')
    title_block(s, 90, 150, ["隐私优先，", "安心使用"], "本地存储、应用锁定、深色模式与主题色", True, 82)
    logo(s, 470, 620, 300)
    phone_frame(s, 290, 1050, 660, 1120, True, "settings")
    s.text(90, 2305, "你的密钥，只由你掌控", 34, CARD, 800)
    s.text(90, 2365, "备份、导出、云空间同步均可按需开启。", 26, "#AFAFAF")
    s.save(OUT_PHONE / "phone_05_privacy_theme.svg")


def desktop_1() -> None:
    s = Svg(1920, 1080, "#EFEFEF")
    s.raw('<circle cx="1520" cy="170" r="350" fill="url(#yellowGlow)"/>')
    logo(s, 110, 90, 84)
    s.text(215, 105, "Authenticator", 44, INK, 900, cls="en")
    s.text(110, 210, "专业的动态令牌管理器", 70, INK, 900)
    s.text(112, 305, "把常用验证码、导入、备份与桌面卡片放进同一个简洁体验。", 30, "#5F6368")
    laptop(s, 490, 385, 1250, 560, False, 3)
    s.save(OUT_DESKTOP / "desktop_01_overview.svg")


def desktop_2() -> None:
    s = Svg(1920, 1080, BLACK)
    s.raw('<circle cx="300" cy="240" r="300" fill="url(#yellowGlow)"/>')
    s.text(110, 100, "多列令牌，快速搜索", 68, CARD, 900)
    s.text(112, 190, "窗口越大，信息越清晰；搜索框始终轻盈克制。", 30, "#AFAFAF")
    laptop(s, 280, 300, 1360, 610, True, 4)
    s.save(OUT_DESKTOP / "desktop_02_multicolumn_search.svg")


def desktop_3() -> None:
    s = Svg(1920, 1080, "#F5F6F8")
    s.text(110, 95, "云空间同步与备份导出", 66, INK, 900)
    s.text(112, 185, "按需同步、手动推送、JSON 与二维码备份，迁移更轻松。", 30, "#5F6368")
    data = [("华为云空间", "自动同步常用令牌", "已开启", "cloud"), ("备份导出", "导出 JSON 或二维码", "选择令牌", "import"), ("同步状态", "记录最近同步结果", "同步成功", "scan")]
    for i, (title, desc, badge, kind) in enumerate(data):
        x, y = 125 + i * 560, 350
        s.rect(x, y, 470, 430, 46, CARD, shadow=True)
        s.circle(x + 88, y + 96, 40, YELLOW)
        button_icon(s, kind, x + 88, y + 96, INK)
        s.text(x + 48, y + 175, title, 42, INK, 900)
        s.text(x + 48, y + 245, desc, 27, MUTED)
        s.rect(x + 48, y + 330, 252, 52, 26, LIGHT_BG)
        s.text(x + 80, y + 343, badge, 24, INK, 800)
    s.save(OUT_DESKTOP / "desktop_03_cloud_backup.svg")


def desktop_4() -> None:
    s = Svg(1920, 1080, YELLOW)
    s.text(110, 90, "服务卡片，多尺寸显示", 68, INK, 900)
    s.text(112, 180, "从最小卡片到大尺寸卡片，桌面快速查看常用验证码。", 30, "#3D3D3D")
    specs = [(125, 340, 330, 180, "1×2"), (510, 340, 330, 330, "2×2"), (895, 340, 470, 330, "2×4"), (1420, 250, 360, 560, "4×4")]
    values = ["896 898", "240 771", "572 009", "305 241", "776 219", "088 640", "004 922", "671 803"]
    for x, y, w, h, label in specs:
        s.rect(x, y, w, h, 36, BLACK, shadow=True)
        s.text(x + 28, y + 28, label, 26, YELLOW, 900, cls="en")
        s.text(x + 28, y + 72, "Authenticator", 22, CARD, 900, cls="en")
        slots = 1 if label == "1×2" else 2 if label == "2×2" else 4 if label == "2×4" else 8
        for i in range(slots):
            yy = y + 115 + i * 50
            if yy > y + h - 55:
                break
            s.text(x + 28, yy, values[i], 34, YELLOW, 900, cls="en")
            s.text(x + w - 74, yy + 5, str(24 - i * 2), 22, GRAY, 900, cls="en")
    s.save(OUT_DESKTOP / "desktop_04_widgets.svg")


def desktop_5() -> None:
    s = Svg(1920, 1080, "#EDEDED")
    s.text(110, 90, "深色 / 浅色，主题随心", 68, INK, 900)
    s.text(112, 180, "六款主题色，配合系统深浅色模式，保持清晰和克制。", 30, "#5F6368")
    laptop(s, 110, 330, 820, 520, False, 3)
    laptop(s, 980, 330, 820, 520, True, 3)
    for i, color in enumerate(["#EBC500", "#D6B75D", "#72A28B", "#6F98AE", "#CE96A4", "#292C30"]):
        s.circle(775 + i * 70, 925, 25, color)
    s.save(OUT_DESKTOP / "desktop_05_theme_modes.svg")


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
