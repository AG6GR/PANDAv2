// Device code for PillBox

local lightOutputPin;
local isOpen;
local alert;
const LIGHT_THRESH = 50000;

// Turns both LEDs off to save power
function ledOff()
{
    hardware.pin1.write(0);
    hardware.pin2.write(0);
    hardware.pin7.write(0);
    hardware.pin8.write(0);
}
// Turn on the leds, true to set green for respective led, false to set red
function setLed(top, bottom)
{
    // Top LED
    hardware.pin7.write(top? 1 : 0);
    hardware.pin8.write(top? 0 : 1);
    
    // Bottom LED
    hardware.pin1.write(bottom? 1 : 0);
    hardware.pin2.write(bottom? 0 : 1);
}
// Turns on the beeper
function startBeep()
{
    hardware.pin9.write(0.5);
    //imp.wakeup(1, endBeep)
}
// Stops the beeper
function endBeep()
{
    hardware.pin9.write(0.0);
}
// Handler for Alert message from agent, lightBox is boolean array with states
//  of top and bottom leds respectively
function onAlert(lightBox)
{
    alert = true;
    server.log("Lighting leds");
    server.log(lightBox[0])
    server.log(lightBox[1])
    setLed(lightBox[0], lightBox[1]);
    startBeep();
}
// Initialization, run once at start
function init()
{
    // Light sensor
    lightOutputPin = hardware.pin5
    lightOutputPin.configure(ANALOG_IN)
    isOpen = lightOutputPin.read() < LIGHT_THRESH;
    
    // LEDs
    hardware.pin1.configure(DIGITAL_OUT);
    hardware.pin2.configure(DIGITAL_OUT);
    hardware.pin7.configure(DIGITAL_OUT);
    hardware.pin8.configure(DIGITAL_OUT);
    ledOff();
    
    // Beeper
    hardware.pin9.configure(PWM_OUT, 0.0005, 0.0);
    hardware.pin9.write(0.0);
    
    // Alert handling
    alert = false;
    agent.on("Alert", onAlert);
    
    server.log("Init finished, starting loop");
}
function loop()
{
    //server.log(lightOutputPin.read())
    local isOpenNow = lightOutputPin.read() < LIGHT_THRESH;
    if (isOpenNow && alert)
    {
        endBeep();
        alert = false;
    }
    if (isOpenNow != isOpen)
    {
        agent.send("box lid event", isOpenNow)
        if (!isOpenNow)
        {
            ledOff();
        }
    }
    isOpen = isOpenNow;
    imp.wakeup(1, loop);
}

init();
// Wait 1 sec to start up
imp.wakeup(1, loop);