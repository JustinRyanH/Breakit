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


ContactEvent :: struct {
	start:  Vec2,
	end:    Vec2,
	normal: Vec2,
	depth:  f32,
}

CollisionEvent :: struct {
	pos:    Vec2,
	normal: Vec2,
}

/////////////////
/// Collision
/////////////////

shape_check_collision :: proc(shape_a: Shape, shape_b: Shape) -> bool {
	switch a in shape_a {
	case Circle:
		switch b in shape_b {
		case Circle:
			_, _, is_colliding := shape_are_circles_colliding(a, b)
		case Rectangle:
			_, is_colliding := shape_is_circle_colliding_rectangle(a, b)
			return is_colliding
		case Line:
			_, is_colliding := shape_is_circle_colliding_line(a, b)
			return is_colliding
		}
	case Rectangle:
		switch b in shape_b {
		case Circle:
			_, is_colliding := shape_is_circle_colliding_rectangle(b, a)
			return is_colliding
		case Rectangle:
			_, is_colliding := shape_are_rects_colliding_obb(a, b)
			return is_colliding
		case Line:
			_, _, is_colliding := shape_is_line_colliding_rect(b, a)
			return is_colliding
		}
	case Line:
		switch b in shape_b {
		case Circle:
			_, is_colliding := shape_is_circle_colliding_line(b, a)
			return is_colliding
		case Rectangle:
			_, _, is_colliding := shape_is_line_colliding_rect(a, b)
			return is_colliding
		case Line:
			_, is_colliding := shape_are_lines_colliding(a, b)
			return is_colliding
		}
	}
	return false
}

// Check collision between rectangles
shape_are_rects_colliding :: proc(
	rect_a, rect_b: Rectangle,
) -> (
	evt_a, evt_b: CollisionEvent,
	is_colliding: bool,
) {
	b_line_closest_to_a := shape_get_closest_line(rect_a.pos, rect_b)
	a_line_closest_to_b := shape_get_closest_line(rect_b.pos, rect_a)
	line_projection_a := shape_point_projected_to_line(rect_a.pos, b_line_closest_to_a)
	line_projection_b := shape_point_projected_to_line(rect_b.pos, a_line_closest_to_b)


	evt_a.pos = line_projection_a
	evt_b.pos = line_projection_b
	is_colliding = true
	return
}


// Check collision between two rectangles using AABB, assumes there is no rotation
shape_are_rects_colliding_aabb :: proc(rec_a, rec_b: Rectangle) -> bool {
	rect_a_min, rect_a_extends := shape_get_rect_extends(rec_a)
	rect_b_min, rect_b_extends := shape_get_rect_extends(rec_b)

	overlap_horizontal := (rect_a_min.x < rect_b_extends.x) && (rect_a_extends.x > rect_b_min.x)
	overlap_vertical := (rect_a_min.y < rect_b_extends.y) && (rect_a_extends.y > rect_b_min.y)

	return overlap_horizontal && overlap_vertical
}

// Check collision between two rectangles using AABB, assumes there is no rotation
shape_are_rects_colliding_obb :: proc(
	rect_a, rect_b: Rectangle,
) -> (
	event: ContactEvent,
	is_colliding: bool,
) {
	seperation_a, axis_a, pen_point_a := shape_rectangle_seperation(rect_a, rect_b)
	if (seperation_a >= 0) {
		return
	}
	seperation_b, axis_b, pen_point_b := shape_rectangle_seperation(rect_b, rect_a)
	if (seperation_b >= 0) {
		return
	}

	if (seperation_a > seperation_b) {
		event.depth = -seperation_a
		event.normal = shape_line_normal(axis_a)
		event.start = pen_point_a
		event.end = pen_point_a + event.normal * event.depth
	} else {
		event.depth = -seperation_b
		event.normal = shape_line_normal(axis_b)
		event.start = pen_point_b
		event.end = pen_point_b + event.normal * event.depth
	}

	return event, true
}

// returns true if the two circles intersect
shape_are_circles_colliding :: proc(
	circle_a, circle_b: Circle,
) -> (
	a_evt, b_evt: CollisionEvent,
	is_colliding: bool,
) {
	delta := circle_b.pos - circle_a.pos
	distance := math.vector_length(delta)
	if (distance <= (circle_a.radius + circle_b.radius)) {
		normal := math.normalize(delta)
		a_evt = CollisionEvent{circle_a.pos + normal * circle_a.radius, normal}
		b_evt = CollisionEvent{circle_b.pos - normal * circle_b.radius, -normal}
		is_colliding = true
		return
	}
	return
}

