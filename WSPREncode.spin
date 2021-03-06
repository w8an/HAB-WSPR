{{
┌──────────────────────────────────────────┐
│ WSPR Message Encoder Version 1.0         │
│ Author: Jeff Whitlatch                   │               
│ Copyright (c) 2012 Jeff Whitlatch        │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

  This object is primarily of interest to licensed Radio Amateurs.
  
  Please see http://www.arrl.org/licensing-education-training for information on becoming a licensed HAM radio operator

  What is WSPR?

  WSPR (pronounced "whisper") stands for Weak Signal Propagation Reporter.  The WSPR software is designed
  for probing potential radio propagation paths using low-power beacon-like transmissions. WSPR signals
  convey a callsign, Maidenhead grid locator, and power level using a compressed data format with strong
  forward error correction and narrow-band 4-FSK modulation.  The protocol is effective at signal-to-noise
  ratios as low as 28 dB in a 2500 Hz bandwidth. Receiving stations with internet access may automatically
  upload reception reports to a central database. The WSPRnet.org web site provides a simple user interface
  for querying the database, a mapping facility, and many other features.

  The WSPR 2.0 Users Guide can be obtained at http://physics.princeton.edu/pulsar/K1JT/WSPR_2.0_User.pdf

  Information about Maidenhead grid squares can be found at http://www.arrl.org/grid-squares

  What is this object?

  The WSPR message encoder is designed to take a callsign, grid locator and power level and return a string
  of encoded symbols that can be used to transmit WSPR signals on Amateur Radio frequencies.

  No additional cogs started by this object.
  
  From WSPR 2.0 Documentation:
  http://physics.princeton.edu/pulsar/K1JT/WSPR_2.0_User.pdf
  
  Standard messages are supported:  Call Sign, 4 digit locatorm dBm  (KO7M CN87 7)
  Standard message components after lossless compression:
        Callsign                28 bits
        Locator                 15 bits
        Power Level              7 bits
  Total of 50 bits.

  Compound call signs and 6 digit locators not currently supported.

  Forward error correction (FEC)  : Convolution code with contraint length K=32, rate r=1/2
  Number of binary channel symbols: nSym = (50+K-1) * 2 = 162
  Keying Rate                     : 12000 / 8192 = 1.4648 baud
  Modulation                      : continuous phase 4-FSK, tone separation 1.4648 Hz
  Bandwidth                       : approximately 6 Hz
  Synchronization                 : 162 bit pseudo-random sync vector
  Each channel symbol conveys one sync bit (LSB) and one data bit (MSB)
  Transmission duration           : 162 * 8192/12000 = 110.6 seconds
  Transmissions nominally start one second into an even UTC minute
  Minimum S/N for reception       : -28 dB on the WSJT scale (2500 Hz reference bandwidth)

  For more information about FEC (forward error-correction coding) please see:
  
     http://www.aero.org/publications/crosslink/winter2002/04_sidebar1.html

  Another great work on how to encode WSPR messages can be found at
     http://physics.princeton.edu/pulsar/K1JT/WSPR_2.0_User.pdf   
}}

CON
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

  WMin  = 381        'WAITCNT-expression-overhead Minimum
  SP    = 32         ' Space character
  TAB   = 9          ' Tab character
  NL    = 13         ' Newline character
  #1, ErrInvalidChar 
  
OBJ
     
VAR
  BYTE em[11]         ' Encoded message
  BYTE sym[170]       ' Symbol table
  BYTE symt[170]      ' Temporary symbol table
  BYTE callsign[16]   ' 6 character callsign allowed.  Room for future expansion
  BYTE locator[8]     ' 4 character locator allowed.  Room for future expansion
  BYTE power[4]       ' power in 0..60 dBm
  LONG dBm            ' power converted to binary   
  LONG encodedCall    ' Encoded callsign
  LONG encodedLoc     ' Encoded grid square locator
  LONG dwErr          ' Error code

