-- VOID.app: opens a Terminal window and runs the void.sh bundled inside the app
on run
	set voidScript to POSIX path of (path to me) & "Contents/Resources/void.sh"
	tell application "Terminal"
		activate
		do script "clear; exec /bin/bash " & quoted form of voidScript
	end tell
end run
