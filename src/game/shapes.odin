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

CollisionEvent :: struct {
	position: Vec2,
	normal:   Vec2,
}

/////////////////
/// Collision
/////////////////

shape_check_collision :: proc(shape_a: Shape, shape_b: Shape) -> bool {
	switch a in shape_a {
	case Circle:
		switch b in shape_b {
		case Circle:
			return shape_are_circles_colliding(a, b)
		case Rectangle:
			return shape_is_circle_colliding_rectangle(a, b)
		case Line:
			_, is_colliding := shape_is_circle_colliding_line(a, b)
			return is_colliding
		}
	case Rectangle:
		switch b in shape_b {
		case Circle:
			return shape_is_circle_colliding_rectangle(b, a)
		case Rectangle:
			return shape_are_rects_colliding_aabb(a, b)
		case Line:
			return shape_is_line_colliding_rect(b, a)
		}
	case Line:
		switch b in shape_b {
		case Circle:
			_, is_colliding := shape_is_circle_colliding_line(b, a)
			return is_colliding
		case Rectangle:
			return shape_is_line_colliding_rect(a, b)
		case Line:
			return shape_are_lines_colliding(a, b)
		}
	}
	return false
}


// Check collision between two rectangles using AABB, assumes there is no rotation
shape_are_rects_colliding_aabb :: proc(rec_a, rec_b: Rectangle) -> bool {
	rect_a_min, rect_a_extends := shape_get_rect_extends(rec_a)
	rect_b_min, rect_b_extends := shape_get_rect_extends(rec_b)

	overlap_horizontal := (rect_a_min.x < rect_b_extends.x) && (rect_a_extends.x > rect_b_min.x)
	overlap_vertical := (rect_a_min.y < rect_b_extends.y) && (rect_a_extends.y > rect_b_min.y)

	return overlap_horizontal && overlap_vertical
}

// returns true if the two circles intersect
shape_are_circles_colliding :: proc(circle_a, circle_b: Circle) -> bool {
	delta := circle_a.pos - circle_b.pos
	distance := math.vector_length(delta)
	if (distance <= (circle_a.radius + circle_b.radius)) {return true}
	return false
}

// returns true if circle intersects the rectangle
shape_is_circle_colliding_rectangle :: proc(circle: Circle, rect: Rectangle) -> bool {
	_, _, is_inside := shape_is_point_inside_rect(circle.pos, rect)
	if (is_inside) {return true}
	lines := shape_get_rect_lines_t(rect)

	for line in lines {
		_, is_colliding := shape_is_circle_colliding_line(circle, line)
		if (is_colliding) {return true}
	}
	return false
}

shape_is_point_inside_rect :: proc(
	point: math.Vector2f32,
	rect: Rectangle,
) -> (
	point_event: CollisionEvent,
	line_event: CollisionEvent,
	did_collide: bool,
) {
	closest_line := shape_get_closest_line(point, rect)
	line_point := shape_point_projected_to_line(point, closest_line)
	line_normal := shape_line_normal(closest_line)
	dir := math.normalize(point - line_point)

	if (dir == line_normal) {
		return
	}

	line_event = CollisionEvent{line_point, line_normal}
	point_event = CollisionEvent{point, -line_normal}

	return line_event, point_event, true
}


// returns true if a line intersects a circle
shape_is_circle_colliding_line :: proc(circle: Circle, line: Line) -> (CollisionEvent, bool) {
	closest_point := shape_point_projected_to_line(circle.pos, line)
	is_point_inside_circle := shape_is_point_inside_circle(closest_point, circle)

	if (is_point_inside_circle) {
		return CollisionEvent{closest_point, shape_line_normal(line)}, true
	}

	return CollisionEvent{}, false
}

// returns true if a point is inside a circle
shape_is_point_inside_circle :: proc(point: math.Vector2f32, circle: Circle) -> bool {
	np_length := math.length(circle.pos - point)
	return np_length < circle.radius
}

// returns true if two lines intersect
shape_are_lines_colliding :: proc(a, b: Line) -> bool {
	_, colliding := shape_get_line_intersection(a, b)
	return colliding
}

// Returns trues if a line intersects a rect
shape_is_line_colliding_rect :: proc(line: Line, rect: Rectangle) -> bool {
	lines := shape_get_rect_lines_t(rect)
	for l in lines {
		if (shape_are_lines_colliding(line, l)) {return true}
	}
	return false
}

/////////////////////////////////
// Helpers
/////////////////////////////////

shape_get_closest_line :: proc(point: Vec2, rectangle: Rectangle) -> (closest_line: Line) {
	rect_lines := shape_get_rect_lines_t(rectangle)
	chosen_line_distance := max(f32)
	for rect_line in rect_lines {
		projected_point := shape_point_projected_to_line(point, rect_line)
		length := math.length2(projected_point - point)
		if (length < chosen_line_distance) {
			chosen_line_distance = length
			closest_line = rect_line
		}
	}

	return
}

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

// Returns the intersection point, second argument is if there is an interaction or not
shape_get_line_intersection :: proc(a: Line, b: Line) -> (Vec2, bool) {
	an := a.end - a.start
	bn := b.end - b.start

	an_bn_normalized := (-bn.x * an.y + an.x * bn.y)
	s_cross := -an.y * (a.start.x - b.start.x) + an.x * (a.start.y - b.start.y)
	t_cross := bn.x * (a.start.y - b.start.y) - bn.y * (a.start.x - b.start.x)
	s := (s_cross) / an_bn_normalized
	t := (t_cross) / an_bn_normalized

	if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
		x := a.start.x + (t * an.x)
		y := a.start.y + (t * an.y)
		return Vec2{x, y}, true

	}

	return Vec2{}, false
}

// Rotates the Vector 90 counter clockwise, normalized
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

shape_point_projected_to_line :: #force_inline proc(point: Vec2, line: Line) -> Vec2 {
	se := line.end - line.start
	se_len := math.length(se)
	pd := point - line.start

	se_n := se / se_len
	pd_n := pd / se_len

	dot := math.clamp(math.dot(se_n, pd_n), 0.0, 1.0)
	return se_n * (dot * se_len) + line.start
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
