local M = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', {
    embedded_languages = {
      'html',
      'css',
      'javascript',
      'sql',
      'json',
    },
    rules = {
      c_sharp = {
          query = [[ 
; query
; injection for {embedded_language}
((comment) @comment .
  [
      (raw_string_literal (raw_string_content) @injection.content )
      (string_literal (string_literal_content) @injection.content )
  ]
  (#match? @comment "{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      typescript = {
        query = [[
; query
; injection for {embedded_language}
((comment) @comment .
  [(string
        (string_fragment) @injection.content)
  (template_string
        (string_fragment) @injection.content)]
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
            ]],
      },
      javascript = {
        query = [[
; query
; injection for {embedded_language}
((comment) @comment .
  [(string
        (string_fragment) @injection.content)
  (template_string
        (string_fragment) @injection.content)]
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
            ]],
      },
    },
  }, opts or {})
end

---@param language string Treesitter parser name, which is not always the same with the value of filetype in Neovim for that language.
local function get_comment_string(language)
  local result = nil
  local filetypes = vim.treesitter.language.get_filetypes(language)
  for _, ft in ipairs(filetypes) do
      local cs = vim.filetype.get_option(ft, 'commentstring')
      if cs and cs ~= '' then
          result = cs
          break
      end
  end

  return result
end

---@param language string Treesitter parser name, which is not always the same with the value of filetype in Neovim for that language.
function M.generate_injections(language)
  local commentstring = get_comment_string(language)
  assert(type(commentstring) == "string", string.format("vim.bo.commentstring of filetype %s is not string", cs))
  -- REF https://stackoverflow.com/a/27455195
  local comment_symbol = string.format(commentstring, ""):gsub('^%s*(.-)%s*$', '%1')

  local result = ''
  for _, embedded_language in pairs(M.opts.embedded_languages) do
    result = result
      .. M.opts.rules[language].query
        :gsub('{embedded_language}', embedded_language)
        :gsub('{comment_symbol}', comment_symbol)
  end
  return result
end

function M.install()
  local plugin_root_dir =
    debug.getinfo(1).source:sub(2, string.len('/lua/syringe/init.lua') * -1 - 1)

  for language, rule in pairs(M.opts.rules) do
    local injection_dir = vim.fs.joinpath(plugin_root_dir, 'queries', language)
    vim.fn.mkdir(injection_dir, 'p')

    local injection_file = vim.fs.joinpath(injection_dir, 'injections.scm')

    local generated_queries = M.generate_injections(language)

    vim.fn.writefile(
      vim.list_extend({ ';; extends' }, vim.fn.split(generated_queries, '\n')),
      injection_file
    )
  end

  vim.notify('[syringe] Queries injected', vim.log.levels.INFO)
end

return M
