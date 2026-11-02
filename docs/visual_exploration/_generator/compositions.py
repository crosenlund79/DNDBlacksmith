"""Town view, main menu and typography sheet compositions."""
import os
import random
import town as T

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def town(st, page):
    svg, _ = T.town_svg(st)
    return page(svg, 1920, 1080)


def sprite_url(st, name):
    folder = next(k for k, v in __import__("styles").STYLES.items() if v is st)
    return f"file://{ROOT}/{folder}/{name}.png"


BUTTONS = ["Continue", "New Game", "Load Game", "Settings", "Credits", "Quit"]
VERSION = "v0.1 · visual exploration build"

ITEMS = [
    ("Common", "Iron Tongs", "Tool · Durability 40/40"),
    ("Magic", "Tempered Longsword of Haste", "+8% attack speed"),
    ("Rare", "Emberforged Breastplate", "Armour 145 · Fire Res +18%"),
    ("Legendary", "Grimhold, the Last Hammer", "Damage 34–52 · Smithing +3"),
    ("Unique", "Old Brannoc's Leather Apron", "Heat Res +40% · Charisma +2"),
    ("Set", "Wyvernscale Pauldron", "Ranger's Regalia (2/5)"),
]


def embers(n, x0, x1, y0, y1, col, seed=1):
    rnd = random.Random(seed)
    s = []
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        r = rnd.uniform(1.2, 3.6)
        s.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.1f}" fill="{col}" opacity="{rnd.uniform(0.3,1):.2f}"/>')
    return "".join(s)


# ======================================================================= MENUS
def menu(st):
    k = st["key"]
    if st.get("noir"):
        return menu_inkgothic(st)
    return {"gothic": menu_gothic, "storybook": menu_storybook, "bold": menu_bold,
            "ballpoint": menu_ballpoint, "sketchbook": menu_sketchbook,
            "ink": menu_ink, "prod": menu_prod}[k](st)


def bg_town(st, css):
    svg, _ = T.town_svg(st)
    return f'<div style="position:absolute;inset:0;{css}">{svg}</div>'


def menu_gothic(st):
    f = st["fonts"]
    btns = "".join(
        f'<div class="b{" hot" if i == 1 else ""}{" dis" if b == "Continue" else ""}"><span class="d">◆</span>{b}</div>'
        for i, b in enumerate(BUTTONS))
    body = f"""
{bg_town(st, "filter:blur(3px) brightness(0.55) saturate(0.7);transform:scale(1.08)")}
<div style="position:absolute;inset:0;background:radial-gradient(ellipse 50% 60% at 72% 80%, rgba(255,120,30,.45), rgba(0,0,0,0) 70%),
 linear-gradient(90deg, rgba(5,6,9,.96) 0%, rgba(5,6,9,.85) 34%, rgba(5,6,9,.1) 60%, rgba(5,6,9,.5) 100%)"></div>
<svg width="1920" height="1080" style="position:absolute;inset:0">{embers(120, 1050, 1900, 300, 1080, st["glow2"], 3)}{embers(60, 0, 1920, 0, 1080, st["glow"], 4)}</svg>
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:1180px;top:300px;width:720px;filter:drop-shadow(0 0 40px rgba(255,120,30,.5))">
<div style="position:absolute;inset:0;box-shadow:inset 0 0 260px 80px #000"></div>
<div class="t">Embers<br><span>of the</span> Forgotten</div>
<div class="sub">— a blacksmith's tale —</div>
<div class="menu">{btns}</div>
<div class="v">{VERSION}</div>
"""
    css = f"""
.t{{position:absolute;left:120px;top:90px;font-family:'{f['title']}';font-weight:800;font-size:150px;line-height:.86;color:#efe2c8;
 text-shadow:0 0 18px rgba(255,138,42,.7),0 0 60px rgba(255,100,20,.45),4px 6px 0 #000;letter-spacing:1px}}
.t span{{font-size:70px;font-weight:500;color:#c9a35a;text-shadow:0 0 12px rgba(255,138,42,.5),3px 4px 0 #000}}
.sub{{position:absolute;left:128px;top:452px;font-family:'{f['heading']}';font-style:italic;font-size:34px;color:#9a8f80;letter-spacing:3px}}
.menu{{position:absolute;left:120px;top:540px;width:520px}}
.b{{font-family:'{f['heading']}';font-weight:600;font-size:40px;color:#d8d0c0;height:66px;line-height:62px;padding-left:60px;margin-bottom:12px;
 background:linear-gradient(90deg,rgba(28,24,22,.95),rgba(16,14,14,.6) 70%,rgba(0,0,0,0));border-left:4px solid #3a3330;
 border-top:1px solid #2a2522;border-bottom:1px solid #000;position:relative;letter-spacing:1px}}
.b .d{{position:absolute;left:22px;font-size:20px;color:#5a504a}}
.b.hot{{color:#fff1d6;border-left-color:{st['glow']};background:linear-gradient(90deg,rgba(120,40,10,.85),rgba(60,20,8,.5) 70%,rgba(0,0,0,0));
 text-shadow:0 0 14px rgba(255,138,42,.9)}}
.b.hot .d{{color:{st['glow2']};text-shadow:0 0 10px {st['glow']}}}
.b.dis{{color:#5e5750}}
.v{{position:absolute;right:40px;bottom:30px;font-family:'{f['ui']}';font-size:20px;color:#6e665e;letter-spacing:1px}}
"""
    return body, 1920, 1080, css


def menu_storybook(st):
    f = st["fonts"]
    btns = "".join(f'<div class="b{" hot" if i == 1 else ""}">{b}</div>' for i, b in enumerate(BUTTONS))
    body = f"""
{bg_town(st, "filter:blur(2.5px) brightness(1.02) saturate(1.05);transform:scale(1.05)")}
<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 45%, rgba(255,220,150,.25), rgba(60,30,10,.55) 100%)"></div>
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:150px;top:470px;width:560px;filter:drop-shadow(10px 18px 14px rgba(60,30,10,.4))">
<img src="{sprite_url(st,'adventurer')}" style="position:absolute;left:1270px;top:470px;width:520px;filter:drop-shadow(10px 18px 14px rgba(60,30,10,.4))">
<div class="panel">
  <div class="inner">
   <div class="t">The Old Anvil</div>
   <div class="orn">❧ &nbsp;a tale of hammer, hearth &amp; home&nbsp; ☙</div>
   <div class="menu">{btns}</div>
  </div>
</div>
<div class="v">{VERSION}</div>
"""
    css = f"""
.panel{{position:absolute;left:600px;top:50px;width:720px;height:960px;border-radius:38px;
 background:linear-gradient(160deg,#a8784a,#7a5232 50%,#5a3a22);box-shadow:0 22px 50px rgba(50,25,8,.55),inset 0 2px 0 rgba(255,230,180,.4);border:4px solid #4a2e18}}
.inner{{position:absolute;inset:22px;border-radius:24px;background:radial-gradient(ellipse at 40% 30%,#fbf1d8,#efdcb0 60%,#dcc08a);
 box-shadow:inset 0 0 40px rgba(140,90,40,.45);border:2px solid #b8935e}}
.t{{margin-top:40px;text-align:center;font-family:'{f['title']}';font-size:96px;line-height:1.05;color:#7a3e1c;
 text-shadow:0 2px 0 #fff4d8,0 5px 10px rgba(120,60,20,.35)}}
.orn{{text-align:center;font-family:'{f['heading']}';font-style:italic;font-size:30px;color:#8a6440;margin-top:6px}}
.menu{{margin:30px auto 0;width:440px}}
.b{{font-family:'{f['heading']}';font-weight:700;font-size:34px;color:#5a3a24;text-align:center;height:64px;line-height:62px;margin-bottom:12px;
 border-radius:36px;background:linear-gradient(180deg,#f7e8c4,#e2c690);border:3px solid #a8784a;box-shadow:0 4px 0 #8a5e38,0 8px 12px rgba(90,50,20,.25)}}
.b.hot{{background:linear-gradient(180deg,#ffd890,#f0a850);color:#5a2a10;border-color:#a0582a;box-shadow:0 4px 0 #8a4a20,0 0 24px rgba(255,180,80,.7)}}
.v{{position:absolute;right:40px;bottom:28px;font-family:'{f['ui']}';font-weight:600;font-size:20px;color:#fbf1d8;text-shadow:0 1px 3px #3a2410}}
"""
    return body, 1920, 1080, css


