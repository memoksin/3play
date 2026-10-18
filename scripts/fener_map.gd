class_name FenerMap
extends RefCounted
## The Fener neighbourhood (#123): Kahramanmaras, 6 Feb 2023, the night after the 04:17 quake.
## Pure data + geometry helpers, shared by the rules (scenes/minigames/fener.gd), the 3D view
## (scenes/minigames/fener/fener_world.gd), the tests and tools/fener_map_png.gd (top-down check).
##
## Units: metres. Logic runs on the ground plane: Vector2(x, z) = world Vector3(x, 0, z).
## +X east, +Z south (toward the camera). The slab spans BOUNDS. Model fronts face +Z (yaw 0).
## Four regions around a crossroads: collapsed apartments (NW), market (NE), old houses (SW),
## camp / assembly area (SE). The avenue (E-W) and the cross street (N-S) meet in the middle.

const BOUNDS := Rect2(-56, -40, 112, 80)
const START := Vector2(-44, -4.8)
## Toplanma alanı: followers that enter it with the player are safe.
const AREA := Rect2(27, 17, 16, 13)
## Where a trapped person can be reported (rescue crew, AFAD tent): centre, radius.
const CREWS: Array[Vector3] = [Vector3(-30.5, -10.5, 5.5), Vector3(25.8, 25.0, 5.0)]
const SIDEWALK_H := 0.12
## People are not placed closer than this to each other / to the start.
const SPREAD := 13.0

## Region name suffixes (text) and rects; outside all = the avenue / crossroads.
const REGIONS := [
	["REGION_RUINS", Rect2(-56, -40, 50, 34)],
	["REGION_MARKET", Rect2(6, -40, 50, 34)],
	["REGION_HOUSES", Rect2(-56, 6, 50, 34)],
	["REGION_CAMP", Rect2(6, 6, 50, 34)],
]
const REGION_AVENUE := "REGION_AVENUE"

## Ground surfaces drawn by the world: [kind, rect]. Later entries draw over earlier ones.
## road = asphalt with slush (y 0), walk = sidewalk pavers (y SIDEWALK_H), lane = trampled snow path.
const SURFACES := [
	["lane", Rect2(-56, -28.0, 50, 5.0)],
	["lane", Rect2(6, -26.6, 50, 12.5)],
	["lane", Rect2(-56, 20.6, 50, 5.0)],
	["lane", Rect2(-30, 6, 4.5, 15)],
	["lane", Rect2(6, 6, 50, 3.0)],
	["road", Rect2(-56, -3.5, 112, 7)],
	["road", Rect2(-3.5, -40, 7, 80)],
	["walk", Rect2(-56, -6, 52.5, 2.5)],
	["walk", Rect2(3.5, -6, 52.5, 2.5)],
	["walk", Rect2(-56, 3.5, 52.5, 2.5)],
	["walk", Rect2(3.5, 3.5, 52.5, 2.5)],
	["walk", Rect2(-6, -40, 2.5, 34)],
	["walk", Rect2(3.5, -40, 2.5, 34)],
	["walk", Rect2(-6, 6, 2.5, 34)],
	["walk", Rect2(3.5, 6, 2.5, 34)],
]

