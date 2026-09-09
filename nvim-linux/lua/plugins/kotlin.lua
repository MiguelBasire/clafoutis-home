-- Kotlin: swap the LSP that `lazyvim.plugins.extras.lang.kotlin` sets up.
--
-- The extra uses fwcd/kotlin-language-server, whose last release (v1.3.13,
-- Jan 2025) embeds a Kotlin 2.1.0 compiler. That compiler reads metadata only
-- up to 2.2.0, so on any project built with Kotlin 2.3+ every kotlin-stdlib
-- class fails to load:
--
--   Class 'kotlin.coroutines.CoroutineContext' was compiled with an
--   incompatible version of Kotlin ... (INCOMPATIBLE_CLASS)
--
-- JetBrains' official Kotlin/kotlin-lsp has supported Kotlin 2.3.0 since
-- v262.2310.0. It is not in the Mason registry -- install it by hand, see the
-- notes at the bottom of this file.

-- nvim-lspconfig's lsp/kotlin_lsp.lua defaults to a bare `intellij-server`,
-- which only resolves if ~/.local/bin is on the PATH nvim inherits. Desktop
-- launchers frequently don't pass the shell's PATH, so fall back to the
-- install location before giving up.
local function server_cmd()
  local exe = vim.fn.exepath("intellij-server")
  if exe == "" then
    local fallback = vim.fn.expand("~/.local/share/kotlin-lsp/bin/intellij-server")
    if vim.uv.fs_stat(fallback) then
      exe = fallback
    end
  end
  -- Left as "intellij-server" when nothing is found, so :checkhealth vim.lsp
  -- reports the missing binary instead of this file failing silently.
  return { exe ~= "" and exe or "intellij-server", "--stdio" }
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Retire the extra's server. `enabled = false` also adds it to
        -- LazyVim's mason_exclude, so Mason stops reinstalling it.
        kotlin_language_server = { enabled = false },

        kotlin_lsp = {
          -- Installed manually from the JetBrains CDN, not from Mason.
          mason = false,
          cmd = server_cmd(),
        },
      },
    },
  },
}

-- Install / update the server (Linux x86_64), latest is v262.9593.0:
--
--   mkdir -p ~/.local/share/kotlin-lsp ~/.local/bin
--   curl -fL -o /tmp/kotlin-server.tar.gz \
--     https://download-cdn.jetbrains.com/language-server/kotlin-server/262.9593.0/kotlin-server-262.9593.0.tar.gz
--   tar -xzf /tmp/kotlin-server.tar.gz -C ~/.local/share/kotlin-lsp --strip-components=1
--   chmod +x ~/.local/share/kotlin-lsp/bin/intellij-server
--   ln -sf ~/.local/share/kotlin-lsp/bin/intellij-server ~/.local/bin/intellij-server
--
-- Check the tarball's layout first (`tar -tzf ... | head`) and drop
-- --strip-components=1 if it doesn't have a single top-level directory.
--
-- The launcher is bin/intellij-server; the old kotlin-lsp.sh was deprecated in
-- v262.4739.0. That release also flags JDK 25 as the runtime -- this is an
-- IntelliJ-style distribution, so check for a bundled jbr/ in the unpacked
-- directory before installing a JDK. It's independent of any project's own
-- Gradle toolchain.
