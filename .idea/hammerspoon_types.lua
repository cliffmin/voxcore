---@meta

-- Hammerspoon type definitions for IntelliJ EmmyLua
-- This provides code completion and type checking

---@class hs
---@field alert table
---@field task table
---@field timer table
---@field fs table
---@field execute function
---@field sound table
---@field settings table
---@field logger table
---@field hotkey table
---@field eventtap table
---@field canvas table
---@field screen table
hs = {}

---@class hs.alert
---@field show function
hs.alert = {}

---@class hs.task
---@field new function
hs.task = {}

---@class hs.timer
---@field doAfter function
---@field secondsSinceEpoch function
---@field new function
hs.timer = {}

---@class hs.fs
---@field attributes function
---@field mkdir function
hs.fs = {}

---@class hs.logger
---@field new function
hs.logger = {}

---@param name string
---@return logger
function hs.logger.new(name) end

---@class logger
---@field i function
---@field d function
---@field e function
---@field w function
---@field setLogLevel function

---@class hs.hotkey
---@field bind function
hs.hotkey = {}

---@class hs.eventtap
---@field event table
---@field new function
hs.eventtap = {}

---@class hs.settings
---@field get function
---@field set function
hs.settings = {}

---@class hs.sound
---@field getByName function
hs.sound = {}

-- Common globals
---@type table
json = {}

---@param str string
---@return table
function json.decode(str) end

---@param tbl table
---@return string
function json.encode(tbl) end
