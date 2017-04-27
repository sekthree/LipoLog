---------------------------------------------------------------------------------------------
---------						LipoLog v1.0                                  ---------------
---------------------------------------------------------------------------------------------
--	File: LipoLog.lua
--	Date: April 20, 2017
--	Auth: sekthree
--	
--	LipoLog Copyright 2017 sekthree
--
--	LipLog is used to log battery comsuption. At inception of this script I
--	only added functionality to add lipos that are labeled A-Z. Lipos can
--	be added or removed, and duplicates are allowed but not recommended. When logging data
--	the following will be logged: 
--			Lipo Name (letter assignment)
--			Flighttime based of timer1
--			VFAS
--			Cels + cels total
--			Fuel
--
--  Logs are saved using the current model name into the /SCRIPTS/LOGS directory.
--  Lipos are saved in a .dat file into the /SCRIPTS/LOGS directory. 
--  Creation of the /LOGS directory will need to be created.
--	
--	There are four menus: Main, Add Entry, Delete, and Log. 
--	  Main allows you to choose your current lipo for logging. 
--	  Add Entry allows for new letter assignment.	
--	  Delete allows for deleting a letter assignment, or deleting
--		ALL letter assignments. 
--	  Log allows writing a log of the current variables,
--		viewing currently stored logs, and deleting current log file.
--	
--	I will continue to further develop LipoLog for better features. 
--	
--	SETUP: Create /SCRIPTS/LOGS/ directory. 
--		   Place LipLog.lua in /SCRIPTS/TELEMETRY
--		   Add SCRIPT and assign LipoLog to a telemetry screen
--         Timer1 should be set up if flighttime is needed
--		   LipoLog should now be availble as one of the telemetry screens
--
--	When adding more than 6 lipos comboBox will no longer drop down, but rather an arrow '>' will 
--   display next to it, and blink when in edit mode. This is due to the comboBox displaying passed
--	the displayable area.
--  ALL lipos entered in any model will be available to ALL models, however only logs recorded for 
-- current model will be available to THAT model.
-----------------------------------------------------------------------------------------------
-- Thank you to (in no specific order)
--	Fig Newton https://www.rcgroups.com/forums/showthread.php?2180477-LUA-scripting-Technical-discussion/page111
--  I Shems (F3K) https://www.rcgroups.com/forums/member.php?u=577751
--  ilihack (LuaPilot) http://rcsettings.com/index.php/viewdownload/13-lua-scripts/237-luapilot-taranis-telemetry
--  everyone at rcgroups lua https://www.rcgroups.com/forums/showthread.php?2180477-LUA-scripting-Technical-discussion
--  OpenTx reference guide https://www.gitbook.com/book/dsbeach/opentx-lua-reference-guide/details
--  https://www.lua.org/
---------------------------------------------------------------------------------------------
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
------------------------------------------------------------------------------------------------
--
-- Global Variables
--
local lipoPacks
local selectedOption
local editMode
local activeField
local fieldMax
local currentMenu
local letter
local lipoCount
local curPos
local nextPage
local prevPage
local recPos
local lineOne
local lineTwo
local lineThree
local lineFour
local lineFive
local page

----------------------------------------------------------------------
-- Function: round
-- Parameters: num, decimal
-- Desc: rounds number passed in to decimal place passed in.
--
----------------------------------------------------------------------
local function round(num,decimal)
	local mult = 10^(decimal or 0)
	return math.floor(num * mult + 0.5) / mult
end --[[round]]

----------------------------------------------------------------------
-- Function: valueIncDec
-- Parameters: event, min, max, step
-- Desc: traverses through availble letters for Lipo Label/name assignment using
--	the plus and/or minus remote buttons
--
----------------------------------------------------------------------
local function valueIncDec(event,min,max,step)
 
	local letters = {' ','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'}
 
	if selectedSize == nil then selectedSize = 1 end
 
    if editMode then
      if event==EVT_PLUS_FIRST or event==EVT_PLUS_REPT then
        if selectedSize<=max-step then
          selectedSize=selectedSize+step
        end
      elseif event==EVT_MINUS_FIRST or event==EVT_MINUS_REPT then
        if selectedSize>=min+step then
          selectedSize=selectedSize-step
        end
      end
    end
    return letters[selectedSize]
