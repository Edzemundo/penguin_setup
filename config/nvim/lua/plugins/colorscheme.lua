-- Tokyo Night colour scheme.
--
-- LazyVim activates this automatically: it reads the `colorscheme` set in the
-- LazyVim opts and loads the matching plugin, which is why `lazy = true` is
-- safe here -- the plugin is only pulled in when the theme is actually used.
--
-- The "night" style matches `theme_tokyonight night` in the fish config and
-- the "Tokyo Night Dark" theme in the Zed settings, so all three agree.
return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = { style = "night" },
}