ICONS = {
    "Continue": '<path d="M8 5 L19 12 L8 19 Z"/>',
    "New Game": '<path d="M12 4 v16 M4 12 h16" stroke-width="4" stroke="currentColor"/>',
    "Load Game": '<path d="M4 7 h6 l2 2 h8 v10 h-16 Z"/>',
    "Settings": '<circle cx="12" cy="12" r="7" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="12" cy="12" r="2.5"/>',
    "Credits": '<path d="M12 3 l2.6 5.6 6 .7 -4.5 4.1 1.2 6 -5.3-3 -5.3 3 1.2-6 -4.5-4.1 6-.7 Z"/>',
    "Quit": '<path d="M6 6 L18 18 M18 6 L6 18" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>',
}


def menu_bold(st):
    f = st["fonts"]
    btns = "".join(
        f'<div class="b{" hot" if i == 1 else ""}"><svg viewBox="0 0 24 24" width="40" height="40" fill="currentColor">{ICONS[b]}</svg>{b}</div>'
        for i, b in enumerate(BUTTONS))
    body = f"""
{bg_town(st, "transform:scale(1.25) translate(80px,40px)")}
<div style="position:absolute;left:-200px;top:0;width:1060px;height:1080px;background:#1c1a2e;opacity:.88;transform:skewX(-10deg)"></div>
<div style="position:absolute;left:780px;top:0;width:24px;height:1080px;background:#ffb92e;transform:skewX(-10deg)"></div>
<img src="{sprite_url(st,'adventurer')}" style="position:absolute;left:1300px;top:120px;width:560px;filter:drop-shadow(0 12px 0 rgba(28,26,46,.5))">
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:920px;top:380px;width:720px;filter:drop-shadow(0 14px 0 rgba(28,26,46,.5))">
<div class="t">Forged<br>Fortunes</div>
<div class="menu">{btns}</div>
<div class="v">{VERSION}</div>
"""
    css = f"""
.t{{position:absolute;left:90px;top:60px;font-family:'{f['title']}';font-weight:900;font-size:124px;line-height:1.0;color:#ffe066;
 -webkit-text-stroke:10px #1c1a2e;paint-order:stroke fill;text-shadow:0 10px 0 #1c1a2e, 0 10px 0 #c0700c}}
.menu{{position:absolute;left:96px;top:410px;width:520px}}
.b{{display:flex;align-items:center;gap:20px;font-family:'{f['ui']}';font-weight:700;font-size:38px;color:#1c1a2e;height:76px;padding-left:26px;margin-bottom:16px;
 background:#fff4d0;border:5px solid #1c1a2e;border-radius:20px;box-shadow:0 7px 0 #1c1a2e}}
.b svg{{color:#c0602a}}
.b.hot{{background:#ffb92e;transform:translateX(18px)}} .b.hot svg{{color:#1c1a2e}}
.v{{position:absolute;left:96px;bottom:30px;font-family:'{f['ui']}';font-weight:600;font-size:22px;color:#b4c2d8}}
"""
    return body, 1920, 1080, css


def menu_ink(st):
    f = st["fonts"]
    rub = st["rubric"]
    rows = "".join(
        f'<div class="b{" hot" if i == 1 else ""}"><span class="n">{["I","II","III","IV","V","VI"][i]}.</span> {b}<span class="lead"></span><span class="pg">{[3,7,12,19,27,33][i]}</span></div>'
        for i, b in enumerate(BUTTONS))
    svg, _ = T.town_svg(st)
    body = f"""
<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 50%,#4a3020,#1e120a 80%)"></div>
<div class="book">
 <div class="page l">
  <div class="hdr">Being a True Account of the Forge at Brindlewick</div>
  <div class="t"><span class="ini">T</span>he Smith's<br>Chronicle</div>
  <div class="rule">— ❦ —</div>
  <div class="menu">{rows}</div>
  <div class="foot">{VERSION}</div>
 </div>
 <div class="page r"><div class="map">{svg}</div><div class="cap">Plate I. — The village of Brindlewick, as surveyed in the year of the Long Frost.</div></div>
</div>
"""
    css = f"""
.book{{position:absolute;left:70px;top:50px;width:1780px;height:980px}}
.page{{position:absolute;top:0;width:880px;height:980px;background:radial-gradient(ellipse at 50% 40%,#f2e4c0,#e2cc9a 70%,#c8a870);
 box-shadow:0 20px 50px rgba(0,0,0,.6),inset 0 0 80px rgba(120,80,30,.35)}}
.page.l{{left:0;border-radius:12px 0 0 12px;box-shadow:0 20px 50px rgba(0,0,0,.6),inset -60px 0 60px -30px rgba(90,60,20,.45),inset 0 0 80px rgba(120,80,30,.3)}}
.page.r{{left:900px;border-radius:0 12px 12px 0;box-shadow:0 20px 50px rgba(0,0,0,.6),inset 60px 0 60px -30px rgba(90,60,20,.45),inset 0 0 80px rgba(120,80,30,.3)}}
.hdr{{text-align:center;margin-top:50px;font-family:'{f['heading']}';font-style:italic;font-size:24px;color:#5a4028;letter-spacing:1px}}
.t{{margin:40px 0 0 110px;font-family:'{f['title']}';font-size:104px;line-height:1.0;color:{st['ink']}}}
.ini{{float:left;font-size:230px;line-height:.82;color:{rub};margin:6px 18px 0 -10px;padding:6px 14px;border:3px double {st['ink']};
 background:repeating-linear-gradient(45deg,rgba(43,29,18,.1) 0 2px,transparent 2px 6px);text-shadow:2px 2px 0 #e9d8b0}}
.rule{{clear:both;text-align:center;font-family:'{f['heading']}';font-size:36px;color:{rub};margin-top:26px}}
.menu{{margin:20px 110px 0 120px}}
.b{{display:flex;align-items:baseline;font-family:'{f['heading']}';font-size:42px;color:{st['ink']};height:68px}}
.b .n{{font-family:'{f['title']}';color:{rub};width:76px;font-size:34px}}
.b .lead{{flex:1;border-bottom:2px dotted rgba(43,29,18,.5);margin:0 14px;transform:translateY(-10px)}}
.b .pg{{font-family:'{f['ui']}';font-style:italic;font-size:30px}}
.b.hot{{color:{rub};font-style:italic}} .b.hot .lead{{border-color:{rub}}}
.foot{{position:absolute;bottom:40px;width:100%;text-align:center;font-family:'{f['ui']}';font-style:italic;font-size:20px;color:#6a5038}}
.map{{position:absolute;left:50px;top:60px;width:780px;height:439px;overflow:hidden;border:3px solid {st['ink']};outline:1px solid {st['ink']};outline-offset:6px}}
.map svg{{width:1920px;height:1080px;transform:scale(.40625);transform-origin:0 0}}
.cap{{position:absolute;left:60px;top:530px;width:760px;text-align:center;font-family:'{f['heading']}';font-style:italic;font-size:26px;color:#4a3420}}
"""
    # add an engraved vignette of the smith beneath the caption
    body = body.replace('</div>\n</div>\n"""', '')
    body = body.replace('as surveyed in the year of the Long Frost.</div></div>',
                        f'as surveyed in the year of the Long Frost.</div><img src="{sprite_url(st,"blacksmith")}" style="position:absolute;left:150px;top:600px;width:360px;opacity:.95">'
                        f'<img src="{sprite_url(st,"armor")}" style="position:absolute;left:470px;top:640px;width:300px;opacity:.95"></div>')
    return body, 1920, 1080, css


