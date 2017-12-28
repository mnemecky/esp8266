# ESP8266 Home Automation projects

My home automation projects based on ESP8266

Scripts are tested on Lua 5.1.4

## Installation

### Installation of NodeMCU

Installation of NodeMCU on Sonoff switches

```
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash --flash_mode qio 0 nodemcu_integer_0.9.6-dev_20150704.bin
```

### Installation of LUA scripts

```
luatool.py -p /dev/ttyUSB0 -b 115200 --src main.lua --dest main.lua
luatool.py -p /dev/ttyUSB0 -b 115200 --src init.lua --dest init.lua
luatool.py -p /dev/ttyUSB0 -b 115200 --src config.lua --dest config.lua
```

Should there be a problem while starting, one can remove simply remove the file init.lua during boot,
which should stop startup.

```
file.remove("init.lua")
```