DAT
  ' 162 bits of a pseudo random synchronization word having good auto-correlation properties 
  syncVector BYTE 1,1,0,0,0,0,0,0,1,0,0,0,1,1,1,0,0,0,1,0,0,1,0,1,1,1,1,0,0,0,0,0
             BYTE 0,0,1,0,0,1,0,1,0,0,0,0,0,0,1,0,1,1,0,0,1,1,0,1,0,0,0,1,1,0,1,0
             BYTE 0,0,0,1,1,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,1,1,0,0,0,1,1,0,1,0,1,0
             BYTE 0,0,1,0,0,0,0,0,1,0,0,1,0,0,1,1,1,0,1,1,0,0,1,1,0,1,0,0,0,1,1,1
             BYTE 0,0,0,0,0,1,0,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,1,0,1,1,0,0,0,1,1,0
             BYTE 0,0
          
PUB Main | i, mySym
  ' Insert test code here to run this module stand-alone.
  ' Declare a variable of type LONG to hold the returned address of an array of 162+1 symbols
  ' VAR
  '   LONG symbols
  ' symbols := encodeWSPR("<your callsign> <your 4 digit grid square> <your power in dBm>")
  '
  ' printing the string built in the symbols array should yield a 162 byte string of digits 0..3
  ' representing the encoded 4-FSK WSPR message
   
PUB encodeWSPR(message)
  ' First parse the message to be encoded into callsign, locator and power
  parseMessage(message)
  ' Encode the message into an array of symbols
  encodeWSPR_(@callsign, @locator, dBm)
  return @sym
  
PUB encodeWSPR_(callSignParam, locatorParam, powerParam)
  ' If you prefer to hand in separate parameters for the components of the WSPR message, use this API
  encodeCall(callSignParam)
  encodeLocPower(locatorParam, powerParam)
  encodeConv
  interleaveSync

PUB getWSPRerrorCode | err
  ' Return any error code set.  Retrieving it will also clear it.
  err := dwErr
  dwErr := 0
  return err
  
PRI chNormalize(ch) : chNormalized
  ' Normalize characters 0..9 A..Z <space> to 0..36
  case ch
    "0".."9": chNormalized := ch - "0"
    "A".."Z": chNormalized := ch - "A" + 10
    "a".."z": chNormalized := ch - "a" + 10
    " "     : chNormalized := 36
    Other   : chNormalized := $ff
              dwErr := ErrInvalidChar

PRI encodeCall(callSignParam) | i
  'Encode call sign
  'NOTICE:  It is critical to ensure that the call sign has a numeric in the third digit position, eg:
  '  KO7M
  '  WA6BCJ
  '   K6FL
  '  CU2AA
  '
  'This routine does no such checking of the passed callsign and therefore it is up to the caller to ensure this
  'condition is met
  encodedCall :=                    chNormalize(BYTE[callsignParam][0])
  encodedCall := encodedCall * 36 + chNormalize(BYTE[callsignParam][1])
  encodedCall := encodedCall * 10 + chNormalize(BYTE[callsignParam][2])
  encodedCall := encodedCall * 27 + chNormalize(BYTE[callsignParam][3]) - 10
  encodedCall := encodedCall * 27 + chNormalize(BYTE[callsignParam][4]) - 10
  encodedCall := encodedCall * 27 + chNormalize(BYTE[callsignParam][5]) - 10

  'Merge coded call sign into encoded message 
  em[0] := encodedCall >> 20    ' MSB of callsign
  em[1] := encodedCall >> 12
  em[2] := encodedCall >> 4
  em[3] := encodedCall << 4     ' 4 LSB of callsign and 4 MSB of locator (eventually)
         
PRI encodeLocPower(locatorParam, powerParam) | i, t1
  'Encode maidenhead locator gridsquare and power
  'Encoded message is filled out to 88 bits as input to FEC convolution encoder
  encodedLoc := (179 - 10 * (chNormalize(BYTE[locatorParam][0])-10) - chNormalize(BYTE[locatorParam][2]))* 180 + 10 * (chNormalize(BYTE[locatorParam][1])-10) + chNormalize(BYTE[locatorParam][3])

  'Add in the power bits (7 bits)
  encodedLoc := encodedLoc * 128 + powerParam + 64

  'Merge coded locator and power into encoded message
  em[3]  := em[3] + ($0f & encodedLoc >> 18) ' 4 MSB of locator
  em[4]  := encodedLoc >> 10
  em[5]  := encodedLoc >> 2
  em[6]  := encodedLoc << 6                  ' 2 LSB of locator
  em[7]  := 0
  em[8]  := 0
  em[9]  := 0
  em[10] := 0                                ' Total of 88 bits, 81 used
  
