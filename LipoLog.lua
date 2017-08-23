---------------------------------------------------------------------------------------------
---------						LipoLog v1.3                                  ---------------
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
--  FOR FULL INSTRUCTIONS PLEASE VISIT GITHUB WIKI:
--  https://github.com/sekthree/LipoLog/wiki/LipoLog:-Setup
--	
--	SETUP: Create /SCRIPTS/LOGS/ directory. 
--		   Place LipoLog.lua in /SCRIPTS/TELEMETRY
--		   Add SCRIPT and assign LipoLog to a telemetry screen
--         Timer1 should be set up if flighttime is needed/wanted
--		   LipoLog should now be availble as one of the telemetry screens
--
--  Version History
--  1.1
--	 When adding more than 6 lipos comboBox will no longer drop down, but rather an arrow '>' will 
--    display next to it, and blink when in edit mode. This is due to the comboBox displaying passed
--	  the displayable area.
--  1.2
--   The combobox functionality has been changed to popup menu.
--  1.3
--   Single letter input for a lipo has been changed to string input (7 characters).
--   Added numbers to available input
--   Writing to lipo file has been altered to encorporate new longer name/string, as well as reading from file.
--   Prevent duplicate entries, display error when encountereds
--
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
local oldSelection
local editMode
local activeField
local fieldMax
local charMax
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
local lineSix
local page
local popup
local lipoEdit
local wordMax
local letterPos
local activeLetter
local lipoName
local lipoNameArray

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
 
	local letters = {' ','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6','7','8','9'}
 
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
	
	if lipoEdit == true and activeLetter == menuItem then
		flg=INVERS
		if editMode then
			flg=INVERS+BLINK
		end	
	elseif lipoEdit == false and activeField == menuItem then
		flg=INVERS
		if editMode then
			flg=INVERS+BLINK
		end
    end
    return flg
end--[[getFieldFlags]]

----------------------------------------------------------------------
-- Function: getNextLetter
-- Parameters: none
-- Desc: Sets selectedSize to value of the next letter so when valueIncDec
--   is called in lipoEntry, letter isn't reset to previous letter
--
----------------------------------------------------------------------
local function getNextLetter()

	local count = 0
	local letters = {' ','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6','7','8','9'}
	
	if selectedSize == nil then selectedSize = 1
	elseif letter ~= letters[selectedSize] then
		while letter ~= letters[count] do
			count = count + 1
		end
		selectedSize = count
	end

end--[[getNextLetter]]

----------------------------------------------------------------------
-- Function: setLipoName
-- Parameters: none
-- Desc: sets the global variable lipoName from lipoNameArray
--
----------------------------------------------------------------------
local function setLipoName()

	local count = 1

	lipoName = lipoNameArray[count]

	while count < wordMax do
		count = count  + 1
		lipoName = lipoName..lipoNameArray[count]
	end

end--[[setLipoName]]

----------------------------------------------------------------------
-- Function: lipoEntry
-- Parameters: event
-- Desc: Allows for a string to be entered on screen
--
----------------------------------------------------------------------
local function lipoEntry(event)

	if event == EVT_ENTER_BREAK and letterPos < wordMax and lipoEdit == true then
		letterPos = letterPos + 1
		letter = lipoNameArray[letterPos]
		activeLetter = activeLetter + 1
		getNextLetter()
	elseif event == EVT_ENTER_BREAK and letterPos >= wordMax then
		letterPos = 1
		lipoEdit = false
		editMode = not editMode
		fieldMax = 1
		activeLetter = 0 
		letter = lipoNameArray[1]
		getNextLetter()
		setLipoName()
	else
		letter = valueIncDec(event,1,charMax,1)
		lipoNameArray[letterPos] = letter
		lipoEdit = true
	end
end--[[lipoEntry]]

----------------------------------------------------------------------
-- Function: exitMenu(event)
-- Parameters: event
-- Returns: boolean
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
	
end--[[deleteFlightLogs]]

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
		currentMenu = 'mainScreen'
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
			lineIn = io.read(liposFile,7)
			if #lineIn == 0 then break end
			count = count + 1
			lipoPacks[count] = lineIn
		end
		io.close(liposFile)
	else
		liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'a')
		io.close(liposFile)
	end
	lipoCount = count
end--[[loadData]]

----------------------------------------------------------------------
-- Function: isDuplicate
-- Parameters: entryName
-- Returns: boolean
-- Desc: Given an entryName search through current lipo array and return
--   if entry is duplicate name
----------------------------------------------------------------------
local function isDuplicate(entryName)
	local count = 0
	
	while count < lipoCount do
		count = count + 1
		if lipoPacks[count] == entryName then 
			lineSix = "Error: Duplicate Entry"
			return true 
		end
	end
	
	return false
end--[[isDuplicate]]

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
local function removeData(oldEntry, selectedOption)

	liposFile = io.open("/SCRIPTS/LOGS/lipo.dat",'w')
	
	if liposFile ~= nil then
		local count = 0
		local lineIn
		
		--Write stored lipo array to file skipping oldEntry
		while count < lipoCount do
			count = count + 1
			if lipoPacks[count] ~= oldEntry and count ~= selectedOption + 1 then
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
end--[[deleteLipoData]]