## Mass of every model that is more than set dressing (local Rect2 at yaw 0, height): what hides the player,
## stops the flashlight (height >= OPAQUE_H), shakes down on an aftershock and what the rescuers route around.
## From the model AABBs. It is NOT what stops the player: that is WALK below.
const OPAQUE_H := 2.2
const FOOT := {
	"bld_apt_blue_3": [Rect2(-5.0, -5.6, 10.2, 11.2), 15.8],
	"bld_apt_grey_8": [Rect2(-8.0, -5.4, 16.2, 11.2), 31.1],
	"bld_apt_mint_4": [Rect2(-7.0, -5.6, 13.6, 11.4), 19.6],
	"bld_apt_peach_5": [Rect2(-6.9, -5.4, 13.5, 11.2), 22.5],
	"bld_apt_yellow_6": [Rect2(-7.4, -5.4, 14.5, 11.2), 25.3],
	"bld_cut_corner": [Rect2(-8.0, -6.0, 14.9, 11.0), 25.3],
	"bld_cut_facade": [Rect2(-9.2, -5.4, 15.7, 10.4), 22.4],
	"bld_cut_half": [Rect2(-9.5, -7.5, 16.0, 12.5), 19.0],
	"bld_house_collapsed": [Rect2(-7.0, -6.0, 13.5, 12.0), 5.0],
	"bld_house_old": [Rect2(-5.0, -4.7, 10.1, 9.0), 9.7],
	"bld_house_open": [Rect2(-5.4, -4.3, 10.4, 8.8), 9.4],
	"bld_pancake_full": [Rect2(-10.5, -7.0, 20.0, 15.0), 8.2],
	"bld_pancake_mid": [Rect2(-9.5, -6.5, 19.0, 13.0), 20.8],
	"bld_pancake_slide": [Rect2(-9.5, -7.0, 19.5, 15.5), 7.0],
	"bld_pancake_soft": [Rect2(-9.5, -7.0, 18.0, 14.5), 16.5],
	"bld_rubble_l": [Rect2(-10.0, -8.5, 19.5, 16.0), 13.0],
	"bld_rubble_lot": [Rect2(-8.0, -6.2, 15.7, 12.7), 5.1],
	"bld_rubble_s": [Rect2(-3.5, -3.2, 6.9, 6.3), 2.4],
	"bld_shop_bakkal": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_shop_berber": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_shop_dondurma": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_shop_eczane": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_shop_firin": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_shop_manav": [Rect2(-2.25, -3.6, 4.5, 7.6), 4.4],
	"bld_toppled": [Rect2(-6.5, -15.0, 13.0, 30.0), 12.0],
	"bld_wall_frame": [Rect2(-2.6, -0.6, 5.3, 1.2), 6.1],
	"bld_wall_garden": [Rect2(-1.5, -0.25, 3.0, 0.5), 1.8],
	"bld_wall_garden_broken": [Rect2(-1.5, -0.25, 3.0, 0.5), 1.2],
	"bld_wall_ruin": [Rect2(-3.6, -1.0, 7.8, 2.0), 7.2],
	"bld_facade_fallen": [Rect2(-5.0, -3.8, 10.4, 7.6), 0.8],
	"car_red": [Rect2(-0.95, -2.25, 1.9, 4.5), 1.5],
	"car_white": [Rect2(-0.95, -2.25, 1.9, 4.5), 1.5],
	"car_cream": [Rect2(-0.95, -2.25, 1.9, 4.5), 1.5],
	"car_crushed": [Rect2(-1.1, -2.25, 2.4, 4.5), 1.3],
	"car_hatch_snow": [Rect2(-1.0, -1.95, 2.0, 4.3), 1.5],
	"car_shelter": [Rect2(-1.0, -3.0, 2.2, 4.9), 1.6],
	"van_snow": [Rect2(-1.0, -2.9, 2.0, 5.1), 2.0],
	"ambulance": [Rect2(-1.26, -2.93, 2.52, 5.88), 2.8],
	"fire_truck": [Rect2(-1.4, -4.4, 2.9, 8.7), 3.8],
	"excavator": [Rect2(-1.5, -3.3, 3.0, 6.6), 4.8],
	"light_tower": [Rect2(-1.2, -1.2, 2.4, 2.4), 2.0],
	"generator": [Rect2(-1.0, -0.9, 3.0, 1.9), 2.0],
	"floodlight_tripod": [Rect2(-0.5, -0.5, 1.0, 1.0), 1.0],
	"tent_afad": [Rect2(-2.76, -3.15, 5.52, 6.7), 3.7],
	"tent_kizilay": [Rect2(-2.66, -3.1, 5.32, 6.55), 2.6],
	"tent_kitchen": [Rect2(-3.3, -2.6, 6.5, 6.0), 3.0],
	"bus_stop": [Rect2(-1.9, -1.0, 3.8, 1.6), 2.7],
	"tree_pine": [Rect2(-0.5, -0.5, 1.0, 1.0), 6.6],
	"tree_pine_small": [Rect2(-0.4, -0.4, 0.8, 0.8), 3.5],
	"tree_cypress": [Rect2(-0.5, -0.5, 1.0, 1.0), 6.4],
	"tree_bare": [Rect2(-0.4, -0.4, 0.8, 0.8), 6.1],
	"tree_fallen": [Rect2(-2.0, -0.8, 7.6, 1.6), 1.2],
	"pole_fallen": [Rect2(-0.6, -0.5, 13.2, 1.0), 0.9],
	"barrier_set": [Rect2(-2.0, -0.4, 7.4, 0.8), 1.1],
	"fire_barrel": [Rect2(-0.6, -0.6, 1.2, 1.2), 1.4],
	"fire_barrel_tea": [Rect2(-0.7, -0.7, 1.4, 1.4), 1.3],
	"fire_barrel_low": [Rect2(-0.6, -0.6, 1.2, 1.2), 0.9],
	"fire_pit": [Rect2(-1.2, -0.9, 2.2, 1.8), 0.7],
	"aid_boxes": [Rect2(-1.2, -0.9, 2.6, 1.3), 1.2],
	"aid_water": [Rect2(-1.0, -0.9, 1.6, 1.8), 1.5],
	"bench_snow": [Rect2(-1.1, -0.4, 2.2, 0.8), 0.9],
}