end--[[valueIncDec]]

----------------------------------------------------------------------
-- Function: fieldIncDec
-- Parameters: event,value,max,force
-- Desc: Determines the current field in a menu that should be active
--	using the plus and minus remote buttons
--
----------------------------------------------------------------------
local function fieldIncDec(event,value,max,force)

    if editMode or force==true then
      if event==EVT_PLUS_FIRST or event == EVT_PLUS_REPT then
        value=value+max
      elseif event==EVT_MINUS_FIRST or event == EVT_MINUS_REPT then
        value=value+max+2
      end
      value=value%(max+1)
    end
    return value
end--[[fieldIncDec]]

----------------------------------------------------------------------
-- Function: getTelemetryId
-- Parameters: name
-- Desc: Gets global id of telemetry field name requested
--
----------------------------------------------------------------------
local function getTelemetryId(name)
	
	local field = getFieldInfo(name)
	
	if field then
	 return field.id
	else
	  return -1
	end
end--[[getTelemetryId]]

----------------------------------------------------------------------
-- Function: getTimer
-- Parameters: none
-- Desc: Gets elapsedTime of timer1, if setup, in hours:minutes:seconds format
--
----------------------------------------------------------------------
local function getTimer()

	local elapsedTime = tonumber(getValue('timer1'))
	
	if elapsedTime <= 0 then
		return '00:00:00'
	else
		local hours = string.format('%02.f',math.floor(elapsedTime/3600))
		local mins  = string.format('%02.f',math.floor(elapsedTime/60 - (hours * 60)))
		local secs  = string.format('%02.f',math.floor(elapsedTime - hours * 3600 - mins * 60))
		return hours..':'..mins..':'..secs
	end
end--[[getTimer]]

----------------------------------------------------------------------
-- Function: getFieldFlags
-- Parameters: menuItem
-- Desc: Determines if active field should be highlighted, blinking, or
--	normal
--
----------------------------------------------------------------------
local function getFieldFlags(menuItem)

    local flg = 0
	
    if activeField == menuItem then
      flg=INVERS
      if editMode then
        flg=INVERS+BLINK
      end
    end
    return flg
end--[[getFieldFlags]]

----------------------------------------------------------------------
-- Function: exitMenu(event)
-- Parameters: event
-- Desc: Determines whether exit button has been pressed
--
----------------------------------------------------------------------
local function exitMenu(event)

	if event == EVT_EXIT_BREAK then return true end
	return false
end--[[exitMenu]]

----------------------------------------------------------------------
-- Function: writeFlightLog
-- Parameters: none
-- Desc: Writes Data to log. Constructs log information by getting 
--  telemetry data, if availble, for the following fields: 
--	VFAS, Cels, Fuel, Timer1. Appends a dash('-') to 
--	mark the end of the log record.
--
----------------------------------------------------------------------
local function writeFlightLog()
	
	local curModel = model.getInfo().name
	local logDir   = "/SCRIPTS/LOGS/" .. curModel .. ".log"
	local cellId   = getTelemetryId('Cels')
	local vfasId   = getTelemetryId('VFAS')
	local fuelId   = getTelemetryId('Fuel')
	local VFASval  = getValue(vfasId)
	local Fuelval  = getValue(fuelId)
	local cellResult
	local cellSum  = 0.00
	local pack	   = lipoPacks[selectedOption+1]
	local telemetryVals = ""

	if VFASval ~= nil or VFASval > 0 then
		telemetryVals = ",VFAS: "..round(VFASval,2)
	end

	if cellId ~= -1 then
		cellResult = getValue(cellId)
		if (type(cellResult) == "table") then
			cellValue = ""
			for i,v in ipairs(cellResult) do
				cellValue = cellValue .. round(v,2) .. " "
				cellSum = cellSum + v
			end
			telemetryVals = telemetryVals..",Cels: "..cellValue.. " = "..cellSum
		end
	end
	
	if Fuelval ~= nil then
		telemetryVals = telemetryVals..",Fuel: "..Fuelval
	elseif telemetryVals == nil then
		telemetryVals = ",telemetry not availble"
	end

	local logFile = io.open(logDir,	'a')
	if logFile ~= nil then
		io.write(logFile,"Lipo Pack: ",pack)
		io.write(logFile, ",Flight Time: ",getTimer())
		io.write(logFile,telemetryVals)
		io.write(logFile,"\r-")
		io.close(logFile)
	end
