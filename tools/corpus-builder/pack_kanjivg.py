#!/usr/bin/env python3
"""Quantizes KanjiVG SVG path strings into compact binary uint16 polyline blobs
and extracts sub-component radical trees for multi-radical intersection."""

import re
import struct
from typing import Dict, List, Set, Tuple
import xml.etree.ElementTree as ET

TOKEN_RE = re.compile(r"([MmCcSsLlZz])|(-?\d+(?:\.\d+)?)")

# Standard 214 Kangxi Radicals (index 1..214) + common variant forms mapped to canonical Kangxi ID
KANGXI_RADICALS = (
    "一丨丶丿乙亅二亠人儿入八冂冖冫几凵刀力勹匕匚匸十卜卩厂厶又"
    "口囗土士夂夊夕大女子宀寸小尢尸屮山巛工己巾干幺广廴廾弋弓彐彡彳"
    "心戈戸手支攴文斗斤方无日曰月木欠止歹殳毋比毛氏气水火爪父爻爿片牙牛犬"
    "玄玉瓜瓦甘生用田疋疒癶白皮皿目矛矢石示禸禾穴立"
    "竹米糸缶网羊羽老而耒耳聿肉臣自至臼舌舛舟艮色艸虍虫血行衣襾"
    "見角言谷豆豕豸貝赤走足身車辛辰辵邑酉釆里"
    "金長門阜隶隹雨青非面革韋韭音頁風飛食首香"
    "馬骨高髟鬥鬯鬲鬼魚鳥鹵鹿麥麻黃黍黑黹黽鼎鼓鼠鼻齊齒龍龜龠"
)

VARIANT_TO_KANGXI: Dict[str, int] = {
    "亻": 9, "𠆢": 9, "儿": 10, "丷": 12, "刂": 18, "力": 19, "勹": 20, "匕": 21,
    "匚": 22, "十": 24, "卜": 25, "卩": 26, "㔾": 26, "厂": 27, "厶": 28, "又": 29,
    "口": 30, "囗": 31, "土": 32, "士": 33, "夂": 34, "夕": 36, "大": 37, "女": 38,
    "子": 39, "宀": 40, "寸": 41, "小": 42, "⺌": 42, "⺍": 42, "尢": 43, "尸": 44,
    "山": 46, "川": 47, "巛": 47, "工": 48, "己": 49, "巾": 50, "干": 51, "幺": 52,
    "广": 53, "廴": 54, "廾": 55, "弋": 56, "弓": 57, "彐": 58, "⺕": 58, "彡": 59,
    "彳": 60, "忄": 61, "⺗": 61, "戈": 62, "戸": 63, "扌": 64, "攵": 66, "文": 67,
    "斗": 68, "斤": 69, "方": 70, "日": 72, "曰": 73, "月": 74, "⺝": 74, "木": 75,
    "欠": 76, "止": 77, "歹": 78, "殳": 79, "毋": 80, "母": 80, "比": 81, "毛": 82,
    "氏": 83, "气": 84, "氵": 85, "氺": 85, "灬": 86, "火": 86, "爪": 87, "爫": 87,
    "父": 88, "片": 91, "牙": 92, "牜": 93, "牛": 93, "犭": 94, "犬": 94, "王": 96,
    "玉": 96, "瓜": 97, "瓦": 98, "甘": 99, "生": 100, "用": 101, "田": 102, "疋": 103,
    "⺪": 103, "疒": 104, "癶": 105, "白": 106, "皮": 107, "皿": 108, "目": 109,
    "罒": 122, "矛": 110, "矢": 111, "石": 112, "礻": 113, "示": 113, "禾": 115,
    "穴": 116, "立": 117, "⺮": 118, "竹": 118, "米": 119, "糹": 120, "糸": 120,
    "缶": 121, "网": 122, "⺶": 123, "羊": 123, "羽": 124, "老": 125, "耂": 125,
    "而": 126, "耒": 127, "耳": 128, "聿": 129, "⺼": 130, "肉": 130, "臣": 131,
    "自": 132, "至": 133, "臼": 134, "舌": 135, "舟": 137, "艮": 138, "色": 139,
    "艹": 140, "艸": 140, "虍": 141, "虫": 142, "血": 143, "行": 144, "衤": 145,
    "衣": 145, "覀": 146, "襾": 146, "見": 147, "角": 148, "言": 149, "訁": 149,
    "谷": 150, "豆": 151, "豕": 152, "豸": 153, "貝": 154, "赤": 155, "走": 156,
    "足": 157, "⻊": 157, "身": 158, "車": 159, "辛": 160, "辰": 161, "辶": 162,
    "⻌": 162, "辵": 162, "阝": 170, "邑": 163, "酉": 164, "釆": 165, "里": 166,
    "金": 167, "釒": 167, "長": 168, "門": 169, "阜": 170, "隶": 171, "隹": 172,
    "雨": 173, "⻗": 173, "青": 174, "非": 175, "面": 176, "革": 177, "韋": 178,
    "音": 180, "頁": 181, "風": 182, "飛": 183, "食": 184, "飠": 184, "首": 185,
    "香": 186, "馬": 187, "骨": 188, "高": 189, "髟": 190, "鬼": 194, "魚": 195,
    "鳥": 196, "鹵": 197, "鹿": 198, "麥": 199, "麻": 200, "黃": 201, "黒": 203,
    "黑": 203, "鼻": 209, "齊": 210, "齒": 211, "龍": 212, "龜": 213,
}

