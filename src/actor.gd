class_name Actor
extends Node2D
## Anything that moves through the tile world. Origin is at the feet.

var vel := Vector2.ZERO
var w := 18.0
var h := 52.0
var ground := false
var on_one_way := false
var wall := 0
var facing := 1
var hp := 3.0
var max_hp := 3.0
var dead := false


func hurtbox() -> Rect2:
	return Rect2(position.x - w / 2, position.y - h, w, h)
