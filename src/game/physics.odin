package game

import math "core:math/linalg"


// Check collision between two rectangles
are_recs_colliding :: proc(rec1, rec2: Rectangle) -> bool {
	overlap_horizontal :=
		rec1.pos.x < (rec2.pos.x + rec2.size.x) && (rec1.pos.x + rec1.size.x) > rec2.pos.x
	overlap_vertical :=
		rec1.pos.y < (rec2.pos.y + rec2.size.y) && (rec1.pos.y + rec1.size.y) > rec2.pos.y
	if (overlap_horizontal && overlap_vertical) {return true}

	return false
}


are_circles_colliding :: proc(circle_a, circle_b: Circle) -> bool {
	delta := circle_a.pos - circle_b.pos
	distance := math.vector_length(delta)
	if (distance <= (circle_a.radius + circle_b.radius)) {return true}
	return false
}


is_circle_colliding_rectangle :: proc(circle: Circle, rectangle: Rectangle) -> bool {
	rec_center := rectangle.pos + rectangle.size / 2.0
	delta := circle.pos - rec_center
	delta.x = math.abs(delta.x)
	delta.y = math.abs(delta.y)

	if (delta.x > (rectangle.size.x / 2.0 + circle.radius)) {return false}
	if (delta.y > (rectangle.size.y / 2.0 + circle.radius)) {return false}

	corner_distance_sq :=
		(delta.x - rectangle.size.x / 2.0) * (delta.x - rectangle.size.x / 2.0) +
		(delta.y - rectangle.size.y / 2.0) * (delta.y - rectangle.size.y / 2.0)


	return corner_distance_sq <= (circle.radius * circle.radius)
}
