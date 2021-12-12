extends Node

var cfg = {
	"unrealistic_slicing": true,
	"slicing_yields": "triangle",
	
	"unrealistic_glueing": true,
	"unrealistic_rounding": true,
	
	# TO DO: make toggelable in (technical) settings
	"dynamic_tutorials": true,
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
	'quatrefoil': { 'frame': 18, 'basic': 'octagon' }
}

var shape_order = ['triangle', 'square', 'pentagon', 'hexagon', 'heptagon', 'octagon', 'nonagon', 'circle']
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
	"button": { "frame": 5 }
}

# NOTE: All their terrains must end in "_lock", 
# (otherwise they are not filtered out (during terrain picking) nor registered as being a "locking" room)
var lock_types = {
	"coin_lock": { "terrain": "lock" },
	"coin_lock_gate": { "coin": true, "terrain": "coin_gate_lock" },
	"mass_gate": { "terrain": "mass_gate_lock", "edge_type": "mass" },
	"sacrifice_gate": { "terrain": "sacrifice_lock", "edge_type": "regular" },
	"sacrifice_coin_gate": { "coin": true, "terrain": "sacrifice_coin_lock", "edge_type": "regular" },
	"button_lock": { "terrain": "button_lock", "edge_type": "button" }
}

var item_types = {
	"spikes": { "frame": 0, "immediate": true, "delete": true, "invincible": true },
	"button_regular": { "frame": 1, "immediate": true, "delete": true, "unpickable": true },
	"button_timed": { "frame": 2, "immediate": true, "unpickable": true },
	"button_order": { "frame": 3, "immediate": true, "unpickable": true, "needs_label": true },
	"button_simultaneous": { "frame": 4, "immediate": true, "unpickable": true }
}

var terrain_types = {
	"finish": { "frame": 0, 'unpickable': true, 'category': 'essential' },
	"lock": { "frame": 1, 'unpickable': true, 'category': 'lock', 'overwrite': true, 'disable_consecutive': true },
	"teleporter": { "frame": 2, 'unpickable': true, 'category': 'essential', 'overwrite': true, 'disable_consecutive': true },
	
	"reverse_gravity": { "frame": 3, 'category': 'gravity', 'disable_consecutive': true, 'tut': 5 },
	"no_gravity": { "frame": 4, 'category': 'gravity', 'tut': 6 },
	"ice": { "frame": 5, 'category': 'physics', 'tut': 7 },
	"bouncy": { "frame": 6, 'category': 'physics', 'tut': 13 },
	"spiderman": { "frame": 7, 'category': 'physics', 'tut': 14 },
	"speed_boost": { "frame": 8, 'category': 'speed', 'tut': 15 },
	"speed_slowdown": { "frame": 9, 'category': 'speed', 'tut': 21 },
	"glue": { "frame": 10, 'category': 'slicing', 'tut': 22 },
	"reverse_controls": { "frame": 11, 'category': 'misc', 'tut': 23 },
	
	"spikes": { "frame": 12, 'category': 'slicing', 'tut': 25 },
	"ghost": { "frame": 13, 'category': 'misc', 'tut': 26 },
	"grower": { "frame": 14, "category": "slicing", 'tut': 27 },
	"no_wolf": { "frame": 15, "category": "misc", 'tut': 28 },
	"body_limit": { "frame": 16, "category": "slicing", 'tut': 29 },
	
	"invincibility": { "frame": 17, "category": "coin", 'tut': 30 },
	"rounder": { "frame": 18, "category": "coin", 'tut': 31 },
	"halver": { "frame": 19, "category": "coin", 'tut': 32 },
	"slower": { "frame": 20, "category": "coin", 'tut': 33 },
	"bomb": { "frame": 21, "category": "coin", 'tut': 34 },
	
	"coin_gate_lock": { "frame": 22, "category": "lock" },
	"mass_gate_lock": { "frame": 23, "category": "lock" },
	"button_lock": { "frame": 24, "category": "lock" },
	"sacrifice_lock": { "frame": 25, "category": "lock" },
	"sacrifice_coin_lock": { "frame": 26, "category": "lock" },
	"shop_lock": { "frame": 27, "category": "lock" },
	"painter_lock": { "frame": 28, "category": "lock" },
	"painter_holes_lock": { "frame": 29, "category": "lock" }
}
