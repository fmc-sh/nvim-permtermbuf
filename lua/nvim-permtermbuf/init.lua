local M = {}

-- Store terminal buffers and windows for each program.
local terminals = {}

-- Utility function to check if a buffer with a given name exists
local function get_buf_by_name(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):match(name) then
			return buf
		end
	end
	return nil
end

-- Function to save the current window layout
local function save_layout(program)
	terminals[program].previous_layout = vim.fn.winrestcmd()
end

-- Function to restore the previous window layout
local function restore_layout(program)
	if terminals[program].previous_layout then
		vim.cmd(terminals[program].previous_layout)
	end
end

-- Generic function to toggle a terminal for any program
local function toggle_terminal(program)
	local term = terminals[program]
	local term_buf = get_buf_by_name(term.buffer_name)

	-- If the terminal is already open, close it and restore layout
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_close(term.win, true)
		restore_layout(program)
		term.win = nil
		vim.cmd('echo "Closed ' .. program .. ' terminal"') -- Debugging message
	else
		-- Save the layout before opening a terminal
		save_layout(program)

		-- If buffer exists, reuse it
		if term_buf then
			vim.cmd("tabnew") -- Open a new tab (simulate full screen)
			vim.api.nvim_set_current_buf(term_buf)
			term.win = vim.api.nvim_get_current_win()
			vim.cmd("startinsert")
			vim.cmd('echo "Opened existing ' .. program .. ' terminal"') -- Debugging message
		else
			-- Create new terminal buffer if it doesn't exist
			term_buf = vim.api.nvim_create_buf(false, true)
			vim.cmd("tabnew")
			vim.api.nvim_set_current_buf(term_buf)
			vim.cmd("terminal " .. term.cmd) -- Run the terminal command

			-- Set buffer name and save window reference
			vim.api.nvim_buf_set_name(term_buf, term.buffer_name)
			term.win = vim.api.nvim_get_current_win()

			-- Store buffer and window
			term.buf = term_buf

			-- Enter insert mode
			vim.cmd("startinsert")
			vim.cmd('echo "Opened new ' .. program .. ' terminal"') -- Debugging message
		end
	end
end

-- Setup function to initialize the plugin with a list of programs
function M.setup(programs)
	for _, program in pairs(programs) do
		-- Initialize program state
		terminals[program.name] = {
			cmd = program.cmd,
			buffer_name = program.buffer_name,
			win = nil,
			buf = nil,
			previous_layout = nil,
		}

		-- Create a toggle function for each program
		M[program.name] = {}
		M[program.name].toggle = function()
			toggle_terminal(program.name)
		end
	end
end

return M
