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
	unused_items:     [N]HandleStruct,
	unused_items_len: int,
}

DataPoolIterator :: struct($N: u32, $T: typeid) {
	dp:    DataPool(N, T),
	index: int,
}


data_pool_add :: proc(dp: ^DataPool($N, $T), v: T) -> (Handle, bool) {
	if (dp.items_len == N && dp.unused_items_len == 0) {
		return 0, false
	}
	if (dp.unused_items_len > 0) {
		handle := dp.unused_items[dp.unused_items_len - 1]
		handle.gen += 1
		dp.items[handle.idx] = DataContainer(T){handle, v}
		dp.unused_items_len -= 1
		return transmute(Handle)handle, true
	}

	handle := HandleStruct{dp.items_len, 1}
	dp.items[dp.items_len] = DataContainer(T){handle, v}
	dp.items_len += 1

	return transmute(Handle)handle, true
}

data_pool_get :: proc(dp: ^DataPool($N, $T), h: Handle) -> (data: T, found: bool) {
	hs := transmute(HandleStruct)h

	db := dp.items[hs.idx]
	if (db.id == hs) {
		return db.data, true
	}
	return
}

data_pool_get_ptr :: proc(dp: ^DataPool($N, $T), h: Handle) -> ^T {
	hs := transmute(HandleStruct)h

	db := dp.items[hs.idx]
	if (db.id == hs) {
		return &dp.items[hs.idx].data
	}
	return nil
}


data_pool_remove :: proc(dp: ^DataPool($N, $T), h: Handle) -> bool {
	hs := transmute(HandleStruct)h

	db := dp.items[hs.idx]
	if (db.id == hs) {

		item := &dp.items[hs.idx]
		dp.unused_items[dp.unused_items_len] = item.id
		dp.unused_items_len += 1
		item.id = HandleStruct{}
		item.data = T{}

		return true
	}


	return false
}

data_pool_valid :: proc(dp: ^DataPool($N, $T), h: Handle) -> bool {}

data_pool_new_iter :: proc(dp: DataPool($N, $T)) -> DataPoolIterator(N, T) {
	return DataPoolIterator(N, T){dp = dp}
}

data_pool_iter :: proc(it: ^DataPoolIterator($N, $T)) -> (val: T, h: Handle, cond: bool) {
	cond = it.index < cast(int)it.dp.items_len
	return
}

@(test)
test_data_pool_add_simple :: proc(t: ^testing.T) {
	assert(size_of(HandleStruct) == size_of(Handle))
	TestStruct :: struct {
		v: u8,
	}

	ByteDataPool :: DataPool(4, TestStruct)
	byte_dp := ByteDataPool{}

	for i := 0; i < 4; i += 1 {
		handle, success := data_pool_add(&byte_dp, TestStruct{cast(u8)i + 5})
		testing.expect(t, success, fmt.tprintf("Data should have been added at index %d", i))
		testing.expect(
			t,
			handle != 0,
			fmt.tprintf("Data should have returned non-zero handle at index %d", i),
		)
	}

	handle, success := data_pool_add(&byte_dp, TestStruct{244})
	testing.expect(t, !success, "Success returns false if it is full")

}

@(test)
test_data_pool_add_reuse :: proc(t: ^testing.T) {

	TestStruct :: struct {
		v: u8,
	}
	ByteDataPool :: DataPool(4, TestStruct)
	byte_dp := ByteDataPool{}

	handle_a, success_a := data_pool_add(&byte_dp, TestStruct{33})
	testing.expect(t, success_a, "data should have been added")

	was_removed := data_pool_remove(&byte_dp, handle_a)
	testing.expect(t, was_removed, "data should have been removed")

	handle_b, success_b := data_pool_add(&byte_dp, TestStruct{33})
	testing.expect(t, success_b, "data cannot be removed twice")

	handle_struct_b := transmute(HandleStruct)handle_b
	handle_struct_a := transmute(HandleStruct)handle_a

	testing.expect(
		t,
		handle_struct_a.idx == handle_struct_b.idx,
		"it re-uses the previously used spots",
	)
	testing.expect(
		t,
		handle_struct_b.gen > handle_struct_a.gen,
		"it iterates the handle generation",
	)
}


@(test)
test_data_pool_get :: proc(t: ^testing.T) {
	assert(size_of(HandleStruct) == size_of(Handle))
	TestStruct :: struct {
		v: u8,
	}

	ByteDataPool :: DataPool(4, TestStruct)
	byte_dp := ByteDataPool{}

	handle, success := data_pool_add(&byte_dp, TestStruct{33})
	testing.expect(t, success, "Data should have been added")

	data, found := data_pool_get(&byte_dp, handle)

	testing.expect(t, found, "Data should have been found")
	testing.expect(t, data.v == 33, fmt.tprintf("Data should have been 33, but was %d", data))
}

@(test)
test_data_pool_get_ptr :: proc(t: ^testing.T) {
	assert(size_of(HandleStruct) == size_of(Handle))
	TestStruct :: struct {
		v: u8,
	}

	ByteDataPool :: DataPool(4, u8)
	byte_dp := ByteDataPool{}

	handle, success := data_pool_add(&byte_dp, 33)
	testing.expect(t, success, "data should have been added")

	{
		data_ptr := data_pool_get_ptr(&byte_dp, handle)
		data_ptr^ = 50
	}

	data, found := data_pool_get(&byte_dp, handle)
	testing.expect(t, found, "Data should have been found")
	testing.expect(t, data == 50, "Data should have been adjusted in memory")
}

@(test)
test_data_pool_remove :: proc(t: ^testing.T) {
	TestStruct :: struct {
		v: u8,
	}
	ByteDataPool :: DataPool(4, TestStruct)
	byte_dp := ByteDataPool{}

	handle_a, success_a := data_pool_add(&byte_dp, TestStruct{33})
	testing.expect(t, success_a, "data should have been added")
	handle_b, success_b := data_pool_add(&byte_dp, TestStruct{44})
	testing.expect(t, success_a, "data should have been added")

	was_removed := data_pool_remove(&byte_dp, handle_a)
	testing.expect(t, was_removed, "data should have been removed")
	was_removed = data_pool_remove(&byte_dp, handle_a)
	testing.expect(t, !was_removed, "data cannot be removed twice")
}

@(test)
test_data_pool_iterator :: proc(t: ^testing.T) {
	TestStruct :: struct {
		v: u8,
	}
	ByteDataPool :: DataPool(4, TestStruct)
	byte_dp := ByteDataPool{}

	handle_a, success_a := data_pool_add(&byte_dp, TestStruct{33})
	handle_b, success_b := data_pool_add(&byte_dp, TestStruct{77})
	handle_c, success_c := data_pool_add(&byte_dp, TestStruct{100})
	handle_d, success_d := data_pool_add(&byte_dp, TestStruct{240})
	successes := []bool{success_a, success_b, success_c, success_d}
	for success in successes {
		testing.expect(t, success, "data should have been added")
	}

	removed := data_pool_remove(&byte_dp, handle_b)
	testing.expect(t, removed, "data should have been removed")

	iter := data_pool_new_iter(byte_dp)


	val, handle, should_continue := data_pool_iter(&iter)
	testing.expect(t, should_continue, "There should be more iterations left")

}
