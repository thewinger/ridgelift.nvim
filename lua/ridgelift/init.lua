local theme = require("ridgelift.theme")
local config = require("ridgelift.config")
local util = require("ridgelift.util")

local M = {}

function M.load()
    if config.options.cache then
        require("ridgelift.cache").load()
        return
    end
    util.load(theme.setup())
end

M.setup = config.setup
M.colorscheme = M.load

vim.api.nvim_create_user_command("ridgeliftToggleMode", function()
    local new_variant = util.toggle_theme_variant()
    util.toggle_lualine_theme()
    vim.api.nvim_exec_autocmds("User", { pattern = "ridgeliftToggleMode", data = new_variant })
end, {})

vim.api.nvim_create_user_command("ridgeliftBuildCache", function()
    require("ridgelift.cache").build(theme.setup())
end, {})

vim.api.nvim_create_user_command("ridgeliftClearCache", function()
    require("ridgelift.cache").clear()
end, {})

-- autocmd runs togle_lualine_theme when background option is changed. checks if the colorscheme is 'ridgelift' and the variant is 'auto' before executing.
vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = function()
        if vim.g.ridgelift_opts.variant ~= "auto" or vim.fn.execute("colorscheme"):find("ridgelift") == nil then
            return
        end
        util.toggle_lualine_theme()
    end,
})

-- the following autocmd checks for lazy.nvim config files containing the string 'ridgelift' and rebuilds the theme's cache file (if enabled) when the file is saved.
-- useful for making changes to the themes config file without having to manually rebuild the cache or turn off the cache option.
vim.api.nvim_create_autocmd("User", {
    pattern = "LazyReload",
    callback = function(data)
        if not config.options.cache then
            return
        end

        local bufnr = data.buf
        local bufcontent = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        for _, line in ipairs(bufcontent) do
            if line:find("ridgelift") then
                require("ridgelift.cache").build(theme.setup())
                return
            end
        end
    end,
})

return M
