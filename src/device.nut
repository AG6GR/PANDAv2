// Device code for PillBox

/* ----- Pin Definitions ----- */
spiBus <- hardware.spi257;
pinBuzzer <- hardware.pin1;
pinLCDEnable <- hardware.pin2;
pinShiftStore <- hardware.pin8;
pinPhotocell <- hardware.pin9;

/* ----- Constants ----- */
const LIGHT_THRESH = 50000;
const BUZZER_PERIOD = 0.0005;
const NUM_LEDS = 2;

// LCD constants
const LCD_COMMAND = 0;
const LCD_DATA = 1;
const LCD_X = 84;       // Screen's pixel width
const LCD_Y = 48;       // Screen's pixel height

// Shift register bit positions
const LCD_DC = 0x02;
const LCD_RESET = 0x04;
const LED0_GREEN = 0x10;
const LED0_RED = 0x20;
const LED1_GREEN = 0x40;
const LED1_RED = 0x80;

// State machine states
const STATE_OPEN = 1;
const STATE_CLOSED = 0;
const STATE_ALERT = 2;

// ASCII is an array of Ascii characters, each defined by an 
// array of five 8-bit values specifying a 5 x 8 pixel matrix
// used for displaying text on the LCD.
// Note: we pad characters in the code

ASCII <- [
[0x00, 0x00, 0x00, 0x00, 0x00], // 20  
[0x00, 0x00, 0x5f, 0x00, 0x00], // 21 !
[0x00, 0x07, 0x00, 0x07, 0x00], // 22 "
[0x14, 0x7f, 0x14, 0x7f, 0x14], // 23 #
[0x24, 0x2a, 0x7f, 0x2a, 0x12], // 24 $
[0x23, 0x13, 0x08, 0x64, 0x62], // 25 %
[0x36, 0x49, 0x55, 0x22, 0x50], // 26 &
[0x00, 0x05, 0x03, 0x00, 0x00], // 27 '
[0x00, 0x1c, 0x22, 0x41, 0x00], // 28 (
[0x00, 0x41, 0x22, 0x1c, 0x00], // 29 )
[0x14, 0x08, 0x3e, 0x08, 0x14], // 2a *
[0x08, 0x08, 0x3e, 0x08, 0x08], // 2b +
[0x00, 0x50, 0x30, 0x00, 0x00], // 2c ,
[0x08, 0x08, 0x08, 0x08, 0x08], // 2d -
[0x00, 0x60, 0x60, 0x00, 0x00], // 2e .
[0x20, 0x10, 0x08, 0x04, 0x02], // 2f /
[0x3e, 0x51, 0x49, 0x45, 0x3e], // 30 0
[0x00, 0x42, 0x7f, 0x40, 0x00], // 31 1
[0x42, 0x61, 0x51, 0x49, 0x46], // 32 2
[0x21, 0x41, 0x45, 0x4b, 0x31], // 33 3
[0x18, 0x14, 0x12, 0x7f, 0x10], // 34 4
[0x27, 0x45, 0x45, 0x45, 0x39], // 35 5
[0x3c, 0x4a, 0x49, 0x49, 0x30], // 36 6
[0x01, 0x71, 0x09, 0x05, 0x03], // 37 7
[0x36, 0x49, 0x49, 0x49, 0x36], // 38 8
[0x06, 0x49, 0x49, 0x29, 0x1e], // 39 9
[0x00, 0x36, 0x36, 0x00, 0x00], // 3a :
[0x00, 0x56, 0x36, 0x00, 0x00], // 3b ;
[0x08, 0x14, 0x22, 0x41, 0x00], // 3c <
[0x14, 0x14, 0x14, 0x14, 0x14], // 3d =
[0x00, 0x41, 0x22, 0x14, 0x08], // 3e >
[0x02, 0x01, 0x51, 0x09, 0x06], // 3f ?
[0x32, 0x49, 0x79, 0x41, 0x3e], // 40 @
[0x7e, 0x11, 0x11, 0x11, 0x7e], // 41 A
[0x7f, 0x49, 0x49, 0x49, 0x36], // 42 B
[0x3e, 0x41, 0x41, 0x41, 0x22], // 43 C
[0x7f, 0x41, 0x41, 0x22, 0x1c], // 44 D
[0x7f, 0x49, 0x49, 0x49, 0x41], // 45 E
[0x7f, 0x09, 0x09, 0x09, 0x01], // 46 F
[0x3e, 0x41, 0x49, 0x49, 0x7a], // 47 G
[0x7f, 0x08, 0x08, 0x08, 0x7f], // 48 H
[0x00, 0x41, 0x7f, 0x41, 0x00], // 49 I
[0x20, 0x40, 0x41, 0x3f, 0x01], // 4a J
[0x7f, 0x08, 0x14, 0x22, 0x41], // 4b K
[0x7f, 0x40, 0x40, 0x40, 0x40], // 4c L
[0x7f, 0x02, 0x0c, 0x02, 0x7f], // 4d M
[0x7f, 0x04, 0x08, 0x10, 0x7f], // 4e N
[0x3e, 0x41, 0x41, 0x41, 0x3e], // 4f O
[0x7f, 0x09, 0x09, 0x09, 0x06], // 50 P
[0x3e, 0x41, 0x51, 0x21, 0x5e], // 51 Q
[0x7f, 0x09, 0x19, 0x29, 0x46], // 52 R
[0x46, 0x49, 0x49, 0x49, 0x31], // 53 S
[0x01, 0x01, 0x7f, 0x01, 0x01], // 54 T
[0x3f, 0x40, 0x40, 0x40, 0x3f], // 55 U
[0x1f, 0x20, 0x40, 0x20, 0x1f], // 56 V
[0x3f, 0x40, 0x38, 0x40, 0x3f], // 57 W
[0x63, 0x14, 0x08, 0x14, 0x63], // 58 X
[0x07, 0x08, 0x70, 0x08, 0x07], // 59 Y
[0x61, 0x51, 0x49, 0x45, 0x43], // 5a Z
[0x00, 0x7f, 0x41, 0x41, 0x00], // 5b [
[0x02, 0x04, 0x08, 0x10, 0x20], // 5c \
[0x00, 0x41, 0x41, 0x7f, 0x00], // 5d ],
[0x04, 0x02, 0x01, 0x02, 0x04], // 5e ^
[0x40, 0x40, 0x40, 0x40, 0x40], // 5f _
[0x00, 0x01, 0x02, 0x04, 0x00], // 60 `
[0x20, 0x54, 0x54, 0x54, 0x78], // 61 a
[0x7f, 0x48, 0x44, 0x44, 0x38], // 62 b
[0x38, 0x44, 0x44, 0x44, 0x20], // 63 c
[0x38, 0x44, 0x44, 0x48, 0x7f], // 64 d
[0x38, 0x54, 0x54, 0x54, 0x18], // 65 e
[0x08, 0x7e, 0x09, 0x01, 0x02], // 66 f
[0x0c, 0x52, 0x52, 0x52, 0x3e], // 67 g
[0x7f, 0x08, 0x04, 0x04, 0x78], // 68 h
[0x00, 0x44, 0x7d, 0x40, 0x00], // 69 i
[0x20, 0x40, 0x44, 0x3d, 0x00], // 6a j 
[0x7f, 0x10, 0x28, 0x44, 0x00], // 6b k
[0x00, 0x41, 0x7f, 0x40, 0x00], // 6c l
[0x7c, 0x04, 0x18, 0x04, 0x78], // 6d m
[0x7c, 0x08, 0x04, 0x04, 0x78], // 6e n
[0x38, 0x44, 0x44, 0x44, 0x38], // 6f o
[0x7c, 0x14, 0x14, 0x14, 0x08], // 70 p
[0x08, 0x14, 0x14, 0x18, 0x7c], // 71 q
[0x7c, 0x08, 0x04, 0x04, 0x08], // 72 r
[0x48, 0x54, 0x54, 0x54, 0x20], // 73 s
[0x04, 0x3f, 0x44, 0x40, 0x20], // 74 t
[0x3c, 0x40, 0x40, 0x20, 0x7c], // 75 u
[0x1c, 0x20, 0x40, 0x20, 0x1c], // 76 v
[0x3c, 0x40, 0x30, 0x40, 0x3c], // 77 w
[0x44, 0x28, 0x10, 0x28, 0x44], // 78 x
[0x0c, 0x50, 0x50, 0x50, 0x3c], // 79 y
[0x44, 0x64, 0x54, 0x4c, 0x44], // 7a z
[0x00, 0x08, 0x36, 0x41, 0x00], // 7b [
[0x00, 0x00, 0x7f, 0x00, 0x00], // 7c |
[0x00, 0x41, 0x36, 0x08, 0x00], // 7d ]
[0x10, 0x08, 0x08, 0x10, 0x08], // 7e ~
[0x78, 0x46, 0x41, 0x46, 0x78], // 7f DEL
];

