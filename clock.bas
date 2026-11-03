' ==============================================================================
' PicoMite MMBasic HT16K33 1.2" 7-Segment Real-Time Clock Program
' Displays local time adjusted from UTC - RTC is set to UTC
' All calculations use Epoch(now) function
' 12/24 hour, TZ offset, DST, and DST Auto are read from a file-based configuration
' ==============================================================================
Option Explicit

' --- Configuration Variables (Loaded from File) ---
Dim Integer cfg_is24hr = 0
Dim Integer cfg_tzOffset = 0
Dim Integer cfg_dstOn = 0
Dim Integer cfg_dstAuto = 0

' --- Configuration Constants ---
Const HT_ADDR = &H70 ' Default HT16K33 7-bit I2C address
Const I2C_BUS = 1    ' Change to 2 if using I2C2 pins

' --- Display Hardware Bitmasks (Adafruit 1.2" Backpack Layout) ---
Const COLON_MASK = &H02 ' Center colon dots
Const AM_MASK = &H04    ' Upper-left dot (typically AM)
Const PM_MASK = &H08    ' Lower-left dot (typically PM)

' --- Global variables ---
Dim Integer segFont(9)    ' Stores raw 7-segment bitmasks for numbers 0-9
Dim Integer dispData(15)  ' 16-byte display buffer (indices 0 to 15)
Dim Integer colonState = 1 ' Tracks colon blinking state

' Initialize Segment Mapping (Standard Top/A=bit0 to Middle/G=bit6 mapping)
segFont(0) = &H3F: segFont(1) = &H06: segFont(2) = &H5B: segFont(3) = &H4F
segFont(4) = &H66: segFont(5) = &H6D: segFont(6) = &H7D: segFont(7) = &H07
segFont(8) = &H7F: segFont(9) = &H6F

' --- Hardware Initialization ---
Print "Loading configuration file..."
LoadConfiguration
Print "Initializing I2C Bus and HT16K33 Display for Clock..."
' I2C Close
' I2C Open 100, 100
InitDisplay

' --- Main Loop ---
Print "Clock Running. Press Ctrl+C in terminal to stop."
Do
  UpdateClockDisplay
  ' Toggle the colon state for the next update
  If colonState = 1 Then
    colonState = 0
  Else
    colonState = 1
  End If
  Pause 1000 ' Update display every second
Loop

' ==============================================================================
' Subroutines & Functions
' ==============================================================================

Sub LoadConfiguration
  Local String lineIn, key, valStr
  Local Integer eqPos
  On Error Skip ' Gracefully catch file access issues
  Open "clock.cfg" For Input As #1
  If MM.ErrNo <> 0 Then
    Print "Warning: Could not open clock.cfg. Using default values."
    Exit Sub
  End If
  Do While Not EOF(#1)
    Line Input #1, lineIn
    lineIn = Trim$(lineIn)
    ' Skip empty lines or comments
    If lineIn <> "" And Left$(lineIn, 1) <> "'" And Left$(lineIn, 1) <> "#" Then
      eqPos = Instr(lineIn, "=")
      If eqPos > 0 Then
        key = UCase$(Trim$(Left$(lineIn, eqPos - 1)))
        valStr = Trim$(Mid$(lineIn, eqPos + 1))
        Select Case key
          Case "IS_24HR"   : cfg_is24hr = Val(valStr)
          Case "TZ_OFFSET" : cfg_tzOffset = Val(valStr)
          Case "DST_ON"    : cfg_dstOn = Val(valStr)
          Case "DST_AUTO"  : cfg_dstAuto = Val(valStr)
        End Select
      End If
    End If
  Loop
  Close #1
End Sub

Function IsUSDSTFromEpoch(targetEpoch As Integer) As Integer
  ' Determines if a given epoch falls within US Daylight Saving Time bounds.
  ' Expected input: Standard Time (UTC + Base Timezone Offset).
  ' US DST starts 2nd Sunday in March @ 02:00 Standard (02:00 Local)
  ' US DST ends 1st Sunday in Nov @ 01:00 Standard (02:00 Local)
  Local String checkDt$ = DATETIME$(targetEpoch)
  Local Integer yr = Val(Mid$(checkDt$, 7, 4))
  Local Integer mo = Val(Mid$(checkDt$, 4, 2))
  Local Integer dy = Val(Mid$(checkDt$, 1, 2))
  Local Integer hr = Val(Mid$(checkDt$, 12, 2))
  Local Integer marchDstStart, novDstEnd

  If mo < 3 Or mo > 11 Then
    IsUSDSTFromEpoch = 0
    Exit Function
  End If
  If mo > 3 And mo < 11 Then
    IsUSDSTFromEpoch = 1
    Exit Function
  End If

  marchDstStart = 14 - ((1 + 5 * yr \ 4) Mod 7)
  novDstEnd = 7 - ((1 + 5 * yr \ 4) Mod 7)

  If mo = 3 Then
    If dy > marchDstStart Then
      IsUSDSTFromEpoch = 1
    ElseIf dy = marchDstStart And hr >= 2 Then
      IsUSDSTFromEpoch = 1
    Else
      IsUSDSTFromEpoch = 0
    End If
  ElseIf mo = 11 Then
    If dy < novDstEnd Then
      IsUSDSTFromEpoch = 1
    ElseIf dy = novDstEnd And hr < 1 Then ' 01:00 Standard Time is 02:00 DST
      IsUSDSTFromEpoch = 1
    Else
      IsUSDSTFromEpoch = 0
    End If
  End If
End Function

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
  Local Integer currentEpoch = EPOCH(NOW)
  Local Integer standardEpoch
  Local Integer localEpoch
  Local String localDt$
  Local Integer hr, mn
  Local Integer h1, h2, m1, m2
  Local Integer isPM = 0
  Local Integer indicatorBuffer = 0
  Local Integer i
  Local Integer i2cBuffer(16)

  ' 1. Apply base timezone offset to get Standard Time (convert hours to seconds)
  standardEpoch = currentEpoch + (cfg_tzOffset * 3600)

  ' 2. Handle Daylight Saving Time calculations using Standard Time reference
  If cfg_dstAuto = 1 Then
    If IsUSDSTFromEpoch(standardEpoch) = 1 Then
      localEpoch = standardEpoch + 3600
    Else
      localEpoch = standardEpoch
    End If
  ElseIf cfg_dstOn = 1 Then
    localEpoch = standardEpoch + 3600
  Else
    localEpoch = standardEpoch
  End If

  ' 3. Parse local date/time text representation string
  ' Format returned by MMBasic is: "dd-mm-yyyy hh:mm:ss"
  localDt$ = DATETIME$(localEpoch)
  hr = Val(Mid$(localDt$, 12, 2))
  mn = Val(Mid$(localDt$, 15, 2))

  ' Handle 12-hour conversion and AM/PM logic
  If cfg_is24hr = 0 Then
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
  For i = 0 To 15
    dispData(i) = 0
  Next i

  ' Map digits to HT16K33 matrix memory layout
  ' 12-hour mode blanks leading zero for single-digit hours
  If cfg_is24hr = 0 And h1 = 0 Then
    dispData(0) = &H00
  Else
    dispData(0) = segFont(h1)
  End If
  dispData(2) = segFont(h2)
  dispData(6) = segFont(m1)
  dispData(8) = segFont(m2)

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
