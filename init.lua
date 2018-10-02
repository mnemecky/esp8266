-- Init script Ringnet IoT
-- Based on code from
--   NodeMCU documentation
--   https://github.com/kovi44/NODEMCU-LUA-OTA-ESP8266

-- load config file
--
function loadConfig(s)
    if (file.open("config.ini","r")) then
        local fileContent = file.read()
        file.close()
        for k, v in string.gmatch(fileContent, "([%w._]+)=([%S ]+)") do
          s[k] = v
        end
    else
      print("Error (init.lua): could not load config file")
    end
end

-- save config file
--
function saveConfig(s)
    file.remove("config.ini")
    file.open("config.ini", "w+")

    for k, v in pairs(s) do
        file.writeline(k .. "=" .. v)
    end

    file.close()
    collectgarbage()
end

-- check for OTA update
--
function checkUpdate()
    http.get("http://" .. config.host .. "/" .. config.path .. "/node.php?id=" .. chipId .. "&update", nil, function(code,data)
        if (code==200) then
            if string.find(data, "UPDATE")~=nil then
                config.update="true"
                saveConfig(config)
                print("Info (init.lua): Update requested, restarting")
                node.restart()
            end
        end
    end)
end

-- startup function
-- check for deleted init.lua, start main.lua
function startupMain()

    -- check for update request
    if (config.update=="true") then
        print("Info (init.lua): Starting update")

        -- remove update flag to prevent boot loop
        config.update="false"
        saveConfig(config)

        if (file.open("update.lua")) then
            file.close()
            dofile("update.lua")
        else
            print("Error (init.lua): update.lua missing, restarting in 5 seconds")
            tmr.create():alarm(5000,tmr.ALARM_SINGLE, function() node.restart() end)
        end

    else
        -- set up update check, requires host config to be set
        if (config.host ~= "") then
            if (tonumber(config.interval) > 0) then
                print("Info (init.lua): checking for updates with " .. config.host .. " (" .. config.interval .. " seconds)")
                tmr.create():alarm(tonumber(config.interval)*1000, tmr.ALARM_AUTO, checkUpdate)
            end
        end

        -- if bootfile config is set, execute it
        if (config.bootfile~="") then
            if (file.open(config.bootfile)) then
                file.close()
                dofile(config.bootfile)
            else
                print("Warning (init.lua): bootfile " .. config.bootfile .. " not found, end of execution")
            end
        else
            print("Warning (init.lua): No bootfile set, end of execution")
        end
    end
end

-- Wifi station event callback
-- STA_CONNECTED 
wifi_connect_event = function(T)
    print("Info (init.lua): Connection to " .. T.SSID .. " established, waiting for IP address...")
    if disconnect_ct ~= nil then disconnect_ct = nil end
end

-- Wifi station event callback
-- STA_GOT_IP
wifi_got_ip_event = function(T)
    print("Info (init.lua): IP address acquired, ",T.IP)
    print("Info (init.lua): Startup will resume in 5 seconds, bootfile ", config.bootfile)
    tmr.create():alarm(5000,tmr.ALARM_SINGLE, startupMain)
end

-- Wifi station event callback
-- STA_DISCONNECTED
wifi_disconnect_event = function(T)
    if T.reason == wifi.eventmon.reason.ASSOC_LEAVE then
      return
    end

    local max_retries=10
    print("Error (init.lua): Connection to " .. T.SSID .. " failed!")

    for key,val in pairs(wifi.eventmon.reason) do
        if val == T.reason then
            print("Error (init.lua): Disconnect reason " .. val .. "(" .. key .. ")")
            break
        end
    end

    if disconnect_ct == nil then
        disconnect_ct = 1
    else
        disconnect_ct = disconnect_ct + 1
    end

    if disconnect_ct < max_retries then
        print("Info (init.lua): Retrying connecting to AP, " .. (disconnect_ct+1) .. " of " .. max_retries .. " retries")
    else
        wifi.sta.disconnect()
        print("Error (init.lua): Aborting connection to AP")
        disconnect_ct = nil
    end
end

-- main routine
chipId = node.chipid()
print("Info (init.lua): ESP node ID " .. chipId)

-- initialise config array
--  ssid: Wifi SSID
--  secret: Wifi password
--  host: hostname or IP for update checks
--  path: URL to update check
--  bootfile: LUA file to start after initialisation
--  interval: time interval to check for updates, default 60 seconds
--  update: update requested
config = { ssid="", secret="", host="", path="", err="", bootfile="", update="false", interval=60 }

-- read config file
loadConfig(config)

-- register Wifi station event callbacks
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_disconnect_event)

-- setup Wifi
print("Info (init.lua): Connecting to AP")
wifi_cfg={}
wifi_cfg.ssid=config.ssid
wifi_cfg.pwd=config.secret
wifi.setmode(wifi.STATION)
wifi.sta.config(wifi_cfg)

