// Agent code for PillBox

const TIME_OFFSET = -5;
const NUM_PRESCRIPTIONS = 2;

// Prescription objects
local prescription = array(NUM_PRESCRIPTIONS);

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
            sendAlert(i);
            prescription[i].giveDose();
        }
    }
    imp.wakeup(1, loop);
}

// Event Handlers

// Called when box lid state changes, boolean isOpen corresponds to lid state
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
// Converts a String in "HH:MM" format to at table in date() format
function stringToTime(input)
{
    local timeTable = {};
    timeTable.hour <- input.slice(0,2).tointeger();
    timeTable.min <- input.slice(3,5).tointeger();
    return timeTable;
}
// HTTP request handler
function requestHandler(request, response)
{
    server.log("Request received");
    try 
    {
        local responseText = "OK\n"
        // Demo
        if ("demo" in request.query) 
        {
            if ("top" in request.query)
                sendAlert(0);
            if ("bottom" in request.query)
                sendAlert(1);
        }
        else
        {
            // Set prescriptions
            if ("id" in request.query && request.query.id != "")
            {
                server.log("Request for id: " + request.query.id);
                local idNum = request.query.id.tointeger();
                if ("time" in request.query && request.query.time != "")
                {
                    // List of times
                    server.log("Setting prescription " + idNum + " to a List prescription");
                    responseText += ("time=" + request.query.time + "\n");
                    local timeStringList = split(request.query.time, ",");
                    local timeIntList = array();
                    foreach(input in timeStringList)
                    {
                        timeIntList.append(stringToTime(input));
                    }
                    if (timeIntList.len() == 1)
                    {
                        server.log("Special case: Setting prescription to a Freq prescription with period 24h");
                        prescription[idNum] = PrescriptionFreq(timeIntList[0], 23, 59);
                    }
                    else
                    {
                        prescription[idNum] = PrescriptionList(timeIntList);
                    }
                }
                else if("start" in request.query && "freqM" in request.query && "freqH" in request.query)
                {
                    // Start time + frequency
                    server.log("Setting prescription "+ idNum + " to a Freq prescription");
                    responseText += ("start=" + request.query.start + "\n");
                    responseText += ("freqM=" + request.query.freqM + "\n");
                    responseText += ("freqH=" + request.query.freqH + "\n");
                    prescription[idNum] = PrescriptionFreq(stringToTime(request.query.start), 
                        (request.query.freqH !="") ? request.query.freqH.tointeger() : 0,
                        (request.query.freqM !="") ? request.query.freqM.tointeger() : 0);
                }
                else
                {
                    server.log("Invalid Prescription " + request.query.id);
                }
            }
            else
            {
                server.log("No ID found");
            }
        }
        server.log("Response text: " + responseText);
        response.header("Access-Control-Allow-Origin", "*");
        response.send(200, responseText);
    } catch (ex) {
        response.send(500, ("Agent Error: " + ex)); // Send 500 response if error occured
        server.log("Exception: " + ex);
    }
}
// Tell device to start an alert, boolean isTop indicates which prescription
function sendAlert(isTop)
{
    server.log("Sending alert");
    device.send("Alert", isTop)
}

// A list-type prescription, which calculates doses based on a list of times
class PrescriptionList
{
    _currentIndex = -1;
    _timeList = null;
    
    constructor(timeList) 
    {
        _timeList = timeList;
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
    // Tests if a time1 is before time2
    function compareDate(time1, time2)
    {
        if (time1.hour == time2.hour)
            return time1.min < time2.min
        else
            return time1.hour < time2.hour
    }
    function getNextTime()
    {
        return _timeList[_currentIndex];
    }
    function giveDose()
    {
        // Calculate time for next dose
        _currentIndex = (_currentIndex + 1) % _timeList.len();
        return _timeList[_currentIndex];
    }
}
// A frequency-type prescription, which calculates doses based on a set time between doses
class PrescriptionFreq
{
    _nextDose = -1;
    _freqHours = 0;
    _freqMinutes = 0;
    
    constructor(nextDose, freqHours, freqMinutes) 
    {
        _nextDose = nextDose;
        _freqHours = freqHours;
        _freqMinutes = freqMinutes;
    }
    function getNextTime()
    {
        return _nextDose;
    }
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