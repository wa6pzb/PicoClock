' ==============================================================================
' PicoMite MMBasic HT16K33 1.2" 7-Segment Real-Time Clock Program
' Displays system time with selectable 12/24 hour modes and AM/PM indicators
' ==============================================================================

Option Explicit

' --- Configuration Constants ---
Const HT_ADDR = &H70      ' Default HT16K33 7-bit I2C address
Const I2C_BUS = 1         ' Change to 2 if using I2C2 pins
Const IS_24HR = 0         ' Set to 1 for 24-hour mode, 0 for 12-hour mode

' --- Display Hardware Bitmasks (Adafruit 1.2" Backpack Layout) ---
Const COLON_MASK = &H02   ' Center colon dots
Const AM_MASK    = &H04   ' Upper-left dot (typically AM)
Const PM_MASK    = &H08   ' Lower-left dot (typically PM)

' --- Global variables ---
Dim Integer segFont(9)    ' Stores raw 7-segment bitmasks for numbers 0-9
Dim Integer dispData(15)  ' 16-byte display buffer (indices 0 to 15)
Dim Integer colonState = 1 ' Tracks colon blinking state

' Initialize Segment Mapping (Standard Top/A=bit0 to Middle/G=bit6 mapping)
segFont(0) = &H3F: segFont(1) = &H06: segFont(2) = &H5B: segFont(3) = &H4F
segFont(4) = &H66: segFont(5) = &H6D: segFont(6) = &H7D: segFont(7) = &H07
segFont(8) = &H7F: segFont(9) = &H6F

' --- Hardware Initialization ---
Print "Initializing I2C Bus and HT16K33 Display for Clock..."
' I2C Close
' I2C Open 100, 100
InitDisplay

' --- Main Loop ---
Print "Clock Running. Press Ctrl+C in terminal to stop."
Do
  UpdateClockDisplay
  
  ' Toggle the colon state for the next update
  If colonState = 1 Then colonState = 0 Else colonState = 1
  
  Pause 1000 ' Update display every second
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
  Local String tStr = TIME$  ' Get system time string "HH:MM:SS"
  Local Integer hr, mn
  Local Integer h1, h2, m1, m2
  Local Integer isPM = 0
  Local Integer indicatorBuffer = 0
  Local Integer i
  Local Integer i2cBuffer(16)

  ' Extract raw numeric values from time string
  hr = Val(Mid$(tStr, 1, 2))
  mn = Val(Mid$(tStr, 4, 2))

  ' Handle 12-hour conversion and AM/PM logic
  If IS_24HR = 0 Then
    If hr >= 12 Then isPM = 1
    If hr > 12 Then hr = hr - 12
    If hr = 0 Then hr = 12
    
    ' Select indicator dot based on AM/PM state
    If isPM = 1 Then
      indicatorBuffer = PM_MASK
    Else
      indicatorBuffer = AM_MASK
    End If
  End If

  ' Separate hours and minutes into individual digits
  h1 = hr \ 10
  h2 = hr Mod 10
  m1 = mn \ 10
  m2 = mn Mod 10

  ' Clear our local display buffer array
  For i = 0 To 15: dispData(i) = 0: Next i

  ' Map digits to HT16K33 matrix memory layout
  ' 12-hour mode blanks leading zero for single-digit hours (e.g., " 9:00" instead of "09:00")
  If IS_24HR = 0 And h1 = 0 Then
    dispData(0) = &H00       ' Blank digit
  Else
    dispData(0) = segFont(h1) ' Digit 1 (Tens of Hours)
  End If
  
  dispData(2) = segFont(h2)   ' Digit 2 (Units of Hours)
  dispData(6) = segFont(m1)   ' Digit 3 (Tens of Minutes)
  dispData(8) = segFont(m2)   ' Digit 4 (Units of Minutes)

  ' Handle colon blinking and append AM/PM indicators
  If colonState = 1 Then
    dispData(4) = COLON_MASK Or indicatorBuffer
  Else
    dispData(4) = indicatorBuffer
  End If

  ' Assemble the sequential I2C payload
  i2cBuffer(0) = 0 ' Set starting register address pointer to 0
  For i = 0 To 15
    i2cBuffer(i + 1) = dispData(i)
  Next i

  ' Blast the 17 total bytes to the display
  I2C Write HT_ADDR, 0, 17, i2cBuffer(0)
End Sub