## Buildings and props: [model, x, z, yaw (deg), tag]. Yaw is snapped to 90 deg for the solid.
## Tags: "" plain, "deco" (never solid), "fade" (fades out when it hides the player; default for
## anything taller than 4 m).
const PLACES := [
	# --- NW: collapsed apartments, the rescue crew at work ---
	["bld_apt_grey_8", -46.0, -34.2, 0, ""],
	["bld_cut_half", -27.6, -32.3, 0, ""],
	["bld_apt_peach_5", -13.4, -34.2, 0, ""],
	["bld_pancake_full", -44.0, -16.0, 0, ""],
	["bld_rubble_lot", -14.6, -17.4, 0, ""],
	["bld_rubble_spill", -28.0, -24.6, 0, "deco"],
	["bld_rubble_spill", -44.0, -6.9, 0, "deco"],
	["excavator", -28.3, -14.2, -90, ""],
	["light_tower", -30.0, -25.2, 160, ""],
	["generator", -24.0, -25.8, 0, ""],
	["floodlight_tripod", -34.0, -9.0, -60, ""],
	["barrier_set", -26.5, -7.2, 0, ""],
	["street_lamp_bent", -20.0, -5.2, 0, "deco"],
	# the toppled block lies across the cross street, north of the avenue
	["bld_toppled", 0.0, -25.2, 0, ""],
	# --- NE: the market (shops on the avenue, apartments behind) ---
	["bld_shop_bakkal", 10.0, -10.5, 0, ""],
	["bld_shop_firin", 14.5, -10.5, 0, ""],
	["bld_shop_eczane", 19.0, -10.5, 0, ""],
	["bld_shop_berber", 28.0, -10.5, 0, ""],
	["bld_shop_manav", 32.5, -10.5, 0, ""],
	["bld_shop_dondurma", 37.0, -10.5, 0, ""],
	["bld_apt_mint_4", 47.8, -11.8, 0, ""],
	["bld_apt_yellow_6", 14.4, -34.2, 0, ""],
	["bld_pancake_mid", 31.4, -33.4, 0, ""],
	["bld_cut_corner", 49.3, -33.8, 0, ""],
	["bld_rubble_spill", 31.4, -24.4, 0, "deco"],
	["car_hatch_snow", 11.5, -21.5, 10, ""],
	["car_white", 45.0, -21.0, 90, ""],
	["street_lamp", 36.0, -5.4, 0, "deco"],
	# --- SW: old houses with gardens ---
	["bld_house_old", -48.0, 14.0, 0, ""],
	["bld_house_open", -34.6, 13.8, 0, ""],
	["bld_house_collapsed", -16.5, 14.4, 0, ""],
	["bld_house_old", -47.0, 31.6, 180, ""],
	["bld_wall_ruin", -34.0, 30.6, 0, ""],
	["bld_house_old", -20.0, 31.4, 0, ""],
	["bld_wall_frame", -10.5, 30.2, 0, ""],
	["car_shelter", -40.5, 37.4, 90, ""],
	["van_snow", -12.0, 37.6, 90, ""],
	["tree_pine", -54.0, 24.5, 0, ""],
	["tree_bare", -27.5, 9.8, 40, ""],
	["tree_cypress", -26.0, 37.5, 0, ""],
	["tree_pine_small", -7.8, 36.5, 0, ""],
	["tree_fallen", -42.0, 27.0, 15, ""],
	["bld_wall_garden", -52.5, 7.4, 180, ""],
	["bld_wall_garden", -49.5, 7.4, 180, ""],
	["bld_wall_garden_broken", -46.5, 7.4, 180, ""],
	["bld_wall_garden", -40.5, 7.4, 180, ""],
	["bld_wall_garden", -37.5, 7.4, 180, ""],
	["bld_wall_garden_broken", -24.0, 7.4, 180, ""],
	["bld_wall_garden", -21.0, 7.4, 180, ""],
	["bld_wall_garden", -18.0, 7.4, 180, ""],
	["bld_wall_garden", -10.5, 7.4, 180, ""],
	["street_lamp", -36.0, 5.4, 180, "deco"],
	["bus_stop", -14.0, 5.9, 180, ""],
	# --- SE: camp and assembly area ---
	["assembly_area", 35.0, 23.6, 0, "deco"],
	["assembly_sign", 28.6, 17.4, -20, "deco"],
	["tent_afad", 20.6, 24.8, 90, ""],
	["tent_kizilay", 20.6, 33.4, 90, ""],
	["tent_kitchen", 35.0, 35.0, 0, ""],
	["fire_barrel_tea", 32.0, 14.6, 0, ""],
	["fire_barrel", 46.5, 21.5, 0, ""],
	["fire_pit", 44.0, 30.5, 0, ""],
	["aid_boxes", 27.4, 34.2, 10, ""],
	["aid_water", 29.4, 36.4, -5, ""],
	["chair_plastic", 33.2, 15.4, -40, "deco"],
	["chair_plastic", 30.8, 15.6, 50, "deco"],
	["ambulance", 11.6, 11.0, 0, ""],
	["light_tower", 50.0, 14.0, -140, ""],
	["generator", 53.2, 18.2, 90, ""],
	["sign_assembly_arrow", 7.6, 7.6, -45, "deco"],
	["sign_assembly_arrow", -7.6, -7.4, 135, "deco"],
	["sign_cardboard", 24.4, 18.6, 20, "deco"],
	["tree_pine", 54.0, 37.5, 0, ""],
	["tree_pine", 10.5, 37.0, 0, ""],
	["tree_bare", 16.0, 18.5, 0, ""],
	["bench_snow", 40.0, 36.8, 0, ""],
	# --- avenue + crossroads ---
	["car_crushed", -9.5, -1.6, 90, ""],
	["car_red", 17.0, 1.8, 92, ""],
	["car_white", -33.0, 1.9, -88, ""],
	["car_cream", 42.0, -1.8, 85, ""],
	["fire_truck", -26.6, 1.0, 90, ""],
	["pole_fallen", -3.0, 15.4, 0, ""],
	["street_lamp", 20.0, 5.4, 180, "deco"],
]