/* ----- Local Variables ----- */
local deviceState; // Current state machine state
local leds = array(NUM_LEDS); // Array of LED objects representing connected LED
local shiftReg; // Shift register object

/* ----- Local Variables ----- */

/* Turns both LEDs off to save power by writing 0 to all LED output addresses */
function ledOff()
{
    local i;
    for (i = 0; i < leds.len(); i++)
    {
        shiftReg.setBit(leds[i].addrGreen, false);
        shiftReg.setBit(leds[i].addrRed, false);
        
        // Set back to red when the box is closed
        leds[i].isGreen = false;
    }
}
/* Turn on the leds, corresponding to state variables */
function ledOn()
{
    local i;
    for (i = 0; i < leds.len(); i++)
    {
        shiftReg.setBit(leds[i].addrGreen, leds[i].isGreen);
        shiftReg.setBit(leds[i].addrRed, (!leds[i].isGreen));
    }
}
/*
 * Turns on the buzzer
 */
function startBeep()
{
    pinBuzzer.write(0.5);
    //imp.wakeup(1, endBeep)
}
/*
 * Stops the buzzer
 */
function endBeep()
{
    pinBuzzer.write(0.0);
}

/*
 * Handler for Alert message from agent
 *
 * data: Array containing the integer id of the LED to activate at index 0 and 
 *       a string to print to the LCD at index 1.
 */
