# ESP8266 Home Automation projects

My home automation projects based on ESP8266

Scripts are tested on Lua 5.1.4 and the following ESP types:
* SONOFF switches
* ESP8266-01

## Installation

### Installation of NodeMCU

Installation of NodeMCU on Sonoff switches

```
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash --flash_mode qio 0 nodemcu_integer_0.9.6-dev_20150704.bin
```

Installation of NodeMCU on ESP8266-01 modules

```
esptool.py --port /dev/ttyUSB0 --baud 115200 write_flash --flash_mode dio 0 nodemcu_integer_0.9.6-dev_20150704.bin
```

### Installation of LUA scripts

```
luatool.py -p /dev/ttyUSB0 -b 115200 --src init.lua --dest init.lua
luatool.py -p /dev/ttyUSB0 -b 115200 --src update.lua --dest update.lua
luatool.py -p /dev/ttyUSB0 -b 115200 --src config.ini --dest config.ini
```

Should there be a problem while starting, one can remove simply remove or rename the bootfile during the 5 seconds wait period after booting and connecting to the Wifi.

```
file.remove("main.lua")
file.rename("main.lua","main.bck")
```

# Credits

Mainly based on
* NodeMCU documentation
* NodeMCU OTA setup by kovi44 at https://github.com/kovi44/NODEMCU-LUA-OTA-ESP8266
