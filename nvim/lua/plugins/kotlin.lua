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
local function server_exe()
  local exe = vim.fn.exepath("intellij-server")
  if exe == "" then
    local fallback = vim.fn.expand("~/.local/share/kotlin-lsp/bin/intellij-server")
    if vim.uv.fs_stat(fallback) then
      exe = fallback
    end
  end
  return exe ~= "" and exe or nil
end

-- This config is shared with machines where the server isn't installed (the
-- Mac): there, kotlin_lsp is simply not started instead of failing on every
-- .kt buffer. Check with `:lua print(vim.fn.exepath("intellij-server"))`
-- if Kotlin files get no LSP on a machine that should have it.
local exe = server_exe()

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
          enabled = exe ~= nil,
          cmd = exe and { exe, "--stdio" } or nil,
        },
      },
    },
  },
}

-- Builds EXPIRE: an old one starts, then quits with exit code 7 and
-- "This build of kotlin-server has expired" in ~/.local/state/nvim/lsp.log.
-- Update to the newest release from https://github.com/Kotlin/kotlin-lsp/releases
-- (v271.2085.0 as of 2026-11-12).
--
-- Install / update the server (Linux x86_64; the -aarch64 tarball for ARM):
--
--   v=271.2085.0
--   rm -rf ~/.local/share/kotlin-lsp
--   mkdir -p ~/.local/share/kotlin-lsp ~/.local/bin
--   curl -fL -o /tmp/kotlin-server.tar.gz \
--     https://download.jetbrains.com/language-server/kotlin-server/$v/kotlin-server-$v.tar.gz
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
