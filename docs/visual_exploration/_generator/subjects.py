"""Shared subject geometry. Every function draws into a 512x512 design space and
returns an SVG fragment.  Per-style proportion tweaks are applied through
`PROPS` so each direction keeps its own consistent proportions."""
import math
import random
from svgcore import ell, rect, poly, smooth, blob, wobbly_ell

# shoulder width, head size, belly size, stroke of exaggeration
PROPS = {
    "gothic":    dict(sh=1.14, hd=0.90, bl=1.08, tilt=0.0),
    "storybook": dict(sh=1.00, hd=1.04, bl=1.04, tilt=0.0),
    "bold":      dict(sh=1.04, hd=1.12, bl=1.00, tilt=0.0),
    "ink":       dict(sh=1.00, hd=0.98, bl=1.00, tilt=0.0),
    "prod":      dict(sh=0.96, hd=1.16, bl=0.98, tilt=0.0),
    "ballpoint": dict(sh=1.02, hd=0.98, bl=1.02, tilt=0.0),
    "sketchbook": dict(sh=1.0, hd=1.08, bl=1.04, tilt=0.0),
}


def mirror(pts, cx=256):
    return [(2 * cx - x, y) for x, y in pts]


def ground_shadow(P, cx, cy, rx, ry):
    k = P.k
    if k == "gothic":
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#000" opacity="0.45" style="filter:blur(6px)"/>'
    if k == "storybook":
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#4a2e14" opacity="0.28" style="filter:blur(9px)"/>'
    if k == "bold":
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#1c1a2e" opacity="0.28"/>'
    if k == "sketchbook":
        return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#6a5a4a" opacity="0.22" style="filter:blur(4px)"/>'
                f'<ellipse cx="{cx}" cy="{cy}" rx="{rx*0.92}" ry="{ry*0.9}" fill="url(#{P.hatch_id})" opacity="0.45"/>')
    if k in ("ink", "ballpoint"):
        hid = P.hatch_id
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#{hid})" opacity="0.55"/>'
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#2e2a35" opacity="0.22"/>'


