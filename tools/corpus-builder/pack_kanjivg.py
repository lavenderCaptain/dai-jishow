#!/usr/bin/env python3
"""Quantizes KanjiVG SVG path strings into compact binary uint16 polyline blobs."""

import re
import struct
from typing import List, Tuple

TOKEN_RE = re.compile(r"([MmCcSsLlZz])|(-?\d+(?:\.\d+)?)")

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
    """Packs a list of SVG 'd' strings into [stroke_cnt:u8] + per-stroke [pt_cnt:u8, x:u16, y:u16...]."""
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
