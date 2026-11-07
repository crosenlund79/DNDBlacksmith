# Ember & Ash — dansk resumé

**Ember & Ash** er et 2D-rollespil og landsbysimulation for Godot 4.3+, set lige oppefra. Du spiller Brannoc Ironhand, en aldrende tidligere eventyrer, der driver smedjen i landsbyen Brindlewick.

## Start

- **Windows:** læg `Godot_v4.x-stable_win64.exe` i mappen `game/`, eller sæt miljøvariablen `GODOT`. Kør derefter `run_windows.bat`. Første opstart importerer grafik og lyd.
- **Test:** kør `run_tests_windows.bat`.

## Styring

| Tast | Handling |
|---|---|
| WASD / piletaster | Gå (Shift løber) |
| E / Mellemrum | Interager |
| I | Lager |
| H | Ansatte |
| K | Færdigheder |
| J | Eventyrere |
| O | Bestillinger |
| L | Regnskab |
| Esc | Menu |
| F5 / F9 | Hurtig gem / indlæs |
| F3 | Diagnose |

## Systemer

- **Håndværk:** 25 specialiserede stationer plus ambolten, fordelt på fem discipliner. Hver har sin egen cirkulære timing-prøve. Præcision giver håndværksprocent, som kan overstige 100 %.
- **Terninger:** automatisk eller fysisk indtastning. Begge bruger samme beregning.
- **Sjældenhed:** farver i Diablo-stil. Legendariske genstande har stjerne, lyd og glimt.
- **Beholdere:** indholdet afsløres én genstand ad gangen.
- **Ansatte:** op til tre. Arbejdstiden fordeles i procent (i alt 100 %). Ekspeditioner kan give udbytte, skader eller død.
- **Eventyrere:** de lever deres eget liv; udstyret påvirker deres overlevelse og succes.
- **Forretning:** butik, reparationer og bestillinger.
- **Relationer:** sociale relationer med familiebånd og hukommelse, uden synlige målere.
- **Romantik og ægteskab:** ægteskab med en eventyrer, der fortsætter sit eventyrliv.
- **Købmanden:** ugentlige leverancer fra købmanden, hvis datter er eventyrer.
- **Gem og indlæs:** versionerede gemmepladser med sikkerhedskopi.
- **Den levende landsby:** eventyrerne danner grupper på kroen kl. 6, køber forsyninger kl. 7 og drager ud kl. 8 til en af fem egne. Ekspeditionen udfolder sig på spillets ur — rejse, spejding, fælder, kister, kampe med terninger og de rigtige genstande — også når ingen ser med.
- **MOST WANTED-tavlen** (i kroen, eller tasten B): faner for Mest efterlyste, Aktive ekspeditioner, På kroen og Legender & historie; dossierer med de faktiske genstande; "Observe Expedition" med kort, rute, journal og genafspilning af hvert kast.
- **Sværhedsgrad** (vælges ved nyt spil, kan ændres i menuen): Lærling (ingen død, fuldt overblik), Svend (moderat risiko), Mester (intet live-overblik, hårdere økonomi).
- **Tid:** P pause, −/+ hastighed ×1–×8. Observation pauser aldrig simuleringen.

Alle scripts har en kommentar øverst på engelsk (EN) og dansk (DA). Den tekniske beskrivelse står i `TECHNICAL.md` (engelsk).