# ===================================================================== blacksmith
def blacksmith(P, shadow=True, detail=True):
    pr = PROPS[P.k]
    sh, hd, bl = pr["sh"], pr["hd"], pr["bl"]
    o = []
    if shadow:
        o.append(ground_shadow(P, 268, 292, 150 * sh, 128))
    # boots
    o.append(P.shape(ell(222, 374, 25, 31), "boot", s=8))
    o.append(P.shape(ell(292, 376, 25, 31), "boot", s=8))
    if detail:
        o.append(P.detail("M204,390 Q222,402 240,390", "boot", 1))
        o.append(P.detail("M274,392 Q292,404 310,392", "boot", 1))
    # hammer (held in his right hand = viewer's left)
    ax = 256 - 112 * sh
    o.append(P.shape(rect(ax - 8, 330, 16, 108, 6), "wood", s=5))
    if detail:
        o.append(P.detail(f"M{ax-6},360 L{ax+6},352 M{ax-6},378 L{ax+6},370 M{ax-6},396 L{ax+6},388", "wood", 0.8))
    o.append(P.shape(rect(ax - 44, 424, 88, 40, 7), "metal", s=8))
    o.append(P.shape(rect(ax - 50, 428, 14, 32, 4), "metal", s=4))
    o.append(P.shape(rect(ax + 36, 428, 14, 32, 4), "metal", s=4))
    if detail:
        o.append(P.detail(f"M{ax-30},436 L{ax-30},452 M{ax+30},436 L{ax+30},452", "metal", 0.8))
    # tongs hanging at the left hip (viewer right)
    tx = 256 + 92 * sh
    o.append(P.shape(poly([(tx - 4, 280), (tx + 4, 280), (tx + 14, 372), (tx + 6, 374)]), "metal", s=3, hl=False))
    o.append(P.shape(poly([(tx - 4, 280), (tx + 4, 280), (tx - 2, 374), (tx - 10, 372)]), "metal", s=3, hl=False))
    # upper arms (sleeves)
    for side in (-1, 1):
        cx = 256 + side * 104 * sh
        o.append(P.shape(ell(cx, 256, 31 * sh, 50), "shirt", s=10))
    # belly
    o.append(P.shape(ell(256, 272, 92 * bl, 82 * bl), "shirt", s=16))
    # apron
    ap = [(256 - 84 * bl, 256), (256 - 74 * bl, 318), (256, 354 * bl - (bl - 1) * 120),
          (256 + 74 * bl, 318), (256 + 84 * bl, 256), (256, 246)]
    o.append(P.shape(smooth(ap), "apron", s=14))
    if detail:
        o.append(P.shape(rect(222, 296, 40, 30, 6), "apron", s=5, hl=False))  # pocket
        o.append(P.detail("M228,300 L256,300", "apron", 0.7))
        o.append(P.detail("M200,284 Q206,316 232,338 M312,284 Q306,316 280,338", "apron", 0.8, 0.7))
        # scorch marks on apron
        o.append(P.spot(ell(292, 312, 10, 7), P.c("apron", 2), 0.6))
        o.append(P.spot(ell(304, 300, 5, 4), P.c("apron", 2), 0.6))
    # belt + buckle + pouch
    o.append(P.shape(smooth([(256 - 92 * bl, 256), (256, 268), (256 + 92 * bl, 256), (256 + 90 * bl, 272), (256, 284), (256 - 90 * bl, 272)]), "leather", s=4))
    o.append(P.shape(rect(244, 264, 24, 22, 4), "gold", s=4))
    o.append(P.shape(rect(256 - 84 * bl, 266, 32, 34, 8), "leather", s=6))
    # shoulders
    o.append(P.shape(ell(256, 202, 110 * sh, 64), "shirt", s=14))
    if detail:
        o.append(P.detail(f"M{256-80*sh},186 Q{256-60*sh},214 {256-70*sh},236", "shirt", 0.8, 0.8))
        o.append(P.detail(f"M{256+80*sh},186 Q{256+60*sh},214 {256+70*sh},236", "shirt", 0.8, 0.8))
    # apron straps over the shoulders (crossing on the back)
    o.append(P.shape(poly([(212, 260), (226, 260), (236, 150), (222, 146)]), "strap", s=3, hl=False))
    o.append(P.shape(poly([(286, 260), (300, 260), (290, 146), (276, 150)]), "strap", s=3, hl=False))
    o.append(P.shape(poly([(222, 146), (236, 150), (290, 146), (276, 150), (256, 140)]), "strap", s=3, hl=False))
    # old adventuring pauldron (left shoulder = viewer right)
    px = 256 + 92 * sh
    o.append(P.shape(ell(px, 196, 38, 32), "metal", s=9))
    o.append(P.shape(ell(px + 4, 214, 30, 16), "metal", s=5))
    if detail:
        for a in (-1.2, -0.6, 0.0, 0.6, 1.2):
            o.append(P.spot(ell(px + 30 * math.sin(a), 196 + 24 * math.cos(a), 2.6, 2.6), P.c("gold", 1)))
        o.append(P.detail(f"M{px-16},180 L{px+14},172 M{px-10},190 L{px+6},186", "metal", 0.6, 0.8))  # scratches
    # forearms + fists
    for side in (-1, 1):
        cx = 256 + side * 112 * sh
        o.append(P.shape(ell(cx, 314, 25, 37), "skin", s=8))
        if detail:
            o.append(P.detail(f"M{cx-8},300 l4,6 M{cx+4},296 l4,6 M{cx-4},318 l4,6 M{cx+8},314 l3,6", "skin", 0.6, 0.7))
        o.append(P.shape(rect(cx - 25, 286, 50, 18, 6), "leather", s=4))  # bracer
        o.append(P.shape(ell(cx, 346, 23, 21), "skin", s=7))
        if detail:
            o.append(P.detail(f"M{cx-12},354 Q{cx},360 {cx+12},354", "skin", 0.7))
    # ears, fringe of grey hair, bald head
    o.append(P.shape(ell(256 - 44 * hd, 194, 9, 13), "skin", s=3, hl=False))
    o.append(P.shape(ell(256 + 44 * hd, 194, 9, 13), "skin", s=3, hl=False))
    o.append(P.shape(ell(256, 186, 46 * hd, 45 * hd), "hair", s=6))
    if detail:
        o.append(P.detail(f"M{256-30*hd},160 l-6,-8 M{256-10*hd},150 l-2,-9 M{256+12*hd},150 l2,-9 M{256+30*hd},160 l6,-8", "hair", 0.7))
    o.append(P.shape(ell(256, 196, 42 * hd, 41 * hd), "skin", s=11))
    if detail:
        # scar across the scalp
        o.append(P.detail("M236,170 Q252,186 276,206", "skin", 1.2))
        o.append(P.detail("M243,172 l-6,8 M253,182 l-6,8 M263,192 l-6,8", "skin", 0.7))
    # eyepatch strap
    o.append(P.detail(f"M{256-42*hd},204 Q256,{150} {256+42*hd},188", None, 2.0))
    # brows, moustache, beard
    o.append(P.shape(ell(238, 232, 14, 7), "beard", s=3, hl=False))
    o.append(P.shape(ell(274, 232, 14, 7), "beard", s=3, hl=False))
    bd = [(222, 228), (210, 256), (226, 292), (244, 322), (256, 334), (268, 322), (286, 292), (302, 256), (290, 228), (256, 238)]
    o.append(P.shape(smooth(bd), "beard", s=10))
    if detail:
        o.append(P.detail("M236,252 Q240,280 252,308 M256,250 L256,312 M276,252 Q272,280 260,308 M224,258 Q230,276 238,290 M288,258 Q282,276 274,290", "beard", 0.7, 0.8))
    o.append(P.shape(rect(247, 312, 18, 12, 3), "gold", s=3))  # beard ring
    o.append(P.shape(ell(238, 240, 20, 10), "beard", s=4, hl=False))
    o.append(P.shape(ell(274, 240, 20, 10), "beard", s=4, hl=False))
    o.append(P.shape(ell(256, 238, 8, 7), "skin", s=3, hl=False))  # nose tip
    if P.st.get("noir"):
        # soot smudges and wear: forearms, apron hem, scalp, hammer head
        soot = P.st["soot"]
        t = P.st["noir"] / 0.15
        if t > 1.1:
            # 80:20: extra scratches, cracked apron leather, scorched hammer face
            o.append(P.detail("M196,300 l10,8 M206,322 l14,4 M300,318 l-12,10 M318,292 l-6,12", "apron", 0.6, 0.8))
            o.append(P.detail(f"M{256-112*sh-30},432 l12,10 M{256-112*sh+8},430 l10,14", "metal", 0.6, 0.9))
            o.append(P.detail(f"M{256+92*sh-22},206 l18,-6 M{256+92*sh},214 l14,6", "metal", 0.6, 0.9))
        for (x, y, rx, ry, op) in [(152, 326, 10, 6, .35), (364, 330, 12, 7, .35), (230, 336, 18, 8, .3), (290, 340, 14, 6, .3),
                                   (270, 178, 9, 5, .22), (256 - 112 * sh, 444, 30, 10, .25), (240, 290, 8, 5, .25)]:
            o.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{soot}" opacity="{min(op * t, 0.5):.2f}" style="filter:blur(2px)"/>')
    return "\n".join(o)