end--[[writeFlightLog]]

----------------------------------------------------------------------
-- Function: deleteFlightLogs
-- Parameters: none
-- Desc: Deletes all flight logs for current model
--
----------------------------------------------------------------------
local function deleteFlightLogs()

	local curModel = model.getInfo().name
	local logDir   = "/SCRIPTS/LOGS/" .. curModel .. ".log"
	local logFile  = io.open(logDir, 'w')
	
	if logFile ~= nil then io.close(logFile) end
end
----------------------------------------------------------------------
-- Function: loadRecordPositions
-- Parameters: none
-- Desc: Reads in logfile of current model and indexes each position
--	a record is found. End of a record is identified by a dash ('-').
--	Record count is saved into global page variable to display page
--	when cycling through logView.
--
----------------------------------------------------------------------
local function loadRecordPositions()

	local curModel = model.getInfo().name
	local logDir   = "/SCRIPTS/LOGS/" .. curModel .. ".log"
	local logFile  = io.open(logDir,'r')
	local index = 2
	page = 0
	local lineIn   = ''
	local readPos  = 0
	recPos = {0} -- Save zero (0) as starting position
	
	if logFile == nil then
		logFile = io.open(logDir,'a')
		io.close(logFile)
		logFile = io.open(logDir,'r')
	end
	
	if logFile ~= nil then
		while true do
			io.seek(logFile,readPos)
			lineIn = io.read(logFile,100)
			if #lineIn == 0 then break
			else
				local iPos = 0
				while true do 
					iPos = string.find(lineIn,"-",iPos+1)
					if iPos == nil then break end
					readPos = readPos + iPos
					recPos[index] = readPos
					index = index + 1
				end
			end
		end
		page = index - 2
		io.close(logFile)	
	end
end--[[loadRecordPositions]]

----------------------------------------------------------------------
-- Function: viewLog
-- Parameters: scroll
-- Desc: String argument passed in should be "up" or "down" to determine
--	 the direction of log to read
--
--
----------------------------------------------------------------------
local function viewLog(scroll)

	local curModel = model.getInfo().name
	local logDir = "/SCRIPTS/LOGS/" .. curModel .. ".log"
	local lineIn = ""
	local output = "_"
	local endPos
	local count  = 0
	
	local logFile = io.open(logDir,'r')
	
	--File could exist with no records,so check record count
	if logFile ~= nil and page > 0 then 
		
		if scroll == "down" or scroll == "up" and page == 1 then
			if recPos[nextPage] == nil then 
				curPos = recPos[prevPage]
				nextPage = prevPage + 1
			else
				prevPage = nextPage - 1
			end	
			
			--move read cursor to curPos then read in the amount
			-- of characters between nextPage and curPos
			-- Store position of dash from the line read
			if logFile ~= nil and curPos ~= nil then
				io.seek(logFile,curPos)
				lineIn = io.read(logFile, recPos[nextPage] - curPos)
				endPos = string.find(lineIn, "-")
			end
			
			if endPos == nil then
				output = "_"
				return 0
			else
				output = string.sub(lineIn,1, endPos - 1)
			end
			
			curPos = recPos[nextPage]
			nextPage = nextPage + 1
			
		elseif scroll == "up" and page > 1 then
			
			if recPos[prevPage - 1] == nil then 
				curPos = recPos[prevPage]
				nextPage = prevPage + 1
			else
				prevPage = prevPage - 1		
				nextPage = prevPage + 1		
				curPos = recPos[prevPage]		
			end
			
			--move read cursor to curPos then read in the amount
			-- of characters between nextPage and curPos
			-- Store position of dash from the line read
			if logFile ~= nil and curPos ~= nil then
				io.seek(logFile,curPos)
				lineIn = io.read(logFile,recPos[nextPage] - curPos)			
				endPos = string.find(lineIn, "-")
			end
			
			if endPos == nil then
				output = "_"
				return 0
			else
				output = string.sub(lineIn,1, endPos - 1)
			end
			curPos = recPos[nextPage]
			nextPage = nextPage + 1			
		end
		
		io.close(logFile)
		
		local aTable = {}
		local ind = 0
		
		--Traverse through output string indexing location
		-- of commas seperating telemetry data
		while true do
			count = string.find(output, ",",count+1)
			if count == nil then break end
			ind = ind + 1
			aTable[ind] = count
		end

		--If code has reached this far clear display variables to 
		-- be written to with record data
		lineOne   = ''
		lineTwo   = ''
		lineThree = ''
		lineFour  = ''
		lineFive  = ''
		
		if aTable[1] then
			lineOne   = string.sub(output,1,aTable[1] - 1)
		end
		if aTable[2] then 
			lineTwo   = string.sub(output,aTable[1]+1, aTable[2] - 1)
		end
		if aTable[3] then
			lineThree = string.sub(output,aTable[2]+1, aTable[3] - 1)
		end
		if aTable[4] then
			lineFour  = string.sub(output,aTable[3]+1,aTable[4] - 1)
		end
		if aTable[4] then
			lineFive  = string.sub(output,aTable[4]+1,endPos - 1)
		end
		
		--Display current record over total records in log
		pageCount = prevPage%nextPage.."/"..page
		
	else --File not successfully opened or no records to display
		currentMenu = 'logMenu'
		activeField = 1
	end
