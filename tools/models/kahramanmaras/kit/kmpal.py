"""Extra palette for the Kahramanmaras building set (bld_*.py). Registered with lib.pal_add().
Interior paints and furniture get almost no snow dust: they sit under a ceiling."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L

EXTRA = {
    # more facade plasters seen in Kahramanmaras blocks
    "plaster_blue":   {"c": "a7b9c8", "r": 0.9, "snow": 0.9},
    "plaster_grey":   {"c": "b3b0aa", "r": 0.9, "snow": 0.9},
    "plaster_cream":  {"c": "ddd2b6", "r": 0.9, "snow": 0.9},
    "plaster_peach":  {"c": "dba98a", "r": 0.9, "snow": 0.9},
    "plaster_olive":  {"c": "b3b48c", "r": 0.9, "snow": 0.9},
    "band_brown":     {"c": "6e4b3b", "r": 0.9, "snow": 0.9},
    "band_grey":      {"c": "7b7975", "r": 0.9, "snow": 0.9},
    "band_cream":     {"c": "d5ccb6", "r": 0.9, "snow": 0.9},
    "iron_bar":       {"c": "2f3136", "r": 0.5, "snow": 0.4},
    "concrete_new":   {"c": "a6a39b", "r": 1.0, "snow": 0.8},   # unfinished top floor
    "brick_hollow":   {"c": "b4694a", "r": 0.95, "snow": 0.7},  # tugla (hollow clay infill)
    "insulation":     {"c": "c9c3b4", "r": 1.0, "snow": 0.6},   # mantolama foam under plaster
    "dust":           {"c": "8e877d", "r": 1.0, "snow": 0.5},
    "debris_grey":    {"c": "8c8780", "r": 1.0, "snow": 0.3},    # rubble mounds: snow only in patches
    "debris_brick":   {"c": "9e5d45", "r": 1.0, "snow": 0.25},
    # interior (no snow: under a ceiling)
    "int_paint_a":    {"c": "d2c7a8", "r": 0.9, "snow": 0.05},
    "int_paint_b":    {"c": "9fb9b7", "r": 0.9, "snow": 0.05},
    "int_paint_c":    {"c": "c9a69e", "r": 0.9, "snow": 0.05},
    "int_paint_d":    {"c": "b9b58e", "r": 0.9, "snow": 0.05},
    "int_paint_e":    {"c": "a9a9c4", "r": 0.9, "snow": 0.05},
    "int_ceiling":    {"c": "d9d5cc", "r": 0.9, "snow": 0.0},
    "int_wood":       {"c": "8d6242", "r": 0.7, "snow": 0.1},
    "int_tile":       {"c": "b9b3a6", "r": 0.4, "snow": 0.1},
    "int_tile_wall":  {"c": "c8d1cf", "r": 0.3, "snow": 0.0},
    # furniture + household
    "f_red":          {"c": "9a3a3c", "r": 1.0, "snow": 0.15},
    "f_blue":         {"c": "425b8a", "r": 1.0, "snow": 0.15},
    "f_green":        {"c": "5d7550", "r": 1.0, "snow": 0.15},
    "f_cream":        {"c": "d6cbb2", "r": 1.0, "snow": 0.15},
    "f_brown":        {"c": "7a5444", "r": 1.0, "snow": 0.15},
    "f_wood":         {"c": "6a462e", "r": 0.75, "snow": 0.15},
    "f_wood_light":   {"c": "a8805a", "r": 0.75, "snow": 0.15},
    "f_white":        {"c": "d4d3cd", "r": 0.45, "snow": 0.15},
    "f_dark":         {"c": "2d2f35", "r": 0.35, "snow": 0.1},
    "f_kilim":        {"c": "8c2e33", "r": 1.0, "snow": 0.2},
    "f_kilim_b":      {"c": "c28b3b", "r": 1.0, "snow": 0.2},
    "f_kilim_c":      {"c": "2f4a6b", "r": 1.0, "snow": 0.2},
    "f_blanket":      {"c": "7a4868", "r": 1.0, "snow": 0.2},
    "f_paper":        {"c": "d8d2c2", "r": 0.8, "snow": 0.0},
    "f_curtain":      {"c": "d3c7a6", "r": 1.0, "snow": 0.2},
    "f_drape":        {"c": "7d3445", "r": 1.0, "snow": 0.2},
    "f_copper":       {"c": "a9653c", "r": 0.35, "snow": 0.1},
    "f_plant":        {"c": "4c6a3c", "r": 0.9, "snow": 0.3},
    "f_pic_a":        {"c": "5f7f94", "r": 0.5, "snow": 0.0},
    "f_pic_b":        {"c": "8e8a5a", "r": 0.5, "snow": 0.0},
    "f_mirror":       {"c": "6f7d8a", "r": 0.1, "snow": 0.0},
    "f_pepper":       {"c": "9c2420", "r": 0.7, "snow": 0.3},   # Maras biberi strings
    "f_orange":       {"c": "c9792e", "r": 0.8, "snow": 0.3},
    "f_yellow_crate": {"c": "c9a43a", "r": 0.8, "snow": 0.6},
}


def setup() -> None:
    L.pal_add(EXTRA)