# ===================================================================== adventurer
def adventurer(P, shadow=True, detail=True):
    pr = PROPS[P.k]
    sh, hd = pr["sh"], pr["hd"]
    o = []
    if shadow:
        o.append(ground_shadow(P, 266, 262, 130 * sh, 136))
    # cloak flowing behind (upwards = back)
    ck = [(256 - 78 * sh, 210), (256 - 96 * sh, 150), (256 - 84 * sh, 92), (256 - 30, 70), (262, 78),
          (256 + 40, 66), (256 + 90 * sh, 96), (256 + 98 * sh, 156), (256 + 78 * sh, 212), (256, 228)]
    o.append(P.shape(smooth(ck), "cloak", s=12))
    if detail:
        o.append(P.detail(f"M{256-60*sh},120 Q{256-50*sh},160 {256-62*sh},200 M{256+64*sh},116 Q{256+52*sh},160 {256+64*sh},200", "cloak", 0.8, 0.8))
    # boots
    o.append(P.shape(ell(232, 318, 19, 27), "boot", s=6))
    o.append(P.shape(ell(282, 322, 19, 27), "boot", s=6))
    # round shield on the back
    o.append(P.shape(ell(256, 146, 66, 66), "wood", s=12))
    if detail:
        o.append(P.detail("M200,120 L312,120 M194,146 L318,146 M200,172 L312,172", "wood", 0.6, 0.7))
    o.append(P.shape("M256,80 A66,66 0 0 1 322,146 L304,146 A48,48 0 0 0 256,98 Z", "cloak", s=4, hl=False))
    o.append(P.shape("M256,212 A66,66 0 0 1 190,146 L208,146 A48,48 0 0 0 256,194 Z", "cloak", s=4, hl=False))
    o.append(P.detail(ell(256, 146, 62, 62), "metal", 2.2))
    o.append(P.shape(ell(256, 146, 18, 18), "metal", s=6))
    # ponytail lying over shield
    o.append(P.shape(smooth([(248, 186), (244, 150), (252, 112), (262, 104), (268, 116), (266, 150), (264, 186)]), "hair", s=5, fill_override=None))
    # sword (held, point forward/down)
    sx = 256 - 76 * sh
    o.append(P.shape(poly([(sx - 7, 300), (sx + 7, 300), (sx + 5, 404), (sx, 424), (sx - 5, 404)]), "metal", s=5))
    if detail:
        o.append(P.detail(f"M{sx},306 L{sx},398", "metal", 0.6))
    o.append(P.shape(rect(sx - 22, 290, 44, 11, 4), "gold", s=4))
    o.append(P.shape(rect(sx - 5, 266, 10, 26, 3), "leather", s=3))
    o.append(P.shape(ell(sx, 262, 7, 7), "gold", s=3))
    # dagger sheathed at the other hip
    dx = 256 + 66 * sh
    o.append(P.shape(rect(dx - 6, 262, 12, 58, 4), "leather", s=4))
    o.append(P.shape(rect(dx - 13, 256, 26, 8, 3), "metal", s=3))
    # upper arms
    for side in (-1, 1):
        cx = 256 + side * 72 * sh
        o.append(P.shape(ell(cx, 240, 20, 38), "tunic", s=7))
    # jerkin / chest
    o.append(P.shape(ell(256, 244, 60, 44), "leather", s=10))
    if detail:
        o.append(P.detail("M256,214 L256,282 M236,224 L240,276 M276,224 L272,276", "leather", 0.6, 0.7))
    o.append(P.shape(smooth([(198, 258), (256, 270), (314, 258), (312, 270), (256, 282), (200, 270)]), "strap", s=3))
    o.append(P.shape(rect(248, 264, 16, 14, 3), "gold", s=3))
    # shoulders
    o.append(P.shape(ell(256, 214, 80 * sh, 44), "tunic", s=10))
    # shield strap across the chest
    o.append(P.shape(poly([(200 , 190), (212, 184), (318, 244), (306, 250)]), "strap", s=2, hl=False))
    # pauldrons
    for side in (-1, 1):
        cx = 256 + side * 70 * sh
        o.append(P.shape(ell(cx, 210, 27, 25), "metal", s=7))
        o.append(P.shape(ell(cx + side * 2, 224, 22, 12), "metal", s=4))
    # forearms + bracers + fists
    for side in (-1, 1):
        cx = 256 + side * 76 * sh
        o.append(P.shape(ell(cx, 270, 16, 24), "leather", s=5))
        o.append(P.shape(ell(cx, 292, 15, 14), "skin", s=4))
    # head: face front visible, hair on top
    o.append(P.shape(ell(256 - 31 * hd, 210, 6, 9), "skin", s=2, hl=False))
    o.append(P.shape(ell(256 + 31 * hd, 210, 6, 9), "skin", s=2, hl=False))
    o.append(P.shape(ell(256, 214, 30 * hd, 32 * hd), "skin", s=6))
    o.append(P.shape(smooth([(256 - 32 * hd, 210), (256 - 28 * hd, 184), (256, 172), (256 + 28 * hd, 184), (256 + 32 * hd, 210),
                             (256 + 22 * hd, 226), (256, 220), (256 - 22 * hd, 226)]), "hair", s=8))
    if detail:
        o.append(P.detail("M256,176 L256,216 M240,182 Q236,200 238,218 M272,182 Q276,200 274,218", "hair", 0.6, 0.8))
    # headband
    o.append(P.detail(f"M{256-31*hd},212 Q256,{200} {256+31*hd},212", None, 1.4))
    o.append(P.shape(ell(256, 240, 6, 5), "skin", s=2, hl=False))
    return "\n".join(o)


