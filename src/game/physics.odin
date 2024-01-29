package game

import fmt "core:fmt"
import math "core:math/linalg"


/////////////////
/// Collision
/////////////////

// Check collision between two rectangles
// FIX: Does AABB and not OBB
shape_are_rects_colliding :: proc(rec_a, rec_b: Rectangle) -> bool {
	rect_a_min, rect_a_extends := shape_get_rect_extends(rec_a)
	rect_b_min, rect_b_extends := shape_get_rect_extends(rec_b)

	overlap_horizontal := (rect_a_min.x < rect_b_extends.x) && (rect_a_extends.x > rect_b_min.x)
	overlap_vertical := (rect_a_min.y < rect_b_extends.y) && (rect_a_extends.y > rect_b_min.y)

	return overlap_horizontal && overlap_vertical
}

// Check collision between two circles
shape_are_circles_colliding :: proc(circle_a, circle_b: Circle) -> bool {
	delta := circle_a.pos - circle_b.pos
	distance := math.vector_length(delta)
	if (distance <= (circle_a.radius + circle_b.radius)) {return true}
	return false
}


// Checks collision between a circle and a rectangle
// FIX: This is not consistent
shape_is_circle_colliding_rectangle :: proc(circle: Circle, rectangle: Rectangle) -> bool {
	return shape_is_circle_colliding_rectangle_v2(circle, rectangle)
	// Move the Circle to the origin
	//delta := math.abs(circle.pos - rectangle.pos)

	//half_rect_size := rectangle.size * 0.5

	//if (delta.x > (half_rect_size.x + circle.radius)) {return false}
	//if (delta.y > (half_rect_size.y + circle.radius)) {return false}

	//corner_distance_sq :=
	//	(delta.x - half_rect_size.x) * (delta.x - half_rect_size.x) +
	//	(delta.y - half_rect_size.y) * (delta.y - half_rect_size.y)


	//return corner_distance_sq <= (circle.radius * circle.radius)
}

shape_is_circle_colliding_rectangle_v2 :: proc(
	circle: Circle,
	rect: Rectangle,
) -> (
	is_colliding: bool,
) {
	if (shape_is_point_inside_rect(circle.pos, rect)) {return true}
	// Return true if circle is colliding with any of the rectangle's edges
	return is_colliding
}

shape_is_point_inside_rect :: proc(point: math.Vector2f32, rect: Rectangle) -> bool {
	rect_min, rect_max := shape_get_rect_extends(rect)
	if (point.x < rect_min.x || point.x > rect_max.x) {return false}
	if (point.y < rect_min.y || point.y > rect_max.y) {return false}
	return true
}

// Get the min and max vectors of a rectangles
shape_get_rect_extends :: proc(rect: Rectangle) -> (math.Vector2f32, math.Vector2f32) {
	rect_min := rect.pos - (rect.size * 0.5)
	rect_max := rect.pos + (rect.size * 0.5)
	return rect_min, rect_max
}
