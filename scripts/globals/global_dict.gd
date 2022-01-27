extends Node

var cfg = {
	"performance_mode": false,
	"unrealistic_slicing": true,
	"max_bodies_per_player": 3,
	"num_starting_coins": 1,
	"num_starting_bodies": 1,
	
	"always_jump_straight_up": true,
	
	"draw_outlines": true,
	
	"route_generation_sneak_improvement": true,
	"min_locks_before_finish": 2,
	
	"transfer_coins_to_biggest_shape_on_self_hit": false,
	"destroyed_body_penalty_in_solo_mode": true,
	
	"allow_preemptive_teleporter_placement": false,
	"dont_teleport_if_no_players": false, # restarts timer if it's 0 but no players actually inside teleporter
	"teleport_if_everyone_inside": false, # although a fine idea, it's a bit sudden, and means the tutorial doesn't show everything FOR CERTAIN ... which is bad
	
	"fog_enabled": false,
	
	# debugging dynamic tutorial stuff
	"debug_forced_locks": [],
	"debug_forced_terrains": [],
	"debug_forced_items": [],
	
	# debugging stuff
	"debug_quick_finish": false,
	"debug_quick_dynamic_tutorial": false,
	"debug_rooms": false,
	"debug_players": false,
	
	# makes it all a bit smoother ... but opens up new avenues and ruins the generation
	"remove_three_way_tiles": false,
	
	# either slicing yields the exact same shape each time (first option)
	# or it just goes back one step
	"slicing_yields": "triangle",
	"slicing_goes_back_one_shape": true,
	
	"unrealistic_glueing": true,
	"unrealistic_rounding": true,

	'wall_jump_strength': 0.266, # set to 0.0 for no wall jump, 1.0 for full effect
	
	'time_penalty_unfinished_bodies': 10.0, # set to 0.0 to eliminate this rule
	
	'cant_slice_triangles': true,
	
	'wolf_takes_coin': true,
	
	'delay_finish_until_all_taught': true,
	'min_rooms_between_last_tut_and_finish': 10,
	
	# no rounding/malforming takes place on every cycle
	# only if you've been on the ground _a lot_ or in the air _a lot_
	'only_round_if_airtime_at_extremes': true,
	
	'dont_place_tiles_inside_rooms_with_tut': true,
	
	'temp_remove_wolf_on_teleport': true,
	
	'reset_players_to_start_shape_at_finish': true,
	'grow_teleporters_to_bigger_size': false, # probably best to leave off forever :p
	
	'generation_speed': 2.0, # higher is faster; inverted (1/X) on game start
	"show_dynamic_tutorials": true,
	"paint_on_tilemap": true,
	"hide_heavy_particles": false, # TO DO: make actually functional
}

# Links shape to spritesheet, but can ALSO contain unique info about the shape in the future (such as shapes that need to be lighter/heavier or cling more strongly)
var shape_list = {
	'circle': { 'frame': 0, 'basic': 'circle' },
	'square': { 'frame': 1, 'basic': 'square' },
	'triangle': { 'frame': 2, 'basic': 'triangle' },
	'pentagon': { 'frame': 3, 'basic': 'pentagon' },
	'hexagon': { 'frame': 4, 'basic': 'hexagon' },
	'parallellogram': { 'frame': 5, 'basic': 'square' },
	'l-shape': { 'frame': 6, 'basic': 'square' },
	'starpenta': { 'frame': 7, 'basic': 'pentagon' },
	'starhexa': { 'frame': 8, 'basic': 'hexagon' },
	'trapezium': { 'frame': 9, 'basic': 'square' },
	'crown': { 'frame': 10, 'basic': 'triangle' },
	'cross': { 'frame': 11, 'basic': 'octagon' },
	'heart': { 'frame': 12, 'basic': 'square' },
	'drop': { 'frame': 13, 'basic': 'square' },
	'arrow': { 'frame': 14, 'basic': 'triangle' },
	'diamond': { 'frame': 15, 'basic': 'pentagon' },
	'crescent': { 'frame': 16, 'basic': 'pentagon' },
	'trefoil': { 'frame': 17, 'basic': 'triangle' },
	'quatrefoil': { 'frame': 18, 'basic': 'pentagon' }
}

var possible_starting_shapes = ['pentagon', 'starpenta', 'cross', 'heart', 'diamond', 'trefoil']
var shape_order = ['triangle', 'square', 'pentagon', 'hexagon', 'heptagon', 'circle']
var points_per_shape = {
	'triangle': 3,
	'square': 4,
	'pentagon': 5,
	'hexagon': 6, 
	'heptagon': 7,
	'octagon': 8,
	'nonagon': 9,
	'circle': 16
}

