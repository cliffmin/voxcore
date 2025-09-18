-- Java Service Bridge for Hammerspoon
-- Talks to PTTServiceDaemon over HTTP

local http = require("hs.http")
local json = require("hs.json")

local M = {}

M.config = {
  base_url = "http://127.0.0.1:8765",
  startup_cmd = {
    "/usr/bin/env", "bash", "-lc",
    "cd ~/code/macos-ptt-dictation/whisper-post-processor && java -cp build/libs/whisper-post.jar com.cliffmin.whisper.daemon.PTTServiceDaemon >/tmp/ptt_daemon.log 2>&1 &"
  },
  health_timeout_sec = 1.5,
  enable_http_daemon = true,   -- if false, fall back to CLI
  cli_cmd = {"/usr/bin/env","bash","-lc","java -jar build/libs/whisper-post.jar"}
}

local function is_up()
  local url = M.config.base_url .. "/health"
  local status, body, _ = http.get(url, nil)
  if status == 200 then
    local ok, tbl = pcall(json.decode, body)
    return ok and tbl and tbl.status == "ok"
  end
  return false
end

function M.ensure_up()
  if not M.config.enable_http_daemon then return false end
  if is_up() then return true end
  -- attempt to start
  hs.task.new(M.config.startup_cmd[1], function() end, function() return true end, {table.unpack(M.config.startup_cmd, 2)}):start()
  hs.timer.usleep(M.config.health_timeout_sec * 1e6)
  return is_up()
end

function M.transcribe(path, model)
  if M.config.enable_http_daemon then
    if not M.ensure_up() then
      return nil, "daemon unavailable"
    end
    local url = M.config.base_url .. "/transcribe"
    local payload = json.encode({ path = path, model = model })
    local headers = { ["Content-Type"] = "application/json" }
    local status, body, _ = http.post(url, payload, headers)
    if status == 200 then
      return json.decode(body), nil
    else
      local ok, err = pcall(json.decode, body)
      if ok and err and err.error then return nil, err.error end
      return nil, "http " .. tostring(status)
    end
  else
    -- Fallback to CLI
    local cmd = table.concat(M.config.cli_cmd, " ") .. string.format(" --json <(echo '{\"text\":\"%s\"}')", path)
    local out, ok = hs.execute(cmd, true)
    if ok then return { text = out }, nil else return nil, "cli error" end
  end
end

return M
