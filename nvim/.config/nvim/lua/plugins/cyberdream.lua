return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,

    opts = {
      transparent = false,
      italic_comments = false,
      borderless_pickers = false,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "cyberdream",
    },
  },
}