----------------------------------------------------------------------
-- Function: menuScreen
-- Parameters: event
-- Desc: Handles variables to be displayed on main menu. Passes control
--	to sub menus by setting currentMenu flag to menu that should be visible
--
----------------------------------------------------------------------
local function menuScreen(event)

	if exitMenu(event) then
		currentMenu = "mainScreen"
		activeField = 0
	end
	
	lineOne = 'View Flight Logs ->'
	lineTwo = 'Add New Lipo Pack ->'
	lineThree = "Delete Things ->"
	lineFour = ""
	fieldMax = 2
	
	if editMode then
		if activeField == 0 then
			editMode = not editMode
			currentMenu = 'logView'
			activeField = 0
			loadRecordPositions()
			viewLog('down')
		elseif activeField == 1 then
			editMode = not editMode
			currentMenu = 'addEntry'
			activeField = 0
		elseif activeField == 2 then
			editMode = not editMode
			currentMenu = 'deleteScreen'
			activeField = 0
			selectedOption = 0
		end
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
end--[[menuScreen]]

----------------------------------------------------------------------
-- Function: addLipoScreen
-- Parameters: event
-- Desc: Handles variables to be displayed on Add Entry menu. Can write
--	new lipo entry by calling writeData function.
--
----------------------------------------------------------------------
local function addLipoScreen(event)

	--Exit to top menu if exit is pressed
	if exitMenu(event) then
		currentMenu = "menuScreen"
		activeField = 1
		editMode = false
		lipoEdit = false
	end
	
	lineOne   = 'Name: '
	lineThree = ''
	lineFour  = ''
	lineSix = ''
	fieldMax  = 1
	
	if lipoName == nil or lipoName == " " or lipoName == "       " then
		lineTwo = ''
		if activeField == 1 then activeField = 0 end
	else
		lineTwo = 'Confirm'
	end
	
	if editMode then
		if activeField == 0 then
			lipoEntry(event)
		elseif activeField == 1 and isDuplicate(lipoName) == false then
			writeData(lipoName)
			loadData()
			editMode = not editMode
			currentMenu = 'menuScreen'
			activeField = 0
		end
	else
		activeField = fieldIncDec(event,activeField, fieldMax, true)
	end
end--[[addLipoScreen]]

-----------------------------------------------------------------
--	Function: deleteScreen
--	Parameters: event	
--	Desc: Changes values referenced in draw to display the delete entry screen, 
--	  handles variables needed to delete an entry from comboBox
--
-----------------------------------------------------------------
local function deleteScreen(event)

	--Exit to top menu if exit is pressed
	if exitMenu(event) and not popup then
		currentMenu = "menuScreen"
		activeField = 2
	end
	
	if lipoCount <= 0 and activeField == 0 then
		activeField = 1
	end
	
	lineOne   = 'Select to Delete: '
	lineTwo   = 'Delete Selected Lipo'
	lineThree = 'Delete ALL Lipos'
	lineFour  = 'Delete ALL Flight Logs'
	fieldMax  = 3
	
	if editMode then
		if activeField == 0 then
			
			if not popup and event == EVT_ENTER_BREAK then
				event = 1
				popup = not popup
				oldSelection = selectedOption
			end
			
		  --popup window for selecting lipo
			optInput = popupInput(lineOne..lipoPacks[selectedOption + 1],event,selectedOption,0,lipoCount - 1)
			
			if optInput == 'OK' then
				editMode = not editMode
				popup = not popup
				activeField = 0
			elseif optInput == 'CANCEL' then
				editMode = not editMode
				popup = not popup
				selectedOption = oldSelection
				activeField = 0
			else
				selectedOption = optInput
			end
			
		elseif activeField == 1 then
			editMode = not editMode
			removeData(lipoPacks[selectedOption+1], selectedOption)
			currentMenu = 'menuScreen'
			selectedOption = 0
		elseif activeField == 2 then
			editMode = not editMode
			deleteLipoData()
			currentMenu = 'menuScreen'
			activeField = 0
		elseif activeField == 3 then
			editMode = not editMode
			deleteFlightLogs()
			currentMenu = 'menuScreen'
			activeField = 2
		end
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
end--[[deleteScreen]]