end--[[viewLog]]
 
----------------------------------------------------------------------
-- Function: loadData
-- Parameters: none
-- Desc: Read Lipo.dat file and load into lipoPack array.
--	Store amount of lipos read.
--
----------------------------------------------------------------------
local function loadData()

	local liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'r')
	local count = 0
	local lineIn
	lipoPacks = {}
	
	if liposFile ~= nil then
		while true do
			lineIn = io.read(liposFile,1)
			if #lineIn == 0 then break end
			count = count + 1
			lipoPacks[count] = lineIn
		end
		io.close(liposFile)
	end
	lipoCount = count
end--[[loadData]]

----------------------------------------------------------------------
-- Function: writeData
-- Parameters: newEntry
-- Desc: Write new entry to lipo file.
--
----------------------------------------------------------------------
local function writeData(newEntry)

	local liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'a')
	
	if liposFile ~= nil then
		io.write(liposFile,newEntry)
		io.close(liposFile)
	end
end--[[writeData]]

----------------------------------------------------------------------
-- Function: removeData
-- Parameters: oldEntry
-- Desc: Passes in Lipo letter to be removed. Opens lipo file to be
--	written to, deleting everything in the file. Writes lipo array 
--	back to file skipping lipo letter passed in. Calls loadData to 
--	load new list from file.
----------------------------------------------------------------------
local function removeData(oldEntry)

	liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'w')
	
	if liposFile ~= nil then
		local count = 0
		local lineIn
		
		--Write stored lipo array to file skipping oldEntry
		while count < lipoCount do
			count = count + 1
			if lipoPacks[count] ~= oldEntry then
				io.write(liposFile,lipoPacks[count])
			end
		end
		io.close(liposFile)
		
		lipoCount = count
		loadData()
	end
end--[[removeData]]

----------------------------------------------------------------------
-- Function: deleteLipoData
-- Parameters: none
-- Desc: Deletes all stored lipos, and resets lipo array and lipo count
--
----------------------------------------------------------------------
local function deleteLipoData()

	local liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'w')
	
	if liposFile ~= nil then io.close(liposFile) end

	loadData()
end

----------------------------------------------------------------------
-- Function: mainMenu
-- Parameters: event
-- Desc: Handles variables to be displayed on main menu. Passes control
--	to sub menus by setting currentMenu flag to menu that should be visible
--
----------------------------------------------------------------------
local function mainMenu(event)
	
	lineOne = 'Lipo:   '
	lineTwo = 'Add Entry->'
	
	if lipoCount <= 0 then
		lineThree   = ''
		lineFour    = ''
		fieldMax    = 1
		activeField = 1
	else
		lineThree = 'Delete ->'
		lineFour  = 'Log ->'
		fieldMax  = 3
	end
	
	if editMode then
		if activeField == 0 then
		  selectedOption = fieldIncDec(event, selectedOption, lipoCount - 1)		  
		  if selectedOption >= lipoCount then selectedOption = lipoCount - 1 end
		elseif activeField == 1 then
			editMode = not editMode
			currentMenu = 'addEntry'
			activeField = 0
		elseif activeField == 2 then
			editMode = not editMode
			currentMenu = 'deleteEntry'
			activeField = 0
			selectedOption = 0
		elseif activeField == 3 then
			editMode = not editMode
			currentMenu = 'logMenu'
			activeField = 0
		end
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
end--[[mainMenu]]

