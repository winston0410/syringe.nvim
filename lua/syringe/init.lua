---@class SyringeLanguageRule
---@field query string The treesitter query for injection

---@class SyringeOpts
---@field injection_prefix string? The optional prefix before the name of the language in comment. This will pass to the [Vim RegExp](https://neovim.io/doc/user/pattern.html#search-pattern) directly, and you need to escape any special character yourself.
---@field rules table<string, SyringeLanguageRule>?

local M = {
  opts = {
    injection_prefix = '',
    rules = {
      ruby = {
        query = [[
; query
((comment) @injection.language .
  [
    (string
      (string_content) @injection.content)
    (assignment right: (string
      (string_content) @injection.content))
    ((assignment right: (heredoc_beginning)) 
        (heredoc_body
          (heredoc_content) @injection.content)
    )
  ]
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
          ]],
      },
      nix = {
        query = [[
; query
((comment) @injection.language .
  [
    (string_expression
      (string_fragment) @injection.content)
    (indented_string_expression
      (string_fragment) @injection.content)
  ]
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
          ]],
      },
      lua = {
        query = [[ 
; query
((comment) @injection.language .
(
  [
        (expression_list (string (string_content) @injection.content))
        (assignment_statement (expression_list (string (string_content) @injection.content)))
        (variable_declaration (assignment_statement (expression_list (string (string_content) @injection.content))))
  ]
)
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
          ]],
      },
      rust = {
        query = [[ 
; query
((line_comment) @injection.language .
(
  [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content) 
  ]
)
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
((block_comment) @injection.language .
(
  [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content) 
  ]
)
  ; not sure if there is a good way to get block comment in Nvim
(#gsub! @injection.language "/%*%s*{injection_prefix}([%w%p]+)%s*%*/" "%1"))
          ]],
      },
      go = {
        query = [[ 
; query
((comment) @injection.language .
(
  [
    (expression_list
      [
        (raw_string_literal (raw_string_literal_content) @injection.content)
        (interpreted_string_literal (interpreted_string_literal_content)@injection.content)
      ]
    )
    (expression_statement
      [
        (raw_string_literal (raw_string_literal_content) @injection.content)
        (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
      ]
    )
  ]
)
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
          ]],
      },
      python = {
        query = [[ 
; query
((comment) @injection.language .
    (expression_statement
        (assignment right: 
            (string
                (string_content)
                    @injection.content 
                        (#gsub! @injection.language "{comment_symbol}%s*([%w%p]+)%s*" "%1"))
        )
    )
)
          ]],
      },
      c_sharp = {
        query = [[ 
; query
((comment) @injection.language .
  [
      (raw_string_literal (raw_string_content) @injection.content )
      (string_literal (string_literal_content) @injection.content )
      ((verbatim_string_literal)  @injection.content )
  ]
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
          ]],
      },
      typescript = {
        query = [[
; query
((comment) @injection.language .
  [
 (expression_statement
   (assignment_expression
     right: [
      (string
            (string_fragment) @injection.content)
      (template_string
            (string_fragment) @injection.content)
         ])
   )
 (lexical_declaration
   (variable_declarator
     value: [
      (string
            (string_fragment) @injection.content)
      (template_string
            (string_fragment) @injection.content)
         ])
   )
  (string
        (string_fragment) @injection.content)
  (template_string
        (string_fragment) @injection.content)
  ]
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
            ]],
      },
      javascript = {
        query = [[
; query
((comment) @injection.language .
  [
 (expression_statement
   (assignment_expression
     right: [
      (string
            (string_fragment) @injection.content)
      (template_string
            (string_fragment) @injection.content)
         ])
   )
 (lexical_declaration
   (variable_declarator
     value: [
      (string
            (string_fragment) @injection.content)
      (template_string
            (string_fragment) @injection.content)
         ])
   )
  (string
        (string_fragment) @injection.content)
  (template_string
        (string_fragment) @injection.content)
  ]
  (#gsub! @injection.language "{comment_symbol}%s*{injection_prefix}([%w%p]+)%s*" "%1"))
            ]],
      },
    },
  },
}

---@param opts SyringeOpts|nil
function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})
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
  assert(
    type(commentstring) == 'string',
    string.format('vim.bo.commentstring of filetype %s is not string', commentstring)
  )
  -- REF https://stackoverflow.com/a/27455195
  local comment_symbol = string.format(commentstring, ''):gsub('^%s*(.-)%s*$', '%1')

  local result = ''
  result = result
    .. M.opts.rules[language].query
      :gsub('{comment_symbol}',  comment_symbol)
      :gsub('{injection_prefix}',  M.opts.injection_prefix)
  return result
end

function M.sync()
  local plugin_root_dir =
    debug.getinfo(1).source:sub(2, string.len('/lua/syringe/init.lua') * -1 - 1)

  for language, _ in pairs(M.opts.rules) do
    local injection_dir = vim.fs.joinpath(plugin_root_dir, 'queries', language)
    vim.fn.delete(injection_dir, 'rf')
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

function M.get_supported_host_languages()
  local results = {}
  for language, _ in pairs(M.opts.rules) do
      table.insert(results, language)
  end
  return results
end

return M
