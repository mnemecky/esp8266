-- Update script Ringnet IoT
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
      print("Error (update.lua): could not load config file")
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
--    collectgarbage()
end

-- split string
--
function splitString(str,sep)
    if sep == nil then
        sep = "%s"
    end

    local t={}; i=1
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        t[i] = s
        i=i+1
    end
    
    return t
end

-- strip for header
--
function stripHeader(c)
    local nStart, nEnd = string.find(c, "\r\n\r\n")
    if (nEnd ~= nil) then
        c = string.sub(c,nEnd+1)
        return c
    else
        return nil
    end
end

-- check for all files downloaded, update bootfile, restart
--
function endUpdate(s,c)
    numFiles = numFiles - 1
    if (numFiles == 0) then

        sck = net.createConnection(net.TCP,0)

        sck:on("receive", function(sck, data)
            local c = stripHeader(data)
            if (c~=nil) then
                print("Info (update.lua): Updating config, set bootfile to " .. c)
                loadConfig(config)
                config.bootfile = c
                saveConfig(config)
                node.restart()
            end
        end)

        sck:on("connection", function(sck)
            sck:send("GET /" .. config.path .. "/node.php?id=" .. chipId .. "&boot HTTP/1.0\r\n" ..
                      "Host: " .. config.host .. "\r\n" ..
                      "Connection: close\r\n" ..
                      "Accept-Charset: utf-8\r\n" ..
                      "Accept-Encoding: \r\n" ..
                      "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n" ..
                      "Accept: */*\r\n\r\n")

        end)

        sck:connect(80,config.host)
    end
end

-- download files to be updated
--
function downloadFiles(s,c)

    c = stripHeader(c)
    local f = splitString(c, "\n")
    numFiles = table.getn(f)

    print("Info (update.lua): Downloading " .. numFiles .. " files")

    for k, v in pairs(f) do
        local buffer = nil
        local maxlength = 1600
        local payloadFound = nil

        file.remove(v)

        srv=net.createConnection(net.TCP,0)

        srv:on("receive", function(sck, data)
            if (not payloadFound) then
                data = stripHeader(data)
                if (data ~= nil) then
                    payloadFound = true
                end
            end
            if (payloadFound) then
                print("Info (update.lua): writing " .. #data .. " bytes to file " .. v)
                file.open(v,"a+")
                file.write(data)
                file.close()
            end
        end)

        srv:on("connection", function(sck)
            sck:send("GET /" .. config.path .. "/uploads/" .. chipId .. "/" .. v .. " HTTP/1.0\r\n" ..
                      "Host: " .. config.host .. "\r\n" ..
                      "Connection: close\r\n" ..
                      "Accept-Charset: utf-8\r\n" ..
                      "Accept-Encoding: \r\n" ..
                      "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n" ..
                      "Accept: */*\r\n\r\n")
        end)

        srv:on("disconnection", endUpdate)

        srv:connect(80,config.host)
    end
end


-- main routine

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

conn = net.createConnection(net.TCP,0)

conn:on("connection", function(c,p)
    conn:send("GET /" .. config.path .. "/node.php?id=" .. chipId .. "&list" ..
              " HTTP/1.1\r\n" ..
              "Host: ".. config.host .. "\r\n" ..
              "Accept: */*\r\n" ..
              "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua;)" ..
              "\r\n\r\n") 
end)

conn:on("receive", downloadFiles)

conn:connect(80,config.host)