-------------------------------------------------------------------
-- Function: mainScreen
-- Parameters: event
-- Desc: Handles variables to be displayed on log menu. Can write telemetry
--	data record to log by calling writeFlightLog function. Can delete log
--	file by calling deleteFlightLogs function. 
--
-------------------------------------------------------------------
local function mainScreen(event)
	
	--Enter Menu Screen if MENU is pressed
	if event == EVT_MENU_BREAK then
		currentMenu = "menuScreen"
	end
	
	if lipoCount <= 0 then
		fieldMax    = 0
		activeField = 0
		lineOne = ""
		lineTwo = ""
		lineThree = "Please add a lipo pack"
		if event == EVT_ENTER_BREAK then
			currentMenu = 'menuScreen'
			editMode = not editMode
			activeField = 1
		end
	else
		lineOne   = 'Lipo Pack: '
		lineTwo   = 'Write Flight Log'
		fieldMax  = 1
		lineThree = ""
	end
	
	lineFour  = ""
	lineSix = "Press [MENU] for Options"
	
	if editMode then
		if activeField == 0 then
		  -- selectedOption = fieldIncDec(event, selectedOption, lipoCount - 1)		  
		  -- if selectedOption >= lipoCount then selectedOption = lipoCount - 1 end
		  if not popup and event == EVT_ENTER_BREAK then
			event = 0
			popup = not popup
			oldSelection = selectedOption
		  end
		  --Uncomment this for popup input
		  optInput = popupInput(lineOne..lipoPacks[selectedOption + 1],event,selectedOption,0,lipoCount - 1)
		  
			if optInput == 'OK' then
				editMode = not editMode
				popup = not popup
				activeField = 0
			elseif optInput == 'CANCEL' then
				editMode = not editMode
				popup = not popup
				selectedOption = oldSelection
				activeField = 0
			else
				selectedOption = optInput
			end
		elseif activeField == 1 then
			editMode = not editMode
			writeFlightLog()
			currentMenu = "mainScreen"
			activeField = 1
		end		
	else
		activeField = fieldIncDec(event, activeField, fieldMax, true)
	end
	
end--[[mainScreen]]

---------------------------------------------------------------
-- Function: draw
-- Parameters: currentMenu
-- Desc: Draws all variables meant to be displayed based on currentMenu
--	being passed in.
--
---------------------------------------------------------------
local function draw(currentMenu)

 if not popup then
	local drawPos = 1
	local drawLoc = 33
	local drawInv = 6
	local flagField = 0
	
	 if currentMenu == "mainScreen" or currentMenu == "addEntry" then
		lcd.drawText(40, 55, lineSix,0) -- Menu Option, Error
	 end
	  -- draw from the bottom up
	  lcd.drawText(3, 40, lineFour, getFieldFlags(3)) -- flightLog, deleteLogs
	  lcd.drawText(3, 28, lineThree, getFieldFlags(2)) --deleteThings, AddLipo,deleteLipos, flightLog
	  
	  if lipoEdit then
		lcd.drawText(3,16,lineTwo,0) --confirm
	  else
		lcd.drawText(3,16,lineTwo,getFieldFlags(1)) --AddLipo, delete lipo,writeLog, flightLog
	  end
	  
	  if currentMenu == "menuScreen" then
		lcd.drawText(3,3,lineOne,getFieldFlags(0)) --ViewLogs
	  else
		lcd.drawText(3,3, lineOne, 0) --Lipo, Select to Delete, Name:
	  end
	  
	  if currentMenu == "addEntry" then
		if lipoEdit then
			fieldMax = 2
			while drawPos <= wordMax do
				lcd.drawText(drawLoc,3,lipoNameArray[drawPos],getFieldFlags(flagField))
				drawLoc = drawLoc + drawInv
				drawPos = drawPos + 1
				flagField = flagField + 1
			end
		else
			lcd.drawText(33,3,lipoName,getFieldFlags(0))
		end
		
	  elseif lipoCount > 0 and (currentMenu == "mainScreen" or currentMenu == "deleteScreen") then

		lcd.drawText(lcd.getLastPos() + 2, 3, lipoPacks[selectedOption + 1],getFieldFlags(0))
		
	  elseif currentMenu == "logView" then
		local xPage = 185
		
		if prevPage%nextPage >= 100 then xPage = 175
		elseif prevPage%nextPage >= 10 then xPage = 180 end
		
		lcd.drawText(xPage,1,pageCount,0) -- Log page number
		lcd.drawText(1,52,lineFive,0)
	  end
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
  charMax = 37
  lipoPacks = {}
  selectedOption = 0
  activeField = 0
  lineOne = "Lipo Pack: "
  lineTwo = "Write Flight Log"
  lineThree = ""
  lineFour = ""
  lineFive = ""
  lineSix = ""
  currentMenu = 'mainScreen'
  lipoCount = 0
  letter = ' ' 
  curPos = 0
  loadData()
  nextPage = 2
  prevPage = 1
  pageCount = ""
  page = 0
  optInput = 1
  lipoEdit = false
  wordMax = 7
  letterPos = 1
  activeLetter = 0
  lipoName = " "
  lipoNameArray = {' ',' ',' ',' ',' ',' ',' '}
  setLipoName()
  
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
  
  if event == EVT_ENTER_BREAK and not popup and lipoEdit == false then
    editMode = not editMode
  end
  
  if currentMenu == "menuScreen" then
	menuScreen(event)
  elseif currentMenu == "addEntry" then
	addLipoScreen(event)
  elseif currentMenu == "deleteScreen" then
	deleteScreen(event)
  elseif currentMenu == "mainScreen" then
	mainScreen(event)
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
		currentMenu = 'menuScreen'
		activeField = 0
		prevPage  = 1
		nextPage  = 2
	end
  end
  draw(currentMenu)
end--[[run]]

return{run=run, init=init}