----------------------------------------------------------------------
-- Function: addEntryMenu
-- Parameters: event
-- Desc: Handles variables to be displayed on Add Entry menu. Can write
--	new lipo entry by calling writeData function.
--
----------------------------------------------------------------------
local function addEntryMenu(event)

	--Exit to top menu if exit is pressed
	if exitMenu(event) then
		editMode = not editMode
		activeField = 2
	end
	
	lineOne   = 'Name: '
	lineThree = '<- Back'
	lineFour  = ''
	fieldMax  = 2
	
	if letter == nil or letter == " " then
		lineTwo = ''
		if activeField == 1 then activeField = 0 end
	else
		lineTwo = 'Confirm'
	end
	
	if editMode then
		if activeField == 0 then
			letter = valueIncDec(event,1, 27, 1)
		elseif activeField == 1 then
			writeData(letter)
			loadData()
			editMode = not editMode
			currentMenu = 'mainMenu'
			activeField = 0
		elseif activeField == 2 then
			editMode = not editMode
			currentMenu = 'mainMenu'
			activeField = 1
		end
	else
		activeField = fieldIncDec(event,activeField, fieldMax, true)
	end
end--[[addEntryMenu]]

-----------------------------------------------------------------
--	Function: deleteEntryMenu
--	Parameters: event	
--	Desc: Changes values referenced in draw to display the delete entry screen, 
--	  handles variables needed to delete an entry from comboBox
--
-----------------------------------------------------------------
local function deleteEntryMenu(event)

	--Exit to top menu if exit is pressed
	if exitMenu(event) then
		editMode = not editMode
		activeField = 3
	end
	
	lineOne   = 'Select to Delete: '
	lineTwo   = 'Delete Entry'
	lineThree = 'Delete ALL Entries'
	lineFour  = '<- Back'
	fieldMax  = 3
	
	if editMode then
		if activeField == 0 then
			selectedOption = fieldIncDec(event, selectedOption, lipoCount - 1)
			if selectedOption >= lipoCount then selectedOption = lipoCount - 1 end
		elseif activeField == 1 then
			editMode = not editMode
			currentMenu = 'mainMenu'
			removeData(lipoPacks[selectedOption+1])
			selectedOption = 0
		elseif activeField == 2 then
			editMode = not editMode
			currentMenu = 'mainMenu'
			activeField = 0
			deleteLipoData()
		elseif activeField == 3 then
			editMode = not editMode
			currentMenu = 'mainMenu'
			activeField = 2
		end
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
end--[[deleteEntryMenu]]

-------------------------------------------------------------------
-- Function: logMenu
-- Parameters: event
-- Desc: Handles variables to be displayed on log menu. Can write telemetry
--	data record to log by calling writeFlightLog function. Can delete log
--	file by calling deleteFlightLogs function. 
--
-------------------------------------------------------------------
local function logMenu(event)
	
	--Exit to top menu if exit is pressed
	if exitMenu(event) then
		editMode = not editMode
		activeField = 3
	end
	
	lineOne   = 'Write Log Entry'
	lineTwo   = 'View Logs'
	lineThree = 'Delete ALL Logs'
	lineFour  = '<- Back'
	fieldMax  = 3
	
	if editMode then
		if activeField == 0 then
			editMode = not editMode
			currentMenu = 'logMenu'
			activeField = 1
			writeFlightLog()
		elseif activeField == 1 then
			editMode = not editMode
			currentMenu = 'logView'
			activeField = 0
			loadRecordPositions()
			viewLog('down')			
		elseif activeField == 2 then
			editMode = not editMode
			deleteFlightLogs()
			activeField = 3
		elseif activeField == 3 then
			editMode = not editMode
			currentMenu = 'mainMenu'
			activeField = 3
		end
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
end--[[logMenu]]

