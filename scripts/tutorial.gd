extends Node2D

var active : bool = true

var forced_dir : int = 0

func is_active():
	return active

# NOTE: We don't destroy this, as there are many references to it and
# it's much cleaner to NOT have to check "does the tutorial still exist?" each time
func finish():
	active = false

func get_forced_dir():
	return forced_dir

func forced_dir_exhausted():
	forced_dir = (forced_dir + 2) % 4
