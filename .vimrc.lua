vim.api.nvim_exec("nnoremap <silent> <leader><leader><leader> :wa<cr>:!zig build run<cr>", true)

local cleanupau = vim.api.nvim_create_augroup("DIGISIM_VIMRC_CLEANUP", { clear = true })

local function cleanup()
	vim.api.nvim_exec("unmap <leader><leader><leader>", true)
	vim.api.nvim_del_augroup_by_id(cleanupau)
	vim.notify("unloaded!")
end

vim.api.nvim_create_autocmd("DirChangedPre", {
	callback = cleanup,
	group = cleanupau,
})