shape_is_circle_colliding_rectangle :: proc(
	circle: Circle,
	rect: Rectangle,
) -> (
	event: ContactEvent,
	is_colliding: bool,
) {
	closest_line := shape_get_closest_line(circle.pos, rect)
	line_point := shape_point_projected_to_line(circle.pos, closest_line)
	normal := shape_line_normal(closest_line)

	circle_edge_point := circle.pos + -normal * circle.radius
	center_seperation := math.dot(circle.pos - closest_line.start, normal)

	circle_center_outside := center_seperation >= 0
	if (circle_center_outside) {
		v1, v2, at_corner := shape_get_corner_vertices(circle, closest_line)
		if (at_corner) {
			if (math.length(v1) > circle.radius) {return}
			event.normal = math.normalize(v1)
			event.depth = circle.radius - math.length(v1)
			event.start = circle.pos
			event.end = event.start + event.normal * -event.depth
			return event, true
		}
		if (center_seperation > circle.radius) {return}
		// At Edge
		event.normal = -normal
		event.depth = circle.radius - center_seperation
		event.start = circle.pos + (normal * -circle.radius)
		event.end = event.start + (normal * event.depth)

		return event, true

	} else {
		// Inside
		event.normal = shape_line_normal(closest_line)
		event.depth = circle.radius
		event.start = line_point
		event.end = circle.pos + event.normal * -event.depth
		return event, true
	}

	return
}