var edge_types = {
	"regular": { "frame": 0 },
	"coin_gate": { "frame": 1, "gate": true },
	"mass": { "frame": 2 },
	"sacrifice": { "frame": 3, "gate": true },
	"sacrifice_coin": { "frame": 4, "gate": true },
	"button": { "frame": 5 },
	"slot_gate": { "frame": 6, "gate": true },
	"fast_gate": { "frame": 7, "gate": true },
	"painter": { "frame": 8 },
	"finish": { "frame": 9 },
	"teleporter": { "frame": 10 }
}

# NOTE: All their terrains must end in "_lock", 
# (otherwise they are not filtered out (during terrain picking) nor registered as being a "locking" room)
var lock_types = {
	"finish": { "terrain": "finish", "edge_type": "finish", "unpickable": true },
	"teleporter": { "terrain": "teleporter", "edge_type": "teleporter", "unpickable": true },
	
	"coin_lock": { "terrain": "lock", "tut": 35, "prob": 3, "demo": true },
	"coin_lock_gate": { "coin_related": true, "terrain": "coin_gate_lock", "tut": 36, "edge_type": "coin_gate" },
	
	"mass_gate": { "terrain": "mass_gate_lock", "edge_type": "mass", "tut": 37, "solo_unpickable": true },
	
	"sacrifice_gate": { "terrain": "sacrifice_lock", "edge_type": "sacrifice", "tut": 39 },
	"sacrifice_coin_gate": { "coin_related": true, "terrain": "sacrifice_coin_lock", "edge_type": "sacrifice_coin", "tut": 40 },
	
	"button_lock_regular": { "terrain": "button_lock", "edge_type": "button", "lock_group": "button_lock", "sub_type": "regular", "tut": 41, "prob": 3, "no_holes": true, "demo": true },
	"button_lock_timed": { "terrain": "button_lock", "edge_type": "button", "lock_group": "button_lock", "sub_type": "timed", "tut": 42 , "prob": 2, "no_holes": true },
	"button_lock_order": { "terrain": "button_lock", "edge_type": "button", "lock_group": "button_lock", "sub_type": "order", "tut": 43 , "prob": 2, "no_holes": true },
	"button_lock_simultaneous": { "terrain": "button_lock", "edge_type": "button", "lock_group": "button_lock", "sub_type": "simultaneous", "tut": 44, "prob": 2, "no_holes": true, "solo_unpickable": true },
	
	"slot_gate": { "terrain": "slot_gate_lock", "edge_type": "slot_gate", "tut": 47 },
	"fast_gate": { "terrain": "fast_gate_lock", "edge_type": "fast_gate", "tut": 48 },
	"float_lock": { "terrain": "float_lock", "edge_type": "regular", "tut": 49, "prob": 2, "solo_prob": 0.8 },
	
	"painter_lock": { "terrain": "painter_lock", "edge_type": "painter", "lock_group": "painter_lock", "sub_type": "regular", "tut": 50, "prob": 3, "no_holes": true, "demo": true },
	"painter_holes_lock": { "terrain": "painter_holes_lock", "edge_type": "painter", "lock_group": "painter_lock", "sub_type": "holes", "tut": 52, "no_holes": true },
	"painter_erase_lock": { "terrain": "painter_erase_lock", "edge_type": "painter", "lock_group": "painter_lock", "sub_type": "erase", "tut": 51, "prob": 3, "no_holes": true },
	
	# "shop_lock": { "terrain": "shop_lock", "edge_type": "regular", "coin_related": true }
}

