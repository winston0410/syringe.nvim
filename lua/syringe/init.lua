local M = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', {
    host_languages = { 'javascript' },
  }, opts or {})
end

function M.install()
  local plugin_root_dir =
    debug.getinfo(1).source:sub(2, string.len('/lua/syringe/init.lua') * -1 - 1)

  for _, language in ipairs(M.opts.host_languages) do
    local injection_dir = vim.fs.joinpath(plugin_root_dir, 'queries', language)
    vim.fn.mkdir(injection_dir, 'p')

    local injection_file = vim.fs.joinpath(injection_dir, 'injections.scm')
    vim.fn.writefile({ ";; extends" },injection_file)
  end
end

return M