for idx, ch in enumerate(KANGXI_RADICALS, start=1):
    VARIANT_TO_KANGXI.setdefault(ch, idx)

def extract_component_radicals(kanji_elem: ET.Element) -> List[int]:
    """Walks KanjiVG <g kvg:element='...'> hierarchy to find all Kangxi radical IDs."""
    found: Set[int] = set()
    kvg_el_attr = "{http://kanjivg.tagaini.net}element"
    kvg_orig_attr = "{http://kanjivg.tagaini.net}original"
    for g in kanji_elem.iter():
        if g.tag.endswith("g"):
            for attr_name in (kvg_el_attr, kvg_orig_attr):
                val = g.attrib.get(attr_name)
                if val and val in VARIANT_TO_KANGXI:
                    found.add(VARIANT_TO_KANGXI[val])
    return sorted(found)

def _eval_cubic(p0: Tuple[float, float], p1: Tuple[float, float],
                p2: Tuple[float, float], p3: Tuple[float, float], steps: int = 6) -> List[Tuple[float, float]]:
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        mt = 1.0 - t
        x = (mt**3)*p0[0] + 3*(mt**2)*t*p1[0] + 3*mt*(t**2)*p2[0] + (t**3)*p3[0]
        y = (mt**3)*p0[1] + 3*(mt**2)*t*p1[1] + 3*mt*(t**2)*p2[1] + (t**3)*p3[1]
        pts.append((x, y))
    return pts

def svg_path_to_polyline(d: str) -> List[Tuple[float, float]]:
    tokens = [m.group(0) for m in TOKEN_RE.finditer(d)]
    idx = 0
    cmd = ""
    cur = (0.0, 0.0)
    last_ctrl = (0.0, 0.0)
    pts: List[Tuple[float, float]] = []

    def next_float() -> float:
        nonlocal idx
        val = float(tokens[idx])
        idx += 1
        return val

    while idx < len(tokens):
        if tokens[idx].isalpha():
            cmd = tokens[idx]
            idx += 1
        if cmd == "M":
            cur = (next_float(), next_float())
            pts.append(cur)
            last_ctrl = cur
            cmd = "L"
        elif cmd == "m":
            cur = (cur[0] + next_float(), cur[1] + next_float())
            pts.append(cur)
            last_ctrl = cur
            cmd = "l"
        elif cmd == "L":
            cur = (next_float(), next_float())
            pts.append(cur)
            last_ctrl = cur
        elif cmd == "l":
            cur = (cur[0] + next_float(), cur[1] + next_float())
            pts.append(cur)
            last_ctrl = cur
        elif cmd == "C":
            p1 = (next_float(), next_float())
            p2 = (next_float(), next_float())
            p3 = (next_float(), next_float())
            pts.extend(_eval_cubic(cur, p1, p2, p3))
            cur = p3
            last_ctrl = p2
        elif cmd == "c":
            p1 = (cur[0] + next_float(), cur[1] + next_float())
            p2 = (cur[0] + next_float(), cur[1] + next_float())
            p3 = (cur[0] + next_float(), cur[1] + next_float())
            pts.extend(_eval_cubic(cur, p1, p2, p3))
            cur = p3
            last_ctrl = p2
        elif cmd == "S":
            p1 = (2*cur[0] - last_ctrl[0], 2*cur[1] - last_ctrl[1])
            p2 = (next_float(), next_float())
            p3 = (next_float(), next_float())
            pts.extend(_eval_cubic(cur, p1, p2, p3))
            cur = p3
            last_ctrl = p2
        elif cmd == "s":
            p1 = (2*cur[0] - last_ctrl[0], 2*cur[1] - last_ctrl[1])
            p2 = (cur[0] + next_float(), cur[1] + next_float())
            p3 = (cur[0] + next_float(), cur[1] + next_float())
            pts.extend(_eval_cubic(cur, p1, p2, p3))
            cur = p3
            last_ctrl = p2
        elif cmd in ("Z", "z"):
            pass
        else:
            idx += 1
    return pts

def pack_strokes_blob(svg_paths: List[str], viewbox_size: float = 109.0) -> bytes:
    """Packs SVG 'd' strings into [stroke_cnt:u8] + per-stroke [pt_cnt:u8, x:u16, y:u16...]."""
    strokes = [svg_path_to_polyline(d) for d in svg_paths if d]
    strokes = [s for s in strokes if s][:255]
    out = bytearray()
    out.append(len(strokes))
    scale = 65535.0 / viewbox_size
    for poly in strokes:
        poly = poly[:255]
        out.append(len(poly))
        for x, y in poly:
            qx = max(0, min(65535, int(round(x * scale))))
            qy = max(0, min(65535, int(round(y * scale))))
            out.extend(struct.pack("<HH", qx, qy))
    return bytes(out)
