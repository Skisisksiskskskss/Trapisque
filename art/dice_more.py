"""
More dice skins (tools/art.py calls sprites()), drawn exactly as art/dice.py draws its
own: "dice_more/<skin>" and "dice_more/<skin>_pip". They're on a sheet of their own so
the sheet already uploaded with the first dice stays as it is (CosmeticArt.die looks here
when dice/ has no such skin). The colours match their looks in Cosmetics.lua.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dice import die, pip  # noqa: E402

# skin: face, face2, pip, edge, material
SKINS = {
    "ocean": ("#3FA7D6", "#1D6E9E", "#FFFFFF", "#0E3F5C", "ocean"),
    "candy": ("#FFF5F8", "#FF5D8F", "#B0124A", "#E3477A", "candy"),
    "lava": ("#2B2422", "#1A1412", "#FFB000", "#FF6A1C", "lava"),
    "sunset": ("#FF8A5C", "#FFC46B", "#3A1E4A", "#FFE08A", "sunset"),
}


def sprites():
    out = []
    for skin, spec in SKINS.items():
        out.append((skin, die(skin, spec)))
        out.append((skin + "_pip", pip(skin, spec)))
    return out
