extends Node

var cfg = {
	"slicing_yields_circles": true
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
	"reverse_gravity": { "frame": 3, 'category': 'gravity', 'disable_consecutive': true },
	"no_gravity": { "frame": 4, 'category': 'gravity' },
	"ice": { "frame": 5, 'category': 'physics' },
	"bouncy": { "frame": 6, 'category': 'physics' },
	"spiderman": { "frame": 7, 'category': 'physics' },
	"speed_boost": { "frame": 8, 'category': 'speed' },
	"speed_slowdown": { "frame": 9, 'category': 'speed' },
	"glue": { "frame": 10, 'category': 'slicing' },
	"reverse_controls": { "frame": 11, 'category': 'misc' },
	"spikes": { "frame": 12, 'category': 'slicing' },
	"ghost": { "frame": 13, 'category': 'misc' },
	"grower": { "frame": 14, "category": "slicing" },
	"no_wolf": { "frame": 15, "category": "misc" },
	"body_limit": { "frame": 16, "category": "slicing" },
	"invincibility": { "frame": 17, "category": "coin" },
	"rounder": { "frame": 18, "category": "coin" },
	"halver": { "frame": 19, "category": "coin" },
	"slower": { "frame": 20, "category": "coin" },
	"bomb": { "frame": 21, "category": "coin" },
	"coin_gate_lock": { "frame": 22, "category": "lock" },
	"mass_gate_lock": { "frame": 23, "category": "lock" },
	"button_lock": { "frame": 24, "category": "lock" },
	"sacrifice_lock": { "frame": 25, "category": "lock" },
	"sacrifice_coin_lock": { "frame": 26, "category": "lock" },
	"shop_lock": { "frame": 27, "category": "lock" },
	"painter_lock": { "frame": 28, "category": "lock" },
	"painter_holes_lock": { "frame": 29, "category": "lock" }
}
