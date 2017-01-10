-- #######################################
-- Simple remote control through REST API
-- Endpoints:
-- /     -> return last status
-- /up   -> trigger up button
-- /down -> trigger down button
-- #######################################

-- Global vars
ssid = "YOUR_SSID"
pass = "YOUR_PASSWORD"
pin_up = 1
pin_down = 2
last_status = "UNKNOWN"

-- =======================================

function triggerPin(pin, duration)
  if pin == pin_up then
    last_status = "UP"
  elseif pin == pin_down then
    last_status = "DOWN"
  end
  gpio.mode(pin, gpio.OUTPUT)
  gpio.write(pin, gpio.HIGH)
  tmr.alarm(0, duration, tmr.ALARM_SINGLE, function()
    gpio.write(pin, gpio.LOW)
  end)
end

function split(str, sep)
  -- copy string, as gmatch consumes it
  local s = str .. ""
  local r = {}
  local i = 1
  for val in s:gmatch(sep) do
    r[i] = val
    i = i + 1
  end
  if r[1] == nil or r[1] == "" then
    r[1] = str
  end
  return r
end

function parseHttpRequest(payload)
  local request = {}
  local data = split(payload, "^\r\n\r\n")
  if (data[2] ~= nil and data[2] ~= "") then
    request.data = json.decode(data[1])
  end
  local header = split(data[1], "%S+")
  request.method = header[1]
  request.path = header[2]
  -- ignore headers...
  return request
end

-- Response format: { status: 200, json: false, data: "Hello" }
-- If json == false, content is assumed to be HTML
function sendHttpResponse(conn, response)
  if response == nil then
    response = {}
  end
  if response.status == nil then
   response.status = 200
  end
  local res = "HTTP/1.1 " .. response.status .. " OK\r\n"
  if response.data ~= nil then
    local type = "text/html"
    local content = response.data
    if response.json ~= nil and response.json then
      type = "application/json"
      content = json.encode(response.data)
    end
    res = res .. "Content-Type:" .. type .. "\r\n\r\n" .. content
  else
    res = res .. "\r\n"
  end
  conn:send(res, function()
    conn:close()
  end)
end

-- =======================================

-- Setup wifi
wifi.setmode(wifi.STATION)
wifi.sta.config(ssid, pass)

-- Blink led
led_on = 0
gpio.mode(4, gpio.OUTPUT)
gpio.write(4, gpio.LOW)
tmr.alarm(0, 50, tmr.ALARM_AUTO, function()
  if led_on == 0 then
    led_on = 1
    gpio.write(4, gpio.HIGH)
  else
    led_on = 0
    gpio.write(4, gpio.LOW)
  end
end)
tmr.alarm(1, 1000, tmr.ALARM_SINGLE, function()
  gpio.write(4, gpio.HIGH)
  tmr.unregister(0)
end)

-- Init server
srv = net.createServer(net.TCP) 
srv:listen(80, function(conn) 
  conn:on("receive", function(conn,payload)
    local request = parseHttpRequest(payload)
    print("path: " .. request.path) 
    if request.path == "/up" then
      triggerPin(pin_up, 200)
      sendHttpResponse(conn)
    elseif request.path == "/down" then
      triggerPin(pin_down, 200)
      sendHttpResponse(conn)
    else
      local html = "NodeMCU RC Status: " .. last_status
      sendHttpResponse(conn, { data = "<!doctype html><html><body>" .. html .. "</body></html>" })
    end
    print(node.heap())
  end)
end)
