' ==============================================================================
' PicoMite MMBasic HT16K33 1.2" 7-Segment Clock Program
' Displays the time from the built-in DS3231 RTC onto an I2C 7-Segment display
' ==============================================================================

Option Explicit

' --- Configuration Constants ---
Const HT_ADDR = &H70      ' Default HT16K33 7-bit I2C address
Const I2C_BUS = 1         ' Change to 2 if using I2C2 pins

' --- Global variables ---
Dim Integer segFont(9)    ' Stores raw 7-segment bitmasks for numbers 0-9
Dim Integer dispData(15)  ' 16-byte display buffer (indices 0 to 15)
Dim Integer blinkState = 1 ' Tracks colon blinking state

' Initialize Segment Mapping (Standard Top/A=bit0 to Middle/G=bit6 mapping)
segFont(0) = &H3F: segFont(1) = &H06: segFont(2) = &H5B: segFont(3) = &H4F
segFont(4) = &H66: segFont(5) = &H6D: segFont(6) = &H7D: segFont(7) = &H07
segFont(8) = &H7F: segFont(9) = &H6F

' --- Hardware Initialization ---
Print "Initializing I2C Bus and HT16K33 Display..."

' Ensure the bus is closed first, then open at a safe standard speed (100kHz)
'I2C Close
'I2C Open 100, 100     
InitDisplay

' --- Main Loop ---
Print "Clock Running. Press Ctrl+C in terminal to stop."
Do
  UpdateClockDisplay
  Pause 500               ' Refresh and blink colon every 500ms
Loop

' ==============================================================================
' Subroutines & Functions
' ==============================================================================

Sub InitDisplay
  ' 1. Turn on internal system oscillator (Command &H21)
  I2C Write HT_ADDR, 0, 1, &H21
  If MM.I2C <> 0 Then Print "Error: Display not found on I2C bus. Check wiring!": End

  ' 2. Set brightness/dimming max level (Command &HEF, range &HE0 to &HEF)
  I2C Write HT_ADDR, 0, 1, &HEF

  ' 3. Turn Display ON with No Blinking (Command &H81)
  I2C Write HT_ADDR, 0, 1, &H81
End Sub

Sub UpdateClockDisplay
  Local String tStr = TIME$      ' MMBasic system variable auto-updated by DS3231
  Local Integer h1, h2, m1, m2
  Local Integer i
  
  ' Create a combined transmission buffer: 
  ' 1 byte for target memory pointer (index 0) + 16 bytes for display data
  Local Integer i2cBuffer(16)

  ' Parse time string "HH:MM:SS" into single digits
  h1 = Val(Mid$(tStr, 1, 1))
  h2 = Val(Mid$(tStr, 2, 1))
  m1 = Val(Mid$(tStr, 4, 1))
  m2 = Val(Mid$(tStr, 5, 1))

  ' Clear our local display buffer array
  For i = 0 To 15: dispData(i) = 0: Next i

  ' Map individual digits to the HT16K33 memory layout matrix
  dispData(0) = segFont(h1)  ' Digit 1 (Tens of Hours)
  dispData(2) = segFont(h2)  ' Digit 2 (Units of Hours)

  ' Toggle the colon on register 4
  If blinkState = 1 Then
    dispData(4) = &H02       ' Use &H02 or &H0C for the 1.2" display colon
    blinkState = 0
  Else
    dispData(4) = &H00
    blinkState = 1
  End If

  dispData(6) = segFont(m1)  ' Digit 3 (Tens of Minutes)
  dispData(8) = segFont(m2)  ' Digit 4 (Units of Minutes)

  ' Assemble the singular sequential payload
  i2cBuffer(0) = 0           ' Set starting register address pointer to 0
  For i = 0 To 15
    i2cBuffer(i + 1) = dispData(i)
  Next i

  ' Send 17 total bytes (1 address pointer byte + 16 data bytes) starting at element 0
  I2C Write HT_ADDR, 0, 17, i2cBuffer(0)
End Sub
