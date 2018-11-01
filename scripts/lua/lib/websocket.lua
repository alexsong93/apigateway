local cjson = require "cjson"
if (cjson.decode_array_with_array_mt ~= nil) then
  cjson.decode_array_with_array_mt(true)
end
local http = require "resty.http"
local server = require "resty.websocket.server"

local logger = require "lib/logger"

local _M = {}

function _M.setup(backendUrl)
  local ws, err = server:new({
    timeout = 5000
  })
  if not ws then
      ngx.log(ngx.ERR, "failed to create new websocket: ", err)
      return ngx.exit(444)
  end
  while true do
    local data, typ, err = ws:recv_frame()
    if not data then
      if not string.find(err, "timeout") then
          ngx.log(ngx.ERR, "failed to receive a frame: ", err)
          return ngx.exit(444)
      end        
    elseif typ == 'close' then
      break
    elseif typ == 'text' then
      local httpc = http.new()
      local res, err = httpc:request_uri(backendUrl, {
        method = 'POST',
        body = data,
        ssl_verify = false
      });

      if not res then
        ngx.say("failed to request: ", err)
        return
      end
      local response = res.body
      if type(response) == 'table' then
        response = cjson.encode(response)
      end
      local bytes, err = ws:send_text(response)
      if not bytes then
        ngx.log(ngx.ERR, "failed to send text: ", err)
        return ngx.exit(444)
      end
    end
  end
  wb:send_close()
end

return _M;
