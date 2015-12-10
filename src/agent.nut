// Agent code for PillBox

/*
 * TODO
 *
 * Remove About from navbar
 */

/* ----- Constants ----- */
const TIME_OFFSET = -5;
const NUM_PRESCRIPTIONS = 3;

/* ----- Local Variables ----- */
local prescription = array(NUM_PRESCRIPTIONS); // Stores prescription objects

/* ----- Functions ----- */

// Initialization, run once at start
function init()
{
    // Register box lid event handler
    device.on("box lid event", onBoxLidEvent);
    // Register HTTP request handler
    http.onrequest(requestHandler);
}
// Loop, run once a second
function loop()
{
    // Get current time
    local currentTime = date();
    currentTime.hour = (currentTime.hour + TIME_OFFSET + 24) % 24;
    
    // Check if it is time to alert for either prescription
    for (local i = 0; i < NUM_PRESCRIPTIONS; i++)
    {
        if (prescription[i] != null && currentTime.hour == prescription[i].getNextTime().hour 
            && currentTime.min == prescription[i].getNextTime().min)
        {
            server.log("Alert for prescription " + i);
            sendAlert(i, prescription[i].getText());
            prescription[i].giveDose();
        }
    }
    imp.wakeup(1, loop);
}

/*
 * Event handler for box lid state changes.
 * 
 * isOpen: boolean corresponding to lid state
 */
function onBoxLidEvent(isOpen)
{
    if (isOpen)
    {
        server.log("Box has been opened");
    }
    else
    {
        server.log("Box has been closed");
    }
}

/*
 * Converts a String input in "HH:MM" format to at table in date() format
 *
 * Returns: A table with the keys "hour" and "min" corresponding the hours and
 *          minutes specified by input.
 */
function stringToTime(input)
{
    local timeTable = {};
    timeTable.hour <- input.slice(0,2).tointeger();
    timeTable.min <- input.slice(3,5).tointeger();
    return timeTable;
}

/*
 * HTTP request handler
 */
function requestHandler(request, response)
{
    server.log("Request received");
    try 
    {
        local responseText = "OK\n"
        response.header("Access-Control-Allow-Origin", "*");
        
        if (request.method == "GET")
        {
            server.log("GET request");
            if ("id" in request.query)
            {
                // Return next time for that id
                local id = request.query.id.tointeger();
                if (id > NUM_PRESCRIPTIONS - 1 || id < 0)
                {
                    response.send(400, "Invalid id");
                }
                else if (prescription[id] == null)
                {
                    response.send(200, "Not Configured");
                }
                else
                {
                    local timeTable = prescription[id].getNextTime()
                    local text = timeTable.hour + ":";
                    text += timeTable.min < 10 ? "0" + timeTable.min : timeTable.min;
                    response.send(200, text);
                }
            }
            else if ("demo" in request.query) 
            {
                // Demo mode
                if ("top" in request.query)
                    sendAlert(0, "0");
                if ("bottom" in request.query)
                    sendAlert(1, "1");
                response.send(200, "OK");
            }
            else
            {
                // Bad request
                server.log("Invalid GET");
                response.send(400, "Invalid GET");
            }
        }
        else
        {
            server.log("POST request");
            // Set prescriptions
            if ("id" in request.query && request.query.id != "")
            {
                server.log("Request for id: " + request.query.id);
                local idNum = request.query.id.tointeger();
                if ("time" in request.query && request.query.time != "")
                {
                    // List of times
                    server.log("Setting prescription " + idNum + " to a List prescription");
                    local timeStringList = split(request.query.time, ",");
                    local timeIntList = array();
                    foreach(input in timeStringList)
                    {
                        timeIntList.append(stringToTime(input));
                    }
                    if (timeIntList.len() == 1)
                    {
                        server.log("Special case: Setting prescription to a Freq prescription with period 24h");
                        prescription[idNum] = PrescriptionFreq(timeIntList[0], 23, 59, request.body);
                    }
                    else
                    {
                        prescription[idNum] = PrescriptionList(timeIntList, request.body);
                    }
                }
                else if("start" in request.query && "freqM" in request.query && "freqH" in request.query)
                {
                    // Start time + frequency
                    server.log("Setting prescription "+ idNum + " to a Freq prescription");
                    prescription[idNum] = PrescriptionFreq(stringToTime(request.query.start), 
                        (request.query.freqH !="") ? request.query.freqH.tointeger() : 0,
                        (request.query.freqM !="") ? request.query.freqM.tointeger() : 0,
                        request.body);
                }
                else
                {
                    server.log("Invalid Prescription " + request.query.id);
                    response.send(400, "Invalid Prescription " + request.query.id);
                }
            }
            else
            {
                server.log("No ID found");
                response.send(400, "No ID found");
            }
        }
    } catch (ex) {
        response.send(500, ("Agent Error: " + ex)); // Send 500 response if error occured
        server.log("Exception: " + ex);
    }
}