## Fixed hazards. kind: cable (live cable end, circle r), hole (under snow, circle r), crack (rect:
## rough, hurts on the aftershock hit), wall (rect under a leaning facade: falling pieces), glass (rect).
## [kind, a, b, ...]: circle -> [kind, Vector2 centre, r, model?]; rect -> [kind, Rect2, model?].
const CABLES := [
	# pole (model origin) and spark end, from scenes/art_pilot/km_street.tscn
	["cable_snapped", Vector2(-38.0, 5.2), 180, Vector2(-41.9, 3.7)],
	["pole_leaning", Vector2(30.0, -17.5), 0, Vector2(36.6, -16.0)],
	["pole_fallen", Vector2(-3.0, 15.4), 0, Vector2(9.0, 13.2)],
]
const CABLE_R := 1.5
## Holes under the snow: a run picks HOLE_COUNT of these.
const HOLES: Array[Vector2] = [
	Vector2(-50.0, -25.4), Vector2(-12.0, -25.6), Vector2(16.0, -18.0), Vector2(42.0, -24.6),
	Vector2(-46.0, 23.0), Vector2(-8.5, 23.4), Vector2(-30.0, 38.6), Vector2(15.0, 23.0),
	Vector2(50.0, 30.0), Vector2(-22.0, -7.6), Vector2(27.0, -4.9), Vector2(-28.0, 16.0),
]
const HOLE_COUNT := 4
const HOLE_R := 0.95
## The open manhole on the avenue: always there, not hidden.
const MANHOLE := Vector2(40.0, 1.4)
const CRACKS := [
	["asphalt_crack", Vector2(0.8, 1.2), 25.0, Rect2(-2.6, -0.6, 7.0, 3.8)],
	["asphalt_heave", Vector2(-17.0, -1.0), 80.0, Rect2(-18.4, -3.4, 2.8, 5.0)],
	["asphalt_crack", Vector2(24.0, -0.6), -10.0, Rect2(20.6, -1.9, 6.8, 2.8)],
	["asphalt_crack", Vector2(-30.0, 23.0), 95.0, Rect2(-31.2, 19.8, 2.6, 6.6)],
]
## Strips under leaning facades / standing ruins.
const WALLS: Array[Rect2] = [
	Rect2(-37.0, -27.6, 16.4, 2.8),
	Rect2(22.0, -26.8, 19.0, 2.6),
	Rect2(-38.2, 27.2, 8.6, 2.4),
	Rect2(-14.0, 30.8, 6.6, 2.6),
	Rect2(41.4, -28.8, 14.0, 2.6),
]
const GLASS: Array[Rect2] = [
	Rect2(16.9, -6.4, 4.2, 1.3),
	Rect2(25.9, -6.4, 4.2, 1.3),
	Rect2(7.9, -6.4, 4.0, 1.3),
]
## Rough ground (rubble aprons, cracks): slower walking. Rect list.
const ROUGH: Array[Rect2] = [
	Rect2(-34.0, -27.2, 12.0, 4.6),
	Rect2(-50.0, -9.2, 12.0, 4.4),
	Rect2(25.4, -26.6, 12.0, 4.4),
]
## Within this distance of a building (solid taller than SHOCK_H) an aftershock drops debris on you.
const SHOCK_PAD := 3.0
const SHOCK_H := 4.0

