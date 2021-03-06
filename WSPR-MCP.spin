{
    WSPR_MCP
    High Altitude Balloon Master Control Program
    using WSPR, Weak Signal Propagation Reporter 

    Steven R. Stuart, W8AN
    Feb-2019

    NOTICE - Radio transmissions on these frequencies may  
             only be used by licensed radio amateur operators.
             Please see www.arrl.org for more information. 
}

''    ---[ THIS IS AN INCOMPLETE PROJECT ]---

{{
Circuit to reduce the power output to 1mW

                  470Ω                                                  
      RF pin 13 ────┳──── 0dBm signal to antenna                             
                        51Ω                   
                       


Circuit to drive one (of five) of the low pass filter relays
                   
                 680Ω  ┌────────── to relay  
        LPF pin ─── 2N2222A                 
                       │
                       
}}                  
CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

  WMin         =         381     'WAITCNT-expression-overhead Minimum
  symbolLength =         683     ' 8192 / 12000 * 1000 = milliseconds
  tokenTime    =         80_000_000 / 1_000 * symbolLength - 3932
  
 'WSPR standard frequencies
 'Shown are the dial frequencies plus 1500 hz to put in the middle of the 200 hz WSPR band
 'WSPR500KHz   =     502_400 + 1_500    ' 500 KHz
  WSPR160M     =   1_836_600 + 1_500    ' 160 metres   center:  1838.100
  WSPR80M      =   3_592_600 + 1_500    '  80 metres   center:  3594.100
 'WSPR60M      =   5_287_200 + 1_500    '  60 metres
  WSPR40M      =   7_038_600 + 1_500    '  40 metres   center:  7040.100
  WSPR30M      =  10_138_700 + 1_500    '  30 metres   center: 10140.200
  WSPR20M      =  14_095_600 + 1_500    '  20 metres   center: 14097.100
 'WSPR17M      =  18_104_600 + 1_500    '  17 metres
 'WSPR15M      =  21_094_600 + 1_500    '  15 metres
 'WSPR12M      =  24_924_600 + 1_500    '  12 metres
 'WSPR10M      =  28_124_600 + 1_500    '  10 metres
 'WSPR6M       =  50_293_000 + 1_500    '   6 metres
 'WSPR4M       =  70_028_600 + 1_500    '   4 metres
 'WSPR2M       = 144_489_000 + 1_500    '   2 metres

  RFPin        =         13
  
{{ Frequency output error is due to variations in the xtal crystal on your Propeller
   Error offsets are calculated by setting Calibrate to TRUE then starting the program.
   A signal will immediately transmit on the band set in the calibration routine.
   I used an Icom IC-7300 set at 1Hz display to zero in on the signal. You can
   then subtract the received frequency from the chosen transmit frequency.
   Enter that number into the appropriate Err..M constant.
}}
{ 'These settings for my Quickstart board
  Err160M      =   48
  Err80M       =   92
  Err40M       =  186
  Err30M       =  266
  Err20M       =  372 
}
  'These settings for my Development board
  Err160M      =   -32
  Err80M       =   -68
  Err40M       =  -129
  Err30M       =  -189
  Err20M       =  -265

  'QPR Labs Ultimate LPF kit: http://qrp-labs.com/ultimatelpf.html
  'Low pass filter pins
  LP20         =  21
  LP30         =  22
  LP40         =  23
  LP80         =  24
  LP160        =  25
                      
OBJ
   gps : "GPS_IO_mini"     
  WSPR : "WSPREncode"
  term : "Parallax Serial Terminal"
  Freq : "Synth"
  
VAR
    BYTE Xmit               'transmit flag
    LONG FreqOffset         'center of the band bias
    LONG Stack[128] 

    long ipos            'for testing

    long Frequency, ErrorOffset
    
DAT
    msgReport BYTE $0[6] 'callsign
    msgGrid   BYTE $0[4] 'grid pos
    msgPower  BYTE "0"  'xmit power
    msg       BYTE "N0CALL EN81 0", 0  'Enter your callsign and maidenhead grid position here

    txttime BYTE $0[7]   'mmddyy,0
    txtsec  BYTE $0[3]   'ss,0
    txtmin  BYTE $0[3]   'mm,0
    txtlat  BYTE $0[12]  '11 char str - ddmm.dddddx
    txtlon  BYTE $0[13]  '12 char str - dddmm.dddddx
    txtsat  BYTE $0[4]  '///not yet implemented
    txtmhg   byte $0[7]  ' 6 char maidenhead grid
        
