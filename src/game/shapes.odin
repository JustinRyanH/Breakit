package game

import fmt "core:fmt"
import math "core:math/linalg"
import "core:testing"

Vector2 :: math.Vector2f32

Rectangle :: struct {
	pos:      Vector2,
	size:     Vector2,
	rotation: f32,
}

Circle :: struct {
	pos:    Vector2,
	radius: f32,
}

Line :: struct {
	start:     Vector2,
	end:       Vector2,
	thickness: f32,
}

Shape :: union {
	Rectangle,
	Circle,
	Line,
}


ContactEvent :: struct {
	normal: Vector2,
	depth:  f32,
}

/////////////////
/// Collision
/////////////////

shape_check_collision :: proc(
	shape_a: Shape,
	shape_b: Shape,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	switch a in shape_a {
	case Circle:
		switch b in shape_b {
		case Circle:
			return shape_are_circles_colliding(a, b)
		case Rectangle:
			return shape_is_circle_colliding_rect(a, b)
		case Line:
			return shape_is_circle_colliding_line(a, b)
		}
	case Rectangle:
		switch b in shape_b {
		case Circle:
			return shape_is_circle_colliding_rect(b, a)
		case Rectangle:
			return shape_are_rects_colliding_obb(a, b)
		case Line:
			return shape_is_line_colliding_rect(b, a)
		}
	case Line:
		switch b in shape_b {
		case Circle:
			return shape_is_circle_colliding_line(b, a)
		case Rectangle:
			return shape_is_line_colliding_rect(a, b)
		case Line:
			point, is_colliding := shape_are_lines_colliding(a, b)
			evt.normal = shape_line_normal(a)
			evt.depth = 0
			return evt, is_colliding
		}
	}
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
	event.depth = max(f32)
	rect_a_vertices := shape_get_rect_vertices(rect_a)
	rect_b_vertices := shape_get_rect_vertices(rect_b)

	for _, i in rect_a_vertices {
		a := rect_a_vertices[i]
		b := rect_a_vertices[(i + 1) % len(rect_a_vertices)]

		edge := b - a
		axis := shape_vector_normalize_perp(edge)

		min_a, max_a := shape_project_vertices_to_axis(rect_a_vertices[:], axis)
		min_b, max_b := shape_project_vertices_to_axis(rect_b_vertices[:], axis)

		if min_a >= max_b || min_b >= max_a {
			return ContactEvent{}, false
		}

		depth := math.min(max_b - min_a, max_a - min_b)
		if (depth < event.depth) {
			event.depth = depth
			event.normal = axis
		}
	}

	for _, i in rect_b_vertices {
		a := rect_b_vertices[i]
		b := rect_b_vertices[(i + 1) % len(rect_b_vertices)]

		edge := b - a
		axis := shape_vector_normalize_perp(edge)

		min_a, max_a := shape_project_vertices_to_axis(rect_a_vertices[:], axis)
		min_b, max_b := shape_project_vertices_to_axis(rect_b_vertices[:], axis)

		if min_a >= max_b || min_b >= max_a {
			return ContactEvent{}, false
		}

		depth := math.min(max_b - min_a, max_a - min_b)
		if (depth < event.depth) {
			event.depth = depth
			event.normal = axis
		}
	}

	is_colliding = true

	dir := rect_a.pos - rect_b.pos
	if (math.dot(dir, event.normal) < 0) {
		event.normal *= -1
	}

	return
}


// returns true if the two circles intersect
shape_are_circles_colliding :: proc(
	circle_a, circle_b: Circle,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	delta := circle_b.pos - circle_a.pos
	distance := math.vector_length(delta)
	if (distance <= (circle_a.radius + circle_b.radius)) {
		normal := math.normalize(delta)
		start := circle_a.pos + math.normalize(delta) * circle_a.radius
		end := circle_b.pos - math.normalize(delta) * circle_b.radius
		evt.depth = math.length(start - end)
		evt.normal = normal

		is_colliding = true
		return
	}
	return
}