function onAlert(data)
{
    local ledID = data[0];
    local text = data[1];
    server.log("Received data: " + text);
    LCDString(text);
    deviceState = STATE_ALERT;
    server.log("STATE_ALERT");
    
    // Set color of alerted led
    leds[ledID].isGreen = true;
    
    startBeep();
}

/* Initialization, run once at start */
function init()
{
    // Light sensor
    pinPhotocell.configure(ANALOG_IN);
    deviceState = STATE_CLOSED;
    
    // LEDs
    leds[0] = LED(false, LED0_GREEN, LED0_RED);
    leds[1] = LED(false, LED1_GREEN, LED1_RED);
    
    // SPI
    spiBus.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 1);
    shiftReg = ShiftRegister74HC595(spiBus, pinShiftStore);
    
    // Beeper
    pinBuzzer.configure(PWM_OUT, BUZZER_PERIOD, 0.0);
    pinBuzzer.write(0.0);
    //startBeep();
    
    // LCD
    LCDInit();

    // Alert handling
    agent.on("Alert", onAlert);
    
    server.log("Init finished, starting loop");
}

/* Loop, run once a second. Implements state machine logic for PANDA */
function loop()
{
    //server.log(pinPhotocell.read());
    
    switch(deviceState)
    {
        case STATE_OPEN:
            if (pinPhotocell.read() > LIGHT_THRESH)
            {
                deviceState = STATE_CLOSED;
                server.log("open -> closed");
                agent.send("box lid event", false);
                ledOff();
            }
            break;
        case STATE_CLOSED:
            if (pinPhotocell.read() < LIGHT_THRESH)
            {
                deviceState = STATE_OPEN;
                server.log("closed -> open");
                agent.send("box lid event", true);
                ledOn();
            }
            break;
        case STATE_ALERT:
            if (pinPhotocell.read() < LIGHT_THRESH)
            {
                deviceState = STATE_OPEN;
                server.log("alert -> open");
                ledOn();
                endBeep();
            }
            
            break;
    }
    imp.wakeup(1, loop);
}

