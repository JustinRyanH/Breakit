package game

import "core:math"
import "core:testing"

RingBuffer :: struct($N: u32, $T: typeid) {
	items:       [N]T,
	start_index: u32,
	end_index:   u32,
}

ring_buffer_append :: proc(rb: ^RingBuffer($N, $T), v: T) -> bool {
	rb.items[rb.end_index] = v
	rb.end_index += 1
	return true
}

ring_buffer_pop :: proc(rb: ^RingBuffer($N, $T)) -> (val: T, empty: bool) {
	if (ring_buffer_len(rb) == 0) {
		return
	}
	if (rb.end_index <= rb.start_index) {
		return
	}
	val = rb.items[rb.start_index]
	rb.start_index = math.min(rb.start_index + 1, rb.end_index)


	return val, true
}

ring_buffer_len :: proc(rb: ^RingBuffer($N, $T)) -> u32 {
	if (rb.end_index <= rb.start_index) {
		return 0
	}
	return rb.end_index - rb.start_index
}


/////////////////////////////
// Tests
/////////////////////////////

@(test)
test_ring_buffer :: proc(t: ^testing.T) {
	using testing

	ByteRingBuffer :: RingBuffer(4, u8)
	buffer := ByteRingBuffer{}

	expect(t, ring_buffer_len(&buffer) == 0, "Starts off with empty buffer")

	ring_buffer_append(&buffer, 10)
	expect(t, ring_buffer_len(&buffer) == 1, "It increases the length of the buffer")

	v, found := ring_buffer_pop(&buffer)
	expect(t, found, "It found the option")
	expectf(t, v == 10, "Expected %v, found %v", 10, v)

	v, found = ring_buffer_pop(&buffer)
	expect(t, !found, "It founds nothing")
	expectf(t, v == 0, "Expected %v, found %v", 0, v)

}