shape_is_circle_colliding_rect :: proc(
	circle: Circle,
	rect: Rectangle,
) -> (
	event: ContactEvent,
	is_colliding: bool,
) {
	event.depth = max(f32)
	rect_vertices := shape_get_rect_vertices(rect)

	for _, i in rect_vertices {
		a := rect_vertices[i]
		b := rect_vertices[(i + 1) % len(rect_vertices)]

		edge := b - a
		axis := shape_vector_normalize_perp(edge)

		min_a, max_a := shape_project_vertices_to_axis(rect_vertices[:], axis)
		circle_depth := axis * circle.radius
		smaller, bigger := circle.pos - circle_depth, circle.pos + circle_depth
		min_b, max_b: f32 = shape_project_vertices_to_axis({smaller, bigger}, axis)

		if min_a >= max_b || min_b >= max_a {
			return ContactEvent{}, false
		}

		depth := math.min(max_b - min_a, max_a - min_b)
		if (depth < event.depth) {
			event.depth = depth
			event.normal = axis
		}
	}

	dir := circle.pos - rect.pos
	if (math.dot(dir, event.normal) < 0) {
		event.normal *= -1
	}

	is_colliding = true


	return
}


// Returns the collision event for a point, and the closest line to the point, 
// returns true if line inside the rect, otherwise returns false
shape_is_point_inside_rect :: proc(
	point: math.Vector2f32,
	rect: Rectangle,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	closest_line := shape_get_closest_line(point, rect)
	line_point := shape_point_projected_to_line(point, closest_line)
	line_normal := shape_line_normal(closest_line)

	dir := math.normalize(point - line_point)

	if (dir == line_normal) {
		return
	}

	evt.normal = line_normal
	evt.depth = math.length(point - line_point)
	is_colliding = true
	return
}


// returns true if a line intersects a circle
// TODO: Handle on the edges.
shape_is_circle_colliding_line :: proc(
	circle: Circle,
	line: Line,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	closest_point := shape_point_projected_to_line(circle.pos, line)
	is_point_inside_circle := shape_is_point_inside_circle(closest_point, circle)

	if (is_point_inside_circle) {
		evt.normal = shape_line_normal(line)
		end := circle.pos - evt.normal * circle.radius
		evt.depth = math.length(closest_point - end)


		return evt, true
	}

	return
}

shape_is_circle_colliding_line_v2 :: proc(
	circle: Circle,
	line: Line,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	closest_point := shape_point_projected_to_line(circle.pos, line)

	evt, is_colliding = shape_are_circles_colliding(
		circle,
		Circle{closest_point, line.thickness / 2},
	)
	evt.normal *= -1
	return
}


// returns true if a point is inside a circle
shape_is_point_inside_circle :: proc(point: math.Vector2f32, circle: Circle) -> bool {
	np_length := math.length(circle.pos - point)
	return np_length < circle.radius
}

// returns true if two lines intersect
shape_are_lines_colliding :: proc(a, b: Line) -> (Vector2, bool) {
	return shape_get_line_intersection(a, b)
}