def menu_prod(st):
    f = st["fonts"]
    btns = "".join(f'<div class="b{" hot" if i == 1 else ""}">{b}</div>' for i, b in enumerate(BUTTONS))
    logo = """<svg width="140" height="110" viewBox="0 0 140 110">
<path d="M10 30 h84 l-6 12 h-16 l-6 16 l12 14 h-50 l12-14 l-6-16 h-18 Z" fill="#b4bfc9"/><path d="M10 30 h84 l-3 6 h-81Z" fill="#dfe5ea"/>
<rect x="96" y="22" width="34" height="46" rx="6" fill="#f2a33a"/><rect x="96" y="22" width="34" height="12" rx="6" fill="#f1eee8"/>
<path d="M130 32 h6 a6 6 0 0 1 6 6 v12 a6 6 0 0 1 -6 6 h-6" fill="none" stroke="#f2a33a" stroke-width="6"/></svg>"""
    body = f"""
{bg_town(st, "filter:saturate(.9)")}
<div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(46,42,53,.15),rgba(46,42,53,.55))"></div>
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:1240px;top:430px;width:560px">
<div class="panel">
 <div class="logo">{logo}</div>
 <div class="t">Anvil <span>&amp;</span> Ale</div>
 <div class="sub">A cosy blacksmith's life</div>
 <div class="menu">{btns}</div>
</div>
<div class="v">{VERSION}</div>
"""
    css = f"""
.panel{{position:absolute;left:150px;top:90px;width:620px;height:900px;background:#2e2a35;border-radius:28px;box-shadow:0 12px 0 rgba(0,0,0,.25)}}
.logo{{text-align:center;margin-top:44px}}
.t{{text-align:center;font-family:'{f['title']}';font-size:100px;color:#f1eee8;text-shadow:0 6px 0 #1e1b24;margin-top:4px}}
.t span{{color:#f2a33a}}
.sub{{text-align:center;font-family:'{f['ui']}';font-weight:600;font-size:26px;color:#b4ab9c;margin-top:-6px;letter-spacing:2px;text-transform:uppercase}}
.menu{{margin:40px auto 0;width:420px}}
.b{{font-family:'{f['ui']}';font-weight:700;font-size:32px;color:#f1eee8;text-align:center;height:66px;line-height:66px;margin-bottom:14px;border-radius:14px;
 background:#46404f;box-shadow:0 5px 0 #1e1b24}}
.b.hot{{background:#f2a33a;color:#2e2a35}}
.v{{position:absolute;right:40px;bottom:28px;font-family:'{f['ui']}';font-weight:600;font-size:20px;color:#f1eee8;opacity:.85}}
"""
    return body, 1920, 1080, css


# ======================================================================= FONT SHEETS
FONT_THEME = {
    "gothic": dict(bg="radial-gradient(ellipse at 30% 20%,#1a1a20,#0b0c10 70%)", panel="rgba(20,18,18,.92)", border="2px solid #3a332e",
                   text="#d8d0c0", muted="#8a8072", accent="#ff8a2a", head="#efe2c8", title_css="color:#efe2c8;text-shadow:0 0 18px rgba(255,138,42,.7),3px 4px 0 #000;font-weight:800",
                   btn="background:linear-gradient(90deg,#221c1a,#141212);border:2px solid #3a332e;color:#d8d0c0",
                   btn_hover="background:linear-gradient(90deg,#78280a,#3c1408);border:2px solid #ff8a2a;color:#fff1d6;text-shadow:0 0 10px #ff8a2a",
                   btn_press="background:#2a0e06;border:2px solid #a04a18;color:#c9a35a", btn_dis="background:#151313;border:2px solid #262220;color:#4e4842",
                   tip="#0b0a0a", radius="2px"),
    "storybook": dict(bg="linear-gradient(160deg,#a8784a,#6a4428)", panel="radial-gradient(ellipse at 40% 30%,#fbf1d8,#ecd6a6)", border="3px solid #a8784a",
                      text="#4a3020", muted="#8a6440", accent="#c0602a", head="#7a3e1c", title_css="color:#7a3e1c;text-shadow:0 2px 0 #fff4d8,0 5px 10px rgba(120,60,20,.35)",
                      btn="background:linear-gradient(180deg,#f7e8c4,#e2c690);border:3px solid #a8784a;color:#5a3a24;border-radius:30px",
                      btn_hover="background:linear-gradient(180deg,#ffd890,#f0a850);border:3px solid #a0582a;color:#5a2a10;border-radius:30px;box-shadow:0 0 18px rgba(255,180,80,.8)",
                      btn_press="background:#d8b070;border:3px solid #8a5a30;color:#4a2a10;border-radius:30px;box-shadow:inset 0 3px 6px rgba(80,40,10,.4)",
                      btn_dis="background:#e6dcc4;border:3px solid #c8b898;color:#b0a088;border-radius:30px", tip="#3a2618", radius="22px"),
    "bold": dict(bg="#2a6ee0", panel="#fff8e6", border="5px solid #1c1a2e", text="#1c1a2e", muted="#5e6e8e", accent="#e0403a", head="#1c1a2e",
                 title_css="color:#ffe066;-webkit-text-stroke:6px #1c1a2e;paint-order:stroke fill;text-shadow:0 8px 0 #1c1a2e;font-weight:900",
                 btn="background:#fff4d0;border:5px solid #1c1a2e;color:#1c1a2e;border-radius:16px;box-shadow:0 6px 0 #1c1a2e;font-weight:700",
                 btn_hover="background:#ffb92e;border:5px solid #1c1a2e;color:#1c1a2e;border-radius:16px;box-shadow:0 6px 0 #1c1a2e;font-weight:700",
                 btn_press="background:#c0700c;border:5px solid #1c1a2e;color:#fff;border-radius:16px;box-shadow:0 1px 0 #1c1a2e;transform:translateY(5px);font-weight:700",
                 btn_dis="background:#c4c8d4;border:5px solid #6a7894;color:#6a7894;border-radius:16px;box-shadow:0 6px 0 #6a7894;font-weight:700",
                 tip="#1c1a2e", radius="22px"),
    "ink": dict(bg="radial-gradient(ellipse at 50% 40%,#f2e4c0,#e2cc9a 70%,#c8a870)", panel="rgba(239,226,192,.6)", border="2px solid #2b1d12",
                text="#2b1d12", muted="#6a5038", accent="#a8321e", head="#2b1d12", title_css="color:#2b1d12",
                btn="background:transparent;border:2px solid #2b1d12;outline:1px solid #2b1d12;outline-offset:3px;color:#2b1d12",
                btn_hover="background:rgba(168,50,30,.1);border:2px solid #a8321e;outline:1px solid #a8321e;outline-offset:3px;color:#a8321e;font-style:italic",
                btn_press="background:rgba(43,29,18,.18);border:2px solid #2b1d12;outline:1px solid #2b1d12;outline-offset:1px;color:#2b1d12",
                btn_dis="background:transparent;border:2px dashed #a89070;color:#a89070", tip="#2b1d12", radius="0"),
    "prod": dict(bg="#3a3542", panel="#2e2a35", border="none", text="#f1eee8", muted="#b4ab9c", accent="#f2a33a", head="#f1eee8",
                 title_css="color:#f1eee8;text-shadow:0 6px 0 #1e1b24",
                 btn="background:#46404f;color:#f1eee8;border-radius:12px;box-shadow:0 5px 0 #1e1b24;font-weight:700",
                 btn_hover="background:#f2a33a;color:#2e2a35;border-radius:12px;box-shadow:0 5px 0 #1e1b24;font-weight:700",
                 btn_press="background:#c98a2e;color:#2e2a35;border-radius:12px;box-shadow:0 1px 0 #1e1b24;transform:translateY(4px);font-weight:700",
                 btn_dis="background:#3a3542;color:#6e6878;border-radius:12px;box-shadow:0 5px 0 #26222c;font-weight:700",
                 tip="#1e1b24", radius="18px"),
}

FONT_THEME["ballpoint"] = dict(
    bg="#f7f6f0", panel="rgba(252,252,249,.55)", border="2.5px solid #1f3a93;border-radius:255px 15px 225px 15px/15px 225px 15px 255px", text="#1f2a44", muted="#4a5f9e",
    accent="#c62828", head="#1f3a93", title_css="color:#1f3a93;font-weight:700",
    btn="background:#fcfcf9;border:2.5px solid #1f3a93;color:#1f3a93;border-radius:255px 15px 225px 15px/15px 225px 15px 255px",
    btn_hover="background:#fcfcf9;border:3px solid #c62828;color:#c62828;border-radius:255px 15px 225px 15px/15px 225px 15px 255px;box-shadow:4px 4px 0 rgba(198,40,40,.25)",
    btn_press="background:repeating-linear-gradient(-35deg,rgba(31,58,147,.25) 0 1px,transparent 1px 5px),#fcfcf9;border:2.5px solid #1f3a93;color:#1f3a93;border-radius:255px 15px 225px 15px/15px 225px 15px 255px",
    btn_dis="background:transparent;border:2px dashed #9aa8d0;color:#9aa8d0;border-radius:255px 15px 225px 15px/15px 225px 15px 255px",
    tip="#16224a", radius="0")
