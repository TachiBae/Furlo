"""Recompute WCAG ratios for the audit's flagged color pairs.

Pairs:
  1. Overdue caption: danger text on surface (cards)      >= 4.5
  2. Overdue caption: danger text on bg                   >= 4.5
  3. Danger button labels: textOnDanger on danger fill    >= 4.5
  4. Status-pill border (danger @ 0.75 over surface/bg)   >= 3.0
  5. Light/Dark theme danger pairs (same as 1-3)          >= 4.5
"""

def srgb_channel(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_color):
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * srgb_channel(r) + 0.7152 * srgb_channel(g) + 0.0722 * srgb_channel(b)


def ratio(fg, bg):
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def blend(fg_hex, alpha, bg_hex):
    f = fg_hex.lstrip("#")
    b = bg_hex.lstrip("#")
    out = ""
    for i in (0, 2, 4):
        fv = int(f[i:i + 2], 16)
        bv = int(b[i:i + 2], 16)
        out += "%02X" % round(alpha * fv + (1 - alpha) * bv)
    return out


palettes = {
    "Default": {
        "bg": "121218", "surface": "1B1B24",
        "danger": "E5646B", "textOnDanger": "181820",
    },
    "Light": {
        "bg": "F5F5F5", "surface": "FFFFFF",
        "danger": "B3261E", "textOnDanger": "FFFFFF",
    },
    "Dark": {
        "bg": "121212", "surface": "1E1E1E",
        "danger": "FF6B6B", "textOnDanger": "121212",
    },
}

print(f"{'theme':8} {'pair':44} {'ratio':>7} {'min':>6} {'pass'}")
all_pass = True
for theme, p in palettes.items():
    checks = [
        (f"danger on surface (overdue caption)", ratio(p["danger"], p["surface"]), 4.5),
        (f"danger on bg (overdue caption)", ratio(p["danger"], p["bg"]), 4.5),
        (f"textOnDanger on danger (button label)", ratio(p["textOnDanger"], p["danger"]), 4.5),
        (f"pill border danger@0.75 over surface vs surface",
         ratio(blend(p["danger"], 0.75, p["surface"]), p["surface"]), 3.0),
        (f"pill border danger@0.75 over bg vs bg",
         ratio(blend(p["danger"], 0.75, p["bg"]), p["bg"]), 3.0),
    ]
    for name, r, minimum in checks:
        ok = r >= minimum
        all_pass = all_pass and ok
        print(f"{theme:8} {name:44} {r:7.2f} {minimum:6.1f} {'PASS' if ok else 'FAIL'}")

print()
print("ALL PASS" if all_pass else "SOME FAILED")
