package game

import fmt "core:fmt"
import math "core:math/linalg"
import "core:testing"

Rectangle :: struct {
	pos:      Vec2,
	size:     Vec2,
	rotation: f32,
}

Circle :: struct {
	pos:    Vec2,
	radius: f32,
}

Line :: struct {
	start:     Vec2,
	end:       Vec2,
	thickness: f32,
}

Shape :: union {
	Rectangle,
	Circle,
	Line,
}


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

shape_is_point_inside_circle :: proc(point: math.Vector2f32, circle: Circle) -> bool {
	np_length := math.length(circle.pos - point)
	return np_length < circle.radius
}


/////////////////////////////////
// Helpers
/////////////////////////////////

// Get the min and max vectors of a rectangles
shape_get_rect_extends :: proc(rect: Rectangle) -> (math.Vector2f32, math.Vector2f32) {
	rect_min := rect.pos - (rect.size * 0.5)
	rect_max := rect.pos + (rect.size * 0.5)
	return rect_min, rect_max
}

// Get the vertices around a rectangle, clockwise
shape_get_rect_vertices_t :: proc(rect: Rectangle) -> []Vec2 {
	rect_min, rect_max := shape_get_rect_extends(rect)
	vertices := make([]Vec2, 4, context.temp_allocator)
	vertices[0] = rect_min
	vertices[1] = Vec2{rect_max.x, rect_min.y}
	vertices[2] = rect_max
	vertices[3] = Vec2{rect_min.x, rect_max.y}

	return vertices
}

// Returns the lines of a rectangle at zero width, using the temp_allocator
shape_get_rect_lines_t :: proc(rect: Rectangle) -> []Line {
	rect_min, rect_max := shape_get_rect_extends(rect)
	lines := make([]Line, 4, context.temp_allocator)
	lines[0] = Line{rect_min, Vec2{rect_max.x, rect_min.y}, 0.0}
	lines[1] = Line{Vec2{rect_max.x, rect_min.y}, rect_max, 0.0}
	lines[2] = Line{rect_max, Vec2{rect_min.x, rect_max.y}, 0.0}
	lines[3] = Line{Vec2{rect_min.x, rect_max.y}, rect_min, 0.0}
	return lines
}

// Rotates the Vector 90 counter clockwise
shape_get_vector_normal :: proc(vec: Vec2) -> Vec2 {
	v := math.normalize(vec)
	l := math.length(vec)
	return Vec2{-v.y, v.x}
}

shape_line_mid_point :: proc(line: Line) -> Vec2 {
	line_at_origin := line.end - line.start
	normalized_direction := math.length(line_at_origin)

	normalized_mid_point := math.normalize(line_at_origin) * (normalized_direction * 0.5)
	return normalized_mid_point + line.start
}

shape_line_normal :: proc(line: Line) -> Vec2 {
	return shape_get_vector_normal(line.start - line.end)
}

/////////////////////////////
// Tests
/////////////////////////////

@(test)
test_shape_get_vector_normal :: proc(t: ^testing.T) {
	v := Vec2{3, 4}
	n := shape_get_vector_normal(v)
	testing.expect(t, math.normalize(Vec2{-4, 3}) == n, "Normal of Vector")
}

@(test)
test_shape_point_in_circle :: proc(t: ^testing.T) {
	circle_center := Vec2{300, 400}
	circle_radius: f32 = 50
	circle := Circle{circle_center, circle_radius}

	testing.expect(
		t,
		!shape_is_point_inside_circle(Vec2{200, 305}, circle),
		"Point should be outside of circle",
	)
	testing.expect(
		t,
		shape_is_point_inside_circle(Vec2{260, 385}, circle),
		"Point should be inside of circle",
	)

}

@(test)
test_shape_rect_vertices_t_unrotated :: proc(t: ^testing.T) {
	// Return Vertices of the Rectangle in a counter clockwise pattern
	rect := Rectangle{Vec2{0, 0}, Vec2{1, 1}, 0.0}

	vertices := shape_get_rect_vertices_t(rect)
	testing.expect(t, vertices[0] == Vec2{-0.5, -0.5}, "Top left most vertex")
	testing.expect(t, vertices[1] == Vec2{0.5, -0.5}, "Top right most vertex")
	testing.expect(t, vertices[2] == Vec2{0.5, 0.5}, "Bottom right most vertex")
	testing.expect(t, vertices[3] == Vec2{-0.5, 0.5}, "bottom left most vertex")

}

@(test)
test_shape_rect_lines_t_unrotated :: proc(t: ^testing.T) {
	// Return Lines of the Rectangle in a counter clockwise pattern
	rect := Rectangle{Vec2{0, 0}, Vec2{1, 1}, 0.0}

	lines := shape_get_rect_lines_t(rect)

	testing.expect(
		t,
		lines[0] == Line{Vec2{-0.5, -0.5}, Vec2{0.5, -0.5}, 0.0},
		"First line is the top line",
	)
	testing.expect(
		t,
		lines[1] == Line{Vec2{0.5, -0.5}, Vec2{0.5, 0.5}, 0.0},
		"Second line is the right line",
	)
	testing.expect(
		t,
		lines[2] == Line{Vec2{0.5, 0.5}, Vec2{-0.5, 0.5}, 0.0},
		"Third line is the bottom line",
	)
	testing.expect(
		t,
		lines[3] == Line{Vec2{-0.5, 0.5}, Vec2{-0.5, -0.5}, 0.0},
		"Forth line is the bottom line",
	)

}

@(test)
test_shape_rect_extends_unrotated :: proc(t: ^testing.T) {
	rect := Rectangle{Vec2{0, 0}, Vec2{1, 1}, 0.0}
	min, max := shape_get_rect_extends(rect)

	testing.expect(
		t,
		min == Vec2{-0.5, -0.5},
		"origin is at zero so minimum extends is half width, left of origin",
	)
	testing.expect(
		t,
		max == Vec2{0.5, 0.5},
		"origin is at zero so maximum extends is half width, right of origin",
	)
}
