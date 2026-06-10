-- Add project compiled Lua to rtp
vim.opt.rtp:append('./lua')
vim.opt.rtp:append('./after')

-- Disable unnecessary output
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
