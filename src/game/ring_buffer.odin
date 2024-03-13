package game


import "core:fmt"
import "core:math"
import "core:testing"

RingBuffer :: struct($N: u32, $T: typeid) {
	index:  u32,
	length: u32,
	items:  [N]T,
}

ring_buffer_append :: proc(rb: ^RingBuffer($N, $T), v: T) -> bool {
	if (ring_buffer_len(rb) == N) {
		return false
	}


	index := (rb.index + rb.length) % N
	assert(index < N, "Out of Range Error, this is wrong")
	rb.items[index] = v
	rb.length += 1
	return true
}

ring_buffer_pop :: proc(rb: ^RingBuffer($N, $T)) -> (val: T, empty: bool) {
	if (ring_buffer_len(rb) == 0) {
		return
	}
	val = rb.items[rb.index]
	rb.index = ((rb.index + 1) % N)
	rb.length -= 1

	return val, true
}

ring_buffer_len :: proc(rb: ^RingBuffer($N, $T)) -> u32 {
	return rb.length
}


/////////////////////////////
// Tests
/////////////////////////////

@(test)
test_ring_buffer :: proc(t: ^testing.T) {
	using testing

	ByteRingBuffer :: RingBuffer(4, u8)
	buffer := ByteRingBuffer{}

	expectf(
		t,
		ring_buffer_len(&buffer) == 0,
		"Starts off with empty buffer: Actual %v",
		ring_buffer_len(&buffer),
	)

	ring_buffer_append(&buffer, 10)
	expect(t, ring_buffer_len(&buffer) == 1, "It increases the length of the buffer")

	v, found := ring_buffer_pop(&buffer)
	expect(t, found, "It found the option")
	expectf(t, v == 10, "Expected %v, found %v", 10, v)

	v, found = ring_buffer_pop(&buffer)
	expect(t, !found, "It founds nothing")
	expectf(t, v == 0, "Expected %v, found %v", 0, v)
}

@(test)
test_ring_buffer_full :: proc(t: ^testing.T) {
	using testing

	ByteRingBuffer :: RingBuffer(4, u8)
	buffer := ByteRingBuffer{}

	expect(t, ring_buffer_len(&buffer) == 0, "Starts off with empty buffer")


	success := ring_buffer_append(&buffer, 5)
	expect(t, success, "Successfully adds")
	expectf(t, ring_buffer_len(&buffer) == 1, "Increases the buffer")
	success = ring_buffer_append(&buffer, 10)
	expect(t, success, "Successfully adds")
	expectf(t, ring_buffer_len(&buffer) == 2, "Increases the buffer")
	success = ring_buffer_append(&buffer, 15)
	expect(t, success, "Successfully adds")
	expectf(t, ring_buffer_len(&buffer) == 3, "Increases the buffer")
	success = ring_buffer_append(&buffer, 20)
	expectf(t, ring_buffer_len(&buffer) == 4, "Fills up: Len %v", buffer)

	success = ring_buffer_append(&buffer, 25)
	expect(t, !success, "does not successfully add if full")
	expect(t, ring_buffer_len(&buffer) == 4, "Stays at 4")
}

@(test)
test_ring_buffer_loop :: proc(t: ^testing.T) {
	using testing

	ByteRingBuffer :: RingBuffer(3, u8)
	buffer := ByteRingBuffer{}

	ring_buffer_append(&buffer, 1)
	ring_buffer_append(&buffer, 2)
	ring_buffer_append(&buffer, 3)

	v, exists := ring_buffer_pop(&buffer)
	expect(t, exists, "Value Exists")
	expect(t, v == 1, "returns the first value")
	v, exists = ring_buffer_pop(&buffer)
	expect(t, exists, "Value Exists")
	expect(t, v == 2, "returns the first value")
	v, exists = ring_buffer_pop(&buffer)
	expect(t, exists, "Value Exists")
	expect(t, v == 3, "returns the first value")

	ring_buffer_append(&buffer, 4)
	expect(t, ring_buffer_len(&buffer) == 1, "The buffer length is 1 after looping")
	ring_buffer_append(&buffer, 5)
	expect(t, ring_buffer_len(&buffer) == 2, "The buffer length is 1 after looping")

	success := ring_buffer_append(&buffer, 6)
	expect(t, success, "stays healthy after looping")
	success = ring_buffer_append(&buffer, 7)
	expect(t, !success, "Only handles 3 elements")


	fmt.println(buffer)
	v, exists = ring_buffer_pop(&buffer)
	expectf(t, v == 4, "Expected: %v found: %v", 4, v)
	v, exists = ring_buffer_pop(&buffer)
	expectf(t, v == 5, "Expected: %v found: %v", 5, v)
	v, exists = ring_buffer_pop(&buffer)
	expectf(t, v == 6, "Expected: %v found: %v", 6, v)
}

@(test)
test_can_i_iter_ring_buffer :: proc(t: ^testing.T) {
	using testing
	ByteRingBuffer :: RingBuffer(3, u8)
	buffer := ByteRingBuffer{}

	ring_buffer_append(&buffer, 1)
	ring_buffer_append(&buffer, 2)
	ring_buffer_append(&buffer, 3)

	i: u8 = 1
	for v in ring_buffer_pop(&buffer) {
		expectf(t, v == i, "Expected Value to be: %v, but found: %v", i, v)
		i += 1
		assert(i <= 3, "In infinate loop")
	}

	expect(t, ring_buffer_len(&buffer) == 0, "Ring Buffer should be empty")
}