# ===================================================================== sword
def sword(P):
    o = ['<g transform="rotate(45 256 256)">']
    o.append(P.shape(poly([(236, 324), (276, 324), (273, 96), (256, 38), (239, 96)]), "metal", s=8))
    o.append(P.detail("M256,314 L256,100", "metal", 1.0))
    o.append(P.detail("M248,312 L247,104 M264,312 L265,104", "metal", 0.4, 0.6))
    for i, y in enumerate((280, 250, 220, 190)):
        o.append(P.detail(f"M250,{y} l6,-8 l6,8 M253,{y-14} l6,0", "gold", 0.5, 0.8))
    guard = [(170, 326), (186, 310), (226, 318), (256, 312), (286, 318), (326, 310), (342, 326),
             (326, 344), (286, 336), (256, 346), (226, 336), (186, 344)]
    if P.st.get("noir") and P.st["noir"] / 0.15 > 1.1:
        # 80:20: ember-lit runes along the fuller (magical equipment emphasis) + nicks in the edge
        runes = " ".join(f"M250,{y} l6,-8 l6,8 M253,{y-14} l6,0" for y in (280, 250, 220, 190, 160))
        o.append(f'<path d="{runes}" fill="none" stroke="{P.st["glow"]}" stroke-width="5" opacity="0.45" style="filter:blur(3px)"/>')
        o.append(f'<path d="{runes}" fill="none" stroke="{P.st["glow2"]}" stroke-width="1.6"/>')
        o.append(P.detail("M273,150 l-5,3 M239,210 l5,2 M274,240 l-4,4", "metal", 0.6))
    o.append(P.shape(smooth(guard), "gold", s=6))
    o.append(P.shape(ell(166, 326, 13, 13), "gold", s=4))
    o.append(P.shape(ell(346, 326, 13, 13), "gold", s=4))
    o.append(P.shape(ell(256, 330, 14, 14), "gem", s=5))
    o.append(P.spot(ell(252, 325, 4, 3), "#ffffff", 0.7 if P.k not in ("ink", "ballpoint") else 0.3))
    o.append(P.shape(rect(243, 346, 26, 84, 8), "leather", s=6))
    o.append(P.detail("M244,356 L268,368 M244,372 L268,384 M244,388 L268,400 M244,404 L268,416", "leather", 0.7))
    o.append(P.shape(smooth([(236, 432), (256, 424), (276, 432), (282, 452), (256, 472), (230, 452)]), "gold", s=6))
    o.append(P.shape(ell(256, 448, 7, 7), "gem", s=3))
    o.append("</g>")
    return "\n".join(o)


