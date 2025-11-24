local M = {}

function M.setup(opts)

end

function M.install()
   local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/init.lua') * -1) 
   print("my dir is", dirname)
end

return M
