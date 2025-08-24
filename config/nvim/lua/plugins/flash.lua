return {
  {
    "folke/flash.nvim",
    -- opts = {
    --   modes = {
    --     char = {
    --       enabled = true,
    --       keys = {
    --         ["<CR>"] = "jump", -- use Enter instead of s
    --       },
    --     },
    --   },
    -- },
    keys = {
      { "<CR>", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      --   -- disable default s and S mappings
      { "s", mode = { "n", "x", "o" }, enabled = false },
      { "S", mode = { "n", "x", "o" }, enabled = false },
      --
      --   -- map flash jump to <CR>
      --   {
      --     "<CR>",
      --     mode = { "n", "x", "o" },
      --     function() require("flash").jump() end,
      --     desc = "Flash Jump",
      --   },
    },
  },
}