/* ----- Classes ----- */

class LED {
    /* Class representing a Bicolor LED connected to PANDA and its state */
    
    isGreen = false; // LED's color
    addrGreen = -1; // Bit position of green output
    addrRed = -1;   // Bit position of red output
    
    /*
     * Creates a new LED object with the specified color and addresses.
     *
     * newisGreen: Boolean specifiying the color of the LED
     * newAddrGreen: Integer address (bit position) of green LED's output
     * newAddrRed: Integer address (bit position) of green LED's output
     */
    constructor(newIsGreen, newAddrGreen, newAddrRed)
    {
        isGreen = newIsGreen;
        addrGreen = newAddrGreen
        addrRed = newAddrRed;
    }
    /* Returns the address of the output corresponding to the current color
     * of the LED
     */
    function getAddr()
    {
        return isGreen ? addrGreen : addrRed;
    }
}

class ShiftRegister74HC595 {
    /* Squirrel class for communicating with 74HC595 shift register over SPI */
    
    // Private Properties
    _state = 0;     // State currently stored in register
    _pinRCK = null; // Register storage latch clock
    _spiBus = null; // SPI bus connected to SCK and Serial Data pins
    
    /** 
     * Creates a new Shift Register object. Returns null if any of the paramters
     * are null.
     * 
     * impSPIbus: SPI Bus to use for communications
     * impRCKbus: GPIO pin connected to register storage latch clock
     */
    constructor(impSPIbus, impRCKpin)
    {
        if (impSPIbus == null || impRCKpin == null)
            return null;
        _spiBus = impSPIbus;
        _pinRCK = impRCKpin;
        _pinRCK.configure(DIGITAL_OUT);
        setState(0x00);
    }
    /** 
     * Updates the outputs of the shift register to correspond to state. 
     * MSB of state corresponds to output 7, LSB of state corresponds to 
     * output 0. Equivalent to shifting out state MSB first.
     */
    function update()
    {
        local value = blob(1);
        value.writen(_state, 'b');
        //server.log(format("%X",_state));
        _pinRCK.write(0);
        _spiBus.write(value);
        _pinRCK.write(1);
        _pinRCK.write(0);
    }
    /** 
     * Sets the outputs of the shift register to values specifified by the byte
     * data. MSB of data corresponds to output 7, LSB of data corresponds to 
     * output 0. Equivalent to shifting out data MSB first.
     * 
     * data: byte specifing new state of the shift register
     */
    function setState(data)
    {
        _state = data;
        update();
    }
    /** 
     * Sets the bit at the specified address to the specified value.
     * 
     * addr: byte specifing which bit to set
     * value: boolean specifiying what value to set the bit to.
     */
    function setBit(addr, value)
    {
        // Note 0 != false returns true, so extra comparison needed
        if (((_state & addr) != 0) != value)
        {
            // Flip bit at addr
            _state = _state ^ addr;
            update();
        }
    }
    /**
     * Returns the current state of the shift register.
     */
    function getState()
    {
        return _state;
    }
}