# NOTE: items can be immediate, toggle, or _none of both_ (don't work on player interaction)
var item_types = {
	"spikes": { "frame": 0, "immediate": true, "delete": true, "invincible": true, "tut": 45, "prob": 3, "solo_prob": 6, "demo": true },
	"button_regular": { "frame": 1, "immediate": true, "delete": true, "unpickable": true, "item_group": "buttons" },
	"button_timed": { "frame": 2, "immediate": true, "unpickable": true, "module": true, "item_group": "buttons" },
	"button_order": { "frame": 3, "immediate": true, "unpickable": true, "needs_label": true, "item_group": "buttons" },
	"button_simultaneous": { "frame": 4, "immediate": true, "unpickable": true, "item_group": "buttons" },
	
	"trampoline": { "frame": 5, "immediate": true, "prob": 3, "tut": 58, "demo": true },
	"speedup": { "frame": 6, "toggle": true, "prob": 2, "tut": 59 },
	"slowdown": { "frame": 7, "toggle": true, "prob": 2, "tut": 60 },
	"ghost": { "frame": 8, "toggle": true, "tut": 61, "beam": true, "mod_beam": Color(136/255.0, 48/255.0, 29/255.0, 0.25), "module": true, "max": 1 },
	"shield": { "frame": 9, "toggle": true, "tut": 62, "beam": true, "unit_beam": true, "mod_beam": Color(1.0, 189/255.0, 0, 0.25) },
	"rounder": { "frame": 10, "toggle": true, "tut": 63, "beam": true, "unit_beam": true, "mod_beam": Color(135/255.0, 188/255.0, 76/255.0, 0.25), "max": 1 },
	"sharper": { "frame": 11, "toggle": true, "tut": 64, "beam": true, "unit_beam": true, "mod_beam": Color(135/255.0, 188/255.0, 76/255.0, 0.25), "max": 1 },
	
	"breakable": { "frame": 12, "immediate": true, "delete": true, "tut": 65 },
	"reset_shape": { "frame": 13, "immediate": true, "tut": 66 },
	"change_shape": { "frame": 14, "immediate": true, "module": true, "tut": 67, "demo": true },
	
	"cannon": { "frame": 15, "module": true, "prob": 3, "tut": 68, "solo_prob": 6, "max": 1 },
	"laser": { "frame": 16, "module": true, "prob": 3, "tut": 69, "solo_prob": 6, "beam": true, "mod_beam": Color(1.0, 22/255.0, 0.0, 0.25), "max": 1 },
	
	"ice": { "frame": 17, "toggle": true, "tut": 70 },
	"spiderman": { "frame": 18, "toggle": true, "tut": 71, "radius": true, "max": 2 },
	"glue": { "frame": 19, "toggle": true, "prob": 2, "tut": 72, "glue_related": true },
	"coin": { "frame": 20, "immediate": true, "prob": 0.25, "delete": true, "tut": 73, "coin_related": true, "demo": true },
	
	"freeze": { "frame": 21, "immediate": true, "delete": true, "tut": 74, "solo_prob": 0.25, "max_usage": 10 },
	"time_bonus": { "frame": 22, "immediate": true, "delete": true, "prob": 2, "tut": 75, "solo_unpickable": true, "demo": true },
	"time_penalty": { "frame": 23, "immediate": true, "delete": true, "prob": 2, "tut": 76, "solo_unpickable": true },
	"fast_forward": { "frame": 24, "immediate": true, "prob": 0.5, "tut": 77, "solo_unpickable": true, "max_usage": 20 },
	"fast_backward": { "frame": 25, "immediate": true, "prob": 0.5, "tut": 78, "solo_unpickable": true, "max_usage": 10 },
	
	"body_buyer": { "frame": 26, "immediate": true, "delete": true, "coin_related": true, "tut": 81 },
	"conditional_freeze": { "frame": 27, "beam": true, "module": true, "max": 1, "mod_beam": Color(160/255.0, 83/255.0, 249/255.0, 0.25), "tut": 82 },
	"all_changer": { "frame": 28, "immediate": true, "delete": true, "max": 1, "tut": 83 },
	
	"body_cleanup_coin": { "frame": 29, "immediate": true, "coin_related": true, "tut": 84, "pay": 2 },
	"repel_coin": { "frame": 30, "immediate": true, "coin_related": true, "solo_unpickable": true, "tut": 85, "pay": 2, "delete": true },
	"time_bonus_coin": { "frame": 31, "immediate": true, "coin_related": true, "solo_unpickable": true, "tut": 86, "pay": 2, "delete": true },
	"shrink_radius_coin": { "frame": 32, "immediate": true, "coin_related": true, "solo_unpickable": true, "tut": 87, "pay": 2, "delete": true },
	"slow_chaser": { "frame": 33, "immediate": true, "delete": true, "coin_related": true, "multi_unpickable": true, "max": 1, "tut": 88, "pay": 2 },
	
	"grow": { "frame": 34, "immediate": true, "tut": 89 },
	"shrink": { "frame": 35, "immediate": true, "prob": 3, "solo_prob": 3.0, "tut": 90 },
	
	"magnet_radius": { "frame": 36, "radius": true, "module": true, "max": 2, "tut": 91 },
	"magnet_beam": { "frame": 37, "beam": true, "module": true, "mod_beam": Color(160/255.0, 83/255.0, 249/255.0, 0.25), "max": 2, "tut": 92 },
	"platform": { "frame": 38, "module": true, "no_area": true, "prob": 4.0, "tut": 93 },
	"platform_moving": { "frame": 39, "module": true, "no_area": true, "max": 2, "prob": 2.0, "tut": 94 },
	"slope": { "frame": 40, "prob": 5.0, "module": true, "no_area": true, "tut": 95 },
	"platform_rotating": { "frame": 41, "module": true, "no_area": true, "max": 2, "tut": 96 }
}

