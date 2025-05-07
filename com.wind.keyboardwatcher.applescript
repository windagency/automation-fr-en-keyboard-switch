#!/usr/bin/osascript
on run
	try
		-- Initialize error handler
		set errorText to ""
		
		-- Get current keyboard state with timeout
		set timeoutSeconds to 5
		set startTime to current date
		set maxAttempts to 50 -- Limit total attempts
		
		repeat while ((current date) - startTime) ² timeoutSeconds
			if my isMxMchnclConnected() then
				processConnectedKeyboard()
				exit repeat
			else
				processDisconnectedKeyboard()
				exit repeat
			end if
			
			delay 0.1 -- Prevent CPU overload
			set maxAttempts to maxAttempts - 1
			
			if maxAttempts ² 0 then
				set errorText to "Maximum attempts reached"
				my writeToLog(errorText)
				error "Maximum attempts reached"
			end if
		end repeat
		
		if ((current date) - startTime) > timeoutSeconds then
			set errorText to "Timeout waiting for keyboard state"
			my writeToLog(errorText)
			error "Timeout waiting for keyboard state"
		end if
		
	on error errorMessage number errorNumber
		-- Log error with timestamp and details
		set errorText to "Error " & errorNumber & " - " & errorMessage
		my writeToLog(errorText)
		
		-- Attempt recovery based on error type
		if errorNumber is -1712 then -- User cancelled
			return false
		end if
		
		if errorNumber is -1009 then -- Connection invalid
			return processDisconnectedKeyboard()
		end if
		
		if errorNumber is -10810 then -- Timeout
			return processDisconnectedKeyboard()
		end if
		
		return false
	end try
end run

on isMxMchnclConnected()
	try
		set bluetoothOutput to do shell script "system_profiler SPBluetoothDataType"
		
		-- Split the output into lines
		set textItems to paragraphs of bluetoothOutput
		set i to 1
		
		repeat while i ² (count of textItems)
			-- Check if current item contains MX MCHNCL
			if item i of textItems contains "MX MCHNCL" then
				-- Look backwards for connection status
				set j to i
				
				repeat while j > 0
					if item j of textItems contains "Not Connected:" then
						-- Device found but not connected
						return false
					end if
					
					if item j of textItems contains "Connected:" then
						-- Device found connected
						return true
					end if
					
					set j to j - 1
				end repeat
			end if
			
			set i to i + 1
		end repeat
	on error errorMessage number errorNumber
		-- Device not found
		my writeToLog("MX MCHNCL not found: " & errorMessage)
		return false
	end try
end isMxMchnclConnected

on getActiveInputSource()
	try
		tell application "System Events"
			tell process "TextInputMenuAgent"
				-- Get all menu items
				set menuItems to menu items of menu 1 of menu bar item 1 of menu bar 2
				
				-- Find the checked item
				repeat with i from 1 to count of menuItems
					set thisItem to item i of menuItems
					if value of attribute "AXMenuItemMarkChar" of thisItem is not missing value then
						return name of thisItem
					end if
				end repeat
				
				return ""
			end tell
		end tell
	on error errorMessage number errorNumber
		-- Log error with timestamp and details
		set errorText to "Error " & errorNumber & " - " & errorMessage
		my writeToLog(errorText)
	end try
end getActiveInputSource

on processConnectedKeyboard()
	if my getActiveInputSource() is not "French" then
		my changeInputSource("French")
	end if
end processConnectedKeyboard

on processDisconnectedKeyboard()
	if my getActiveInputSource() is not "British" then
		my changeInputSource("British")
	end if
end processDisconnectedKeyboard

on changeInputSource(entryName)
	try
		ignoring application responses
			tell application "System Events"
				click menu bar item 1 of menu bar 2 of application process "TextInputMenuAgent"
			end tell
		end ignoring
		
		delay 0.1
		
		do shell script "killall 'System Events'"
		delay 0.1
		
		tell application "System Events"
			launch
			click
			delay 0.1
			click menu item entryName of menu 1 of menu bar item 1 of menu bar 2 of application process "TextInputMenuAgent"
		end tell
	on error errorMessage number errorNumber
		my writeToLog("Failed to switch to " & entryName & ": " & errorMessage)
		return false
	end try
end changeInputSource

on writeToLog(logText)
	-- Create log file if it doesn't exist
	set logDir to POSIX path of (path to desktop)
	set logFile to logDir & "keyboard_language_switcher.log"
	
	-- Write to log using shell commands
	try
		-- Ensure directory exists and is writable
		do shell script "mkdir -p \"" & logDir & "\""
		do shell script "touch \"" & logFile & "\""
		
		-- Set proper permissions
		do shell script "chmod 644 \"" & logFile & "\""
		
		-- Write to log file
		do shell script "echo \"[" & (current date) & "] " & logText & "\" >> \"" & logFile & "\""
		
	on error errorMessage number errorNumber
		-- Log error to system logs
		do shell script "logger -t KeyboardWatcher \"Failed to write to log file: " & errorMessage & "\""
		
		-- Display error dialog
		display dialog "Could not write to log file: " & errorMessage buttons {"OK"} default button 1
	end try
end writeToLog

-- Helper function to clean device names
on cleanDeviceName(deviceName)
	set deviceName to my trimText(deviceName)
	if deviceName ends with ":" then
		set deviceName to text 1 thru -2 of deviceName
	end if
	return deviceName
end cleanDeviceName

-- Helper function to trim whitespace
on trimText(str)
	-- Remove all types of whitespace and tabs
	set str to do shell script "echo \"" & str & "\" | tr -d '\\t '"
	
	-- Handle empty strings
	if length of str = 0 then
		return ""
	end if
	
	return str
end trimText