# ===================================================================== armour
def armor(P):
    o = []
    # under-tunic / straps
    o.append(P.shape(smooth([(176, 150), (336, 150), (352, 300), (330, 410), (182, 410), (160, 300)]), "tunic", s=10))
    # pauldrons (three lames each)
    for side in (-1, 1):
        def m(pts):
            return pts if side < 0 else mirror(pts)
        o.append(P.shape(smooth(m([(98, 232), (104, 196), (130, 182), (168, 192), (176, 226), (150, 250), (118, 252)])), "metal", s=6))
        o.append(P.shape(smooth(m([(104, 206), (112, 168), (140, 152), (178, 164), (186, 200), (160, 222), (126, 224)])), "metal", s=7))
        o.append(P.shape(smooth(m([(114, 172), (130, 132), (170, 112), (212, 124), (216, 162), (184, 190), (140, 192)])), "metal", s=9))
        for (x, y) in m([(150, 136), (186, 128), (128, 160)]):
            o.append(P.spot(ell(x, y, 4, 4), P.c("gold", 1)))
    # gorget
    o.append(P.shape(smooth([(198, 112), (256, 92), (314, 112), (308, 146), (256, 158), (204, 146)]), "metal", s=6))
    o.append(P.detail("M206,128 Q256,144 306,128", "metal", 0.7))
    # breastplate
    bp = [(186, 146), (256, 156), (326, 146), (346, 214), (334, 300), (296, 344), (256, 354), (216, 344), (178, 300), (166, 214)]
    o.append(P.shape(smooth(bp), "metal", s=18))
    o.append(P.detail("M256,160 L256,348", "metal", 1.0))
    o.append(P.detail("M196,170 Q210,250 236,330 M316,170 Q302,250 276,330", "metal", 0.5, 0.6))
    # emblem: anvil
    an = [(222, 226), (290, 226), (290, 236), (276, 240), (270, 256), (282, 266), (230, 266), (242, 256), (236, 240), (214, 234)]
    o.append(P.shape(poly(an), "gold", s=4))
    o.append(P.shape(ell(256, 210, 9, 9), "gem", s=3))
    # faulds
    for i, y in enumerate((346, 370, 394)):
        w = 92 + i * 6
        o.append(P.shape(smooth([(256 - w, y), (256, y + 12), (256 + w, y), (256 + w - 4, y + 26), (256, y + 38), (256 - w + 4, y + 26)]), "metal", s=6))
    # tassets
    for side in (-1, 1):
        x = 256 + side * 56
        o.append(P.shape(rect(x - 30, 418, 60, 54, 10), "metal", s=6))
        o.append(P.shape(rect(x - 6, 412, 12, 22, 3), "leather", s=3))
    # side straps + buckles
    for side in (-1, 1):
        x = 256 + side * 88
        o.append(P.shape(rect(x - 7, 184, 14, 120, 4), "leather", s=3))
        o.append(P.shape(rect(x - 10, 230, 20, 16, 3), "gold", s=3))
    # rivets
    for (x, y) in [(196, 168), (316, 168), (178, 294), (334, 294), (256, 176)]:
        o.append(P.spot(ell(x, y, 4.5, 4.5), P.c("gold", 1)))
    if P.st.get("noir") and P.st["noir"] / 0.15 > 1.1:
        # 80:20: scratches, a dent and a faint ember-lit rune on the emblem
        o.append(P.detail("M300,170 l22,18 M206,240 l18,10 M318,300 l-14,12 M236,372 l16,6 M282,398 l-12,8", "metal", 0.5, 0.9))
        o.append(f'<path d="M248,282 l8,-14 l8,14 M252,276 h8" fill="none" stroke="{P.st["glow"]}" stroke-width="2.2" opacity="0.8" style="filter:drop-shadow(0 0 4px {P.st["glow"]})"/>')
    if P.st.get("noir"):
        o.append(P.detail("M200,200 q8,30 4,60 M312,200 q-8,30 -4,60 M232,300 l10,24 M286,296 l-6,20", "metal", 0.8, 0.8))
        for (x, y) in [(214, 330), (300, 186), (330, 260)]:
            o.append(f'<ellipse cx="{x}" cy="{y}" rx="16" ry="9" fill="{P.st["soot"]}" opacity="0.25" style="filter:blur(3px)"/>')
    return "\n".join(o)


