package game

import "core:fmt"
import "core:testing"

DataPoolResult :: enum {
	None,
	NotFound,
	AtCapacity,
}

Handle :: distinct u64
HandleStruct :: struct {
	idx: u32,
	gen: u32,
}

DataContainer :: struct($T: typeid) {
	id:   HandleStruct,
	data: T,
}

DataPool :: struct($N: u32, $T: typeid) {
	items:            [N]DataContainer(T),
	items_len:        u32,
	unused_items:     [N]u32,
	unused_items_idx: int,
}

DataPoolIterator :: struct($N: u32, $T: typeid) {
	dp:    DataPool(N, T),
	index: int,
}


data_pool_add :: proc(dp: ^DataPool($N, $T), v: T) -> (Handle, bool) {
	if (dp.items_len == N && dp.unused_items_idx == 0) {
		return 0, false
	}
	handle := HandleStruct{dp.items_len, 1}
	dp.items_len += 1
	return transmute(Handle)handle, true
}

data_pool_get :: proc(dp: ^DataPool($N, $T), h: Handle) -> (data: T, found: bool) {
	return
}

data_pool_get_ptr :: proc(dp: ^DataPool($N, $T)) -> ^T {
	return
}


data_pool_remove :: proc(dp: ^DataPool($N, $T), h: Handle) -> bool {
	return false
}

data_pool_valid :: proc(dp: ^DataPool($N, $T), h: Handle) -> bool {}

data_pool_new_iter :: proc(dp: DataPool($N, $T)) -> DataPoolIterator(N, T) {
	return DataPoolIterator(N, T){dp = dp}
}

data_pool_iter :: proc(it: DataPoolIterator($N, $T)) -> (val: T, h: Handle, cond: bool) {
	return
}


@(test)
test_data_pool_add_simple :: proc(t: ^testing.T) {
	assert(size_of(HandleStruct) == size_of(Handle))

	ByteDataPool :: DataPool(4, u8)
	byte_dp := ByteDataPool{}

	for i := 0; i < 4; i += 1 {
		handle, success := data_pool_add(&byte_dp, cast(u8)i + 5)
		testing.expect(t, success, fmt.tprintf("Data should have been added at index %d", i))
		testing.expect(
			t,
			handle != 0,
			fmt.tprintf("Data should have returned non-zero handle at index %d", i),
		)
	}

	handle, success := data_pool_add(&byte_dp, 244)
	testing.expect(t, !success, "Success returns false if it is full")

}
