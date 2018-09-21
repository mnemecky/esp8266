-- Doorbell
--
--

-- Wifi station event callback
-- STA_CONNECTED 
wifi_connect_event = function(T)
    print("Info (init.lua): Connection to " .. T.SSID .. " established, waiting for IP address...")
    if disconnect_ct ~= nil then disconnect_ct = nil end
end

-- Wifi station event callback
-- STA_GOT_IP
wifi_got_ip_event = function(T)
    print("Info: IP address acquired:",T.IP)
    print("Info: Startup... ")
    tmr.create():alarm(5,tmr.ALARM_SINGLE, startupMain)
end

-- Wifi station event callback
-- STA_DISCONNECTED
wifi_disconnect_event = function(T)
    if T.reason == wifi.eventmon.reason.ASSOC_LEAVE then
      return
    end

    local max_retries=3
    print("Error: Connection to " .. T.SSID .. " failed!")

    for key,val in pairs(wifi.eventmon.reason) do
        if val == T.reason then
            print("Error: Disconnect reason " .. val .. "(" .. key .. ")")
            break
        end
    end

    if disconnect_ct == nil then
        disconnect_ct = 1
    else
        disconnect_ct = disconnect_ct + 1
    end

    if disconnect_ct < max_retries then
        print("Info: Retrying connecting to AP, " .. (disconnect_ct+1) .. " of " .. max_retries .. " retries")
    else
        wifi.sta.disconnect()
        print("Error: Aborting connection to AP")
        disconnect_ct = nil
        node.dsleep(0,2)
    end
end

function startupMain()

    -- go to sleep after 30 seconds
    tmr.create():alarm(30000,tmr.ALARM_SINGLE, function() node.dsleep(0,2) end)

    -- initiate MQTT connection
    m = mqtt.Client("DOORBELL-" .. node.chipid(), 180)
 
    -- MQTT last will and testament
    m:lwt("/lwt", "DOORBELL " .. node.chipid(), 0, 0)

    -- connect, subscribe and post a message
    m:connect(config.mqttBroker, 1883, 0, function(conn)
        m:subscribe(config.mqttTopic,0, function(conn)
            m:publish(config.mqttTopic,"RING",0,0, function(conn)
                print("Info: MQTT message published, sleeping")
                node.dsleep(0,2)
            end)
        end)
    end)

end

-- main routine

-- initialise config array
--  ssid: Wifi SSID
--  secret: Wifi password
--  host: hostname or IP for update checks
--  path: URL to update check
--  bootfile: LUA file to start after initialisation
--  update: update requested
config = { ssid="", secret="", host="", path="", err="", bootfile="", update="false", mqttBroker="", mqttTopic="" }

-- read config file
if (file.open("config.ini","r")) then
    local fileContent = file.read()
    file.close()
    for k, v in string.gmatch(fileContent, "([%w._]+)=([%S ]+)") do
      config[k] = v
    end
else
  print("Error: could not load config file")
  node.dsleep(0,2)
end

-- register Wifi station event callbacks
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_disconnect_event)

-- setup Wifi
print("Info: Connecting to AP")
wifi_cfg={}
wifi_cfg.ssid=config.ssid
wifi_cfg.pwd=config.secret
wifi.setmode(wifi.STATION)
wifi.sta.config(wifi_cfg)



