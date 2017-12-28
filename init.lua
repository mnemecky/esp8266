-- Init script Ringnet IoT
-- Based on NodeMCU documentation

-- load credentials
dofile("credentials.lua")

-- startup function - check for deleted init.lua
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        dofile("main.lua")
    end
end

-- Wifi station event callbacks
wifi_connect_event = function(T)
    print("Connection to AP("..T.SSID..") established")
    print("Waiting for IP address...")
    if disconnect_ct ~= nil then disconnect_ct = nil end
end

wifi_got_ip_event = function(T)
    print("Wifi connection is ready, IP address: "..T.IP)
    print("Startup will resume in 5 seconds.")
    print("Waiting...")
    tmr.create():alarm(5000,tmr.ALARM_SINGLE, startup)
end

wifi_disconnect_event = function(T)
    if T.reason == wifi.eventmon.reason.ASSOC_LEAVE then
      return
    end

    local totalt_tries = 75
    print("\nWifi connection to AP("..T.SSID..") has failed!")

    for key,val in pairs(wifi.eventmon.reason) do
        if val == T.reason then
            print("Disconnect reason "..val.."("..key..")")
            break
        end
    end

    if disconnect_ct == nil then
        disconnect_ct = 1
    else
        disconnect_ct = disconnect_ct + 1
    end

    if disconnect_ct < local_tries then
        print("Retrying connecting to AP ("..(disconnect_ct+1).." of "..local_tries..")")
    else
        wifi.sta.disconnect()
        print("Aborting connection to AP")
        disconnect_ct = nil
    end
end

-- register Wifi station event callbacks
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_disconnect_event)

-- setup Wifi
print("Connecting to AP")
wifi_cfg={}
wifi_cfg.ssid=WIFI_SSID
wifi_cfg.pwd=WIFI_SECRET
wifi.setmode(wifi.STATION)
wifi.sta.config(wifi_cfg)

