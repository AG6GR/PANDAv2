# PANDA

**P**ersonal
**A**utomated
**N**etworked
**D**rug
**A**ssistant

<img src=/img/PANDA.png width="300">

PANDA is a smart pillbox that reminds you when to take your medicine! Using the web interface, you can tell PANDA what medicines you are taking and when to remind you.

<img src=/doc/Closed.jpg width="400"><img src=/doc/Open.jpg width="400">

Once it is time to take your medication, PANDA will start beeping and light up the indicator next to the medicine you need to take. The only way to quiet PANDA is to open the box, so there is no chance you will forget to take your medicine. In addition, PANDA remembers if you took your medicine already. If the light is red, you know you don't need to take the pill again. 

# Motivation

Everyone has taken medications at some point in their life. According to a report by the [Kaiser Family Foundation](http://kff.org/other/state-indicator/total-retail-rx-drugs/), over 4 billion prescriptions were filled in 2014. Maybe it was antibiotics for an infection, statins for managing cholesterol levels, or just daily vitamins or supplements. What is in common for all of these medications is that they need to be taken at regular intervals for an extended period of time. 

Based on my own personal experience and the experiences of my parents and other people around me, I know the worry and frustration involved in keeping track of when to take medication. Beyond the inconvenience of managing multiple complex prescriptions, mistakes can have serious consequences. It is easy to forget to take a pill, or even worse, to accidentally take an extra dose. Approximately 44 people die from accidental overdoses every day in the US (Source: [CDC](http://www.cdc.gov/drugoverdose/data/overdose.html)). Many of these overdoses are unnecessary deaths which can be easily prevented. When someone is sick, the last thing they want to be worrying about is when to take their vital medications. PANDA aims to use the power of IoT technology to help solve this important issue.

I first tackled this problem with a partner during the Fall 2015 HackPrinceton hackathon. We developed PANDA, a smart, user-friendly pillbox powered by Electric Imp. PANDA can be configured remotely with a web interface, after which it will automatically notify the user whenever it is time to take medicine. After the hackathon, I extended PANDA to create PANDA v2, overhauling the user interface and backend software as well as expanding the physical PANDA device. A basic overview of the technical details under the hood of PANDA is provided in the sections below.

# Hardware

<img src=/doc/OverviewOpen.jpg width="400">

PANDA is built around the Electric Imp platform. All processing is done by the imp001 module held in an April breakout board. A ribbon cable connects the pins of the April breakout board to a header on the protoboard where the other components are soldered. EAGLE schematics and a [Bill of Materials](https://github.com/AG6GR/PANDAv2/blob/gh-pages/doc/BillOfMaterials.csv) for the electronics of PANDA are available in the `doc` directory.

The enclosure for PANDA is a repurposed cardboard box, with the dividers for the electronics and medicine created from thinner recycled card stock. The PANDA logos were printed out using a standard color printer and glued onto the enclosure. Overall, the mechanical design was aimed at reducing cost and reusing available materials whenever possible.

Major changes in PANDAv2:
* Added shift register for improved scalability
* Added third medicine slot (and corresponding LED)
* Transistor driver for buzzer

## Electronics
<img src=/doc/LEDSchematic.png>

<img src=/doc/BoardTop.jpg width="400"><img src=/doc/BoardBottom.jpg width="400">

PANDA uses a CdS photocell to detect if the lid is open or not based on the brightness change. This photocell is read using an analog input on the Electric Imp using a 1kΩ resistor on the high side in a voltage divider configuration. Note that since the photocell's resistance decreases with increasing light level, the analog voltage read by the Electric Imp **decreases** when the light level increases. A DAC pin is used to drive the piezo speaker (Sparkfun COM-07950) using a fixed frequency PWM signal. PANDAv2 includes a transistor to increase the amount of current used to drive the piezo speaker. PANDA is powered by a 4xAA battery holder hooked into the battery input (P+/-) pads on the Electric Imp.

## Medicine LEDs

<img src=/doc/LED.jpg width=250>

Each medicine slot has a corresponding bicolor common-cathode LED which lights up green if the medicine should be taken and red if the medicine should not be taken. Each LED has its own 100Ω current limiting resistor between the cathode and ground, and the whole assembly is lovingly heat-shrink wrapped and connected to the main board with 22AWG wire. These LEDs are controlled through a 74HC595n shift register driven using one of the Electric Imp's hardware SPI busses. The advantage of the shift register is that it allows the number of LEDs to be increased despite the limited number of GPIO pins. Shift registers can also be easily chained to drive very large numbers of LEDs. By writing a 1 to the bit corresponding to the green or red anode of the LED, the LED will light with the desired color. Similarly, writing a 0 turns off the LED at that bit. A simple shift register class and LED classes have been created to handle LED toggling.

# Software

PANDA can be configured using a [web interface](http://ag6gr.github.io/PANDA/), created using Bootstrap and Javascript. The web interface communicates with the Electric Imp servers using http requests. Timekeeping, request handling, and alert triggering are managed by the server side of the Electric Imp. The device is notified of alerts using the standard message passing functionality built into the Electric Imp platform. Source code is available on [Github](https://github.com/AG6GR/PANDAv2).

Major changes in PANDAv2:
* Added "Next Scheduled Doses" display to web interface
* Rewrite of web interface Javascript
* Formalized device state machine
* Expanded agent HTTP request handling
* Modularized representation of prescriptions and LEDs for scalability
* General code cleanup

## Electric Imp

Source code for the Electric Imp agent and device can be found in the [src directory](https://github.com/AG6GR/PANDAv2/tree/gh-pages/src) of this repository.

### Device
<img src=/doc/StateMachine.jpg width="640">

The device handles all of the I/O operations, managing the state of the LEDs and monitoring the photocell. The overall structure of the device code can be summarized with the state machine diagram above. During normal operation, the device transitions between the "Closed" and "Open" states based on the light level detected by the photocell. The LEDs are turned off when the box is closed to save power and are turned back on when the box is reopened. When an alert message from the agent is received, the device decodes the ID of the LED to illuminate based on the data attached to the message. The corresponding LED is set to green, and the buzzer is sounded. 

A dedicated shift register class (`ShiftRegister74HC595`) keeps track of the state of the shift register's outputs and manages the logic behind toggling outputs and driving the shift register. An instance of `ShiftRegister74HC595` is created on initialization, specifying the SPI bus and register latch clock output pin. Most operations are performed using the `setBit(addr, value)` function, which sets the shift register output corresponding to the specified address to the specified value.

A LED class keeps track of the shift register addresses and color of a LED. The device uses an array of LED objects to keep track of the state of each LED and to properly identify which LED to turn on when an alert is received. 

The current iteration of PANDA is also designed to allow the connection of a Nokia 5110 LCD (Sparkfun LCD-10168), using pin # as a chip select, driving the control lines using the shift register, and using the same SPI bus used for the shift register for data transfer. However, the LCD unit I originally planed to use had a mechanical defect which caused unreliable connections between the LCD module and the breakout board. Because I didn't have a reliable unit to test my code with, I decided to work on other parts of PANDA due to time constraints. The schematic and code for driving the LCD has been left in the repository under the branch lcd. 

### Agent
<img src=/doc/RequestFlowchart.jpg width="640">

The agent is responsible for handling HTTP requests from the web interface, tracking prescription data, and issuing alerts to the device. 

A flowchart for the process of handling a HTTP request is shown above. Depending on the parameters given, the agent will create a prescription object for each prescription that has been configured. These objects are stored in a prescriptions array at the index corresponding to their ID number. 

Every second, a polling loop fetches the current time and checks if any of the prescriptions are due for an alert. If so, a message is crafted with the ID of the prescription to alert and the text corresponding to the prescription as the data. Once the message is sent, the prescription object calculates the time of the next dose, and the process continues.

## Web Interface

The web interface was constructed using the [Bootstrap framework](http://getbootstrap.com/) and Javascript. 

### Main Page
When the main page is loaded, a Javascript script fetches the next scheduled alert times for each prescription using GET requests. The body of the response is then displayed under the corresponding label.

### Configuration Page
The configuration page features a series of forms, one for each prescription. A prescription is assumed to be active if a name or description is given. The user has the option of selecting between two different ways to set the alert times using radio buttons. One is based on a fixed interval between doses, where the user specifies a start time and the time between doses in hours and minutes. Alternatively, the user can provide a comma separated list of times to be alerted.

When the submit button is clicked, a script sends a POST request for each filled-out prescription with the configuration parameters passed through the URL query string and the name/description of the prescription passed in the body of the POST request.

# Next Steps

While PANDAv2 makes many improvements over the original PANDA software and hardware, there are still ways to continue to make PANDA better. A couple possibilities are listed below.
* LCD Integration: As noted in the Software section, PANDAv2 was originally intended to include an LCD. The device code and hardware necessary to interface with the LCD is already in place, and once a LCD is obtained, extending PANDAv2 to display dosage information to the user would substantially improve the usability of PANDA.
* Web Interface Modularity: The Electric Imp code has been designed to be easily extendable, and the process of adding support for additional prescriptions is just a matter of changing a few constants. It would be great to extend this to the web interface, allowing the interface to detect how many prescriptions are actually supported and generate the forms accordingly.
* Miniaturization: While still quite portable, PANDA could probably be made much smaller with a custom PCB for the electronics and a redesigned enclosure. This would allow users to more easily take PANDA with them, expanding PANDA's ease of use.