## Candidate spots per person group (FenerPerson.spot_group).
const SPOTS := {
	&"lost_a": [Vector2(26.0, -20.0), Vector2(-17.0, 23.0), Vector2(40.0, -20.0), Vector2(12.0, 26.0)],
	&"lost_b": [Vector2(-38.0, 23.2), Vector2(46.0, -21.0), Vector2(-9.0, -26.0), Vector2(-4.5, 33.0)],
	&"slow": [Vector2(-48.0, 23.0), Vector2(-4.4, 25.0), Vector2(18.0, -24.6), Vector2(46.0, 33.0)],
	&"trapped": [Vector2(-24.2, -23.4), Vector2(34.5, -23.6), Vector2(-15.6, 21.4)],
	&"cold": [Vector2(-30.0, 30.0), Vector2(-14.0, 3.9), Vector2(40.0, -4.8)],
}
## Pickups belong to a rescue crew zone (CREWS: the nearest one to the spot) and are taken by walking into
## that zone, wherever the rescuers stand; the spot only says where the supply is drawn. kind -> spots; the
## first ITEM_COUNT spots are used. The first battery and the kit belong to the crew near the start, the
## second battery to the camp crew. The blanket belongs to the crew that is the shorter detour from the
## player when a person who needs one is found. Nothing is out before it is needed (see Fener.needs()).
## The zone is a place, not a person: each spot lies on open ground of its zone, at least 2 m from every
## rescuer and 1.5 m inside the ring (east of the chief by the street, north of the camp rescuer), clear of
## props and the park fence (the model spins), so a supply never reads as held by a rescuer
## (tests/test_fener_items.gd).
const ITEMS := {
	&"battery": [Vector2(-26.8, -11.4), Vector2(25.9, 22.0)],
	&"kit": [Vector2(-26.8, -9.2)],
	&"blanket": [Vector2(-26.4, -10.3), Vector2(27.3, 22.0)],
}
const ITEM_COUNT := {&"battery": 2, &"kit": 1, &"blanket": 1}

## Aftershock changes (one per shock, order shuffled per run): a ruin falls (new rubble blocks part of
## the lane), a pole comes down (new live cable), the road splits (new open hole).
## [id, region suffix, solid Rect2 or null, hazard: [kind, centre/rect, r] or null, model, pos, yaw]
const EVENTS := [
	[&"wall", "REGION_HOUSES", Rect2(-37.0, 27.4, 6.0, 2.4), null, "bld_rubble_s", Vector2(-34.0, 28.6), 20.0],
	[&"pole", "REGION_MARKET", null, ["cable", Vector2(44.0, 2.2), CABLE_R], "pole_fallen", Vector2(33.0, -4.6), -12.0],
	[&"hole", "REGION_AVENUE", null, ["hole", Vector2(-10.0, 4.6), HOLE_R], "asphalt_hole", Vector2(-10.0, 4.6), 0.0],
]

