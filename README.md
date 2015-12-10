# PANDA

**P**ersonal
**A**utomated
**N**etworked
**D**rug
**A**ssistant

<img src=/img/PANDA.png width="300">

PANDA is a smart pillbox that reminds you when to take your medicine! Using the web interface, you can tell PANDA when to remind you. PANDA can take either a list of times or set period between reminders.

Once it is time to take your medication, PANDA will start beeping and light up the indicator next to the medicine you need to take. Dosage and other helpful information will be conveniently displayed next to the medicine compartments. The only way to quiet PANDA is to open the box, so there is no chance you will forget to take your medicine. In addition, PANDA remembers if you took your medicine already. If the light is red, you know you don't need to take the pill again.

# Motivation

Regardless of how careful doctors and pharmacists are at prescribing medicine, the responsibility of actually taking the correct medication at the right times still falls on the patient. Pharmacists still have to give instructions verbally to patients, and these instructions grow increasingly complex as the number of prescriptions increase. Using PANDA, patients can bring a pharmacist home with them. Pharmacists can fill out an online form with drug administration instructions and that information is then transmitted via Wi-Fi using Electric Imp to PANDA. The PANDA beeps when itâis time to take medicine and the beeping only stops when a light sensor detects that PANDA has been opened. LEDs show which medicines to take by lighting up green. Because the PANDA is battery-operated, it can be put in the most convenient location. PANDA is great for patients who have to take medicine daily, from those taking Lipitor after a heart attack, to women on birth control.

After the Hackathon, I extended the original version of PANDA by updating the web interface to show the time of the next aler for each medicine and modularized the code in response to feedback received at the Hackathon. This way, the patient can check when the next alert will come, which helps them plan accordingly and improves the usability of PANDA. 

# Hardware

<img src=/doc/Schematic.png width="480">

PANDA is built around the Electric Imp platform. PANDA uses a CdS photocell to detect if the lid is open or not based on the brightness change. This photocell is read using an analog input on the Electric Imp using a 1k½ resistor on the high side in a voltage divider configuration. Note that since the photocell's resistance decreases with increasing light level, the analog voltage read by the Electric Imp **decreases** when the light level increases. A DAC pin is used to drive the piezo speaker (Sparkfun COM-07950) using a fixed frequency PWM signal. PANDA is powered by a 4xAA battery holder hooked into the battery input (P+/-) pads on the Electric Imp.

Each medicine slot has a corresponding bicolor common-anode LED which lights up green if the medicine should be taken and red if the medicine should not be taken. These LEDs are controlled through a 74HC595n shift register driven using one of the Electric Imp's hardware SPI busses. The advantage of the shift register is that it allows the number of LEDs to be increased despite the limited number of GPIO pins. Shift registers can also be easily chained to drive very large numbers of LEDs. By writing a 1 to the bit corresponding to the green or red cathode of the LED, the LED will light with the desired color. Similarly, writing a 0 turns off the LED at that bit. A simple shift register class and LED classes have been created to handle LED toggling.

The enclosure for PANDA is a repurposed cardboard box, with the dividers for the electronics and medicine created from thinner recycled cardstock. The PANDA logos were printed out using a standard color printer and glued onto the enclosure. Overall, the mechanical design was aimed at reducing cost and reusing available materials whenever possible.

The current iteration of PANDA is also designed to allow the connection of a Nokia 5110 LCD (Sparkfun LCD-10168), using pin # as a chip select, driving the control lines using the shift register, and using the same SPI bus used for the shift register for data transfer. However, the LCD unit I originally planed to use had a mechanical defect which caused unreliable connections between the LCD module and the breakout board. Because I didn't have a reliable unit to test my code with, I decided to work on other parts of PANDA due to time constraints. The code for driving the LCD has been left in the repository under the branch lcd. 

# Software

PANDA can be configured using a [web interface](http://ag6gr.github.io/PANDA/), created using Bootstrap and Javascript. The web interface communicates with the Electric Imp servers using http requests. The main page fetches the time of the next dose using GET requests. The configuration page uses POST requests, with the configuration paramemters passed through the URL query string and the name/description of the prescription passed in the body of the POST request.

Timekeeping, request handling, and alert triggering are managed by the server side of the Electric Imp. The device is notified of alerts using the standard message passing functionality built into the Electric Imp platform. Source code is available on [Github](https://github.com/AG6GR/PANDA).
