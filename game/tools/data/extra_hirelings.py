"""Iteration 010, hirelings: remembrance — the wildflowers a friendly ghost leaves on the smithy step, the
headstones of hirelings who died on expeditions, and the vase that keeps the flowers (art: make_hireling_art.py)."""
from make_data_helpers import it, P

ITEMS = [
    it("flowers_remembrance", "Wildflowers", "material", None, 0, tags=["keepsake", "remembrance"],
       desc="A handful of meadow flowers tied with grass, left on the smithy step in the night. "
            "They would look well in the vase in your quarters."),
]

PROPS = {
    "headstone_hireling": P(64, 80, desc="a fresh headstone of pale stone over a new earth mound, a name cut into its face"),
    "wildflowers_bundle": P(48, 40, solid=False, desc="a small bunch of wildflowers tied with grass, lying on a doorstep"),
    "vase_flowers": P(48, 64, desc="the quarters' small glazed vase holding a bunch of wildflowers"),
}
