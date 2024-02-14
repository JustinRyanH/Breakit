package input


import "core:fmt"
import "core:math"
import "core:os"


import mu "../microui"


input_gui_file_explorer :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
	mu.layout_row(ctx, {-1})
	mu.label(ctx, fmt.tprintf("Loaded File: %s", state.ifs.current_file))

	header_res := mu.header(ctx, "Input Files", {.CLOSED})
	if .ACTIVE not_in header_res {
		log_dir, err := os.open("logs")

		if err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}
		defer os.close(log_dir)

		files, dir_err := os.read_dir(log_dir, 50, context.temp_allocator)

		if dir_err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}

		for file in files {
			mu.layout_row(ctx, {-1})
			button_ref := mu.button(ctx, fmt.tprintf("Load %s", file.name))
			if .SUBMIT in button_ref {
				new_file := fmt.tprintf("logs/%s", file.name)
				err := input_debugger_load_file(state, new_file)
				if err != nil {
					fmt.printf("Err: %v", err)
					return
				}
			}
		}

		return
	}
}