## What stops the player (#123): the part of each model that is a body-height obstacle, measured from the mesh
## (scripts/fener_footprint.gd: surface between STEP_H 0.4 m and BODY_H 1.8 m above the ground; tools/fener_footprints.gd,
## checked by tests/test_fener_walk.gd). Lower things (stones, bricks, flat debris, snow banks, cables) are stepped
## over, eaves / balconies / branches overhead do not count. Local coordinates at yaw 0, exact yaw at the place.
## Shape: Rect2 (box), Vector3(x, z, radius) (disc), [Vector2 centre, Vector2 half size, yaw deg] (turned box).
## Not listed = no WALK shape = never blocks.
const WALK := {
	"aid_boxes": [Rect2(-1.15, -0.35, 1.8, 0.8)],
	"aid_water": [Rect2(-0.55, -0.35, 1.1, 0.7)],
	"ambulance": [Rect2(-1.25, -2.95, 2.5, 5.9)],
	# a red and a white barrier with tape between them (tape is not a wall)
	"barrier_set": [Rect2(-2.05, -0.15, 2.9, 0.6), Rect2(2.55, -0.05, 2.3, 0.3)],
	"bench_snow": [Rect2(-0.95, -0.25, 1.9, 0.5)],
	# buildings: the walls at body height (their eaves, awnings and balconies hang over the street)
	"bld_apt_blue_3": [Rect2(-4.65, -4.65, 9.3, 9.2)],
	"bld_apt_grey_8": [Rect2(-7.65, -4.65, 15.3, 9.3)],
	"bld_apt_mint_4": [Rect2(-6.15, -4.65, 12.3, 9.3)],
	"bld_apt_peach_5": [Rect2(-6.15, -4.65, 12.3, 9.3)],
	"bld_apt_yellow_6": [Rect2(-6.15, -4.65, 12.3, 9.3)],
	"bld_cut_corner": [Rect2(-6.85, -4.65, 13.0, 9.65)],
	"bld_cut_facade": [Rect2(-6.75, -4.65, 12.9, 9.65)],
	"bld_cut_half": [Rect2(-7.55, -5.95, 13.7, 10.95)],
	"bld_facade_fallen": [Rect2(-4.45, -3.05, 3.2, 6.0), Rect2(-0.05, 1.45, 3.1, 0.4)],
	"bld_house_collapsed": [Rect2(-6.15, -5.55, 12.1, 10.2)],
	"bld_house_old": [Rect2(-4.15, -3.65, 8.3, 7.3)],
	"bld_house_open": [Rect2(-4.15, -3.65, 8.3, 8.15)],
	# rubble piles: the heap that is higher than a knee (the loose bricks round it are walkable, see ROUGH)
	"bld_pancake_full": [Rect2(-6.65, -5.35, 13.6, 13.35)],
	"bld_pancake_mid": [Rect2(-6.75, -4.65, 12.9, 11.15)],
	"bld_pancake_slide": [Rect2(-7.65, -4.45, 14.7, 12.95)],
	"bld_pancake_soft": [Rect2(-6.85, -5.15, 14.4, 12.65)],
	"bld_rubble_l": [Rect2(-7.55, -6.75, 15.0, 13.7)],
	"bld_rubble_lot": [Rect2(-5.85, -5.45, 11.9, 10.2)],
	"bld_rubble_s": [Rect2(-2.75, -2.45, 5.9, 4.9)],
	"bld_shop_bakkal": [Rect2(-2.25, -3.55, 4.5, 7.3)],
	"bld_shop_berber": [Rect2(-2.25, -3.45, 4.5, 7.3)],
	"bld_shop_dondurma": [Rect2(-2.25, -3.45, 4.5, 7.45)],
	"bld_shop_eczane": [Rect2(-2.25, -3.45, 4.5, 7.1)],
	"bld_shop_firin": [Rect2(-2.25, -3.55, 4.5, 7.1)],
	"bld_shop_manav": [Rect2(-2.25, -3.55, 4.5, 7.55)],
	"bld_toppled": [Rect2(-6.5, -12.35, 11.95, 27.0)],
	"bld_wall_frame": [Rect2(-2.15, -0.15, 4.3, 0.75)],
	"bld_wall_garden": [Rect2(-1.55, -0.15, 3.1, 0.3)],
	# the middle of the broken wall is open
	"bld_wall_garden_broken": [Rect2(0.45, -0.75, 1.8, 0.9), Rect2(-1.55, -0.15, 1.1, 0.3)],
	"bld_wall_ruin": [Rect2(-3.6, -1.0, 6.75, 2.0)],
	"bus_stop": [Rect2(-1.65, -0.75, 3.3, 1.3)],
	"car_cream": [Rect2(-0.95, -2.25, 1.9, 4.5)],
	# the car and the slab / ladder that fell on its side
	"car_crushed": [Rect2(-0.95, -2.25, 1.9, 4.5), Rect2(0.9, -1.4, 1.7, 1.8)],
	"car_hatch_snow": [Rect2(-1.25, -1.95, 2.1, 3.9)],
	"car_red": [Rect2(-0.95, -2.25, 1.9, 4.5)],
	"car_shelter": [Rect2(-0.85, -1.95, 1.7, 3.9)],
	"car_white": [Rect2(-0.95, -2.25, 1.9, 4.5)],
	# body and tracks, and the bucket on the ground (the boom between them is overhead)
	"excavator": [Rect2(-1.45, -2.15, 2.9, 4.3), Rect2(-0.65, 4.35, 1.6, 1.6)],
	"fire_barrel": [Vector3(0.0, -0.05, 0.42)],
	"fire_barrel_low": [Vector3(0.0, 0.0, 0.42)],
	"fire_barrel_tea": [Vector3(0.0, -0.05, 0.42)],
	# the ring of stones is a step; only the burning logs in the middle stop you
	"fire_pit": [Vector3(0.0, 0.0, 0.3)],
	"fire_truck": [Rect2(-1.35, -4.45, 2.7, 8.7)],
	# the pole: legs are thin, the mast is the obstacle
	"floodlight_tripod": [Vector3(0.0, -0.1, 0.3)],
	"generator": [Rect2(-1.1, -0.7, 2.3, 1.4)],
	"light_tower": [Rect2(-1.2, -0.7, 2.4, 1.4)],
	# lies on the ground at an angle (about 13 degrees away from +X)
	"pole_fallen": [[Vector2(4.65, -1.3), Vector2(4.3, 0.35), 13.1]],
	"tent_afad": [Rect2(-2.55, -2.95, 5.1, 5.2)],
	"tent_kitchen": [Rect2(-1.85, 0.85, 3.9, 1.0), Rect2(-2.55, -1.95, 5.1, 2.0), Rect2(-0.55, -0.65, 0.8, 0.8),
			Rect2(-1.65, -0.65, 0.7, 0.8)],
	"tent_kizilay": [Rect2(-2.45, -2.85, 4.9, 5.0)],
	# trees: the trunk (branches start higher than a person), the cypress is dense down to the ground
	"tree_bare": [Vector3(0.0, 0.0, 0.22)],
	"tree_cypress": [Vector3(0.05, 0.05, 0.72)],
	# root ball, trunk, crown
	"tree_fallen": [Rect2(-0.6, -1.1, 0.65, 1.9), Rect2(0.2, -0.2, 1.3, 0.45), Rect2(1.4, -1.15, 2.8, 2.6),
			Rect2(4.2, -0.45, 1.55, 1.6)],
	"tree_pine": [Vector3(0.0, 0.0, 0.25)],
	"tree_pine_small": [Vector3(0.0, 0.0, 0.25)],
	"van_snow": [Rect2(-1.15, -2.25, 2.1, 4.5)],
}
## Gap between the player and a shape that counts as touching (so a push-out leaves him just clear).
const TOUCH := 0.002


