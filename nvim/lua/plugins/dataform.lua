return {
  {
    "magal1337/dataform.nvim",
    -- Must load at startup: the plugin sets the `sqlx` filetype itself from
    -- plugin/dataform.vim, so an `ft = "sqlx"` trigger would never fire.
    lazy = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    -- Install the Dataform CLI locally (not `npm i -g`, which fails on nix
    -- because npm's global prefix lives in the read-only store). Re-runs on
    -- :Lazy update / :Lazy build dataform.nvim.
    build = function()
      local dir = vim.fn.stdpath("data") .. "/dataform-cli"
      vim.fn.mkdir(dir, "p")
      local out = vim.fn.system({ "npm", "install", "--prefix", dir, "@dataform/cli@latest" })
      if vim.v.shell_error ~= 0 then
        error("npm install @dataform/cli failed:\n" .. out)
      end
    end,
    opts = {
      -- refresh dataform metadata on each save
      compile_on_save = true,
      -- skip recompilation when project files are unchanged (in-memory)
      cache = true,
      -- persist cache to disk so it survives across Neovim sessions
      cache_persist = false,
    },
    config = function(_, opts)
      -- The plugin shells out to `dataform` by name; expose the local install.
      local bin = vim.fn.stdpath("data") .. "/dataform-cli/node_modules/.bin"
      if not vim.env.PATH:find(bin, 1, true) then
        vim.env.PATH = bin .. ":" .. vim.env.PATH
      end

      require("dataform").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dataform-keymaps", { clear = true }),
        pattern = "sqlx",
        callback = function(ev)
          local function map(lhs, cmd, desc)
            vim.keymap.set("n", lhs, cmd, { buffer = ev.buf, desc = "Dataform: " .. desc })
          end
          map("gd", "<cmd>DataformGoToRef<cr>", "Go to ref")
          map("<localleader>c", "<cmd>DataformCompileFull<cr>", "Compile (full)")
          map("<localleader>C", "<cmd>DataformCompileIncremental<cr>", "Compile (incremental)")
          map("<localleader>r", "<cmd>DataformRunAction<cr>", "Run action (full refresh)")
          map("<localleader>R", "<cmd>DataformRunActionIncremental<cr>", "Run action (incremental)")
          map("<localleader>a", "<cmd>DataformRunAssertions<cr>", "Run assertions")
          map("<localleader>A", "<cmd>DataformRunAll<cr>", "Run all")
          map("<localleader>t", ":DataformRunTag ", "Run tag(s)")
          map("<localleader>d", "<cmd>DataformFindDependencies<cr>", "Find dependencies")
          map("<localleader>D", "<cmd>DataformFindDependents<cr>", "Find dependents")
          map("<localleader>x", "<cmd>DataformClearCache<cr>", "Clear cache")
        end,
      })
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    optional = true,
    opts = function(_, opts)
      -- The plugin only registers its source if cmp is already loaded when
      -- plugin/dataform.vim runs, which isn't the case with LazyVim (cmp loads
      -- on InsertEnter). Register it here instead. The source only reports
      -- itself available inside sqlx JS strings, so adding it globally is safe.
      require("cmp").register_source("dataform_actions", require("dataform").completion_cmp_source)
      table.insert(opts.sources, 1, { name = "dataform_actions" })
    end,
  },
}