var terrain_types = {
	"finish": { "frame": 0, 'unpickable': true, 'category': 'essential' },
	"lock": { "frame": 1, 'unpickable': true, 'category': 'lock', 'overwrite': true, 'disable_consecutive': true },
	"teleporter": { "frame": 2, 'unpickable': true, 'category': 'essential', 'overwrite': true, 'disable_consecutive': true, "tut": 38 },
	
	"reverse_gravity": { "frame": 3, 'category': 'gravity', 'disable_consecutive': true, 'tut': 5, "prob": 2 },
	"no_gravity": { "frame": 4, 'category': 'gravity', 'tut': 6, "max_usage": 10 },
	"ice": { "frame": 5, 'category': 'physics', 'tut': 7 },
	"bouncy": { "frame": 6, 'category': 'physics', 'tut': 13, "prob": 2, "demo": true },
	"spiderman": { "frame": 7, 'category': 'physics', 'tut': 14, "prob": 2 },
	"speed_boost": { "frame": 8, 'category': 'speed', 'tut': 15 },
	"speed_slowdown": { "frame": 9, 'category': 'speed', 'tut': 21, "disable_consecutive": true, "prob": 0.33 },
	"glue": { "frame": 10, 'category': 'slicing', 'tut': 22, "glue_related": true, "prob": 3, "demo": true },
	"reverse_controls": { "frame": 11, 'category': 'misc', 'tut': 23, "prob": 2, "demo": true, "max_usage": 15 },
	
	"spikes": { "frame": 12, 'category': 'slicing', 'tut': 25, "prob": 2, "solo_unpickable": true },
	"ghost": { "frame": 13, 'category': 'misc', 'tut': 26 },
	"grower": { "frame": 14, "category": "slicing", 'tut': 27 },
	"no_wolf": { "frame": 15, "category": "misc", 'tut': 28, "solo_unpickable": true },
	"body_limit": { "frame": 16, "category": "slicing", 'tut': 29, "solo_unpickable": true, "max_usage": 12 },
	
	"invincibility": { "frame": 17, "category": "coin", "coin_related": true, 'tut': 30 },
	"rounder": { "frame": 18, "category": "coin", "coin_related": true, 'tut': 31, "demo": true, "max_usage": 12 },
	"halver": { "frame": 19, "category": "coin", "coin_related": true, 'tut': 32, "disable_consecutive": true, "max_usage": 12 },
	"slower": { "frame": 20, "category": "coin", "coin_related": true, 'tut': 33, "prob": 0.6 },
	"bomb": { "frame": 21, "category": "coin", "coin_related": true, 'tut': 34, "prob": 0.3, "disable_consecutive": true, "max_usage": 4 },
	
	"coin_gate_lock": { "frame": 22, "category": "lock", "unpickable": true },
	"mass_gate_lock": { "frame": 23, "category": "lock", "unpickable": true },
	"button_lock": { "frame": 24, "category": "lock", "unpickable": true },
	"sacrifice_lock": { "frame": 25, "category": "lock", "unpickable": true },
	"sacrifice_coin_lock": { "frame": 26, "category": "lock", "unpickable": true },
	"shop_lock": { "frame": 27, "category": "lock", "unpickable": true },
	"painter_lock": { "frame": 28, "category": "lock", "unpickable": true },
	"painter_holes_lock": { "frame": 29, "category": "lock", "unpickable": true },
	
	"reverse_rounding": { "frame": 30, "category": "slicing", "tut": 46 },
	
	"slot_gate_lock": { "frame": 31, 'category': 'lock', "unpickable": true },
	"fast_gate_lock": { "frame": 32, 'category': 'lock', "unpickable": true },
	"float_lock": { "frame": 33, 'category': 'lock', "unpickable": true },
	
	"painter_erase_lock": { "frame": 34, 'category': 'lock', "unpickable": true },
	
	# menu terrains are here (35, 36)
	
	"magnet": { "frame": 37, 'category': 'physics', 'tut': 53 },
	"body_cleanup": { 'frame': 38, 'category': 'slicing', 'tut': 54, "max_usage": 15 }
}