PUB Main | Gcog, Xcog, Ccog, gpsValid, valsec, valmin, random, rfsh, trigger, Filter, calibrate  

    term.start(115_200)
    waitcnt(clkfreq*3 + cnt)
    
    Gcog := gps.start  
    Ccog := cognew(FreqCheck, @fc_stack)

    random := cnt       'seed for transmit freq offset
    FreqOffset := 0   '+/-80Hz
    Xmit := FALSE
    Xcog := cognew(Transmit, @Stack)

    dira[LP20]~~   'outputs
    dira[LP30]~~
    dira[LP40]~~
    dira[LP80]~~
    dira[LP160]~~
    
    outa[LP20] := 0  'disable all
    outa[LP30] := 0
    outa[LP40] := 0
    outa[LP80] := 0
    outa[LP160] := 0

    ''Calibration routine
    calibrate := FALSE
    if calibrate
      repeat
        Frequency   := WSPR40M
        ErrorOffset := -129   'adjust this value to set constants Err160, Err80, etc.
        outa[LP40] := 1
        Xmit := TRUE
      
    repeat

      waitcnt(clkfreq/5+cnt)
    
      '
      ' populate time and location character arrays
      '
      BYTEMOVE(@txttime, gps.time, 6)                'get a time stamp      
      BYTEMOVE(@txtsec, @txttime+4, 2)       
      BYTEMOVE(@txtmin, @txttime+2, 2)
      BYTEMOVE(@txtlat, gps.latitude, 10)  
      BYTEMOVE(@txtlat+10, gps.N_S, 1)     
      BYTEMOVE(@txtlon, gps.longitude, 11)
      BYTEMOVE(@txtlon+11, gps.E_W, 1)

      gpsValid := (strsize(@txtlat)>10) & (strsize(@txtlon)>11)
      
      if gpsValid                      
        valsec := (((txtsec[0])-48)*10+((txtsec[1])-48)) <# 60 'set seconds value
        valmin := (((txtmin[0])-48)*10+((txtmin[1])-48)) <# 60 'set minute value
        LatLon2Mh(@txtLat, @txtlon, @txtmhg)                   'calc maidenhead grid loc 

      if (valsec == 0) & (not Xmit) & gpsValid
        case valmin   

          2,12,22,32,42,52: '160 meter
             Frequency   := WSPR160M   
             ErrorOffset := Err160M
             Filter := string("160")   
             outa[LP160] := 1
             trigger := TRUE  

          4,14,24,34,44,54: '80 meter
             Frequency   := WSPR80M   
             ErrorOffset := Err80M
             Filter := string("80")   
             outa[LP80] := 1
             trigger := TRUE    

          6,16,26,36,46,56: '40 meter
             Frequency   := WSPR40M   
             ErrorOffset := Err40M  
             Filter := string("40")   
             outa[LP40] := 1
             trigger := TRUE    

          8,18,28,38,48,58: '30 meter
             Frequency   := WSPR30M   
             ErrorOffset := Err30M   
             Filter := string("30")   
             outa[LP30] := 1
             trigger := TRUE    

          0,10,20,30,40,50: '20 meter
             Frequency   := WSPR20M   
             ErrorOffset := Err20M
             Filter := string("20")   
             outa[LP20] := 1
             trigger := TRUE    

        if trigger                     'transmit
          trigger := FALSE            
          FreqOffset := random?//80    'Rand +/-80Hz
          waitcnt(clkfreq/2+cnt)       '1/2 sec delay. put xmit closer to 1 sec start mark
          Xmit := TRUE                 'launch transmitter

      if not Xmit
        outa[LP20] := 0  'disable all low pass filters
        outa[LP30] := 0
        outa[LP40] := 0
        outa[LP80] := 0
        outa[LP160] := 0
        Filter := string("None")
      

      '
      ' The following lines are for terminal display testing only
      '                                                   
      if (valsec==55)&rfsh     'periodic screen refresh
        term.clear
        rfsh := FALSE
      else
        rfsh := TRUE

      term.home
      term.str(string(" ---[ GPS ]---"))
      term.newline

      term.str(string("Stat:"))
      if gpsValid
        term.str(string(" Valid"))
      else
        term.str(string(" Not valid"))
      term.char(term#CE)
      term.newline 

      term.str(string("UTC : "))                                                                    
      term.str(@txttime)                                         
      term.char(term#CE)                                                   
      term.newline                                                         
                                                                          
      term.str(string("Date: "))                                                                    
      term.str(gps.date)                                                                  
      term.char(term#CE)                                                   
      term.newline                                                                                  
                                                                                                    
      term.str(string("Lat : "))                                                                     
      if gpsValid                                                          
        term.str(@txtlat)                                                                  
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)                                                   
      term.newline
                                                                             
      term.str(string("Lon : "))                                                                    
      if gpsValid                                                          
        term.str(@txtlon)                                                                       
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)                                                   
      term.newline                                                                                  
                                                                                                    
      term.str(string("Grid: "))                                                              
      if gpsValid                                                          
        term.str(@txtmhg)                                                                             
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)                                                   
      term.newline                                                                                  
                                                                                                    
      term.str(string("Alt : "))                                                                     
      if gpsValid                                                          
        term.str(gps.GPSaltitude)                                                        
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)                                                   
      term.newline                                                                                  
 
      term.str(string("Sats: "))                                                                     
      term.str(gps.satellites)                                                        
      term.char(term#CE)                                                   
      term.newline                                                                                  
 
      term.newline
      term.str(string(" ---[ WSPR ]---"))
      term.newline
      
      term.str(string("Data: "))
      term.str(@msg)
      term.char(term#CE)                                                   
      term.newline

      term.str(string("Foff: "))
      term.dec(FreqOffset)
      term.char(term#CE)                                                   
      term.newline                                                                                  

      term.str(string("Freq: "))
      term.dec(Frequency + FreqOffset)
      term.char(term#CE)                                                   
      term.newline

      term.str(string("Xmit: "))
      if Xmit
        term.str(string("-[ ON AIR ]-"))
      else
        term.str(string("-Off- "))
      term.char(term#CE)     
      term.newline

      term.str(string("Filt: "))
      term.str(Filter)
      term.char(term#CE)     
      term.newline

      term.newline
      term.str(string(" ---[ SYSTEM ]---"))
      term.newline

      term.str(string("Vtim: "))
      term.dec(valmin)      'num min
      term.str(string(":"))
      term.dec(valsec)      'num sec
      term.char(term#CE)     
      term.newline

      term.str(string("Zsat: "))
      term.dec(strsize(@txtsat))
      term.char(term#CE)                                                   
      term.newline
      term.str(string("Zlat: "))
      term.dec(strsize(@txtlat))
      term.char(term#CE)                                                   
      term.newline
      term.str(string("Zlon: "))
      term.dec(strsize(@txtlon))
      term.char(term#CE)                                                   
      term.newline
      
      
      term.str(string("XCog= "))
      term.dec(Xcog)
      term.newline
      term.str(string("GCog= "))
      term.dec(Gcog)
      term.newline   
      
      term.str(string("Symb: "))
      term.dec(ipos)
      term.char(term#CE)
      term.newline


      term.str(string("FCnt: "))
      if gpsValid                                                          
        term.dec(FCount)
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)
      term.newline
      
      term.str(string("FDif: "))
      if gpsValid                                                          
        term.dec(FDiff)
      else                                                                 
        term.str(string("-"))                                              
      term.char(term#CE)
      term.newline
      
      term.str(string("XFrq: "))
      if gpsValid                                                          
        term.dec(FDiff/16)
      else                                                                 
        term.str(string("-"))                                              
      term.str(string(" Hz"))
      term.char(term#CE)
      term.newline
      
      term.str(string("XDif: "))
      if gpsValid                                                          
        term.dec((FDiff/16)-(clkfreq/16))
      else                                                                 
        term.str(string("-"))                                              
      term.str(string(" Hz"))
      term.char(term#CE)
      
CON
   GpsPpsPin  =   0  'P0 -  1 pps input from gps
   PpsDspPin  =   1  'P1 -  1 pps display led
  
VAR  
   long fc_stack[24] 
   long FCount,FDiff   'freq count and diff values 

PUB FreqCheck 

  'count the clock cycles between 1pps signal rise
  
''//TODO- Use this info to auto-adjust the frequency output error
    
  dira[GpsPpsPin]~  '1 pps input
  dira[PpsDspPin]~~ 'pps indicator led
  
  repeat
    waitpeq(%01, %01, GpsPpsPin) 'wait for pps pin level rise
    FDiff := cnt - FCount        'calculate difference
    FCount := cnt                'get a new start value
    outa[PpsDspPin] := 1         'flash the led
    waitcnt(clkfreq/16+cnt)        
    outa[PpsDspPin] := 0         
    waitpne(%01, %01, GpsPpsPin) 'ensure the gps pulse has dropped

PUB Transmit | sym, iSym

  repeat

    repeat until Xmit  'wait for transmit flag                                                                               

    sym := WSPR.encodeWSPR(@msg)                                                         
    repeat iSym from 0 to 161                                                                                           

      case byte[sym][iSym]            

        "0", 0:                                    
          Freq.Synth("A",RFPin, Frequency + ErrorOffset + FreqOffset - 3)                               
          waitcnt((tokenTime #> WMin) + cnt)                    

        "1", 1:                                    
          Freq.Synth("A",RFPin, Frequency + ErrorOffset + FreqOffset - 1)                               
          waitcnt((tokenTime #> WMin) + cnt)                    

        "2", 2:                                    
          Freq.Synth("A",RFPin, Frequency + ErrorOffset + FreqOffset + 1)                               
          waitcnt((tokenTime #> WMin) + cnt)                    

        "3", 3:                                    
          Freq.Synth("A",RFPin, Frequency + ErrorOffset + FreqOffset + 3)                               
          waitcnt((tokenTime #> WMin) + cnt)                    

      iPos := iSym 'debug
                            
    stopTone                                                                                                                                                                  
    Xmit := FALSE                                         

                                                
PUB sendTone(tone)
  Freq.Synth("A",RFPin, Frequency + tone + ErrorOffset + FreqOffset)

PUB stopTone
  Freq.Synth("A",RFPin, 0)
  
PRI LatLon2Mh(latstr, lonstr, mstr) : str | _lat, _lon, _latm, _lonm, _latm8, _lonm8
{{
  Convert Lat-Lon to 6-char Maidenhead grid. Put the result into mstr

                            1 1 
  Pos:  0 1 2 3 4 5 6 7 8 9 0 1 
       +-+-+-+-+-+-+-+-+-+-+-+-+
  Lat:  4 1 2 0 . 4 6 2 2 1 N
  Lon:  0 8 3 3 2 . 9 8 1 5 7 W
       +-+-+-+-+-+-+-+-+-+-+-+-+
}}

  _lat   := ((byte[latstr][0] - "0") * 10)  +  (byte[latstr][1] - "0")
  _latm  := ((byte[latstr][2] - "0") * 100) + ((byte[latstr][3] - "0") * 10) + (byte[latstr][5] - "0") 
  _latm8 := ((byte[latstr][3] - "0") * 100) + ((byte[latstr][5] - "0") * 10) + (byte[latstr][6] - "0")
  
  _lon   := ((byte[lonstr][0] - "0") * 100) + ((byte[lonstr][1] - "0") * 10) + (byte[lonstr][2] - "0") 
  _lonm  := ((byte[lonstr][3] - "0") * 10) +   (byte[lonstr][4] - "0") 
  _lonm8 := ((byte[lonstr][4] - "0") * 100) + ((byte[lonstr][6] - "0") * 10) + (byte[lonstr][7] - "0")  

  if(byte[latstr][10]=="S")
    _lat := -_lat
  _lat := _lat + 90

  if(byte[lonstr][11]=="W")
    _lon := -_lon
  _lon := _lon + 180

' 1st char
  byte[mstr][0] := "A" + _lon/20
  if(byte[lonstr][11]=="W")
    if((_lon//20)==0)
      byte[mstr][0] := byte[mstr][0] - 1      

' 2nd char
  byte[mstr][1] := "A" + _lat/10
  if(byte[latstr][10]=="S")
    if((_lat//10)==0)
      byte[mstr][1] := byte[mstr][1] -1

  _lon := _lon - 180
  _lat := _lat - 90

' 3rd char
  if(byte[lonstr][11]=="W")
    byte[mstr][2] := "9" + ((_lon//20)/2)   '+ OK. Lon is negative when West
  else
    byte[mstr][2] := "0" + ((_lon//20)/2)

' 4th char
  if(byte[latstr][10]=="N")
    byte[mstr][3] := "0" + (_lat//10)
  else
    byte[mstr][3] := "9" + (_lat//10)       '+ OK. Lat is negative when South

' 5th char
  if((_lon//2)==0) 'even
    if(byte[lonstr][11]=="W")
      byte[mstr][4] := "x" - (_lonm/5)
    else
      byte[mstr][4] := "a" + (_lonm/5)
  else
    if(byte[lonstr][11]=="W")
      byte[mstr][4] := "l" - (_lonm/5)
    else
      byte[mstr][4] := "m" + (_lonm/5)

' 6th char
  if(byte[latstr][10]=="N")
    byte[mstr][5] := "a" + (_latm/25)
  else
    byte[mstr][5] := "x" - (_latm/25)
  byte[mstr][6] := 0


DAT     
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}       
    