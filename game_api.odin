
package main


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
	draw:         proc(),
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

	api_file := game_api_file_path(api)
	dll_time, dll_time_err := os.last_write_time_by_name(api_file)

	if dll_time_err != os.ERROR_NONE {
		fmt.println("Could not fetch last write date of", api_file)
		return {}, false
	}

	new_file := game_api_version_path(api)


  data, success := os.read_entire_file_from_filename(api_file)
  if !success {
    fmt.println("Failed to open file");
    return {}, false
  }
  success = os.write_entire_file(new_file, data)
  if !success {
    fmt.println("Failed to copy game.dylib to", new_file)
  }

	lib, lib_ok := dynlib.load_library(new_file)

	if !lib_ok {
		fmt.println("Failed loading game DLL")
		return {}, false
	}

	// Method Definitions
	api.init = cast(proc())(dynlib.symbol_address(lib, "game_init") or_else nil)
	api.update = cast(proc() -> bool)(dynlib.symbol_address(lib, "game_update") or_else nil)
	api.draw = cast(proc())(dynlib.symbol_address(lib, "game_draw") or_else nil)
	api.shutdown = cast(proc())(dynlib.symbol_address(lib, "game_shutdown") or_else nil)
	api.memory = cast(proc() -> rawptr)(dynlib.symbol_address(lib, "game_memory") or_else nil)
	api.hot_reloaded =
	cast(proc(_: rawptr))(dynlib.symbol_address(lib, "game_hot_reloaded") or_else nil)

	// Library and Meta Information
	api.lib = lib
	api.dll_time = dll_time
	api.iteration = iteration

	if api.init == nil ||
	   api.update == nil ||
	   api.shutdown == nil ||
	   api.memory == nil ||
	   api.hot_reloaded == nil ||
	   api.draw == nil {
		game_api_unload(api)
		fmt.println("Game DLL missing required procedure")
		return {}, false
	}


	return api, true
}

game_api_file_path :: proc(api: GameAPI) -> string {
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
