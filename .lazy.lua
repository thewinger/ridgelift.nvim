-- Ported from TokyoNight's "Dev Mode" feature
-- Shows colors and highlights while editing the theme, hot-reloads on save.

-- All credits to the original author: @folke 💚
-- https://github.com/folke/tokyonight.nvim

--# selene: allow(global_usage)
local colors
local cache = {}
local hl_groups = {}

local function resolve(groups)
    for _, hl in pairs(groups) do
        if type(hl.style) == "table" then
            for k, v in pairs(hl.style) do
                hl[k] = v
            end
            hl.style = nil
        end
    end
    return groups
end

local function get_hl_group(hl)
    local group = "ridgeliftDev" .. vim.inspect(hl):gsub("%W+", "_")
    if not hl_groups[group] then
        hl = type(hl) == "string" and { link = hl } or hl
        hl = vim.deepcopy(hl, true)
        resolve({ foo = hl })
        hl.fg = hl.fg or colors.fg
        vim.api.nvim_set_hl(0, group, hl)
        hl_groups[group] = true
    end
    return group
end

local function get_group(buf)
    local fname = vim.api.nvim_buf_get_name(buf or 0)
    fname = vim.fs.normalize(fname)
    if not fname:find("lua/ridgelift/extensions/") then
        return
    end
    return vim.fn.fnamemodify(fname, ":t:r")
end

local function load(group)
    if cache[group] then
        return
    end
    cache[group] = {}
    local opts
    colors = require("ridgelift.colors").default
    colors.bg_solid = colors.bg ~= "NONE" and colors.bg or colors.bgAlt
    opts = require("ridgelift.config").options
    local highlights = require("ridgelift.extensions." .. group).get(opts, colors)
    for k, v in pairs(highlights) do
        cache[group][k] = get_hl_group(v)
    end
end

vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("ridgelift_dev", { clear = true }),
    pattern = "*/lua/ridgelift/**.lua",
    callback = vim.schedule_wrap(function(ev)
        local opts = require("ridgelift.config").options
        for k in pairs(package.loaded) do
            if k:find("^ridgelift") then
                package.loaded[k] = nil
            end
        end
        require("ridgelift").setup(opts)
        vim.cmd.colorscheme(vim.g.colors_name)
        hl_groups = {}
        local hi = require("mini.hipatterns")
        local group = get_group(ev.buf)
        if group then
            cache[group] = nil
        end
        for _, buf in ipairs(hi.get_enabled_buffers()) do
            hi.update(buf)
        end
    end),
})

return {
    {
        "echasnovski/mini.hipatterns",
        opts = function(_, opts)
            opts.highlighters = opts.highlighters or {}
            opts.highlighters.ridgelift = {
                pattern = function(buf)
                    local group = get_group(buf)
                    if not group or group == "init" then
                        return
                    end
                    load(group)
                    return group and '^%s*%[?"?()[%w%.@]+()"?%]?%s*='
                end,
                group = function(buf, match, _)
                    local name = get_group(buf)
                    if name == "kinds" then
                        match = "LspKind" .. match
                    end
                    return name and cache[name][match]
                end,
                extmark_opts = { priority = 2000 },
            }

            opts.highlighters.ridgelift_colors = {
                pattern = {
                    "%f[%w]()t%.[%w_%.]+()%f[%W]",
                },
                group = function(_, match)
                    local parts = vim.split(match, ".", { plain = true })
                    local t = _G --[[@as table]]
                    if parts[1]:sub(1, 1) == "t" then
                        table.remove(parts, 1)
                        colors = require("ridgelift.colors").default
                        t = colors
                    end
                    local color = vim.tbl_get(t, unpack(parts))
                    return type(color) == "string" and get_hl_group({ fg = color })
                end,
                extmark_opts = function(_, _, data)
                    return {
                        virt_text = { { "⬤ ", data.hl_group } },
                        virt_text_pos = "inline",
                        priority = 2000,
                    }
                end,
            }
        end,
    },
}