# ===================================================================== tree
def tree(P, cx=246, cy=240, r=172, seed=7, shadow=True, role="foliage", detail=True):
    o = []
    k = P.k
    if shadow:
        sd = blob(cx + r * 0.14, cy + r * 0.18, r * 0.98, 11, 0.06, seed)
        if k in ("ink", "ballpoint"):
            o.append(f'<path d="{sd}" fill="url(#{P.hatch_id})" opacity="0.6"/>')
        elif k == "sketchbook":
            o.append(f'<path d="{sd}" fill="#6a5a4a" opacity="0.22" style="filter:blur(4px)"/>')
            o.append(f'<path d="{sd}" fill="url(#{P.hatch_id})" opacity="0.4"/>')
        else:
            col = {"gothic": "#000", "storybook": "#3a2a10", "bold": "#1c1a2e", "prod": "#2e2a35"}[k]
            op = {"gothic": 0.55, "storybook": 0.3, "bold": 0.3, "prod": 0.22}[k]
            bl = {"gothic": 4, "storybook": 8, "bold": 0, "prod": 0}[k]
            o.append(f'<path d="{sd}" fill="{col}" opacity="{op}" style="filter:blur({bl}px)"/>')
    # trunk stub & roots peeking out (seen from above)
    o.append(P.shape(blob(cx + r * 0.05, cy + r * 0.62, r * 0.16, 5, 0.25, seed + 3), "wood", s=4, hl=False))
    o.append(P.shape(blob(cx, cy, r * 0.86, 11, 0.06, seed), role, s=r * 0.09))
    rnd = random.Random(seed)
    cl = []
    n = 9
    for i in range(n):
        a = i / n * math.tau + rnd.uniform(-0.2, 0.2)
        rr = r * rnd.uniform(0.56, 0.64)
        cl.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, r * rnd.uniform(0.36, 0.42), i))
    for i in range(5):
        a = i / 5 * math.tau + 0.5
        rr = r * rnd.uniform(0.22, 0.3)
        cl.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, r * rnd.uniform(0.3, 0.36), 10 + i))
    cl.append((cx - r * 0.08, cy - r * 0.08, r * 0.3, 30))
    # clusters facing the light (top-left) are drawn last so they sit on top
    cl.sort(key=lambda c: (c[0] + c[1]), reverse=True)
    for (x, y, rr, i) in cl:
        o.append(P.shape(blob(x, y, rr, 9, 0.07, seed + i, rot=i), role, s=rr * 0.2, line=(k != "storybook")))
    if detail and k in ("gothic", "ink", "bold", "storybook", "ballpoint", "sketchbook"):
        # leaf scallops
        segs = []
        for i in range(22 if k != "bold" else 10):
            a = rnd.uniform(0, math.tau)
            rr = rnd.uniform(0.1, 0.8) * r
            x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            w = r * (0.05 if k != "bold" else 0.07)
            segs.append(f"M{x-w:.1f},{y:.1f} q{w:.1f},{w*0.9:.1f} {2*w:.1f},0")
        o.append(P.detail(" ".join(segs), role, 0.6 * max(1, r / 190), 0.7))
    if k in ("storybook", "prod", "bold", "sketchbook"):
        # dappled light / blossom accents
        for i in range(9 if k != "prod" else 6):
            a = rnd.uniform(3.4, 5.4)
            rr = rnd.uniform(0.25, 0.8) * r
            x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            col = P.c(role, 0)
            o.append(P.spot(ell(x, y, r * 0.05, r * 0.04), col, 0.85))
    return "\n".join(o)


# construction / guide lines drawn under standalone sprites (ballpoint style)
GUIDES = {
    "blacksmith": "M256,90 L256,470 M120,200 L392,200 M100,272 L412,272 " + ell(256, 192, 58) + " " + ell(256, 270, 122, 104),
    "adventurer": "M256,60 L256,440 M150,214 L362,214 " + ell(256, 146, 76) + " " + ell(256, 240, 100, 80),
    "sword": "M90,422 L422,90 M150,250 L262,362 " + ell(256, 256, 200),
    "armor": "M256,80 L256,480 M90,230 L422,230 M150,350 L362,350 " + ell(256, 250, 120, 140),
    "tree": "M60,240 L440,240 M246,50 L246,430 " + ell(246, 240, 150) + " " + ell(246, 240, 100),
}


def guides(P, name):
    if P.k != "ballpoint" or name not in GUIDES:
        return ""
    return (f'<path d="{GUIDES[name]}" fill="none" stroke="{P.ink}" stroke-width="0.8" opacity="0.28" '
            f'stroke-dasharray="40 6 2 6"/>')
