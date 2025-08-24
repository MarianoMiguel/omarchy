return {
  "nvim-pack/nvim-spectre",
  lazy = false,
  keys = {
     {'<leader>fr',"<cmd>SpectreWithCWD<cr>",mode={'n'}},
  },
  config = function()
     require('spectre').setup({ is_block_ui_break = true })
  end,
}
