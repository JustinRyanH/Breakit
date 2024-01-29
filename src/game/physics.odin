package game

import math "core:math/linalg"


// Check collision between two rectangles
are_recs_colliding :: proc(rec_a, rec_b: Rectangle) -> bool {
	rect_a_min, rect_a_extends := get_rect_extends(rec_a)
	rect_b_min, rect_b_extends := get_rect_extends(rec_b)

	overlap_horizontal := (rect_a_min.x < rect_b_extends.x) && (rect_a_extends.x > rect_b_min.x)
	overlap_vertical := (rect_a_min.y < rect_b_extends.y) && (rect_a_extends.y > rect_b_min.y)

	return overlap_horizontal && overlap_vertical
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

// Get the min and max vectors of a rectangle
get_rect_extends :: proc(rect: Rectangle) -> (math.Vector2f32, math.Vector2f32) {
	rect_min := rect.pos - (rect.size * 0.5)
	rect_max := rect.pos + (rect.size * 0.5)
	return rect_min, rect_max
}
