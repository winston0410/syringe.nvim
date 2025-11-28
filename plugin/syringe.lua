  local completion_args = { 'sync' }

  vim.api.nvim_create_user_command('Syringe', function(cmd)
    if cmd.args == 'sync' then
      require("syringe").sync()
    end
  end, {
    desc = 'Syringe',
    bar = true,
    bang = true,
    nargs = '?',
    complete = function(_)
      return completion_args
    end,
  })
