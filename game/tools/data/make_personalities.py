"""Generates game/data/personalities.json — the voices of awakened equipment (ItemSpirit).
Run: python3 tools/data/make_personalities.py

A few exceptional pieces (named legendaries, Epic pieces, cursed or arcane ones after a great deed)
develop a small personality and now and then say something while the smith works on them.

types.<id>:  name, desc, lines{context: [text, ...]}
Contexts:    repair, sharpen, reforge (forge/anvil/quench), enchant (rune socket), treat (oils, coatings),
             inspect, idle (on display), maker (acknowledges the smith who forged it), any (fallback).
Placeholders (filled from the item's real history; a line whose placeholder has no value is skipped):
  {name} the piece, {maker} who forged it, {first_owner} / {last_owner} who carried it, {deed} its great deed
  (Epic distinction), {place} where something happened to it, {enemy} a foe it felled, {days} days since it was
  made, {owners} how many hands it passed through, {kills} its tally.
Keep the lines short, restrained and atmospheric: one breath, no conversations.
"""
import json
import os

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "..", "data", "personalities.json")

TYPES = {
    "proud": dict(name="Proud", desc="Knows its worth and would like you to know it too.", lines=dict(
        repair=["Careful with that edge. Kings have fallen before it.",
                "Mend me well, smith. {enemy} did not have the last word."],
        sharpen=["Finer. Finer still. I am no butcher's cleaver."],
        reforge=["Remake me if you must. You will not make me humble."],
        enchant=["A rune? Very well. Let it learn from me."],
        treat=["A coat of oil will not hide what I am. Ask anyone in {place}."],
        inspect=["Look closer. You will not see work like me twice.",
                 "{deed}. And still they ask whether I am sharp enough."],
        idle=["Do they not see me? Put me where the light falls."],
        maker=["{maker}. You made me well. Do not let it go to your head."],
        any=["Mind the edge. It remembers {enemy}."])),
    "sarcastic": dict(name="Sarcastic", desc="Has passed through too many hands to be impressed by any of them.", lines=dict(
        repair=["Oh, splendid. More grinding.",
                "{last_owner} used me to open crates. Just so you know where the nicks came from."],
        sharpen=["Yes, yes, sharper. Because that went so well last time."],
        reforge=["Wonderful. Another bath in molten metal."],
        enchant=["A rune. How original. Shall we add a little bell as well?"],
        treat=["Oil. Lovely. I'll smell like a lamp for a week."],
        inspect=["Go on, stare. {owners} pairs of hands so far; one more won't hurt.",
                 "Yes, that dent is from {place}. No, I don't want to talk about it."],
        idle=["On display again. Like a ham in a window."],
        maker=["Ah, {maker}. Come to admire your own handiwork? Fair. It is good handiwork."],
        any=["{first_owner} at least said thank you."])),
    "impatient": dict(name="Impatient", desc="Made for work, and bored by everything else.", lines=dict(
        repair=["Less polishing. More chopping.",
                "Are we done? There is a road out there and I am not on it."],
        sharpen=["Sharp enough. Sharp enough! Let me go."],
        reforge=["Hammer faster. Somewhere, something needs hitting."],
        enchant=["Set it and be done. Runes are for people with time."],
        treat=["One coat. One. Then back on the road."],
        inspect=["{days} days in the world, and too many of them on shelves.",
                 "You've looked. I'm still here. Can we go?"],
        idle=["Sell me. Lend me. Throw me. Anything but this."],
        maker=["{maker}, you made me for work. So let me work."],
        any=["Hurry. The road back to {place} is long."])),
    "noble": dict(name="Noble", desc="Carried by good people, and means to stay worthy of them.", lines=dict(
        repair=["Mend me true, smith. I have a vow to keep.",
                "{first_owner} carried me with honour. See that I am fit for it still."],
        sharpen=["Keep the edge clean. A clean blade ends things quickly."],
        reforge=["Fire purifies. I do not fear it."],
        enchant=["Let the rune serve the weak, as I do."],
        treat=["Thank you. A small kindness, kindly given."],
        inspect=["I bear the marks of {place} without shame.",
                 "Judge me by those I protected, not by my polish."],
        idle=["I would rather stand guard than stand for sale."],
        maker=["Well made, {maker}. You gave me a good heart."],
        any=["We stood fast against {enemy}. We would again."])),
    "mischievous": dict(name="Mischievous", desc="Has a habit of going missing and turning up again.", lines=dict(
        repair=["Hold still? You hold still. I'm having fun.",
                "I hid from {last_owner} for three days once. Best three days of my life."],
        sharpen=["Ooh, sparks! Again, again!"],
        reforge=["Make me a little lighter. I like to wander off."],
        enchant=["Does this rune make me invisible? Shame. I'd have had fun with that."],
        treat=["That tickles. Do the other side."],
        inspect=["Check the pommel. No, the other end. Made you look.",
                 "I was lost in {place}, you know. Well. 'Lost'."],
        idle=["Leave me near the till. I promise nothing."],
        maker=["{maker}! You left a little hammer-mark under my guard. I love it. Don't tell anyone."],
        any=["Psst. {first_owner} still owes me a sharpening."])),
    "melancholy": dict(name="Melancholy", desc="Has outlived the people who carried it.", lines=dict(
        repair=["My first master was kinder than the last.",
                "Leave the nick by the hilt, if you would. {first_owner} made it."],
        sharpen=["Each pass takes a little of me away. It's all right."],
        reforge=["Melt the old memories with the metal, if you can. You can't."],
        enchant=["A new light in me. The old ones went out in {place}."],
        treat=["Gentle hands. I had forgotten."],
        inspect=["{days} days since I left this forge. It felt longer.",
                 "{last_owner} did not come home. I did."],
        idle=["Rain on the shutters. {first_owner} used to hum when it rained."],
        maker=["You made me, {maker}. Did you mean me for all this?"],
        any=["Everyone who carries me goes away in the end."])),
    "bloodthirsty": dict(name="Bloodthirsty", desc="Has tasted battle and wants more of it.", lines=dict(
        repair=["Fix me fast. I'm thirsty.",
                "{enemy} bled well. I want more like that."],
        sharpen=["Yes. Sharper. Sharper means quicker."],
        reforge=["Quench me in something warmer than water next time."],
        enchant=["Does the rune burn them? Tell me it burns them."],
        treat=["Good. Let them feel it twice."],
        inspect=["{kills} notches, and I want a hundred.",
                 "Remember {place}? I remember {place}."],
        idle=["A peg on a wall. A slow death for a blade."],
        maker=["{maker}, you forged a hungry thing. I thank you for it."],
        any=["When do we go back out?"])),
    "wise": dict(name="Wise", desc="Has listened to wizards by the fire for a long time.", lines=dict(
        repair=["Patience. Grit before polish, as in all things.",
                "{first_owner} read aloud by the fire. I learnt more than you might think."],
        sharpen=["An edge is a promise. Keep it modest."],
        reforge=["Change the shape, and the shape changes you. Gently, now."],
        enchant=["Mind the third line of the rune. It wants to curl. Let it."],
        treat=["Frost and fire both fade. Good craft remains."],
        inspect=["{days} days in the world. I know a little of it now.",
                 "In {place} I learnt that the dark listens. Speak softly there."],
        idle=["Watch who looks at me without wanting me. That one will be a friend."],
        maker=["Your hand is steadier than when you made me, {maker}. Good."],
        any=["Slowly. The metal tells you when."])),
    "vengeful": dict(name="Vengeful", desc="Something was done to it, or to its bearer, and it has not forgotten.", lines=dict(
        repair=["Mend me. {enemy} still walks, and so must I.",
                "{last_owner} fell. The thing that did it has not."],
        sharpen=["Sharpen for a single throat."],
        reforge=["Burn away the rust. Not the grudge."],
        enchant=["Bind something cruel into me. I will find a use for it."],
        treat=["Let it sting."],
        inspect=["I remember every face from {place}.",
                 "Do not wipe that stain. It is a reminder."],
        idle=["I am not for sale. I am waiting."],
        maker=["You made me, {maker}. Others made me what I am."],
        any=["Not yet. Not yet. Soon."])),
    "dutiful": dict(name="Dutiful", desc="Took the blows so its bearer did not have to.", lines=dict(
        repair=["Close the gap on the left side, please. It let the cold in at {place}.",
                "Patch me up. {last_owner} will need me again."],
        sharpen=["Rim, not edge. I keep people. I don't cut them."],
        reforge=["Thicker at the shoulder. That's where they always aim."],
        enchant=["A ward. Good. One more thing between them and harm."],
        treat=["Thank you. Rust is the one enemy I cannot stop."],
        inspect=["That dent was meant for {first_owner}'s heart.",
                 "I took the blows so they didn't have to."],
        idle=["Hang me where I can see the door."],
        maker=["Solid work, {maker}. I held. Every time."],
        any=["Still standing. Still holding."])),
}

# Contexts a station or service may ask for, and the context whose lines it borrows when it has none.
ALIASES = {"forge": "reforge", "anvil": "reforge", "quench": "reforge", "grind": "sharpen", "polish": "repair",
           "rune": "enchant", "socket": "enchant", "oil": "treat", "coat": "treat", "display": "idle"}
FALLBACK = {"sharpen": "repair", "reforge": "repair", "treat": "repair", "enchant": "any", "repair": "any",
            "inspect": "any", "idle": "any", "maker": "any"}


def main():
    for tid, t in TYPES.items():
        n = sum(len(v) for v in t["lines"].values())
        assert 8 <= n <= 14, (tid, n)
    data = {"types": TYPES, "aliases": ALIASES, "fallback": FALLBACK}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    print("personalities ok", len(TYPES), "types,", sum(sum(len(v) for v in t["lines"].values()) for t in TYPES.values()), "lines")


if __name__ == "__main__":
    main()
