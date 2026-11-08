"""Ironfront content for make_data.py: the host, Barnaby Quill, who runs the card table in his basement."""
from make_data_helpers import ch, L

CHARACTERS = [
    ch("barnaby", "Barnaby Quill", "villager",
       L(build="slim", female=False, skin="#e6c2a0", hair="curly", hair_col="#8a5a32", beard="stubble", beard_col="#8a5a32",
         armor="none", shirt="#a07c3c", cloak=None, back="none", hand="none", extras=["spectacles", "helmet_m1"]),
       age=36, title="Ironfront enthusiast and host of the basement war-room",
       personality="Eager, precise and wonderfully nerdy; owns more tiny painted iron beetles than spoons. "
                   "Wears a green steel helmet at the card table and insists everyone else does too.",
       home="barnaby_house", work="ironfront_basement"),
]
