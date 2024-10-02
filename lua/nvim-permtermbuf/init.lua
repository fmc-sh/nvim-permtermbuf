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

-- Callback function to handle terminal output
local function handle_output(program)
	local buf = terminals[program].buf
	-- Only process output if the program exited, not if it was manually closed
	if terminals[program].exited then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		-- Process lines and call the callback defined for the program
		if terminals[program].callback then
			terminals[program].callback(lines)
		end
	end
end

-- Function to close terminal and handle cleanup
local function close_terminal(program, program_exited)
	local term = terminals[program]
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_close(term.win, true)
		term.win = nil
		restore_layout(program)

		-- Set a flag if the terminal is closed due to the program exiting
		term.exited = program_exited or false

		-- Only trigger callback if the program exited (not when toggled out)
		if program_exited then
			handle_output(program)
		end

		-- Only delete the buffer if the program has exited
		if term.exited and term.buf and vim.api.nvim_buf_is_valid(term.buf) then
			vim.cmd("silent! bdelete! " .. term.buf) -- Silent buffer deletion
			term.buf = nil
		end
	end
end

-- Function to close any other program tabs except the current one
local function close_other_program_tabs(current_program_name)
	for program_name, term in pairs(terminals) do
		-- Skip the current program
		if program_name ~= current_program_name then
			-- Close the terminal window if it's open
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				close_terminal(program_name, false)
			end
		end
	end
end

-- Generic function to toggle a terminal for any program
local function toggle_terminal(program)
	local term = terminals[program]
	local term_buf = get_buf_by_name(term.buffer_name)

	-- Close any other open program tabs
	close_other_program_tabs(program)

	-- If the terminal is already open, close it and cleanup
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		-- Close terminal manually, indicating the program didn't exit naturally
		close_terminal(program, false)
	else
		-- Save the layout before opening a terminal
		save_layout(program)

		-- If buffer exists, reuse it
		if term_buf then
			vim.cmd("tabnew") -- Open a new tab (simulate full screen)
			vim.api.nvim_set_current_buf(term_buf)
			term.win = vim.api.nvim_get_current_win()
			vim.cmd("startinsert")
			vim.cmd('echo "Opened existing ' .. program .. ' terminal"')
		else
			-- Create new terminal buffer if it doesn't exist
			term_buf = vim.api.nvim_create_buf(false, true)
			vim.cmd("tabnew")
			vim.api.nvim_set_current_buf(term_buf)
			vim.cmd("terminal " .. term.cmd)

			-- Set buffer name and save window reference
			vim.api.nvim_buf_set_name(term_buf, term.buffer_name)

			-- Mark the buffer as unlisted using nvim_set_option_value
			vim.api.nvim_set_option_value("buflisted", false, { buf = term_buf })

			term.win = vim.api.nvim_get_current_win()

			-- Store buffer and window
			term.buf = term_buf

			-- Enter insert mode
			vim.cmd("startinsert")
			vim.cmd('echo "Opened new ' .. program .. ' terminal"')

			-- Attach autocmd to handle terminal exit
			vim.api.nvim_create_autocmd("TermClose", {
				buffer = term_buf,
				callback = function()
					-- Close terminal indicating the program exited
					close_terminal(program, true)
				end,
			})
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
			callback = program.callback, -- Store callback for each program
			exited = false, -- Flag to track if program exited
		}

		-- Create a toggle function for each program
		M[program.name] = {}
		M[program.name].toggle = function()
			toggle_terminal(program.name)
		end
	end
end

return M
