cls

macrodir = LEAP.ActiveArea.Directory & "Macro\"
macrofile = "LEAP-Macro-run.jl"

function GetJuliaPath()
	Dim shell
	Dim PathEV
	Dim PathArray, LocalAppDataPath
	Dim i

	Set shell = CreateObject("WScript.Shell")
	waitTillComplete = False
	style = 1

	GetJuliaPath = Null

	Set re = New RegExp
	With re
		.Pattern    = "julia"
		.IgnoreCase = True
		.Global     = False
	End With

	' First check in the PATH environment variable
	PathEV = shell.ExpandEnvironmentStrings( "%PATH%" )
	PathArray = Split(PathEV,";")
	For i = 0 to UBound(PathArray)
		If re.Test(PathArray(i)) Then
			GetJuliaPath = PathArray(i) & "\julia.exe"
			Exit For
		End If
	Next

	' Then check in C:\USER\AppData\Local\Programs
	if IsNull(GetJuliaPath) Then
		LocalAppDataPath = shell.ExpandEnvironmentStrings("%localappdata%")
		Set FSO = CreateObject("Scripting.FileSystemObject")
		For Each LocalProgramsFolder In FSO.GetFolder(LocalAppDataPath & "\Programs").SubFolders
			If re.Test(LocalProgramsFolder) Then
				GetJuliaPath =  LocalProgramsFolder & "\bin\julia.exe"
			End If
		Next
	End If
	
	' Then check for registry keys created during NEMO/Julia installation
	on error resume next

	' JuliaPath recorded during NEMO installation
	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4EEC991C-8D33-4773-84D3-7FE4162EEF82}\JuliaPath")
	End If
	
	' Keys created during Julia installation (some common versions)
	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Julia-1.7.2_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Julia-1.7.2_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Julia-1.7.2_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKCU\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Julia-1.7.2_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{054B4BC6-BD30-45C8-A623-8F5BA6EBD55D}_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{054B4BC6-BD30-45C8-A623-8F5BA6EBD55D}_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{054B4BC6-BD30-45C8-A623-8F5BA6EBD55D}_is1\DisplayIcon")
	End If

	If IsNull(GetJuliaPath) Then
		GetJuliaPath = shell.RegRead("HKCU\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{054B4BC6-BD30-45C8-A623-8F5BA6EBD55D}_is1\DisplayIcon")
	End If

	on error goto 0

End Function

Dim shell
Dim juliapath

Set shell = CreateObject("WScript.Shell")
waitTillComplete = False
style = 1

' Find Julia
juliapath = GetJuliaPath()

' If Julia found, then execute
If IsNull(juliapath) Then
	' Wscript.echo doesn't work when using LEAP 64-bit
	msgbox("Could not locate the Julia executable. Try adding the path to the executable to the Windows environment variable named 'Path'.")
Else
	path = Chr(34) & juliapath & Chr(34) & " " & Chr(34) & macrodir & macrofile & Chr(34) & " "  & Chr(34)

	errorcode = shell.Run(path, style, waitTillComplete)
End If