// Returns trues if a line intersects a rect
shape_is_line_colliding_rect :: proc(
	line: Line,
	rect: Rectangle,
) -> (
	evt: ContactEvent,
	is_colliding: bool,
) {
	i: int = 0
	draw := ctx.draw_cmds
	c_points: [2]Vector2
	c_lines: [2]Line
	lines := shape_get_rect_lines(rect)
	for l in lines {
		point, is_colliding := shape_get_line_intersection(line, l)
		if is_colliding {

			c_points[i] = point
			c_lines[i] = l
			i += 1
		}
		if i == 2 {break}
	}
	switch i {
	case 0:
		return
	case 1:
		line_normal := shape_line_normal(c_lines[0])
		test_point := line.start - c_points[0]
		dot_1 := math.dot(test_point, line_normal)

		evt.normal = line_normal
		end := line.start if dot_1 < 0 else line.end
		evt.depth = math.length(c_points[0] - end)

		return evt, true
	case 2:
		evt.normal = shape_line_normal(c_lines[0])
		evt.depth = math.length(c_points[0] - c_points[1])
		return evt, true
	}
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
	pen_point: Vector2,
) {
	seperation = min(f32)
	rect_a_lines := shape_get_rect_lines(rect_a)
	rect_b_lines := shape_get_rect_lines(rect_b)


	for line_a in rect_a_lines {
		line_n := shape_line_normal(line_a)

		smallest_sep := max(f32)
		min_vertex: Vector2

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

shape_get_closest_line :: proc(point: Vector2, rectangle: Rectangle) -> (closest_line: Line) {
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
shape_get_rect_vertices :: proc(rect: Rectangle) -> (vertices: [4]Vector2) {
	len := math.length(rect.size) / 2
	nm_v := math.normalize(rect.size)
	normalized_points := [4]Vector2 {
		-nm_v,
		Vector2{nm_v.x, -nm_v.y},
		Vector2{nm_v.x, nm_v.y},
		Vector2{-nm_v.x, nm_v.y},
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
shape_get_line_intersection :: proc(a: Line, b: Line) -> (Vector2, bool) {
	an := a.end - a.start
	bn := b.end - b.start

	bn_flip := Vector2{bn.y, -bn.x}
	an_bn_dot := math.dot(bn_flip, an)

	if (an_bn_dot == 0) {
		return Vector2{}, false
	}

	s_cross := -an.y * (a.start.x - b.start.x) + an.x * (a.start.y - b.start.y)
	t_cross := bn.x * (a.start.y - b.start.y) - bn.y * (a.start.x - b.start.x)

	s := (s_cross) / an_bn_dot
	t := (t_cross) / an_bn_dot

	if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
		x := a.start.x + (t * an.x)
		y := a.start.y + (t * an.y)
		return Vector2{x, y}, true

	}

	return Vector2{}, false
}

// Rotates the Vector 90 counter clockwise, normalized
shape_vector_normalize_perp :: proc(vec: Vector2) -> Vector2 {
	v := math.normalize(vec)
	l := math.length(vec)
	return Vector2{-v.y, v.x}
}

shape_line_mid_point :: proc(line: Line) -> Vector2 {
	line_at_origin := line.end - line.start
	normalized_direction := math.length(line_at_origin)

	normalized_mid_point := math.normalize(line_at_origin) * (normalized_direction * 0.5)
	return normalized_mid_point + line.start
}

shape_line_normal :: proc(line: Line) -> Vector2 {
	return shape_vector_normalize_perp(line.start - line.end)
}

shape_point_projected_to_line :: #force_inline proc(point: Vector2, line: Line) -> Vector2 {
	se := line.end - line.start
	se_len := math.length(se)
	pd := point - line.start

	se_n := se / se_len
	pd_n := pd / se_len

	dot := math.clamp(math.dot(se_n, pd_n), 0.0, 1.0)
	return se_n * (dot * se_len) + line.start
}

shape_invert_line :: #force_inline proc(line: Line) -> (new_line: Line) {
	new_line.start, new_line.end = line.end, line.start
	return
}


shape_rotate_vector :: proc(v: Vector2, radians: f32) -> Vector2 {
	rotated_point := math.normalize(v)
	rotated_point.x = v.x * math.cos(radians) - v.y * math.sin(radians)
	rotated_point.y = v.x * math.sin(radians) + v.y * math.cos(radians)
	return rotated_point
}

///////////////////////////////////////////
/// Private
///////////////////////////////////////////

@(private = "file")
shape_get_corner_vertices :: proc(p: Vector2, l: Line) -> (Vector2, Vector2, bool) {
	v1 := p - l.start
	v2 := l.end - l.start
	dot := math.dot(v1, v2)
	if (dot < 0) {return v1, v2, true}
	v1 = p - l.end
	v2 = l.start - l.end
	dot = math.dot(v1, v2)
	if (dot < 0) {return v1, v2, true}

	return Vector2{}, Vector2{}, false
}


@(private = "file")
shape_project_vertices_to_axis :: proc(vertices: []Vector2, axis: Vector2) -> (min_t, max_t: f32) {
	min_t = max(f32)
	max_t = min(f32)

	for vertex in vertices {
		dp := math.dot(vertex, axis)
		max_t = math.max(dp, max_t)
		min_t = math.min(dp, min_t)
	}


	return
}

/////////////////////////////
// Tests
/////////////////////////////

@(test)
test_shape_get_vector_normal :: proc(t: ^testing.T) {
	v := Vector2{3, 4}
	n := shape_vector_normalize_perp(v)
	testing.expect(t, math.normalize(Vector2{-4, 3}) == n, "Normal of Vector")
}

@(test)
test_shape_point_in_circle :: proc(t: ^testing.T) {
	circle_center := Vector2{300, 400}
	circle_radius: f32 = 50
	circle := Circle{circle_center, circle_radius}

	testing.expect(
		t,
		!shape_is_point_inside_circle(Vector2{200, 305}, circle),
		"Point should be outside of circle",
	)
	testing.expect(
		t,
		shape_is_point_inside_circle(Vector2{260, 385}, circle),
		"Point should be inside of circle",
	)
}

@(test)
test_shape_rect_vertices_unrotated :: proc(t: ^testing.T) {
	// Return Vertices of the Rectangle in a counter clockwise pattern
	rect := Rectangle{Vector2{0, 0}, Vector2{1, 1}, 0.0}

	vertices := shape_get_rect_vertices(rect)

	expected_vertices := [4]Vector2 {
		Vector2{-0.5, -0.5},
		Vector2{0.5, -0.5},
		Vector2{0.5, 0.5},
		Vector2{-0.5, 0.5},
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
	rect := Rectangle{Vector2{0, 0}, Vector2{1, 1}, 0.0}

	lines := shape_get_rect_lines(rect)

	expected_starts := [4]Vector2 {
		Vector2{-0.5, -0.5},
		Vector2{0.5, -0.5},
		Vector2{0.5, 0.5},
		Vector2{-0.5, 0.5},
	}
	expected_ends := [4]Vector2 {
		Vector2{0.5, -0.5},
		Vector2{0.5, 0.5},
		Vector2{-0.5, 0.5},
		Vector2{-0.5, -0.5},
	}

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
	rect := Rectangle{Vector2{0, 0}, Vector2{1, 1}, 0.0}
	min, max := shape_get_rect_extends(rect)

	testing.expect(
		t,
		min == Vector2{-0.5, -0.5},
		"origin is at zero so minimum extends is half width, left of origin",
	)
	testing.expect(
		t,
		max == Vector2{0.5, 0.5},
		"origin is at zero so maximum extends is half width, right of origin",
	)
}

@(test)
test_shape_get_line_intersection :: proc(t: ^testing.T) {
	line_a := Line{Vector2{-1, 0}, Vector2{1, 0}, 0.0}
	line_b := Line{Vector2{-1, 1}, Vector2{1, 1}, 0.0}
	line_c := Line{Vector2{-1, 0}, Vector2{1, 0}, 0.0}
	line_d := Line{Vector2{0, -1}, Vector2{0, 1}, 0.0}

	point, did_intersect := shape_get_line_intersection(line_a, line_b)
	testing.expect(t, !did_intersect, "Parallel lines do not intersect")

	point, did_intersect = shape_get_line_intersection(line_c, line_d)
	testing.expect(t, did_intersect, "Overlapping Lines intersect")
	testing.expect(t, point == Vector2{}, "This case intersects at origin")
}
