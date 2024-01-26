
package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "game"


GameAPI :: struct {
	name:         string,
	path:         string,

	// Accessible Procs
	init:         proc(),
	update:       proc() -> bool,
	shutdown:     proc(),
	memory:       proc() -> rawptr,
	hot_reloaded: proc(_: rawptr),


	// DLL specific items
	lib:          dynlib.Library,
	dll_time:     os.File_Time,
	api_version:  int,
}

game_api_load :: proc(api_version: int, name: string, path: string) -> (GameAPI, bool) {
	when ODIN_OS == .Darwin {
		dll_extension := ".dylib"
	}

	file_name := fmt.tprintf("{0}{1}", name, dll_extension)
	api_file := filepath.join({path, file_name})

	dll_time, dll_time_err := os.last_write_time_by_name(api_file)

	if dll_time_err != os.ERROR_NONE {
		fmt.println("Could not fetch last write date of", api_file)
		return {}, false
	}

	new_name := fmt.tprintf("{0}_{1}{2}", name, api_version, dll_extension)
	new_file := filepath.join({path, new_name}, context.temp_allocator)

	when ODIN_OS == .Darwin {
		copy_cmd := fmt.ctprintf("cp {0} {1}", api_file, new_file)
	}

	if libc.system(copy_cmd) != 0 {
		fmt.println("Failed to copy game.dylib to", new_file)
		return {}, false
	}

	lib, lib_ok := dynlib.load_library(new_file)

	if !lib_ok {
		fmt.println("Failed loading game DLL")
		return {}, false
	}

	api := GameAPI {
		// API File Information
		name         = name,
		path         = path,

		// Methods
		init         = cast(proc())(dynlib.symbol_address(lib, "game_init") or_else nil),
		update       = cast(proc() -> bool)(dynlib.symbol_address(lib, "game_update") or_else nil),
		shutdown     = cast(proc())(dynlib.symbol_address(lib, "game_shutdown") or_else nil),
		memory       = cast(proc(
		) -> rawptr)(dynlib.symbol_address(lib, "game_memory") or_else nil),
		hot_reloaded = cast(proc(
			_: rawptr,
		))(dynlib.symbol_address(lib, "game_hot_reloaded") or_else nil),

		// Meta
		lib          = lib,
		dll_time     = dll_time,
		api_version  = api_version,
	}

	if api.init == nil ||
	   api.update == nil ||
	   api.shutdown == nil ||
	   api.memory == nil ||
	   api.hot_reloaded == nil {
		game_api_unload(api)
		fmt.println("Game DLL missing required procedure")
		return {}, false
	}


	return api, true
}

game_api_file_path :: proc(api: GameAPI) -> string {
	when ODIN_OS == .Darwin {
		dll_extension := ".dylib"
	}

	file_name := fmt.tprintf("{0}{1}", api.name, dll_extension)
	return filepath.join({api.path, file_name}, context.temp_allocator)
}

game_api_hot_load :: proc(api: GameAPI) -> GameAPI {
	new_api, new_api_ok := game_api_load(api.api_version + 1, api.name, api.path)

	if new_api_ok {
		game_memory := api.memory()

		game_api_unload(api)

		new_api.hot_reloaded(game_memory)
		return new_api
	}
	return api

}


game_api_unload :: proc(api: GameAPI) {
	if api.lib != nil {
		dynlib.unload_library(api.lib)
	}

	del_cmd := fmt.ctprintf("rm bin\\game_{0}.dylib", api.api_version)
	if libc.system(del_cmd) != 0 {
		fmt.println("Failed to remove game_{0}.dylib copy", api.api_version)
	}
}
