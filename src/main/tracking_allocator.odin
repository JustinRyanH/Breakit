package main

import "core:runtime"
import "core:mem"
import "core:sync"
import "core:fmt"

Tracking_Allocator_Entry :: struct {
	memory:    rawptr,
	size:      int,
	alignment: int,
	mode:      mem.Allocator_Mode,
	err:       mem.Allocator_Error,
	location:  runtime.Source_Code_Location,
}

Tracking_Allocator :: struct {
	backing:           mem.Allocator,
	allocation_map:    map[rawptr]Tracking_Allocator_Entry,
	mutex:             sync.Mutex,
	clear_on_free_all: bool,
}

tracking_allocator_init :: proc(t: ^Tracking_Allocator, backing_allocator: mem.Allocator, internals_allocator := context.allocator) {
	t.backing = backing_allocator
	t.allocation_map.allocator = internals_allocator

	if .Free_All in mem.query_features(t.backing) {
		t.clear_on_free_all = true
	}
}

tracking_allocator_destroy :: proc(t: ^Tracking_Allocator) {
	delete(t.allocation_map)
}


tracking_allocator_clear :: proc(t: ^Tracking_Allocator) {
	sync.mutex_lock(&t.mutex)
	clear(&t.allocation_map)
	sync.mutex_unlock(&t.mutex)
}


@(require_results)
allocator_from_tracking_allocator :: proc(data: ^Tracking_Allocator) -> mem.Allocator {
	return mem.Allocator{
		data = data,
		procedure = tracking_allocator_proc,
	}
}

tracking_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                                size, alignment: int,
                                old_memory: rawptr, old_size: int, loc := #caller_location) -> (result: []byte, err: mem.Allocator_Error) {
	data := (^Tracking_Allocator)(allocator_data)

	sync.mutex_guard(&data.mutex)

	if mode == .Query_Info {
		info := (^mem.Allocator_Query_Info)(old_memory)
		if info != nil && info.pointer != nil {
			if entry, ok := data.allocation_map[info.pointer]; ok {
				info.size = entry.size
				info.alignment = entry.alignment
			}
			info.pointer = nil
		}

		return
	}

	if mode == .Free && old_memory != nil && old_memory not_in data.allocation_map {
		fmt.panicf("At %v: Bad free!", loc)
	} else {
		result = data.backing.procedure(data.backing.data, mode, size, alignment, old_memory, old_size, loc) or_return
	}
	result_ptr := raw_data(result)

	if data.allocation_map.allocator.procedure == nil {
		data.allocation_map.allocator = context.allocator
	}

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		data.allocation_map[result_ptr] = Tracking_Allocator_Entry{
			memory = result_ptr,
			size = size,
			mode = mode,
			alignment = alignment,
			err = err,
			location = loc,
		}
	case .Free:
		delete_key(&data.allocation_map, old_memory)
	case .Free_All:
		if data.clear_on_free_all {
			clear_map(&data.allocation_map)
		}	
	case .Resize, .Resize_Non_Zeroed:
		if old_memory != result_ptr {
			delete_key(&data.allocation_map, old_memory)
		}
		data.allocation_map[result_ptr] = Tracking_Allocator_Entry{
			memory = result_ptr,
			size = size,
			mode = mode,
			alignment = alignment,
			err = err,
			location = loc,
		}

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All, .Resize, .Query_Features, .Query_Info}
		}
		return nil, nil

	case .Query_Info:
		unreachable()
	}

	return
}

