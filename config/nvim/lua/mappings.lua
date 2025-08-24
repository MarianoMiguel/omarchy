require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "$", "$<Right>")
map('n', '<Leader>d', '"_dd', { noremap = true, silent = true })