FONT_THEME["sketchbook"] = dict(
    bg="#f1e6cf", panel="rgba(250,244,230,.6)", border="2.5px solid #3a2e28;border-radius:255px 15px 225px 15px/15px 225px 15px 255px", text="#3a2e28", muted="#7a6a58",
    accent="#b8501c", head="#3a2e28", title_css="color:#3a2e28",
    btn="background:#e8dcc0;border:2.5px solid #3a2e28;color:#3a2e28;border-radius:255px 15px 225px 15px/15px 225px 15px 255px",
    btn_hover="background:#bfe8f0;border:2.5px solid #3a2e28;color:#0a5a74;border-radius:255px 15px 225px 15px/15px 225px 15px 255px;box-shadow:0 0 14px rgba(31,181,214,.55)",
    btn_press="background:#cdbd98;border:2.5px solid #3a2e28;color:#3a2e28;border-radius:255px 15px 225px 15px/15px 225px 15px 255px;box-shadow:inset 0 3px 6px rgba(58,46,40,.35)",
    btn_dis="background:transparent;border:2px dashed #b4a48c;color:#b4a48c;border-radius:255px 15px 225px 15px/15px 225px 15px 255px",
    tip="#3a2e28", radius="18px")

FONT_EXTRA = dict(
    ballpoint=""".nm{font-family:'Patrick Hand';font-weight:400;font-size:32px} .h1,.h2{font-weight:400}
.line{font-family:'Patrick Hand';font-style:normal;color:#eef1fa} .spk{color:#ff8a80;font-weight:400} .opt{color:#ffb4ad}
.title{text-decoration:underline;text-decoration-color:#c62828;text-decoration-thickness:4px;text-underline-offset:14px}
.bt{font-family:'Patrick Hand'} .items{background:transparent;padding:0} .st b{color:#1f3a93}""",
    sketchbook=""".nm{font-family:'Shantell Sans';font-weight:700;font-size:27px} .h1{font-size:64px} .h2{font-size:46px;color:#2d8aa0} .h3{font-family:'Shantell Sans';font-size:26px}
.line{font-family:'Shantell Sans';font-style:italic;font-weight:400;color:#f4ecdc;font-size:24px} .spk{color:#7fd8ea;font-family:'Fondamento';font-weight:400} .opt{color:#f2d266}
.bt{font-family:'Shantell Sans';font-weight:600;font-size:26px} .items{background:transparent;padding:0} .title span{color:#1fb5d6}
.lbl{font-family:'Shantell Sans'}""",
)
FONT_EXTRA = {k: v.replace("{{", "{").replace("}}", "}") for k, v in FONT_EXTRA.items()}


NOIR_FONT_CSS = """
body{background:radial-gradient(ellipse at 18% 100%,rgba(224,120,42,.35),transparent 45%),radial-gradient(ellipse at 50% 40%,#e8d6ac,#d2b886 70%,#a8875a)!important}
.col{border:3px solid #24170e!important;box-shadow:inset 0 0 60px rgba(60,36,16,.35),0 6px 18px rgba(20,12,6,.35);background:rgba(236,222,186,.7)!important}
.title .ini{font-family:'Grenze Gotisch';font-weight:800;color:#8e2a16;font-size:1.25em;line-height:.8;text-shadow:0 0 10px rgba(224,120,42,.45)}
.h2{color:#8e2a16!important}
.dlg{background:linear-gradient(180deg,#2a1c12,#1a120c)!important;border:2px solid #6e4a2a!important;box-shadow:inset 0 0 30px rgba(224,120,42,.15)}
.dlg .line{color:#efe4cc!important} .dlg .spk{color:#ff9a48!important} .dlg .opt{color:#f0d060!important}
.tip{background:linear-gradient(180deg,#2a1c12,#140e08)!important;border:1px solid #6e4a2a!important}
.bt.h{box-shadow:0 0 14px rgba(224,120,42,.45)}
.digits{text-shadow:0 1px 0 rgba(255,255,255,.3)}
"""