/* 
 * Tells device to start an alert for a specified LED.
 * 
 * id: integer id of prescription to alert for.
 * text: string to display
 */
function sendAlert(id, text)
{
    server.log("Sending alert");
    device.send("Alert", [id, text])
}

/* A list-type prescription, which calculates doses based on a list of times */
class PrescriptionList
{
    _currentIndex = -1; // Index of the next scheduled alert time
    _timeList = null;   // List of times to alert on
    _text = "";         // Text corresponding to this prescription
    
    /*
     * Constructs a new list-type prescription. 
     *
     * timeList: Array of date() style tables containing the hour and min of the
     *           times when an alert is scheduled for this prescription.
     * text: String to display for this prescription
     */
    constructor(timeList, text) 
    {
        _timeList = timeList;
        _text = text;
        local currentDate = date();
        currentDate.hour = (currentDate.hour + TIME_OFFSET + 24) % 24;
        // If the current time is after the last time in the list, use the first in the list
        if (compareDate(timeList[timeList.len() - 1], currentDate))
        {
            _currentIndex = 0;
        }
        else
        {
            // Iterate to find the first time that is after the current time
            for (_currentIndex = 0; compareDate(timeList[_currentIndex], currentDate); _currentIndex++);
        }
    }
    /*
     * Tests if time1 is before time2
     *
     * time1, time2: date() style tables specifying an hour and min to compare.
     *
     * Returns: boolean true if the time represented by time1 is before the time
     *          represented by time2, false otherwise.
     */
    function compareDate(time1, time2)
    {
        if (time1.hour == time2.hour)
            return time1.min < time2.min
        else
            return time1.hour < time2.hour
    }
    /* 
     * Returns the time of the next scheduled dose.
     *
     * Returns: A table with the keys "hour" and "min" corresponding the hour 
     *          and minute of the next scheduled dose.
     */
    function getNextTime()
    {
        return _timeList[_currentIndex];
    }
    /*
     * Gives a dose, causing the prescription to advance to the next scheduled
     * alert time.
     */
    function giveDose()
    {
        // Calculate time for next dose
        _currentIndex = (_currentIndex + 1) % _timeList.len();
        return _timeList[_currentIndex];
    }
    /*
     * Returns the text associated with this prescription.
     */
    function getText()
    {
        return _text;
    }
}

/* 
 * A frequency-type prescription, which calculates doses based on a fixed time 
 * between doses.
 */
class PrescriptionFreq
{
    _nextDose = -1; // Time of next dose
    _freqHours = 0; // Number of hours between doses
    _freqMinutes = 0; // Number of minutes between doses
    _text = ""; // Text corresponding to this prescription
    
    /*
     * Constructs a new frequency-type prescription. 
     *
     * nextDose: date() style table containing the hour and min of the starting
     *           dose time.
     * freqHours: integer number of hours between doses
     * freqMinutes: integer number of minutes between doses
     * text: String to display for this prescription
     */
    constructor(nextDose, freqHours, freqMinutes, text) 
    {
        _nextDose = nextDose;
        _freqHours = freqHours;
        _freqMinutes = freqMinutes;
        _text = text;
    }
    /*
     * Returns the text associated with this prescription.
     */
    function getText()
    {
        return _text;
    }
    /* 
     * Returns the time of the next scheduled dose.
     *
     * Returns: A table with the keys "hour" and "min" corresponding the hour 
     *          and minute of the next scheduled dose.
     */
    function getNextTime()
    {
        return _nextDose;
    }
    /*
     * Gives a dose, causing the prescription to advance to the next scheduled
     * alert time.
     */
    function giveDose()
    {
        // Calculate time for next dose
        local newMin = (_nextDose.min + _freqMinutes) % 60;
        local newHour = (_nextDose.hour + (_nextDose.min + _freqMinutes) / 60 + _freqHours) % 24;
        _nextDose.hour = newHour;
        _nextDose.min = newMin;
        return _nextDose;
    }
}

// Main
init();
loop();