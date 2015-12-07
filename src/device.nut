// Device code for PillBox

// Pin Definitions
spiBus <- hardware.spi257;
pinBuzzer <- hardware.pin1;
pinLCDEnable <- hardware.pin2;
pinShiftStore <- hardware.pin8;
pinPhotocell <- hardware.pin9;

// Constants
const LIGHT_THRESH = 50000;
const BUZZER_PERIOD = 0.0005;
const NUM_LEDS = 2;

// Shift register bit positions
const LCD_DC = 0x02;
const LCD_RESET = 0x04;
const LED0_GREEN = 0x10;
const LED0_RED = 0x20;
const LED1_GREEN = 0x40;
const LED1_RED = 0x80;

const STATE_OPEN = 1;
const STATE_CLOSED = 0;
const STATE_ALERT = 2;

// Local Variables
local deviceState;
local leds = array(NUM_LEDS);
local shiftReg;

// Turns both LEDs off to save power
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
// Turn on the leds, corresponding to state variables
function ledOn()
{
    local i;
    for (i = 0; i < leds.len(); i++)
    {
        shiftReg.setBit(leds[i].addrGreen, leds[i].isGreen);
        shiftReg.setBit(leds[i].addrRed, (!leds[i].isGreen));
    }
}
// Turns on the beeper
function startBeep()
{
    pinBuzzer.write(0.5);
    //imp.wakeup(1, endBeep)
}
// Stops the beeper
function endBeep()
{
    pinBuzzer.write(0.0);
}

// Handler for Alert message from agent
function onAlert(ledID)
{
    deviceState = STATE_ALERT;
    server.log("STATE_ALERT");
    
    // Set color of alerted led
    leds[ledID].isGreen = true;
    
    startBeep();
}

// Initialization, run once at start
function init()
{
    // Light sensor
    pinPhotocell.configure(ANALOG_IN);
    deviceState = STATE_CLOSED;
    
    // LEDs
    leds[0] = LED(false, LED0_GREEN, LED0_RED);
    leds[1] = LED(false, LED1_GREEN, LED1_RED);
    
    // SPI
    spiBus.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 3000);
    shiftReg = ShiftRegister74HC595(spiBus, pinShiftStore);
    
    // Beeper
    pinBuzzer.configure(PWM_OUT, BUZZER_PERIOD, 0.0);
    pinBuzzer.write(0.0);
    
    //startBeep();
    
    // Alert handling
    agent.on("Alert", onAlert);
    
    server.log("Init finished, starting loop");
}
// Loop, run once a second
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

/* ----- LCD Functions ----- */

function LCDWriteByte(byteValue) 
{   
	// Takes a byte of data and writes it out to the 5110 bit by bit,
	// most significant bit first, least significant bit last.
	// Each bit is signalled by setting pin CLK low and setting CLK
	// high after the bit has been sent. The bit is sent on pin DIN.
	
	for (local i = 8 ; i > 0 ; i--)
    {		  
		PIN_CLK.write(0);
		PIN_DIN.write(byteValue & 0x80);
		byteValue = byteValue << 1;
		PIN_CLK.write(1);
	}
}

class LED {
    /* Class representing a LED connected to PANDA and its state */
    isGreen = false;
    addrGreen = -1;
    addrRed = -1;
    
    constructor(newIsGreen, newAddrGreen, newAddrRed)
    {
        isGreen = newIsGreen;
        addrGreen = newAddrGreen
        addrRed = newAddrRed;
    }
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
        server.log(value);
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

init();
// Wait 1 sec to start up
imp.wakeup(1, loop);