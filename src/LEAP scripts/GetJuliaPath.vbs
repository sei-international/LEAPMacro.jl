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
End Function
