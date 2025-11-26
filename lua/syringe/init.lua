local M = {}

---@class SyringeLanguageRule
---@field query string

---@class SyringeOpts
---@field embedded_languages string[]?
---@field rules table<string, SyringeLanguageRule>?

---Setup Syringe
---@param opts SyringeOpts|nil
function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', {
    embedded_languages = {
      'html',
      'css',
      'javascript',
      'sql',
      'json',
      'lua',
    },
    rules = {
      nix = {
          query = [[
; query
((comment) @comment .
  [
    (string_expression
      (string_fragment) @injection.content)
    (indented_string_expression
      (string_fragment) @injection.content)
  ]
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      lua = {
          query = [[ 
; query
((comment) @comment .
(
  [
        (expression_list (string (string_content) @injection.content))
        (assignment_statement (expression_list (string (string_content) @injection.content)))
        (variable_declaration (assignment_statement (expression_list (string (string_content) @injection.content))))
  ]
)
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      rust = {
          query = [[ 
; query
((line_comment) @comment .
(
  [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content) 
  ]
)
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
((block_comment) @comment .
(
  [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content) 
  ]
)
  ; not sure if there is a good way to get block comment in Nvim
  (#match? @comment "^/\\*+( )*{embedded_language}( )*\\*/")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      go = {
          query = [[ 
; query
((comment) @comment .
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
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      python = {
          query = [[ 
; query
((comment) @comment .
           (expression_statement
             (assignment right: 
                         (string
                           (string_content)
                           @injection.content 
                           (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
                           (#set! injection.language "{embedded_language}")))))
          ]]
      },
      c_sharp = {
          query = [[ 
; query
((comment) @comment .
  [
      (raw_string_literal (raw_string_content) @injection.content )
      (string_literal (string_literal_content) @injection.content )
      ((verbatim_string_literal)  @injection.content )
  ]
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
          ]]
      },
      typescript = {
        query = [[
; query
((comment) @comment .
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
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
            ]],
      },
      javascript = {
        query = [[
; query
((comment) @comment .
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
  (#match? @comment "^{comment_symbol}+( )*{embedded_language}( )*")
  (#set! injection.language "{embedded_language}"))
            ]],
      },
    },
  }, opts or {})

    local completion_args = {"sync"}

    vim.api.nvim_create_user_command("Syringe", function (cmd)
        if cmd.args == "sync" then
            M.sync()
        end
    end, {
        desc = "Syringe",
        bar = true,
        bang = true,
        nargs = "?",
        complete = function(_)
            return completion_args
        end,
    })
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
  assert(type(commentstring) == "string", string.format("vim.bo.commentstring of filetype %s is not string", commentstring))
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

function M.sync()
  local plugin_root_dir =
    debug.getinfo(1).source:sub(2, string.len('/lua/syringe/init.lua') * -1 - 1)

  for language, _ in pairs(M.opts.rules) do
    local injection_dir = vim.fs.joinpath(plugin_root_dir, 'queries', language)
    vim.fn.delete(injection_dir, "rf")
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
