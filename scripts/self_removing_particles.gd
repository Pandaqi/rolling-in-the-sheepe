extends Node2D

func _on_Timer_timeout():
	self.queue_free()
