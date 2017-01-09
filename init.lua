-- Start script after 10s delay
tmr.alarm(0, 10000, tmr.ALARM_SINGLE, function()
  dofile("rc.lua")
end)