PRI encodeConv | ich, isym, ch, shiftreg, i
  'Convolutional encoding of message array into a 162 bit stream.
  'Encoded message in em[] is expanded to add FEC with rate 1/2, constraint length 32.
  ich       := 0
  isym      := 0
  shiftreg  := 0
  ch        := em[0]

  '81 bits are read out MSB first.  Bits are clocked into a 32 bit shift register (shiftreg)
  'which feeds two exclusive-OR parity generators from feedback taps described by the 32
  'bit values $F2D05351 and $E4613C47.  Each of the 81 bits shifted in generates a parity bit
  'from both generators for a total of 162 bits.
  repeat i from 0 to 80
    if i // 8 == 0
      ch := em[ich++]           ' get next byte of encoded message
    if ch & $80
      shiftreg |= 1
    symt[isym++] := parity(shiftreg & $F2D05351)
    symt[isym++] := parity(shiftreg & $E4613C47)
    ch  <<= 1
    shiftreg <<= 1
  
PRI parity(x) | po
  po := 0
  repeat while x <> 0           ' Loop through x counting 1 bits
    po++
    x &= (x-1)                  ' This removes the least significant bit wherever it is
  return (po & 1)

PRI interleaveSync | i, iRev, iSym
  'Interleave reorder the 162 data bits and merge table with the sync vector
  '
  'Reorder is accomplished by reversing the bits of an 8 bit index into the 162
  'symbol table and moving the source symbol to it's new location specified by
  'the bit-reversed index.  Only the symbols from 0..161 are considered.
  '
  'While reordering, the data bits are merged with 162 bits of a pseudo random
  'synchronization word having good auto-correlation properties producing a four
  'state symbol value.
  iSym := 0
  repeat while iSym < 162    
    repeat i from 0 to 255
      ' Reverse the bits of i into iRev
      iRev := i >< 8            ' Bitwise reverse 8 bits
      if iRev < 162
        sym[iRev] := syncVector[iRev] + 2 * symt[iSym] + "0"   ' Make printable
        iSym++
  sym[162] := 0                 ' Null terminate string

PRI parseMessage(message) | i
  ' Parse the WSPR message into its constituent parts.
  copyToSpace(@callsign, message)
  copyToSpace(@locator, message + strsize(@callsign) + 1)
  copyToSpace(@power, message + strsize(@callsign) + strsize(@locator) + 2)
  normalizeCallsign(@callsign)
  ' Convert string version of dBm to binary
  dBm := 0
  repeat i from 0 to strsize(@power)-1
    dBm := dBm * 10 + byte[@power][i] - "0"

PRI normalizeCallsign(callsignParam) | ich, cch
  ' Callsigns must be space padded front and back to 6 bytes and
  ' the third digit must be numeric.  
  ich := 0
  cch := strsize(callsignParam)
  ' Upper case callsign
  REPEAT cch
    CASE byte[callsignParam][ich]
      "a".."z": byte[callsignParam][ich] -= $20
    ich++
  ' If third character of callsign is non-numeric, need to pad with space on front
  ' The assumption is that if a non-numeric is found that there is only a single leading
  ' character in front of the numberic.  (e.g. K7... vs. KA7...)
  CASE byte[callsignParam][2]
    "A".."Z": repeat ich
                byte[callsignParam][ich] := byte[callsignParam][ich-1]
                ich--
              byte[callsignParam][0] := SP
              byte[callsignParam][++cch] := 0
  ' If callsign is less than 6 characters, need to padd the end with spaces and zero terminate
  ich := 6 - cch
  repeat ich
    byte[callsignParam][cch++] := SP
  byte[callsignParam][6] := 0
   
PRI copyToSpace(dest, source) | ich, cch
  ' Copy bytes from source to dest until a whitespace or end of string is found
  ich := 0
  cch := strsize(source)
  repeat while ich < cch and (byte[source][ich] <> " " and byte[source][ich] <> TAB)
    byte[dest][ich] := byte[source][ich]
    ich++
  ' Null terminate the new string
  byte[dest][ich] := 0    
      
DAT{
PRI delay(Duration)
  ' While not used by this object, it is useful to have a millisecond delay routine when testing.
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> WMin) + cnt)
}  
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