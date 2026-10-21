-- LazyVim extras, declared here instead of via :LazyExtras (which writes to
-- an untracked ~/.config/nvim/lazyvim.json outside this repo).
return {
  { import = "lazyvim.plugins.extras.editor.telescope" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.nix" },
  { import = "lazyvim.plugins.extras.lang.ruby" },
  { import = "lazyvim.plugins.extras.lang.toml" },

  -- Provided by home.nix instead of Mason (see the comment there).
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nil_ls = { mason = false },
        ruby_lsp = { mason = false },
        rubocop = { mason = false },
      },
    },
  },
}