def menu_inkgothic(st):
    """Hybrid menu: a smith's ledger on a forge-lit workbench (~15% Gothic Noir in lighting and contrast)."""
    f = st["fonts"]
    rub, ink = st["rubric"], st["ink"]
    folios = ["xii", "xiv", "xxi", "xxx", "xli", "l"]
    rows = "".join(
        f'<div class="b{" hot" if i == 1 else ""}{" dim" if i == 0 else ""}"><span class="n">{["I","II","III","IV","V","VI"][i]}.</span>{b}'
        f'<span class="lead"></span><span class="pg">fol. {folios[i]}</span></div>' for i, b in enumerate(BUTTONS))
    svg, _ = T.town_svg(st)
    t = st["noir"] / 0.15
    title = st["title"].replace("&", "&amp;")
    if title.startswith("The Smith"):
        tblock = '<span class="ini">T</span>he Smith\'s<br>Chronicle'
    else:
        first, rest = title.split(" ", 1)
        tblock = f'<span class="ini">{first[0]}</span>{first[1:]}<br>{rest}'
    header = st.get("ledger_header", "Ledger of the Forge at Brindlewick · Anno XXXI")
    caption = st.get("plate_caption", "Plate I. — Brindlewick at the turning of the day, the forge yet burning.")
    gilt = st.get("gilt")
    orn = ""
    if gilt:
        # restrained gold + dark iron corner ornaments on both pages
        def corner(x, y, sx, sy):
            return (f'<g transform="translate({x},{y}) scale({sx},{sy})"><path d="M0,0 h70 M0,0 v70 M8,8 h40 M8,8 v40" stroke="{ink}" stroke-width="3" fill="none"/>'
                    f'<path d="M14,14 q20,0 26,20 q-20,-4 -26,-20 Z M14,14 q0,20 20,26 q-4,-20 -20,-26 Z" fill="{gilt}" opacity=".85"/>'
                    f'<circle cx="8" cy="8" r="5" fill="{gilt}"/></g>')
        cs = "".join(corner(x, y, sx, sy) for (x, y, sx, sy) in
                     [(92, 64, 1, 1), (1838, 64, -1, 1), (92, 1016, 1, -1), (1838, 1016, -1, -1), (952, 64, -1, 1), (988, 64, 1, 1), (952, 1016, -1, -1), (988, 1016, 1, -1)])
        orn = f'<svg width="1920" height="1080" style="position:absolute;inset:0;pointer-events:none">{cs}</svg>'
    body = f"""
<div style="position:absolute;inset:0;background:radial-gradient(ellipse 55% 70% at 8% 100%,rgba(224,120,42,{0.55 + 0.15 * (t - 1):.2f}),transparent 60%),
 radial-gradient(ellipse 30% 30% at 96% 4%,rgba(255,192,112,.28),transparent 70%),
 repeating-linear-gradient(90deg,#24160c 0 180px,#2a1a0e 180px 360px),#1e120a"></div>
<svg width="1920" height="1080" style="position:absolute;inset:0">{embers(int(70 * t), 0, 520, 600, 1080, st["glow2"], 7)}{embers(int(40 * t), 0, 700, 400, 1080, st["glow"], 8)}</svg>
<div class="book">
 <div class="page l">
  <div class="hdr">{header}</div>
  <div class="t">{tblock}</div>
  <div class="rule">— ⁂ —</div>
  <div class="colh"><span>Entry</span><span>Folio</span></div>
  <div class="menu">{rows}</div>
  <div class="seal">B</div>
  <div class="foot">{VERSION}</div>
 </div>
 <div class="page r">
  <div class="map">{svg}</div>
  <div class="cap">{caption}</div>
  <img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:110px;top:590px;width:340px">
  <img src="{sprite_url(st,'sword')}" style="position:absolute;left:430px;top:600px;width:200px">
  <img src="{sprite_url(st,'armor')}" style="position:absolute;left:600px;top:610px;width:220px">
  <div class="plate" style="left:150px">Fig. 1 — The Smith</div><div class="plate" style="left:520px">Fig. 2 &amp; 3 — Commissions</div>
 </div>
</div>
{orn}
<div style="position:absolute;inset:0;box-shadow:inset 0 0 200px 40px rgba(10,6,3,{0.75 + 0.1 * (t - 1):.2f});pointer-events:none"></div>
"""
    pg = "radial-gradient(ellipse at 50% 40%,#f0e0b8,#dcc290 68%,#b08c5c)"
    css = f"""
.book{{position:absolute;left:70px;top:46px;width:1780px;height:988px}}
.page{{position:absolute;top:0;width:880px;height:988px;background:{pg}}}
.page.l{{left:0;border-radius:10px 0 0 10px;box-shadow:0 24px 60px rgba(0,0,0,.75),inset -70px 0 70px -30px rgba(70,40,14,.6),inset 0 0 110px rgba(70,40,14,.45)}}
.page.r{{left:900px;border-radius:0 10px 10px 0;box-shadow:0 24px 60px rgba(0,0,0,.75),inset 70px 0 70px -30px rgba(70,40,14,.6),inset 0 0 110px rgba(70,40,14,.45)}}
.page.l::after{{content:"";position:absolute;left:30px;bottom:60px;width:170px;height:90px;border-radius:50%;background:rgba(26,18,12,.12);filter:blur(10px)}}
.hdr{{text-align:center;margin-top:48px;font-family:'{f['heading']}';font-style:italic;font-size:24px;color:#4a3420;letter-spacing:1px}}
.t{{margin:34px 0 0 104px;font-family:'{f['title']}';font-size:104px;line-height:1.0;color:{ink}}}
.ini{{float:left;font-family:'{f['initial']}';font-weight:800;font-size:236px;line-height:.8;color:{rub};margin:8px 20px 0 -12px;padding:4px 16px 12px;
 border:3px double {ink};background:radial-gradient(circle at 50% 60%,rgba(224,120,42,.18),transparent 70%),repeating-linear-gradient(45deg,rgba(36,23,14,.14) 0 2px,transparent 2px 6px);
 text-shadow:0 0 14px rgba(224,120,42,.45),2px 2px 0 #e2cea2}}
.rule{{clear:both;text-align:center;font-family:'{f['heading']}';font-size:34px;color:{rub};margin-top:24px}}
.colh{{display:flex;justify-content:space-between;margin:10px 110px 0 120px;font-family:'{f['ui']}';font-style:italic;font-size:20px;color:#5a4028;border-bottom:2px solid {ink};padding-bottom:2px}}
.menu{{margin:8px 110px 0 120px}}
.b{{display:flex;align-items:baseline;font-family:'{f['heading']}';font-size:42px;color:{ink};height:66px;border-bottom:1px solid rgba(36,23,14,.25)}}
.b .n{{font-family:'{f['title']}';color:{rub};width:76px;font-size:32px}}
.b .lead{{flex:1;border-bottom:2px dotted rgba(36,23,14,.45);margin:0 14px;transform:translateY(-10px)}}
.b .pg{{font-family:'{f['ui']}';font-style:italic;font-size:26px}}
.b.hot{{color:{rub};font-style:italic;text-shadow:0 0 12px rgba(224,120,42,.35);background:linear-gradient(90deg,rgba(224,120,42,.16),transparent 80%)}}
.b.hot .lead{{border-color:{rub}}}
.b.dim{{color:rgba(36,23,14,.42)}} .b.dim .n{{color:rgba(142,42,22,.45)}}
.seal{{position:absolute;right:46px;bottom:30px;width:96px;height:96px;border-radius:50%;background:radial-gradient(circle at 40% 35%,#b2401e,#7a1e0c 70%);
 color:#e8b48a;font-family:'{f['initial']}';font-size:58px;font-weight:800;text-align:center;line-height:92px;box-shadow:0 3px 6px rgba(0,0,0,.45);transform:rotate(-12deg)}}
.foot{{position:absolute;bottom:38px;width:100%;text-align:center;font-family:'{f['ui']}';font-style:italic;font-size:20px;color:#5a4028}}
{".rule{color:" + gilt + "!important;text-shadow:0 0 6px rgba(230,112,42,.35)} .colh{border-bottom-color:" + gilt + "!important} .ini{border-color:" + gilt + "!important} .map{border-color:" + ink + ";outline-color:" + gilt + "!important}" if gilt else ""}
.map{{position:absolute;left:50px;top:56px;width:780px;height:439px;overflow:hidden;border:3px solid {ink};outline:1px solid {ink};outline-offset:6px}}
.map svg{{width:1920px;height:1080px;transform:scale(.40625);transform-origin:0 0}}
.cap{{position:absolute;left:60px;top:524px;width:760px;text-align:center;font-family:'{f['heading']}';font-style:italic;font-size:25px;color:#3e2a18}}
.plate{{position:absolute;top:930px;font-family:'{f['heading']}';font-style:italic;font-size:20px;color:#4a3420}}
"""
    return body, 1920, 1080, css


def paper_url(st, which=None):
    folder = next(k for k, v in __import__("styles").STYLES.items() if v is st)
    return f"file://{ROOT}/{folder}/{which or st['paper']}"


