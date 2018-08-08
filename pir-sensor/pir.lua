-- PIR detector
--
--

-- GPIO pin 0
pirPin = 3
gpio.mode(pirPin, gpio.INPUT)

-- trigger on level change
gpio.trig(pirPin, "both", function(level)
    print("GPIO 0, level change to " .. level)
    if (level == 0) then
        m:publish(pir.mqttTopic .. "/state","OFF",0,0)
    else
        m:publish(pir.mqttTopic .. "/state","ON",0,0)
    end

end)

-- Subscribe to MQTT
function mqtt_sub()
    m:subscribe(pir.mqttTopic,0, function(conn)
        print("Info (pir.lua): MQTT subscribed to " .. pir.mqttTopic)
    end)
end

-- config variable
pir = { mqttBroker="", mqttUser="", mqttPass="", topicRoot="", roomID="", deviceID="" }

-- load config file
if (not file.open("pir.ini","r")) then
    print("Error (pir.lua): could not load config file pir.ini")
else
    local fileContent = file.read()
    file.close()
    for k, v in string.gmatch(fileContent, "([%w._]+)=([%S ]+)") do
        pir[k] = v
    end

    -- MQTT connection
    m = mqtt.Client("PIR-" .. node.chipid(), 180, pir.mqttUser, pir.mqttPass)
 
    -- MQTT last will and testament
    m:lwt("/lwt", "PIR " .. node.chipid(), 0, 0)

    -- on MQTT offline, reconnect
    m:on("offline", function(con)
        print ("Info (pir.lua): MQTT reconnecting to " .. pir.mqttBroker)
        tmr.alarm(1, 10000, 0, function() node.restart() end)
    end)

    m:connect(pir.mqttBroker, 1883, 0, function(conn)
        print("Info (pir.lua): MQTT connected to " .. pir.mqttBroker)
        mqtt_sub() -- run the subscription function
    end)
end
