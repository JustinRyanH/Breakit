package main


import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "game"

stub_tear_down :: proc() {}


GameAPI :: struct {
	name:         string,
	path:         string,

	// Accessible Procs
	init:         proc(),
	setup:        proc(_: ^game.Context),
	update:       proc(_: ^game.Context) -> bool,
	draw:         proc(_: ^game.PlatformDrawCommands),
	shutdown:     proc(),
	memory:       proc() -> rawptr,
	hot_reloaded: proc(_: rawptr),


	// DLL specific items
	lib:          dynlib.Library,
	dll_time:     os.File_Time,
	iteration:    int,
}

game_api_load :: proc(iteration: int, name: string, path: string) -> (api: GameAPI, failed: bool) {
	api.name = name
	api.path = path
	api.iteration = iteration

	api_file := game_api_file_path(api)
	dll_time, dll_time_err := os.last_write_time_by_name(api_file)

	if dll_time_err != os.ERROR_NONE {
		fmt.println("Could not fetch last write date of", api_file)
		return {}, false
	}

	new_file := game_api_version_path(api)


	file_handle, file_handle_err := os.open(api_file)
	if file_handle_err != os.ERROR_NONE {
		fmt.println("Failed to open file")
		return {}, false
	}

	data, success := os.read_entire_file_from_handle(file_handle, context.temp_allocator)
	if !success {
		fmt.println("Failed to read data out of file")
		return {}, false
	}
	os.close(file_handle)

	success = os.write_entire_file(new_file, data)
	if !success {
		fmt.println("Failed to copy game.dylib to", new_file)
	}

	lib, lib_ok := dynlib.load_library(new_file)

	if !lib_ok {
		fmt.println("Failed loading game DLL")
		return {}, false
	}

	defer if api.lib == nil {
		dynlib.unload_library(lib)
	}

	// Method Definitions
	api.init = cast(proc())(dynlib.symbol_address(lib, "game_init") or_else nil)
	if api.init == nil {
		fmt.println("game_init not found in dll")
		return {}, false
	}

	api.setup =
	cast(proc(ctx: ^game.Context))(dynlib.symbol_address(lib, "game_setup") or_else nil)
	if api.init == nil {
		fmt.println("game_setup not found in dll")
		return {}, false
	}

	api.update =
	cast(proc(ctx: ^game.Context) -> bool)(dynlib.symbol_address(lib, "game_update") or_else nil)
	if api.init == nil {
		fmt.println("game_update not found in dll")
		return {}, false
	}

	api.draw =
	cast(proc(platform: ^game.PlatformDrawCommands))(dynlib.symbol_address(
			lib,
			"game_draw",
		) or_else nil)
	if api.init == nil {
		fmt.println("game_draw not found in dll")
		return {}, false
	}

	api.shutdown = cast(proc())(dynlib.symbol_address(lib, "game_shutdown") or_else nil)
	if api.init == nil {
		fmt.println("game_shutdown not found in dll")
		return {}, false
	}

	api.memory = cast(proc() -> rawptr)(dynlib.symbol_address(lib, "game_memory") or_else nil)
	if api.init == nil {
		fmt.println("game_memory not found in dll")
		return {}, false
	}

	api.hot_reloaded =
	cast(proc(_: rawptr))(dynlib.symbol_address(lib, "game_hot_reloaded") or_else nil)
	if api.init == nil {
		fmt.println("game_hot_reloaded not found in dll")
		return {}, false
	}

	api.lib = lib
	api.dll_time = dll_time


	return api, true
}

game_api_file_path :: proc(api: GameAPI) -> string {
	// TODO(jhr): Extraxct to constant
	when ODIN_OS == .Darwin {
		dll_extension := ".dylib"
	} else when ODIN_OS == .Windows {
		dll_extension := ".dll"
	}

	file_name := fmt.tprintf("{0}{1}", api.name, dll_extension)
	return filepath.join({api.path, file_name}, context.temp_allocator)
}

game_api_version_path :: proc(api: GameAPI) -> string {
	when ODIN_OS == .Darwin {
		dll_extension := ".dylib"
	} else when ODIN_OS == .Windows {
		dll_extension := ".dll"
	}

	new_name := fmt.tprintf("{0}_{1}{2}", api.name, api.iteration, dll_extension)
	return filepath.join({api.path, new_name}, context.temp_allocator)

}

game_api_hot_load :: proc(api: GameAPI) -> GameAPI {
	new_api, new_api_ok := game_api_load(api.iteration + 1, api.name, api.path)

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

	err := os.remove(game_api_version_path(api))

	if err != os.ERROR_NONE {
		fmt.printf("Failed to remove {0} copy\n", game_api_version_path(api))
	}
}