## One thing that stops the player: a box (any yaw) or a disc, on the ground plane.
class Body:
	extends RefCounted
	var c := Vector2.ZERO  # centre
	var half := Vector2.ZERO  # box half size along ax / az (ZERO for a disc)
	var r := 0.0  # disc radius
	var ax := Vector2.RIGHT  # world direction of the box's local +X
	var az := Vector2.DOWN  # ... local +Z
	var box := Rect2()  # world bounds
	var model := ""

	## Distance from p to the shape (0 inside).
	func dist(p: Vector2) -> float:
		var d := p - c
		if half == Vector2.ZERO:
			return maxf(d.length() - r, 0.0)
		var qx := absf(d.dot(ax)) - half.x
		var qz := absf(d.dot(az)) - half.y
		return Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()

	func near(p: Vector2, pad: float) -> bool:
		return p.x > box.position.x - pad and p.x < box.end.x + pad and p.y > box.position.y - pad and p.y < box.end.y + pad

	## How far to move a circle of radius pad at p to clear the shape (ZERO when clear).
	func push(p: Vector2, pad: float) -> Vector2:
		if not near(p, pad):
			return Vector2.ZERO
		var d := p - c
		if half == Vector2.ZERO:
			var l := d.length()
			if l >= r + pad:
				return Vector2.ZERO
			return (d / l if l > 0.000001 else Vector2.UP) * (r + pad + FenerMap.TOUCH - l)
		var lx := d.dot(ax)
		var lz := d.dot(az)
		var ox := lx - clampf(lx, -half.x, half.x)
		var oz := lz - clampf(lz, -half.y, half.y)
		var l := sqrt(ox * ox + oz * oz)
		if l >= pad:
			return Vector2.ZERO
		if l > 0.000001:
			var k := (pad + FenerMap.TOUCH - l) / l
			return ax * (ox * k) + az * (oz * k)
		# the centre is inside: out through the nearest face
		var px := half.x - absf(lx)
		var pz := half.y - absf(lz)
		if px < pz:
			return ax * (signf(lx) * (px + pad + FenerMap.TOUCH)) if lx != 0.0 else ax * (px + pad + FenerMap.TOUCH)
		return az * (signf(lz) * (pz + pad + FenerMap.TOUCH)) if lz != 0.0 else az * (pz + pad + FenerMap.TOUCH)