// Returns the collision event for a point, and the closest line to the point, 
// returns true if line inside the rect, otherwise returns false
shape_is_point_inside_rect :: proc(
	point: math.Vector2f32,
	rect: Rectangle,
) -> (
	point_event: CollisionEvent,
	rect_event: CollisionEvent,
	is_colliding: bool,
) {
	closest_line := shape_get_closest_line(point, rect)
	line_point := shape_point_projected_to_line(point, closest_line)
	line_normal := shape_line_normal(closest_line)

	dir := math.normalize(point - line_point)

	if (dir == line_normal) {
		return
	}

	rect_event = CollisionEvent{line_point, line_normal}
	// The point normal likely should be rotated towards collision point, inversed, and normalized
	point_event = CollisionEvent{point, -line_normal}
	is_colliding = true
	return
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
shape_are_lines_colliding :: proc(a, b: Line) -> (Vec2, bool) {
	return shape_get_line_intersection(a, b)
}

// Returns trues if a line intersects a rect
shape_is_line_colliding_rect :: proc(
	line: Line,
	rect: Rectangle,
) -> (
	line_evt, rect_evt: CollisionEvent,
	is_colliding: bool,
) {
	lines := shape_get_rect_lines(rect)
	for l in lines {
		point, is_colliding := shape_get_line_intersection(line, l)

		is_colliding = true
		return
	}
	return
}

// Returns trues if a line intersects a rect
shape_is_line_colliding_rect_v2 :: proc(
	line: Line,
	rect: Rectangle,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	i: int = 0
	c_points: [2]Vec2
	c_lines: [2]Line
	lines := shape_get_rect_lines(rect)
	for l in lines {
		point, is_colliding := shape_get_line_intersection(line, l)
		if is_colliding {

			c_points[i] = point
			c_lines[i] = line
			i += 1
		}
		if i == 2 {break}
	}
	fmt.printf("c_points: %v\n", c_lines)
	return
}

/////////////////////////////////
// Helpers
/////////////////////////////////

shape_rectangle_seperation :: proc(
	rect_a: Rectangle,
	rect_b: Rectangle,
) -> (
	seperation: f32,
	axis: Line,
	pen_point: Vec2,
) {
	seperation = min(f32)
	rect_a_lines := shape_get_rect_lines(rect_a)
	rect_b_lines := shape_get_rect_lines(rect_b)


	for line_a in rect_a_lines {
		line_n := shape_line_normal(line_a)

		smallest_sep := max(f32)
		min_vertex: Vec2

		for line_b in rect_b_lines {
			projected_point := math.dot(line_b.start - line_a.start, line_n)
			if (projected_point < smallest_sep) {
				smallest_sep = projected_point
				min_vertex = line_b.start

			}
			smallest_sep = min(smallest_sep, projected_point)
		}
		if (smallest_sep > seperation) {
			seperation = smallest_sep
			pen_point = min_vertex
			axis = line_a
		}
	}

	return
}

shape_get_closest_line :: proc(point: Vec2, rectangle: Rectangle) -> (closest_line: Line) {
	rect_lines := shape_get_rect_lines(rectangle)
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
shape_get_rect_vertices :: proc(rect: Rectangle) -> (vertices: [4]Vec2) {
	len := math.length(rect.size) / 2
	nm_v := math.normalize(rect.size)
	normalized_points := [4]Vec2 {
		-nm_v,
		Vec2{nm_v.x, -nm_v.y},
		Vec2{nm_v.x, nm_v.y},
		Vec2{-nm_v.x, nm_v.y},
	}

	rad := math.to_radians(rect.rotation)
	for vertex, i in normalized_points {
		rotated_point := vertex
		rotated_point.x = vertex.x * math.cos(rad) - vertex.y * math.sin(rad)
		rotated_point.y = vertex.x * math.sin(rad) + vertex.y * math.cos(rad)
		vertices[i] = rect.pos + rotated_point * len
	}


	return vertices
}

// Returns the lines of a rectangle at zero width, using the temp_allocator
shape_get_rect_lines :: proc(rect: Rectangle) -> (lines: [4]Line) {
	vertices := shape_get_rect_vertices(rect)
	a := vertices[0]
	b := vertices[1]
	c := vertices[2]
	d := vertices[3]
	lines[0] = Line{a, b, 1}
	lines[1] = Line{b, c, 1}
	lines[2] = Line{c, d, 1}
	lines[3] = Line{d, a, 1}
	return lines
}

// Returns the intersection point, second argument is if there is an interaction or not
shape_get_line_intersection :: proc(a: Line, b: Line) -> (Vec2, bool) {
	an := a.end - a.start
	bn := b.end - b.start

	bn_flip := Vec2{bn.y, -bn.x}
	an_bn_dot := math.dot(bn_flip, an)

	if (an_bn_dot == 0) {
		return Vec2{}, false
	}

	s_cross := -an.y * (a.start.x - b.start.x) + an.x * (a.start.y - b.start.y)
	t_cross := bn.x * (a.start.y - b.start.y) - bn.y * (a.start.x - b.start.x)

	s := (s_cross) / an_bn_dot
	t := (t_cross) / an_bn_dot

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

@(private = "file")
shape_get_corner_vertices :: proc(c: Circle, l: Line) -> (Vec2, Vec2, bool) {
	v1 := c.pos - l.start
	v2 := l.end - l.start
	dot := math.dot(v1, v2)
	if (dot < 0) {return v1, v2, true}
	v1 = c.pos - l.end
	v2 = l.start - l.end
	dot = math.dot(v1, v2)
	if (dot < 0) {return v1, v2, true}

	return Vec2{}, Vec2{}, false
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
test_shape_rect_vertices_unrotated :: proc(t: ^testing.T) {
	// Return Vertices of the Rectangle in a counter clockwise pattern
	rect := Rectangle{Vec2{0, 0}, Vec2{1, 1}, 0.0}

	vertices := shape_get_rect_vertices(rect)

	expected_vertices := [4]Vec2 {
		Vec2{-0.5, -0.5},
		Vec2{0.5, -0.5},
		Vec2{0.5, 0.5},
		Vec2{-0.5, 0.5},
	}

	tolerance: f32 = 0.001
	for expected_vetrex, i in expected_vertices {
		compare := math.abs(vertices[i] - expected_vetrex)
		testing.expect(
			t,
			compare.x < tolerance && compare.y < tolerance,
			fmt.tprintf("\nExpected: %v\nGot:\t  %v", expected_vetrex, vertices[i]),
		)
	}
}

@(test)
test_shape_rect_lines_unrotated :: proc(t: ^testing.T) {
	// Return Lines of the Rectangle in a counter clockwise pattern
	rect := Rectangle{Vec2{0, 0}, Vec2{1, 1}, 0.0}

	lines := shape_get_rect_lines(rect)

	expected_starts := [4]Vec2{Vec2{-0.5, -0.5}, Vec2{0.5, -0.5}, Vec2{0.5, 0.5}, Vec2{-0.5, 0.5}}
	expected_ends := [4]Vec2{Vec2{0.5, -0.5}, Vec2{0.5, 0.5}, Vec2{-0.5, 0.5}, Vec2{-0.5, -0.5}}

	tolerance: f32 = 0.001
	for _, i in lines {
		line := lines[i]

		compare_line_start := math.abs(line.start - expected_starts[i])
		compare_line_end := math.abs(line.end - expected_ends[i])

		is_good :=
			compare_line_start.x < tolerance &&
			compare_line_start.y < tolerance &&
			compare_line_end.x < tolerance &&
			compare_line_end.y < tolerance

		testing.expect(
			t,
			is_good,
			fmt.tprintf(
				"\nExpected: %v\nGot:\t%v\n",
				Line{expected_starts[i], expected_ends[i], 0.0},
				line,
			),
		)
	}
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

@(test)
test_shape_get_line_intersection :: proc(t: ^testing.T) {
	line_a := Line{Vec2{-1, 0}, Vec2{1, 0}, 0.0}
	line_b := Line{Vec2{-1, 1}, Vec2{1, 1}, 0.0}
	line_c := Line{Vec2{-1, 0}, Vec2{1, 0}, 0.0}
	line_d := Line{Vec2{0, -1}, Vec2{0, 1}, 0.0}

	point, did_intersect := shape_get_line_intersection(line_a, line_b)
	testing.expect(t, !did_intersect, "Parallel lines do not intersect")

	point, did_intersect = shape_get_line_intersection(line_c, line_d)
	testing.expect(t, did_intersect, "Overlapping Lines intersect")
	testing.expect(t, point == Vec2{}, "This case intersects at origin")
}
