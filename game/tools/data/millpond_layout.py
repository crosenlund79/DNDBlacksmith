"""v1.7 (#65–66), canonical v1.7 §4.1 — the millpond, its stream and the watermill, on the village ground the compact
smithy freed (east and south of its 19 × 18 footprint). Scenery and sound only: no milling, fishing or water supply.

  layout["millpond"]   {center, radius, wobble, dock [x, y, w, h], reeds, lilies, ducks}   an irregular natural pond
  layout["millstream"] {width, points}   the outflow, running south past the mill and off the map
  layout["watermill"]  {pos, wheel, label}   the mill house and its wheel turning in the stream (drawn by the world)
Applied by make_layout.py after the smithy.
"""


def apply(layout):
    layout["millpond"] = {
        "center": [42.6, 42.6], "radius": [4.4, 3.3], "wobble": 0.13, "seed": 9,
        "dock": [37.6, 41.6, 2.2, 1.0],                       # a small wooden dock on the west shore
        "reeds": [[38.6, 39.6], [39.6, 38.9], [44.6, 38.9], [46.4, 39.9], [47.2, 41.6], [47.0, 44.2], [45.6, 46.0],
                  [38.4, 44.9], [39.4, 46.0], [41.6, 46.6]],
        "lilies": [[41.0, 41.8], [44.4, 43.6], [42.8, 40.4]],
        "ducks": [[42.0, 42.0], [43.8, 41.0]],
    }
    layout["millstream"] = {
        "width": 1.25,
        "points": [[43.4, 45.6], [44.0, 48.6], [43.4, 51.6], [44.4, 54.8], [43.8, 58.4], [44.6, 61.6], [44.2, 65.5]],
    }
    layout["watermill"] = {"pos": [47.2, 52.6], "wheel": [45.1, 52.8], "label": "The watermill — its wheel turning in the millstream"}
    # keep the boundary woodland off the stream where it leaves the village
    kc = layout["boundary"].setdefault("keep_clear", [])
    if [41, 58, 6, 8] not in kc:
        kc.append([41, 58, 6, 8])