def fonts(st):
    k = st["key"]
    f = st["fonts"]
    th = dict(FONT_THEME[k])
    if "paper" in st:
        th["bg"] = f"url('{paper_url(st)}') repeat"
    rar = st["rarity"]
    title = st["title"].replace("&", "&amp;")
    if st.get("noir"):
        title = f'<span class="ini">{title[0]}</span>{title[1:]}'
    tip_rar = st.get("rarity_dark", rar)

    def item_rows(rset, on_dark):
        rows = ""
        for (r, name, sub) in ITEMS:
            outline = ""
            if k == "bold":
                outline = "-webkit-text-stroke:3px #1c1a2e;paint-order:stroke fill;"
            if st.get("noir") and r == "Legendary":
                outline = ("text-shadow:0 0 8px rgba(224,120,42,.75),0 0 2px rgba(255,192,112,.9);" if on_dark
                           else "text-shadow:0 0 6px rgba(224,120,42,.45);")
            rows += (f'<div class="it"><span class="tag" style="color:{rset[r]};border-color:{rset[r]}">{r}</span>'
                     f'<span class="nm" style="color:{rset[r]};{outline}">{name}</span>'
                     f'<span class="sb" style="color:{"#a8a090" if on_dark else th["muted"]}">{sub}</span></div>')
        return rows

    main_rows = item_rows(rar, k in ("gothic", "prod", "bold"))
    second = ""
    if "rarity_dark" in st:
        second = f'<div class="tip"><div class="tiph">On dark tooltips</div>{item_rows(tip_rar, True)}</div>'
    stats = [("Damage", "34 – 52"), ("Armour", "145"), ("Attack speed", "1.20 /s"), ("Fire resistance", "+18%"),
             ("Durability", "212 / 240"), ("Sale price", "1,250 gold")]
    stat_html = "".join(f'<div class="st"><span>{a}</span><b>{b}</b></div>' for a, b in stats)
    body = f"""
<div class="sheet">
 <div class="col a">
  <div class="lbl">Title · {f['title']}</div>
  <div class="title">{title}</div>
  <div class="lbl">Headings · {f['heading']}</div>
  <div class="h1">The Forge at Brindlewick</div>
  <div class="h2">Commissions &amp; Repairs</div>
  <div class="h3">Chapter II — A Stranger at the Door</div>
  <div class="lbl">UI / body text · {f['ui']}</div>
  <div class="body">Heat the billet until it glows the colour of a ripe apricot, then strike. Quenched steel holds an edge; rushed steel holds a grudge. Customers waiting: 3 · Coal: 42 · Iron ingots: 17.</div>
  <div class="lbl">Dialogue</div>
  <div class="dlg"><div class="spk">Old Brannoc</div><div class="line">"Forty years I carried a sword for coin. Now I make them — and I sleep better for it. What'll it be, traveller?"</div>
   <div class="opt">▸ I need my blade sharpened.</div><div class="opt dim">▸ Tell me about the scar.</div></div>
  <div class="lbl">Readability at gameplay sizes (1080p)</div>
  <div class="small" style="font-size:14px">14px · Quest log: Deliver 3 horseshoes to the Tipsy Wyvern stable — reward 40 gold</div>
  <div class="small" style="font-size:16px">16px · Quest log: Deliver 3 horseshoes to the Tipsy Wyvern stable — reward 40 gold</div>
  <div class="small" style="font-size:20px">20px · Quest log: Deliver 3 horseshoes to the Tipsy Wyvern stable</div>
 </div>
 <div class="col b">
  <div class="lbl">Buttons · normal / hover / pressed / disabled</div>
  <div class="btns"><div class="bt n">Forge</div><div class="bt h">Forge</div><div class="bt p">Forge</div><div class="bt d">Forge</div></div>
  <div class="lbl">Item names · rarity colours</div>
  <div class="items">{main_rows}</div>
  {second}
  <div class="lbl">Numbers &amp; statistics · {f['numbers']} (tabular figures)</div>
  <div class="stats">{stat_html}</div>
  <div class="digits">0123456789 · +12% · −4 · ×3 · 1,250g</div>
 </div>
</div>
"""
    tipcss = ""
    if "rarity_dark" in st:
        tipcss = f""".tip{{background:{th['tip']};padding:12px 20px;margin-top:10px;border:1px solid #000}}
.tiph{{font-family:'{f['heading']}';font-style:italic;color:#efe4cc;font-size:20px;margin-bottom:4px}}
.tip .it{{height:34px}} .tip .nm{{font-size:24px}} .tip .tag,.tip .sb{{display:none}}"""
    dark_items = k in ("storybook", "ink", "bold")
    css = f"""
body{{background:{th['bg']}}}
.sheet{{position:absolute;inset:40px;display:flex;gap:40px}}
.col{{background:{th['panel']};border:{th['border']};border-radius:{th['radius']};padding:30px 44px;box-sizing:border-box}}
.col.a{{width:960px}} .col.b{{flex:1}}
.lbl{{font-family:'{f['ui']}';font-weight:600;font-size:16px;letter-spacing:2px;text-transform:uppercase;color:{th['muted']};margin:12px 0 6px;
 border-bottom:1px solid {th['muted']}55;padding-bottom:3px}}
.title{{font-family:'{f['title']}';font-size:{dict(gothic=96,storybook=108,bold=80,ink=84,prod=108,ballpoint=120,sketchbook=96)[k]}px;line-height:1.05;{th['title_css']}}}
.h1{{font-family:'{f['heading']}';font-weight:700;font-size:50px;color:{th['head']};line-height:1.1}}
.h2{{font-family:'{f['heading']}';font-weight:600;font-size:40px;color:{th['accent']};line-height:1.2}}
.h3{{font-family:'{f['heading']}';font-style:italic;font-weight:500;font-size:30px;color:{th['text']}}}
.body{{font-family:'{f['ui']}';font-size:25px;line-height:1.45;color:{th['text']}}}
.dlg{{background:{th['tip'] if k!='ink' else 'rgba(239,226,192,.9)'};border:{th['border'] if k!='prod' else '3px solid #46404f'};border-radius:{th['radius']};padding:14px 22px;margin-top:6px}}
.spk{{font-family:'{f['heading']}';font-weight:700;font-size:28px;color:{th['accent'] if k!='bold' else '#ffb92e'}}}
.line{{font-family:'{f['heading'] if k in ('gothic','storybook','ink') else f['ui']}';font-style:{'italic' if k in ('gothic','storybook','ink') else 'normal'};font-size:27px;line-height:1.4;
 color:{'#f1eee8' if k in ('gothic','prod','bold','storybook') else '#2b1d12'}}}
.opt{{font-family:'{f['ui']}';font-weight:600;font-size:21px;color:{'#ffe066' if k=='bold' else th['accent']};margin-top:6px}} .opt.dim{{opacity:.6}}
.btns{{display:flex;gap:18px}}
.bt{{width:170px;height:62px;line-height:58px;text-align:center;font-family:'{f['heading'] if k in ('gothic','storybook','ink') else f['ui']}';font-size:30px;box-sizing:border-box}}
.bt.n{{{th['btn']}}} .bt.h{{{th['btn_hover']}}} .bt.p{{{th['btn_press']}}} .bt.d{{{th['btn_dis']}}}
.items{{background:{th['tip'] if dark_items and k!='ink' else 'transparent'};padding:{'10px 18px' if dark_items and k!='ink' else '0'};border-radius:{th['radius']}}}
.it{{display:flex;align-items:baseline;gap:14px;height:52px}}
.tag{{font-family:'{f['ui']}';font-weight:700;font-size:13px;letter-spacing:1px;text-transform:uppercase;border:1.5px solid;border-radius:4px;padding:1px 6px;width:86px;text-align:center}}
.nm{{font-family:'{f['heading']}';font-weight:700;font-size:30px;white-space:nowrap}}
.sb{{font-family:'{f['ui']}';font-size:15px;margin-left:auto;white-space:nowrap}}
.stats{{display:grid;grid-template-columns:1fr 1fr;column-gap:40px}}
.st{{display:flex;justify-content:space-between;font-family:'{f['numbers']}';font-size:25px;color:{th['text']};border-bottom:1px dotted {th['muted']}88;padding:4px 0;
 font-variant-numeric:tabular-nums lining-nums}}
.st b{{font-weight:700;color:{th['head'] if k!='gothic' else '#f2d65a'}}}
.digits{{font-family:'{f['numbers']}';font-weight:700;font-size:42px;color:{th['head']};margin-top:10px;font-variant-numeric:tabular-nums lining-nums}}
{tipcss}
.small{{font-family:'{f['ui']}';color:{th['text']};line-height:1.6}}
"""
    if k == "storybook":
        css += ".items .sb{color:#c8b090!important}"
    if st.get("noir"):
        css += NOIR_FONT_CSS
        if st.get("gilt"):
            css += (f".title .ini{{color:{st['rubric']};text-shadow:0 0 14px rgba(230,112,42,.6)}} .h2{{color:{st['rubric']}!important}}"
                    f" .col{{outline:1px solid {st['gilt']};outline-offset:-8px}} .lbl{{border-bottom-color:{st['gilt']}88!important}}"
                    ".dlg{box-shadow:inset 0 0 40px rgba(230,112,42,.22)!important}")
    if k in ("ballpoint", "sketchbook"):
        css += FONT_EXTRA[k] + ".digits{white-space:nowrap;font-size:36px}"
    return body, 1920, 1080, css


# ======================================================================= PAPER (06 / 07)
PAPER_TONES = {
    # key: (base, rule colour, rule opacity, grain rgb, fibre colour)
    "ballpoint": ("#f7f6f0", "#9db3d8", 0.75, (0.42, 0.45, 0.55), "#b9c4d8"),
    "sketchbook": ("#f1e6cf", "#b4a084", 0.6, (0.45, 0.33, 0.2), "#cdb894"),
}


def paper_svg(st, grid):
    """512x512 seamlessly tileable paper (stitched noise, rules on a 32px pitch, wrapped fibres)."""
    k = st["key"]
    base, rule, rop, g, fib = PAPER_TONES[k]
    S = 512
    rnd = random.Random(11 if grid else 13)
    fib_paths = []
    for _ in range(46):
        x, y = rnd.uniform(0, S), rnd.uniform(0, S)
        dx, dy = rnd.uniform(-26, 26), rnd.uniform(-10, 10)
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                fib_paths.append(f"M{x+ox:.1f},{y+oy:.1f} q{dx/2:.1f},{dy+rnd.uniform(-4,4):.1f} {dx:.1f},{dy:.1f}")
    rules = ""
    if grid:
        lines = " ".join(f"M{p+0.5},0 V{S} M0,{p+0.5} H{S}" for p in range(0, S, 32))
        rules = f'<path d="{lines}" stroke="{rule}" stroke-width="1" opacity="{rop}"/>'
    mottle = "0.012" if k == "sketchbook" else "0.008"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