static var _solids: Array[Rect2] = []
static var _heights: Array[float] = []
static var _models: Array[String] = []
static var _bodies: Array[Body] = []


## World rect of a local rect at a 90-degree-snapped yaw (deg) and position.
static func turn_rect(r: Rect2, yaw_deg: float, at: Vector2) -> Rect2:
	var q := posmod(roundi(yaw_deg / 90.0), 4)
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var o: Rect2
	match q:
		0: o = Rect2(x0, z0, x1 - x0, z1 - z0)
		1: o = Rect2(z0, -x1, z1 - z0, x1 - x0)  # +90: local +X turns toward -Z
		2: o = Rect2(-x1, -z1, x1 - x0, z1 - z0)
		_: o = Rect2(-z1, x0, z1 - z0, x1 - x0)
	o.position += at
	return o


static func _build() -> void:
	if not _solids.is_empty():
		return
	for e in PLACES:
		var model: String = e[0]
		if e[4] == "deco" or not FOOT.has(model):
			continue
		var f: Array = FOOT[model]
		_solids.append(turn_rect(f[0], e[3], Vector2(e[1], e[2])))
		_heights.append(f[1])
		_models.append(model)
	for e in PLACES:
		if e[4] != "deco":
			_bodies.append_array(make_bodies(e[0], Vector2(e[1], e[2]), e[3]))


## Every fixed solid (buildings, vehicles, trees...) as world rects; heights() matches by index.
static func solids() -> Array[Rect2]:
	_build()
	return _solids


static func heights() -> Array[float]:
	_build()
	return _heights


static func models() -> Array[String]:
	_build()
	return _models


## Everything that stops the player, from WALK at every place (exact yaw). The aftershock rubble is added by
## the game (event_bodies).
static func bodies() -> Array[Body]:
	_build()
	return _bodies


## The WALK shapes of `model` placed at `at`, yaw (deg, as the model node's rotation_degrees.y).
static func make_bodies(model: String, at: Vector2, yaw_deg: float) -> Array[Body]:
	var out: Array[Body] = []
	if not WALK.has(model):
		return out
	var a := deg_to_rad(yaw_deg)
	for s in WALK[model]:
		var lc := Vector2.ZERO  # local centre
		var half := Vector2.ZERO
		var rad := 0.0
		var turn := 0.0
		if s is Rect2:
			lc = s.get_center()
			half = s.size * 0.5
		elif s is Vector3:
			lc = Vector2(s.x, s.y)
			rad = s.z
		else:
			lc = s[0]
			half = s[1]
			turn = deg_to_rad(s[2])
		var b := Body.new()
		b.model = model
		var pa := Vector2(cos(a), -sin(a))  # the model's +X / +Z in the world
		var pz := Vector2(sin(a), cos(a))
		b.c = at + pa * lc.x + pz * lc.y
		b.half = half
		b.r = rad
		var t := a + turn
		b.ax = Vector2(cos(t), -sin(t))
		b.az = Vector2(sin(t), cos(t))
		var ext := Vector2(rad, rad) if half == Vector2.ZERO else Vector2(absf(b.ax.x) * half.x + absf(b.az.x) * half.y,
				absf(b.ax.y) * half.x + absf(b.az.y) * half.y)
		b.box = Rect2(b.c - ext, ext * 2.0)
		out.append(b)
	return out


## The bodies an aftershock change adds (FenerMap.EVENTS[i]): its rubble model where it lies.
static func event_bodies(i: int) -> Array[Body]:
	var ev: Array = EVENTS[i]
	if ev[2] == null:
		return []
	return make_bodies(ev[4], ev[5], ev[6])


static func region_of(p: Vector2) -> String:
	for r in REGIONS:
		if (r[1] as Rect2).has_point(p):
			return r[0]
	return REGION_AVENUE


## Ground height: the roads lie a kerb below everything else.
static func ground_y(p: Vector2) -> float:
	for s in SURFACES:
		if s[0] == "road" and (s[1] as Rect2).has_point(p):
			return 0.0
	return SIDEWALK_H


## Surface kind under p: road, walk, lane or snow (the last listed rect wins).
static func surface_at(p: Vector2) -> String:
	var k := "snow"
	for s in SURFACES:
		if (s[1] as Rect2).has_point(p):
			k = s[0]
	return k


static func in_rect(p: Vector2, r: Rect2, pad := 0.0) -> bool:
	return p.x > r.position.x - pad and p.x < r.end.x + pad and p.y > r.position.y - pad and p.y < r.end.y + pad


## Distance from p to rect r (0 inside).
static func rect_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dz * dz)
