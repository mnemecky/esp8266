-- read config file
dofile("config.lua")

-- Pin which the relay is connected to
relayPin = 6
gpio.mode(relayPin, gpio.OUTPUT)
gpio.write(relayPin, gpio.LOW)
 
-- Connected to switch with internal pullup enabled
buttonPin = 3
buttonDebounce = 250
gpio.mode(buttonPin, gpio.INPUT, gpio.PULLUP)
 
-- MQTT led
mqttLed=7
gpio.mode(mqttLed, gpio.OUTPUT)
gpio.write(mqttLed, gpio.HIGH)

-- MQTT connection
m = mqtt.Client("Sonoff-" .. roomID .. "-" .. deviceID, 180, mqttUser, mqttPass)
 
-- MQTT last will and testament
m:lwt("/lwt", "Sonoff " .. deviceID, 0, 0)

-- on MQTT offline, reconnect
m:on("offline", function(con)
    ip = wifi.sta.getip()
    print ("MQTT reconnecting to " .. mqttBroker .. " from " .. ip)
    tmr.alarm(1, 10000, 0, function()
        node.restart();
    end)
end)

-- On publish message receive event
m:on("message", function(conn, topic, data)
    mqttAct()
    print("Received:" .. topic .. ":" .. data)
    if (data=="ON" or data=="1") then
        print("Enabling Output")
        gpio.write(relayPin, gpio.HIGH)
    elseif (data=="OFF" or data=="0") then
        print("Disabling Output")
        gpio.write(relayPin, gpio.LOW)
    else
        print("Invalid command (" .. data .. ")")
    end
    mqtt_update()
end)

m:connect(mqttBroker, 1883, 0, function(conn)
            print("MQTT connected to:" .. mqttBroker)
            mqtt_sub() -- run the subscription function
end)

-- Pin to toggle the status
buttondebounced = 0
gpio.trig(buttonPin, "down",function (level)
    if (buttondebounced == 0) then
        buttondebounced = 1
        tmr.create():alarm(buttonDebounce, tmr.ALARM_SINGLE, function() buttondebounced = 0; end)
      
        --Change the state
        if (gpio.read(relayPin) == 1) then
            gpio.write(relayPin, gpio.LOW)
            print("Was on, turning off")
        else
            gpio.write(relayPin, gpio.HIGH)
            print("Was off, turning on")
        end
         
        mqttAct()
        mqtt_update()
    end
end)
 
-- Make a short flash with the led on MQTT activity
function mqttAct()
    if (gpio.read(mqttLed) == 1) then gpio.write(mqttLed, gpio.HIGH) end
    gpio.write(mqttLed, gpio.LOW)
    tmr.create():alarm(50,tmr.ALARM_SINGLE, function() gpio.write(mqttLed, gpio.HIGH) end ) 
end

-- Update status to MQTT
function mqtt_update()
    if (gpio.read(relayPin) == 0) then
        m:publish("/" .. topicRoot .. "/" .. roomID .. "/" .. deviceID .. "/state","OFF",0,0)
    else
        m:publish("/" .. topicRoot .. "/".. roomID .."/" .. deviceID .. "/state","ON",0,0)
    end
end

-- Subscribe to MQTT
function mqtt_sub()
    mqttAct()
    m:subscribe("/" .. topicRoot .. "/".. roomID .."/" .. deviceID,0, function(conn)
        print("MQTT subscribed to /" .. topicRoot .. "/" .. roomID .."/" .. deviceID)
    end)
end
