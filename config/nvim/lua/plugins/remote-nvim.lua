-- remote-nvim.nvim -- edit projects on remote hosts over SSH, with Neovim and
-- its plugins installed on the remote automatically.
--
-- Run :RemoteStart to pick a host from your ~/.ssh/config and open a session.
-- Reference: https://github.com/amitds1997/remote-nvim.nvim
return {
  "amitds1997/remote-nvim.nvim",
  version = "*", -- Pin to GitHub releases rather than tracking main
  dependencies = {
    "nvim-lua/plenary.nvim", -- For standard functions
    "MunifTanjim/nui.nvim", -- To build the plugin UI
    "nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
  },
  -- `config = true` means "call setup() with no arguments"; the plugin's
  -- defaults are fine and all host detail comes from ~/.ssh/config.
  config = true,
}