---------------------------------------------------------------
-- Function: draw
-- Parameters: currentMenu
-- Desc: Draws all variables meant to be displayed based on currentMenu
--	being passed in.
--
---------------------------------------------------------------
local function draw(currentMenu)

  -- draw from the bottom up so we don't overwrite the combo box if open
  lcd.drawText(1, 38, lineFour, getFieldFlags(3)) -- LogMenu
  lcd.drawText(1, 26, lineThree, getFieldFlags(2)) --DeleteMenu, <-Back
  lcd.drawText(1, 14, lineTwo, getFieldFlags(1)) --AddEntryMenu, Confirm, Delete
  
  if currentMenu == "logMenu" then
	lcd.drawText(1,1,lineOne,getFieldFlags(0)) --Write To Log
  else
	lcd.drawText(1, 1, lineOne, 0) --Lipo, Select to Delete, Name:
  end
  
  if currentMenu == "addEntry" then
	lcd.drawText(lcd.getLastPos() + 2, 1, letter, getFieldFlags(0)) --Lipo Entry box
  elseif lipoCount > 0 and currentMenu == "mainMenu" or currentMenu == "deleteEntry" then
	local cFlag
	if lipoCount > 6 then
		cFlag = 0
		lcd.drawText(lcd.getLastPos() + 2, 1, '>', getFieldFlags(0)) --Display arrow > when lipo count exceeds 6
	else
		cFlag = getFieldFlags(0)
	end
	lcd.drawCombobox(lcd.getLastPos() + 2, 1, 70, lipoPacks, selectedOption, cFlag)	--Lipo drop down
  elseif currentMenu == "logView" then
	local xPage = 185
	
	if prevPage%nextPage >= 100 then xPage = 175
	elseif prevPage%nextPage >= 10 then xPage = 180 end
	
	lcd.drawText(xPage,1,pageCount,0) -- Log page number
	lcd.drawText(1,52,lineFive,0)
  end
  
end--[[draw]]

------------------------------------------------------------
-- Function: init
-- Parameters: none
-- Desc: Initialization of all global variables
--
------------------------------------------------------------
local function init()

  recPos = {}
  fieldMax = 2
  lipoPacks = {}
  selectedOption = 0
  activeField = 0
  lineOne = "Lipo:   "
  lineTwo = "AddEntry"
  lineThree = "DeleteEntry"
  lineFour = "Log Data"
  currentMenu = 'mainMenu'
  lipoCount = 0
  letter = ' ' 
  curPos = 0
  loadData()
  nextPage = 2
  prevPage = 1
  pageCount = ""
  page = 0
end--[[init]]

----------------------------------------------------------
-- Function: run
-- Parameters: event
-- Desc: Main method that is called continously when progam is displaying. Initially 
--	clears the lcd and redraws according to what menu is active. Contains 
--	function calls to determine what screen (menu) should be currently
--	displaying. Accepts the event parameter, equivalent to button presses. 
--	The event parameter can be passed to each menu function call for further
--	processing.
----------------------------------------------------------
local function run(event)
  lcd.clear()
  
  if event == EVT_ENTER_BREAK then
    editMode = not editMode
  end
  
  if currentMenu == "mainMenu" then
	mainMenu(event)
  elseif currentMenu == "addEntry" then
	addEntryMenu(event)
  elseif currentMenu == "deleteEntry" then
	deleteEntryMenu(event)
  elseif currentMenu == "logMenu" then
	logMenu(event)
  elseif currentMenu == "logView" then
  --viewLog is only called when event has been captured
	if event == EVT_PLUS_BREAK or event == EVT_PLUS_REPT then
		viewLog('up')
	elseif event == EVT_MINUS_BREAK or event == EVT_MINUS_REPT then
		viewLog('down')
	elseif event == EVT_EXIT_BREAK then
		pageCount = ''
		curPos    = 0
		prevPos   = 0
		currentMenu = 'logMenu'
		activeField = 1
		prevPage  = 1
		nextPage  = 2
	end
  end
  draw(currentMenu)
end--[[run]]

return{run=run, init=init}