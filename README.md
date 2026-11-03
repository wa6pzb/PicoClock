# PicoClock
Implementation of a clock on a Raspberry Pi Pico using mmBasic, DS3231 RTC module, 4 digit I2C seven segment display and 4x4 keypad.

### Requirements
# Basic
- [a] 12 or 24 hour settings
- Use UNIX time epoch for calculations 
- Use UTC as the reference time
- Use time zones with UTC offsets
- Adjust time for Day Light Savings
- Auto or Manual dimming
- Local temperature sensor 
- Display Day and Date 
- Display temperature
- Selectable chime to announce day date display
- Simple time/date set method using 4x4 keypad
- Include a time adjust function for minor time corrections (e.g. add 2 seconds, subtract 1 second, etc.)
# Advanced
- Only display Day and Date during day or with light detected
- Battery operation on power fail
- Set time using Sun observation
- Determine rough Lat/Long and nearest major city using inclinometer observations 