<defs>
<filter id="grain" filterUnits="userSpaceOnUse" x="0" y="0" width="{S}" height="{S}">
 <feTurbulence type="fractalNoise" baseFrequency="0.7" numOctaves="3" seed="4" stitchTiles="stitch"/>
 <feColorMatrix values="0 0 0 0 {g[0]}  0 0 0 0 {g[1]}  0 0 0 0 {g[2]}  0 0 0 -1.4 0.82"/>
</filter>
<filter id="mottle" filterUnits="userSpaceOnUse" x="0" y="0" width="{S}" height="{S}">
 <feTurbulence type="fractalNoise" baseFrequency="{mottle}" numOctaves="3" seed="9" stitchTiles="stitch"/>
 <feColorMatrix values="0 0 0 0 {g[0]}  0 0 0 0 {g[1]}  0 0 0 0 {g[2]}  0 0 0 1.1 -0.5"/>
</filter>
</defs>
<rect width="{S}" height="{S}" fill="{base}"/>
<rect width="{S}" height="{S}" filter="url(#mottle)" opacity="{0.5 if k=='sketchbook' else 0.25}"/>
<rect width="{S}" height="{S}" filter="url(#grain)" opacity="{0.45 if k=='sketchbook' else 0.3}"/>
<path d="{' '.join(fib_paths)}" fill="none" stroke="{fib}" stroke-width="0.7" opacity="0.55"/>
{rules}
</svg>'''


def paper(st, grid):
    return paper_svg(st, grid), 512, 512, ""


# ======================================================================= MENUS (06 / 07)
def hand_buttons(cls_hot=1):
    return "".join(f'<div class="b{" hot" if i == cls_hot else ""}">{b}</div>' for i, b in enumerate(BUTTONS))


def menu_ballpoint(st):
    f = st["fonts"]
    svg, _ = T.town_svg(st, paper=False)
    body = f"""
<div style="position:absolute;inset:0;background:url('{paper_url(st, 'paper_grid.png')}') repeat"></div>
<div class="sheet"><div class="cropped">{svg}</div></div>
<div class="tape t1"></div><div class="tape t2"></div>
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:1180px;top:520px;width:500px">
<img src="{sprite_url(st,'sword')}" style="position:absolute;left:1600px;top:640px;width:250px;transform:rotate(12deg)">
<svg width="1920" height="1080" style="position:absolute;inset:0">
 <path d="M150,330 C400,345 700,318 930,332" stroke="#c62828" stroke-width="5" fill="none" stroke-linecap="round"/>
 <path d="M170,346 C420,356 640,340 880,350" stroke="#c62828" stroke-width="2.5" fill="none" stroke-linecap="round" opacity=".7"/>
 <path d="M120,60 L120,1020 M60,120 L1000,120" stroke="#1f3a93" stroke-width="1" opacity=".35" stroke-dasharray="40 6 2 6"/>
 <ellipse cx="300" cy="512" rx="190" ry="44" fill="none" stroke="#c62828" stroke-width="3" transform="rotate(-2 300 512)"/>
 <path d="M500,500 q60,-40 120,-10" stroke="#c62828" stroke-width="2.4" fill="none"/>
</svg>
<div class="t">The Inkbound Forge</div>
<div class="sub">a sketchbook of hammer &amp; flame</div>
<div class="note" style="left:640px;top:450px">← start here!</div>
<div class="menu">{hand_buttons()}</div>
<div class="v">{VERSION} · sheet 1</div>
"""
    hand = "border-radius:255px 15px 225px 15px/15px 225px 15px 255px"
    css = f"""
.sheet{{position:absolute;left:1000px;top:70px;width:820px;height:461px;transform:rotate(1.5deg);background:#fcfcf9;
 box-shadow:3px 4px 0 rgba(31,58,147,.15);border:2px solid #1f3a93;overflow:hidden}}
.cropped svg{{width:1920px;height:1080px;transform:scale(.4271);transform-origin:0 0}}
.tape{{position:absolute;width:150px;height:40px;background:rgba(220,210,170,.55);border:1px solid rgba(150,140,100,.35)}}
.t1{{left:960px;top:52px;transform:rotate(-14deg)}} .t2{{left:1720px;top:500px;transform:rotate(-10deg)}}
.t{{position:absolute;left:130px;top:150px;font-family:'{f['title']}';font-weight:700;font-size:150px;color:#1f3a93;line-height:1;transform:rotate(-1.5deg)}}
.sub{{position:absolute;left:150px;top:360px;font-family:'{f['heading']}';font-size:34px;color:#1f3a93}}
.menu{{position:absolute;left:150px;top:470px;width:340px}}
.b{{font-family:'{f['ui']}';font-size:44px;color:#1f3a93;height:70px;line-height:66px;padding-left:28px;margin-bottom:16px;
 background:rgba(252,252,249,.9);border:2.5px solid #1f3a93;{hand}}}
.b.hot{{color:#c62828;border-color:#c62828;background:repeating-linear-gradient(-35deg,rgba(198,40,40,.12) 0 1px,transparent 1px 6px),rgba(252,252,249,.9)}}
.note{{position:absolute;font-family:'{f['title']}';font-size:40px;color:#c62828;transform:rotate(-4deg)}}
.v{{position:absolute;right:50px;bottom:30px;font-family:'{f['heading']}';font-size:22px;color:#1f3a93}}
"""
    return body, 1920, 1080, css


def menu_sketchbook(st):
    f = st["fonts"]
    svg, _ = T.town_svg(st, paper=False)
    body = f"""
<div style="position:absolute;inset:0;background:url('{paper_url(st, 'paper_plain.png')}') repeat"></div>
<div class="vign">{svg}</div>
<svg width="1920" height="1080" style="position:absolute;inset:0">
 <defs><filter id="wc"><feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="3" seed="3"/><feDisplacementMap in="SourceGraphic" scale="40"/><feGaussianBlur stdDeviation="3"/></filter></defs>
 <ellipse cx="960" cy="230" rx="560" ry="120" fill="#86b0b8" opacity=".35" filter="url(#wc)"/>
 <ellipse cx="1180" cy="210" rx="200" ry="80" fill="#1fb5d6" opacity=".25" filter="url(#wc)"/>
 <ellipse cx="740" cy="260" rx="220" ry="70" fill="#c8a258" opacity=".3" filter="url(#wc)"/>
 <rect x="700" y="400" width="520" height="560" rx="40" fill="#e8dcc0" opacity=".55" filter="url(#wc)"/>
</svg>
<img src="{sprite_url(st,'blacksmith')}" style="position:absolute;left:180px;top:470px;width:540px;filter:drop-shadow(8px 12px 8px rgba(90,70,50,.25))">
<img src="{sprite_url(st,'adventurer')}" style="position:absolute;left:1240px;top:470px;width:500px;filter:drop-shadow(8px 12px 8px rgba(90,70,50,.25))">
<img src="{sprite_url(st,'tree')}" style="position:absolute;left:-90px;top:-80px;width:420px">
<img src="{sprite_url(st,'tree')}" style="position:absolute;left:1620px;top:-60px;width:400px;transform:rotate(70deg)">
<div class="t">Tales from the <span>Anvil</span></div>
<div class="sub">— stories hammered out in a little village —</div>
<div class="menu">{hand_buttons()}</div>
<div class="v">{VERSION}</div>
"""
    hand = "border-radius:255px 15px 225px 15px/15px 225px 15px 255px"
    css = f"""
.vign{{position:absolute;inset:0;opacity:.5;-webkit-mask-image:radial-gradient(ellipse 60% 60% at 50% 60%,#000 30%,transparent 75%)}}
.t{{position:absolute;left:0;width:1920px;top:150px;text-align:center;font-family:'{f['title']}';font-size:128px;color:#3a2e28;
 text-shadow:0 0 0 #3a2e28, 2px 2px 0 rgba(255,250,235,.7)}}
.t span{{color:#1a8eaa}}
.sub{{position:absolute;left:0;width:1920px;top:310px;text-align:center;font-family:'{f['ui']}';font-style:italic;font-size:30px;color:#6e5a48}}
.menu{{position:absolute;left:760px;top:420px;width:400px}}
.b{{font-family:'{f['heading']}';font-weight:700;font-size:52px;color:#3a2e28;text-align:center;height:72px;line-height:72px;margin-bottom:14px;
 background:rgba(244,236,216,.85);border:2.5px solid #3a2e28;{hand};box-shadow:3px 4px 0 rgba(58,46,40,.18)}}
.b.hot{{background:rgba(160,224,236,.9);color:#0a5a74;box-shadow:0 0 22px rgba(31,181,214,.55),3px 4px 0 rgba(58,46,40,.18)}}
.v{{position:absolute;right:46px;bottom:28px;font-family:'{f['ui']}';font-size:20px;color:#6e5a48}}
"""
    return body, 1920, 1080, css


# ======================================================================= SCENE COMPOSITE (06 / 07)
def scene_composite(st):
    import subjects
    k = st["key"]
    f = st["fonts"]
    Z, OX, OY = 1.8, 330, 330
    acc = st["accent"]

    def extras(P):
        o = []
        if k == "ballpoint":
            o.append(f'<ellipse cx="632" cy="726" rx="62" ry="40" fill="none" stroke="{acc}" stroke-width="2.5" stroke-dasharray="10 5"/>')
        else:
            o.append(f'<ellipse cx="632" cy="726" rx="60" ry="38" fill="{acc}" opacity=".25" style="filter:blur(6px)"/>'
                     f'<ellipse cx="632" cy="726" rx="60" ry="38" fill="none" stroke="{acc}" stroke-width="2.5"/>')
        o.append(T.char(P, subjects.blacksmith, 600, 690, 120, 0.17))
        o.append(T.char(P, subjects.adventurer, 626, 590, 0, 0.15))
        o.append(T.villager(P, 960, 500, 30, "tunic", scale=0.85))
        o.append(T.villager(P, 1120, 520, 160, "cloak", scale=0.85))
        o.append(T.villager(P, 880, 640, -60, "shirt", scale=0.85))
        return "\n".join(o)

    svg, _ = T.town_svg(st, paper=True, interior=True, people=False, with_overlay=False, extra_fn=extras)
    sx = lambda x: (x - OX) * Z
    sy = lambda y: (y - OY) * Z
    ink = st["ink"]
    panel = "#fcfcf9" if k == "ballpoint" else "#f4ecd8"
    hand = "border-radius:255px 15px 225px 15px/15px 225px 15px 255px"
    slots = ["sword", "armor", None, None, None, None, None, None]
    slot_html = ""
    for i, s in enumerate(slots):
        inner = f'<img src="{sprite_url(st, s)}" style="width:84px">' if s else ""
        slot_html += f'<div class="slot{" sel" if i == 0 else ""}">{inner}<span>{i+1}</span></div>'
    body = f"""
<div class="world">{svg}</div>
<div class="prompt" style="left:{sx(632)+70:.0f}px;top:{sy(726)+30:.0f}px"><b>E</b> Work the anvil</div>
<div class="bubble" style="left:{sx(626)+60:.0f}px;top:{sy(590)-150:.0f}px">"Can you mend this pauldron by dusk, old man?"</div>
<div class="quest"><div class="qh">Commission</div><div class="qt">Wyvernscale Pauldron</div>
 <div class="qi">☐ Hammer 3 scale plates <i>(2/3)</i></div><div class="qi">☐ Quench in the trough</div><div class="qi">☑ Fire the forge</div></div>
<div class="gold">⚒ Day 14 · 1,250 g</div>
<div class="bar">{slot_html}</div>
<div class="cap">scene_composite — transparent sprite &amp; building layers over the separate tiled {st['paper'].replace('.png','')} layer (smithy shown with roof removed)</div>
"""
    css = f"""
body{{background:#000}}
.world{{position:absolute;left:0;top:0;width:1920px;height:1080px;overflow:hidden}}
.world svg{{width:1920px;height:1080px;transform:translate({-OX*Z}px,{-OY*Z}px) scale({Z});transform-origin:0 0}}
.prompt{{position:absolute;font-family:'{f['ui']}';font-size:30px;color:{ink};background:{panel};border:2.5px solid {acc};padding:4px 16px;{hand}}}
.prompt b{{display:inline-block;width:36px;height:36px;line-height:36px;text-align:center;border:2.5px solid {acc};color:{acc};margin-right:8px;border-radius:8px}}
.bubble{{position:absolute;width:360px;font-family:'{f['ui']}';font-size:26px;line-height:1.3;color:{ink};background:{panel};border:2.5px solid {ink};padding:12px 18px;{hand}}}
.quest{{position:absolute;left:36px;top:36px;width:420px;background:{panel};border:2.5px solid {ink};padding:14px 22px;{hand};box-shadow:4px 5px 0 rgba(0,0,0,.12)}}
.qh{{font-family:'{f['heading']}';font-size:{24 if k=='ballpoint' else 34}px;font-weight:700;color:{acc if k=='ballpoint' else '#7a6a58'};letter-spacing:1px}}
.qt{{font-family:'{f['title']}';font-size:{44 if k=='ballpoint' else 34}px;font-weight:700;color:{ink};line-height:1.1;margin-bottom:6px}}
.qi{{font-family:'{f['ui']}';font-size:24px;color:{ink};line-height:1.4}}
.gold{{position:absolute;right:36px;top:36px;font-family:'{f['numbers']}';font-weight:700;font-size:32px;color:{ink};background:{panel};border:2.5px solid {ink};padding:6px 22px;{hand}}}
.bar{{position:absolute;left:50%;bottom:48px;transform:translateX(-50%);display:flex;gap:12px;padding:12px;background:{panel};border:2.5px solid {ink};{hand}}}
.slot{{position:relative;width:96px;height:96px;border:2px solid {ink};display:flex;align-items:center;justify-content:center;border-radius:10px;background:rgba(255,255,255,.4)}}
.slot.sel{{border:3px solid {acc};box-shadow:0 0 0 3px {acc}33}}
.slot span{{position:absolute;left:5px;top:1px;font-family:'{f['numbers']}';font-size:18px;color:{ink}}}
.cap{{position:absolute;left:50%;transform:translateX(-50%);top:14px;white-space:nowrap;background:{panel};padding:2px 14px;border-radius:6px;opacity:1 !important;font-family:'{f['ui']}';font-size:18px;color:{ink};opacity:.75}}
"""
    return body, 1920, 1080, css


# ======================================================================= PAPER COMPARISON (06 / 07)
def paper_comparison(st):
    f = st["fonts"]
    ink = st["ink"]
    cols = [("Grid paper", f"url('{paper_url(st, 'paper_grid.png')}') repeat", "paper_grid.png"),
            ("Plain paper", f"url('{paper_url(st, 'paper_plain.png')}') repeat", "paper_plain.png"),
            ("No paper (transparent)", "repeating-conic-gradient(#d4d4d4 0 25%, #f4f4f4 0 50%) 0 0/32px 32px", "alpha only")]
    panels = ""
    for i, (name, bg, file) in enumerate(cols):
        panels += f"""<div class="p" style="left:{20+i*633}px;background:{bg}">
 <div class="h">{name}<span>{file}</span></div>
 <img src="{sprite_url(st,'blacksmith')}" style="left:40px;top:120px;width:330px">
 <img src="{sprite_url(st,'adventurer')}" style="left:330px;top:110px;width:280px">
 <img src="{sprite_url(st,'tree')}" style="left:40px;top:470px;width:330px">
 <img src="{sprite_url(st,'sword')}" style="left:350px;top:440px;width:220px">
 <img src="{sprite_url(st,'armor')}" style="left:370px;top:650px;width:220px">
</div>"""
    body = f'<div class="title">{st["title"]} — sprites over grid paper, plain paper and no paper</div>{panels}'
    css = f"""
body{{background:#3a3a3a}}
.title{{position:absolute;left:24px;top:14px;font-family:'{f['ui']}';font-size:34px;color:#f4f4f4}}
.p{{position:absolute;top:70px;width:613px;height:990px;overflow:hidden;border-radius:6px}}
.p img{{position:absolute}}
.h{{position:absolute;left:0;right:0;top:0;padding:14px 22px;font-family:'{f['heading']}';font-size:36px;font-weight:700;color:{ink};
 background:rgba(255,255,255,.75);border-bottom:2px solid {ink}}}
.h span{{float:right;font-family:'{f['ui']}';font-size:22px;font-weight:400;margin-top:10px;opacity:.8}}
"""
    return body, 1920, 1080, css