/* ----- LCD Functions ----- */
/* Adapted from community.electricimp.com/tutorials/phone-home-how-to-add-a-nokia-5110-lcd-panel-to-your-project/ */
function LCDInit()
{
    // Configure the imp's pins
    pinLCDEnable.configure(DIGITAL_OUT);
    pinLCDEnable.write(1);
    
    // Reset the PCD8544 by setting RESET low then, after 10ms, back to high
    server.log("LCD Resets");
    shiftReg.setBit(LCD_RESET, true);
    shiftReg.setBit(LCD_RESET, false);
    imp.sleep(0.1); // Bad, is there a better alternative?
    pinLCDEnable.write(1);
    shiftReg.setBit(LCD_RESET, true);
    
    
    server.log("LCD Init");
    // Initialize the PCD8544 for use
    // Send Function command (0x20) to select either  
    // basic command set (+0), or extended command set (+1)
    
    LCDWrite(LCD_COMMAND, 0x21);    
    
    // Set LCD contrast command (0x80) using Vop
    // Try 0xB1 (good @ 3.3V) or 0xBF if your display is too dark
    
    LCDWrite(LCD_COMMAND, 0x80); 
    
    // Set LCD temperature coefficient (0x04 + 0-3)
    
    LCDWrite(LCD_COMMAND, 0x04);
    
    // Set LCD bias voltage (0x10 + 0-7)
    
    LCDWrite(LCD_COMMAND, 0x14);
    
    // Send Function command (0x20) to select either
    // horizontal screen addressing (+0) or vertical addressing (+2)
    
    LCDWrite(LCD_COMMAND, 0x20);
    
    // Set LCD display mode (0x08) plus
    // 0 - All pixels clear (0x08)
    // 1 - All pixels set (0x09)
    // 4 - Normal video (0x0C)
    // 5 - Inverse video (0x0D)
    
    LCDWrite(LCD_COMMAND, 0x09);
    
    //LCDClear();
    LCDString("Hello World!");
}
function LCDXY(x, y)
{
    // Position the cursor at column x, row y
    // Origin is top left. x = 0-83. y = 0-5
    
    LCDWrite(LCD_COMMAND, 0x80 | x);
    LCDWrite(LCD_COMMAND, 0x40 | y);
}
function LCDClear()
{
    // Clear the LCD by writing zeros to the entire screen

    for (local index = 0 ; index < (LCD_X * LCD_Y / 8) ; index++)
    {
        LCDWrite(LCD_DATA, 0x00);
    }
    
    // Position the cursor at the origin
    
    LCDXY(0, 0);
}
function LCDWriteByte(byteValue) 
{   
	// Takes a byte of data and writes it out to the 5110 bit by bit,
	// most significant bit first, least significant bit last.
	// Each bit is signalled by setting pin CLK low and setting CLK
	// high after the bit has been sent.
	local value = blob(1);
    value.writen(byteValue, 'b');
	spiBus.write(value);
	pinLCDEnable.write(1);
	spiBus.write(value);
}
function LCDWrite(data_or_command, data)
{
    // There are two memory banks in the LCD: one for data, another for
    // commands. Select the one you want by setting pin DC high (data) or
    // low (command). Then signal the data/command transmission by setting
    // pin CE low, writing the data/command, them setting CE high.
    
    if (data_or_command == LCD_COMMAND)
    {
        //server.log("command");
        shiftReg.setBit(LCD_DC, false);
    }
    else
    {
        //server.log("data");
        shiftReg.setBit(LCD_DC, true);
    }
    
    // Send the data
    pinLCDEnable.write(0);
    LCDWriteByte(data);
}
function LCDCharacter(character)
{
    // Writes a 5 x 8 character graphic from the ASCII array to the screen
    // at the current cursor position. The integer parameter is the Ascii
    // code of the character you want to print. The character is padded with
    // one blank line to its left and another to its right.
    
    LCDWrite(LCD_DATA, 0x00);

    for (local index = 0 ; index < 5 ; index++)
    {
        LCDWrite(LCD_DATA, ASCII[character - 0x20][index]);
    }
    
    LCDWrite(LCD_DATA, 0x00);
}
function LCDString(string) 
{
    // Write a string of chracters to the LCD by taking each individual
    // character and writing it with LCDCharacter(). The PCD8544 chip will
    // move the cursor for you, wrapping the line and scrolling if necessary

    foreach (character in string)
    {
        LCDCharacter(character);
    }
}

init();
// Wait 1 sec to start up
imp.wakeup(1, loop);