-- SONOFF device
--
-- connect via MQTT

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

-- Make a short flash with the led on MQTT activity
function mqttAct()
    if (gpio.read(mqttLed) == 1) then gpio.write(mqttLed, gpio.HIGH) end
    gpio.write(mqttLed, gpio.LOW)
    tmr.create():alarm(50,tmr.ALARM_SINGLE, function() gpio.write(mqttLed, gpio.HIGH) end) 
end

-- Update status to MQTT
function mqtt_update()
    if (gpio.read(relayPin) == 0) then
        m:publish(sonoff.mqttTopic .. "/state","OFF",0,0)
    else
        m:publish(sonoff.mqttTopic .. "/state","ON",0,0)
    end
end

-- Subscribe to MQTT
function mqtt_sub()
    mqttAct()
    m:subscribe(sonoff.mqttTopic, 0, function(conn)
        print("Info (sonoff.lua): MQTT subscribed to " .. sonoff.mqttTopic)
    end)
end

-- Pin to toggle the status
buttondebounced = 0
gpio.trig(buttonPin, "down",function (level)
    if (buttondebounced == 0) then
        buttondebounced = 1
        tmr.create():alarm(buttonDebounce, tmr.ALARM_SINGLE, function() buttondebounced = 0; end)
  
        --Change the state
        if (gpio.read(relayPin) == 1) then
            gpio.write(relayPin, gpio.LOW)
        else
            gpio.write(relayPin, gpio.HIGH)
        end
         
        mqttAct()
        mqtt_update()
    end
end)

sonoff = { mqttBroker="", mqttPort="1883", mqttUser="", mqttPass="", mqttTopic="", startupState="OFF" }

-- load config file
if (not file.open("sonoff.ini","r")) then
    print("Error (sonoff.lua): could not load config file")
else
    local fileContent = file.read()
    file.close()
    for k, v in string.gmatch(fileContent, "([%w._]+)=([%S ]+)") do
        sonoff[k] = v
    end

    -- MQTT connection
    m = mqtt.Client(node.chipid(), 180, sonoff.mqttUser, sonoff.mqttPass)
 
    -- MQTT last will and testament - inform that device is OFF
    m:lwt(sonoff.mqttTopic .. "/state", "OFF")

    -- on MQTT offline, restart
    m:on("offline", function(con)
        print ("Info (sonoff.lua): MQTT connection to " .. sonoff.mqttBroker .. " lost, restarting.")
        tmr.alarm(1, 10000, 0, function() node.restart() end)
    end)

    -- On publish message receive event
    m:on("message", function(conn, topic, data)
        mqttAct()
        print("Info (sonoff.lua): Received ",topic,":",data)
        if (data=="ON" or data=="1") then
            gpio.write(relayPin, gpio.HIGH)
        elseif (data=="OFF" or data=="0") then
            gpio.write(relayPin, gpio.LOW)
        else
            print("Warning (sonoff.lua): Invalid command (" .. topic .. ":" .. data .. ")")
        end
        mqtt_update()
    end)

    m:connect(sonoff.mqttBroker, sonoff.mqttPort, 0, function(conn)
        print("Info (sonoff.lua): MQTT connected to " .. sonoff.mqttBroker .. ":" .. sonoff.mqttPort)
        mqtt_sub()
        if( sonoff.startupState == "OFF" ) then
            gpio.write(relayPin, gpio.LOW)
        elseif( sonoff.startupState == "ON" ) then
            gpio.write(relayPin, gpio.HIGH)
        end
    end, function(conn, reason)
        print("Error (sonoff.lua): MQTT connection failed (reason " .. reason .. "), restarting in 60 seconds...")
        tmr.alarm(1, 60000, 0, function() node.restart() end)
    end)
end
