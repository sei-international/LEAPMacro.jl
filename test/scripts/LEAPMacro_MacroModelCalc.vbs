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

'' SIG '' Begin signature block
'' SIG '' MIIhwgYJKoZIhvcNAQcCoIIhszCCIa8CAQExDzANBglg
'' SIG '' hkgBZQMEAgEFADB3BgorBgEEAYI3AgEEoGkwZzAyBgor
'' SIG '' BgEEAYI3AgEeMCQCAQEEEE7wKRaZJ7VNj+Ws4Q8X66sC
'' SIG '' AQACAQACAQACAQACAQAwMTANBglghkgBZQMEAgEFAAQg
'' SIG '' 9MqCh4jdOlWbm0lx1qz6lCCfEqVL26QSPMzsCVLFdR6g
'' SIG '' ggtcMIIFXzCCBEegAwIBAgIRAJhRmGdnH0nzo4lNRzCZ
'' SIG '' 95cwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCR0Ix
'' SIG '' GzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G
'' SIG '' A1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBM
'' SIG '' aW1pdGVkMSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2Rl
'' SIG '' IFNpZ25pbmcgQ0EwHhcNMjAwMjExMDAwMDAwWhcNMjMw
'' SIG '' MjEwMjM1OTU5WjCBzzELMAkGA1UEBhMCVVMxDjAMBgNV
'' SIG '' BBEMBTAyMTQ0MRYwFAYDVQQIDA1NYXNzYWNodXNldHRz
'' SIG '' MRMwEQYDVQQHDApTb21lcnZpbGxlMRkwFwYDVQQJDBAx
'' SIG '' MSBDdXJ0aXMgQXZlbnVlMTMwMQYDVQQKDCpTVE9DS0hP
'' SIG '' TE0gRU5WSVJPTk1FTlQgSU5TVElUVVRFIFUuUy4sIElO
'' SIG '' Qy4xMzAxBgNVBAMMKlNUT0NLSE9MTSBFTlZJUk9OTUVO
'' SIG '' VCBJTlNUSVRVVEUgVS5TLiwgSU5DLjCCASIwDQYJKoZI
'' SIG '' hvcNAQEBBQADggEPADCCAQoCggEBAKL2QAwxGVfd2o1E
'' SIG '' JGn6/nPdNgPolb0qIDMsBVGoKhsvJcXvf7wFGq7VrdeI
'' SIG '' q5ZAXUyKibRAm5jHc0xbItmsgbsHq2ivDngeO4qUsMfR
'' SIG '' UP2pRal0eY4MdoYnmxllA4qU6+lpjLJESNpB2iDa9uLO
'' SIG '' T5nVoYLq+PfW08nhD+jnMXqbfi+TdIfFdJ5PIaGEFVHh
'' SIG '' RWcGk2XYpqLmIHse3XIyHao8qa4j9smZM8Kgb3nX/Rgv
'' SIG '' uEXfrtv2ueXZH0eYcs4I/061Qh6o1oVjsJc2TeFz3DsT
'' SIG '' RAC+5h5Oiz3JGwtfEXeMYJqZWUruCNcfZ43pjrhZC1XI
'' SIG '' VXV54CkDmrwjLRxdz00CAwEAAaOCAYYwggGCMB8GA1Ud
'' SIG '' IwQYMBaAFA7hOqhTOjHVir7Bu61nGgOFrTQOMB0GA1Ud
'' SIG '' DgQWBBSY3etSMrfJrpjt0mpL/zDGzVQ7xTAOBgNVHQ8B
'' SIG '' Af8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
'' SIG '' BggrBgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwQAYD
'' SIG '' VR0gBDkwNzA1BgwrBgEEAbIxAQIBAwIwJTAjBggrBgEF
'' SIG '' BQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwQwYD
'' SIG '' VR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5zZWN0aWdv
'' SIG '' LmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcmww
'' SIG '' cwYIKwYBBQUHAQEEZzBlMD4GCCsGAQUFBzAChjJodHRw
'' SIG '' Oi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FDb2Rl
'' SIG '' U2lnbmluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0cDov
'' SIG '' L29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQELBQAD
'' SIG '' ggEBAEUXA7d3fTVZ7ynRRHkDLkSi1ExDswu6OywNndVy
'' SIG '' 28BgEcdM2PiosXdt8nZE51J8nrJ1AmVu3QRoJm9+pyix
'' SIG '' L0DYvYQpHBfSyPiYV7yf4o7T58tZuO6lE1Ra2/pZ+l3D
'' SIG '' K5PvGf6fL4uLYjYEUKMwi5ziAuo07rXVbt++x0oH6t4v
'' SIG '' wZpLCZ3kQ4tFz1OKE22w29wp2hfIjz3vfpcTkAH5UPen
'' SIG '' KUa/58lH7zSKGoveRlp68Trye7l+sgAYJuljtPruNtWD
'' SIG '' 3tDn8Xkpe0EcPPSaj14j3QNk0EAOdcXRz6u7wWzAlATs
'' SIG '' IjzGyq5EBd4AB3yQlki1qzpczXTt5sYuXfuYUVswggX1
'' SIG '' MIID3aADAgECAhAdokgwb5smGNCC4JZ9M9NqMA0GCSqG
'' SIG '' SIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UE
'' SIG '' CBMKTmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENp
'' SIG '' dHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29y
'' SIG '' azEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
'' SIG '' Y2F0aW9uIEF1dGhvcml0eTAeFw0xODExMDIwMDAwMDBa
'' SIG '' Fw0zMDEyMzEyMzU5NTlaMHwxCzAJBgNVBAYTAkdCMRsw
'' SIG '' GQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNV
'' SIG '' BAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
'' SIG '' aXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBT
'' SIG '' aWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
'' SIG '' MIIBCgKCAQEAhiKNMoV6GJ9J8JYvYwgeLdx8nxTP4ya2
'' SIG '' JWYpQIZURnQxYsUQ7bKHJ6aZy5UwwFb1pHXGqQ5QYqVR
'' SIG '' kRBq4Etirv3w+Bisp//uLjMg+gwZiahse60Aw2Gh3Gll
'' SIG '' bR9uJ5bXl1GGpvQn5Xxqi5UeW2DVftcWkpwAL2j3l+1q
'' SIG '' cr44O2Pej79uTEFdEiAIWeg5zY/S1s8GtFcFtk6hPldr
'' SIG '' H5i8xGLWGwuNx2YbSp+dgcRyQLXiX+8LRf+jzhemLVWw
'' SIG '' t7C8VGqdvI1WU8bwunlQSSz3A7n+L2U18iLqLAevRtn5
'' SIG '' RhzcjHxxKPP+p8YU3VWRbooRDd8GJJV9D6ehfDrahjVh
'' SIG '' 0wIDAQABo4IBZDCCAWAwHwYDVR0jBBgwFoAUU3m/Wqor
'' SIG '' Ss9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFA7hOqhTOjHV
'' SIG '' ir7Bu61nGgOFrTQOMA4GA1UdDwEB/wQEAwIBhjASBgNV
'' SIG '' HRMBAf8ECDAGAQH/AgEAMB0GA1UdJQQWMBQGCCsGAQUF
'' SIG '' BwMDBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
'' SIG '' UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2Vy
'' SIG '' dHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRp
'' SIG '' b25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGowaDA/
'' SIG '' BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3Qu
'' SIG '' Y29tL1VTRVJUcnVzdFJTQUFkZFRydXN0Q0EuY3J0MCUG
'' SIG '' CCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3Qu
'' SIG '' Y29tMA0GCSqGSIb3DQEBDAUAA4ICAQBNY1DtRzRKYaTb
'' SIG '' 3moqjJvxAAAeHWJ7Otcywvaz4GOz+2EAiJobbRAHBE++
'' SIG '' uOqJeCLrD0bs80ZeQEaJEvQLd1qcKkE6/Nb06+f3FZUz
'' SIG '' w6GDKLfeL+SU94Uzgy1KQEi/msJPSrGPJPSzgTfTt2Sw
'' SIG '' piNqWWhSQl//BOvhdGV5CPWpk95rcUCZlrp48bnI4sMI
'' SIG '' FrGrY1rIFYBtdF5KdX6luMNstc/fSnmHXMdATWM19jDT
'' SIG '' z7UKDgsEf6BLrrujpdCEAJM+U100pQA1aWy+nyAlEA0Z
'' SIG '' +1CQYb45j3qOTfafDh7+B1ESZoMmGUiVzkrJwX/zOgWb
'' SIG '' +W/fiH/AI57SHkN6RTHBnE2p8FmyWRnoao0pBAJ3fEtL
'' SIG '' zXC+OrJVWng+vLtvAxAldxU0ivk2zEOS5LpP8WKTKCVX
'' SIG '' KftRGcehJUBqhFfGsp2xvBwK2nxnfn0u6ShMGH7EezFB
'' SIG '' cZpLKewLPVdQ0srd/Z4FUeVEeN0B3rF1mA1UJP3wTuPi
'' SIG '' +IO9crrLPTru8F4XkmhtyGH5pvEqCgulufSe7pgyBYWe
'' SIG '' 6/mDKdPGLH29OncuizdCoGqC7TtKqpQQpOEN+BfFtlp5
'' SIG '' MxiS47V1+KHpjgolHuQe8Z9ahyP/n6RRnvs5gBHN27XE
'' SIG '' p6iAb+VT1ODjosLSWxr6MiYtaldwHDykWC6j81tLB9wy
'' SIG '' WfOHpxptWDGCFb4wghW6AgEBMIGRMHwxCzAJBgNVBAYT
'' SIG '' AkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIx
'' SIG '' EDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3Rp
'' SIG '' Z28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0Eg
'' SIG '' Q29kZSBTaWduaW5nIENBAhEAmFGYZ2cfSfOjiU1HMJn3
'' SIG '' lzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwx
'' SIG '' AjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
'' SIG '' CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
'' SIG '' SIb3DQEJBDEiBCC8cjNfs9YplxCsGvv52M30Vsgljm6F
'' SIG '' PON7EoLS3dRKYTANBgkqhkiG9w0BAQEFAASCAQAC+Spr
'' SIG '' ccsHLux7kcTy3TO9iSl8BnWbL1LO/sBH+bH0wnrlHYOn
'' SIG '' PNay2RkQtEFhOSrVK2kwJO9sUq7vvRfvRdv/cD9f2ZHC
'' SIG '' n0w257HGvwD9Qmu20BB9l3EpwLao91DH2thgabUaqxL8
'' SIG '' OhIXWqUbkvW4Mugboq5Z+ChmFZTO5uKrMpLFWMtyR3Gz
'' SIG '' OXPBH3dqnzLKSjgZ2yRixVubTrE+nXpcZKyqTPM636UG
'' SIG '' c32gqGAObOjuIeJYiMt3LBNwzWfKU7uSdaqEWrAcWvh9
'' SIG '' 3sTBno21Hn+aywEsPf2r9d3CmNmHxs+vwLEOAlOEFXYA
'' SIG '' nxrd14tjdEHE116X3KtzQ+DpYe7QoYITfzCCE3sGCisG
'' SIG '' AQQBgjcDAwExghNrMIITZwYJKoZIhvcNAQcCoIITWDCC
'' SIG '' E1QCAQMxDzANBglghkgBZQMEAgIFADCCAQwGCyqGSIb3
'' SIG '' DQEJEAEEoIH8BIH5MIH2AgEBBgorBgEEAbIxAgEBMDEw
'' SIG '' DQYJYIZIAWUDBAIBBQAEIFzaVGLPF4wJtGko18V0eulq
'' SIG '' 9ztFiuoAWTxpRbe47p5+AhROk7RxtU6lkxeMqdbnax6y
'' SIG '' HY2nUxgPMjAyMjA0MTQxNTA5MjhaoIGKpIGHMIGEMQsw
'' SIG '' CQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5j
'' SIG '' aGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQK
'' SIG '' Ew9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMMI1NlY3Rp
'' SIG '' Z28gUlNBIFRpbWUgU3RhbXBpbmcgU2lnbmVyICMyoIIN
'' SIG '' +zCCBwcwggTvoAMCAQICEQCMd6AAj/TRsMY9nzpIg41r
'' SIG '' MA0GCSqGSIb3DQEBDAUAMH0xCzAJBgNVBAYTAkdCMRsw
'' SIG '' GQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNV
'' SIG '' BAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
'' SIG '' aXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBT
'' SIG '' dGFtcGluZyBDQTAeFw0yMDEwMjMwMDAwMDBaFw0zMjAx
'' SIG '' MjIyMzU5NTlaMIGEMQswCQYDVQQGEwJHQjEbMBkGA1UE
'' SIG '' CBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdT
'' SIG '' YWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQx
'' SIG '' LDAqBgNVBAMMI1NlY3RpZ28gUlNBIFRpbWUgU3RhbXBp
'' SIG '' bmcgU2lnbmVyICMyMIICIjANBgkqhkiG9w0BAQEFAAOC
'' SIG '' Ag8AMIICCgKCAgEAkYdLLIvB8R6gntMHxgHKUrC+eXld
'' SIG '' CWYGLS81fbvA+yfaQmpZGyVM6u9A1pp+MshqgX20XD5W
'' SIG '' EIE1OiI2jPv4ICmHrHTQG2K8P2SHAl/vxYDvBhzcXk6T
'' SIG '' h7ia3kwHToXMcMUNe+zD2eOX6csZ21ZFbO5LIGzJPmz9
'' SIG '' 8JvxKPiRmar8WsGagiA6t+/n1rglScI5G4eBOcvDtzrN
'' SIG '' n1AEHxqZpIACTR0FqFXTbVKAg+ZuSKVfwYlYYIrv8azN
'' SIG '' h2MYjnTLhIdBaWOBvPYfqnzXwUHOrat2iyCA1C2VB43H
'' SIG '' 9QsXHprl1plpUcdOpp0pb+d5kw0yY1OuzMYpiiDBYMby
'' SIG '' AizE+cgi3/kngqGDUcK8yYIaIYSyl7zUr0QcloIilSqF
'' SIG '' VK7x/T5JdHT8jq4/pXL0w1oBqlCli3aVG2br79rflC7Z
'' SIG '' GutMJ31MBff4I13EV8gmBXr8gSNfVAk4KmLVqsrf7c9T
'' SIG '' qx/2RJzVmVnFVmRb945SD2b8mD9EBhNkbunhFWBQpbHs
'' SIG '' z7joyQu+xYT33Qqd2rwpbD1W7b94Z7ZbyF4UHLmvhC13
'' SIG '' ovc5lTdvTn8cxjwE1jHFfu896FF+ca0kdBss3Pl8qu/C
'' SIG '' dkloYtWL9QPfvn2ODzZ1RluTdsSD7oK+LK43EvG8VsPk
'' SIG '' rUPDt2aWXpQy+qD2q4lQ+s6g8wiBGtFEp8z3uDECAwEA
'' SIG '' AaOCAXgwggF0MB8GA1UdIwQYMBaAFBqh+GEZIA/DQXdF
'' SIG '' KI7RNV8GEgRVMB0GA1UdDgQWBBRpdTd7u501Qk6/V9Oa
'' SIG '' 258B0a7e0DAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/
'' SIG '' BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBABgNV
'' SIG '' HSAEOTA3MDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUF
'' SIG '' BwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzBEBgNV
'' SIG '' HR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnNlY3RpZ28u
'' SIG '' Y29tL1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5jcmww
'' SIG '' dAYIKwYBBQUHAQEEaDBmMD8GCCsGAQUFBzAChjNodHRw
'' SIG '' Oi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FUaW1l
'' SIG '' U3RhbXBpbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6
'' SIG '' Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUA
'' SIG '' A4ICAQBKA3iQQjPsexqDCTYzmFW7nUAGMGtFavGUDhlQ
'' SIG '' /1slXjvhOcRbuumVkDc3vd/7ZOzlgreVzFdVcEtO9KiH
'' SIG '' 3SKFple7uCEn1KAqMZSKByGeir2nGvUCFctEUJmM7D66
'' SIG '' A3emggKQwi6Tqb4hNHVjueAtD88BN8uNovq4WpquoXqe
'' SIG '' E5MZVY8JkC7f6ogXFutp1uElvUUIl4DXVCAoT8p7s7Ol
'' SIG '' 0gCwYDRlxOPFw6XkuoWqemnbdaQ+eWiaNotDrjbUYXI8
'' SIG '' DoViDaBecNtkLwHHwaHHJJSjsjxusl6i0Pqo0bglHBbm
'' SIG '' wNV/aBrEZSk1Ki2IvOqudNaC58CIuOFPePBcysBAXMKf
'' SIG '' 1TIcLNo8rDb3BlKao0AwF7ApFpnJqreISffoCyUztT9t
'' SIG '' r59fClbfErHD7s6Rd+ggE+lcJMfqRAtK5hOEHE3rDbW4
'' SIG '' hqAwp4uhn7QszMAWI8mR5UIDS4DO5E3mKgE+wF6FoCSh
'' SIG '' F0DV29vnmBCk8eoZG4BU+keJ6JiBqXXADt/QaJR5oaCe
'' SIG '' jra3QmbL2dlrL03Y3j4yHiDk7JxNQo2dxzOZgjdE1CYp
'' SIG '' JkCOeC+57vov8fGP/lC4eN0Ult4cDnCwKoVqsWxo6Srk
'' SIG '' ECtuIf3TfJ035CoG1sPx12jjTwd5gQgT/rJkXumxPObQ
'' SIG '' eCOyCSziJmK/O6mXUczHRDKBsq/P3zCCBuwwggTUoAMC
'' SIG '' AQICEDAPb6zdZph0fKlGNqd4LbkwDQYJKoZIhvcNAQEM
'' SIG '' BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcg
'' SIG '' SmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwG
'' SIG '' A1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYD
'' SIG '' VQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24g
'' SIG '' QXV0aG9yaXR5MB4XDTE5MDUwMjAwMDAwMFoXDTM4MDEx
'' SIG '' ODIzNTk1OVowfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
'' SIG '' EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2Fs
'' SIG '' Zm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUw
'' SIG '' IwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5n
'' SIG '' IENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
'' SIG '' AgEAyBsBr9ksfoiZfQGYPyCQvZyAIVSTuc+gPlPvs1rA
'' SIG '' dtYaBKXOR4O168TMSTTL80VlufmnZBYmCfvVMlJ5Lslj
'' SIG '' whObtoY/AQWSZm8hq9VxEHmH9EYqzcRaydvXXUlNclYP
'' SIG '' 3MnjU5g6Kh78zlhJ07/zObu5pCNCrNAVw3+eolzXOPEW
'' SIG '' snDTo8Tfs8VyrC4Kd/wNlFK3/B+VcyQ9ASi8Dw1Ps5EB
'' SIG '' jm6dJ3VV0Rc7NCF7lwGUr3+Az9ERCleEyX9W4L1GnIK+
'' SIG '' lJ2/tCCwYH64TfUNP9vQ6oWMilZx0S2UTMiMPNMUopy9
'' SIG '' Jv/TUyDHYGmbWApU9AXn/TGs+ciFF8e4KRmkKS9G493b
'' SIG '' kV+fPzY+DjBnK0a3Na+WvtpMYMyou58NFNQYxDCYdIIh
'' SIG '' z2JWtSFzEh79qsoIWId3pBXrGVX/0DlULSbuRRo6b83X
'' SIG '' hPDX8CjFT2SDAtT74t7xvAIo9G3aJ4oG0paH3uhrDvBb
'' SIG '' fel2aZMgHEqXLHcZK5OVmJyXnuuOwXhWxkQl3wYSmgYt
'' SIG '' nwNe/YOiU2fKsfqNoWTJiJJZy6hGwMnypv99V9sSdvqK
'' SIG '' QSTUG/xypRSi1K1DHKRJi0E5FAMeKfobpSKupcNNgtCN
'' SIG '' 2mu32/cYQFdz8HGj+0p9RTbB942C+rnJDVOAffq2OVgy
'' SIG '' 728YUInXT50zvRq1naHelUF6p4MCAwEAAaOCAVowggFW
'' SIG '' MB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bL
'' SIG '' MB0GA1UdDgQWBBQaofhhGSAPw0F3RSiO0TVfBhIEVTAO
'' SIG '' BgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIB
'' SIG '' ADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAI
'' SIG '' MAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDov
'' SIG '' L2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNl
'' SIG '' cnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUF
'' SIG '' BwEBBGowaDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51
'' SIG '' c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUFkZFRydXN0
'' SIG '' Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51
'' SIG '' c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBt
'' SIG '' VIGlM10W4bVTgZF13wN6MgstJYQRsrDbKn0qBfW8Oyf0
'' SIG '' WqC5SVmQKWxhy7VQ2+J9+Z8A70DDrdPi5Fb5WEHP8ULl
'' SIG '' EH3/sHQfj8ZcCfkzXuqgHCZYXPO0EQ/V1cPivNVYeL9I
'' SIG '' duFEZ22PsEMQD43k+ThivxMBxYWjTMXMslMwlaTW9JZW
'' SIG '' CLjNXH8Blr5yUmo7Qjd8Fng5k5OUm7Hcsm1BbWfNyW+Q
'' SIG '' PX9FcsEbI9bCVYRm5LPFZgb289ZLXq2jK0KKIZL+qG9a
'' SIG '' JXBigXNjXqC72NzXStM9r4MGOBIdJIct5PwC1j53BLwE
'' SIG '' NrXnd8ucLo0jGLmjwkcd8F3WoXNXBWiap8k3ZR2+6rzY
'' SIG '' QoNDBaWLpgn/0aGUpk6qPQn1BWy30mRa2Coiwkud8Tle
'' SIG '' TN5IPZs0lpoJX47997FSkc4/ifYcobWpdR9xv1tDXWU9
'' SIG '' UIFuq/DQ0/yysx+2mZYm9Dx5i1xkzM3uJ5rloMAMcofB
'' SIG '' bk1a0x7q8ETmMm8c6xdOlMN4ZSA7D0GqH+mhQZ3+sbig
'' SIG '' ZSo04N6o+TzmwTC7wKBjLPxcFgCo0MR/6hGdHgbGpm0y
'' SIG '' XbQ4CStJB6r97DDa8acvz7f9+tCjhNknnvsBZne5VhDh
'' SIG '' IG7GrrH5trrINV0zdo7xfCAMKneutaIChrop7rRaALGM
'' SIG '' q+P5CslUXdS5anSevUiumDGCBC0wggQpAgEBMIGSMH0x
'' SIG '' CzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1h
'' SIG '' bmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNV
'' SIG '' BAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2Vj
'' SIG '' dGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQQIRAIx3oACP
'' SIG '' 9NGwxj2fOkiDjWswDQYJYIZIAWUDBAICBQCgggFrMBoG
'' SIG '' CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG
'' SIG '' 9w0BCQUxDxcNMjIwNDE0MTUwOTI4WjA/BgkqhkiG9w0B
'' SIG '' CQQxMgQwJdriP69ekoyBRRTcqgzRmm01VkRUuDcldFPj
'' SIG '' 3I1/h8wm22wUdbgX9Oi3KSzKQoVlMIHtBgsqhkiG9w0B
'' SIG '' CRACDDGB3TCB2jCB1zAWBBSVETcQHYgvMb1RP5Sa2kxo
'' SIG '' rYwI9TCBvAQUAtZbleKDcMFXAJX6iPkj3ZN/rY8wgaMw
'' SIG '' gY6kgYswgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpO
'' SIG '' ZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEe
'' SIG '' MBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4w
'' SIG '' LAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRp
'' SIG '' b24gQXV0aG9yaXR5AhAwD2+s3WaYdHypRjaneC25MA0G
'' SIG '' CSqGSIb3DQEBAQUABIICACKamaYrtiEVrJEdaicNkMd3
'' SIG '' Xn68SndoS27PJg55MfWHbo7QEO/TFdyzKSGlkkxcxPSl
'' SIG '' wCDiUNsgx79myflRc9IS6zIWkzJLEq/MhR+Tu6Ik52gG
'' SIG '' EtDY0SpofF/ACV5z89LS8MW/S36Vt41Hq5hfXgLuchyj
'' SIG '' nllUzsTZc5mvl1LCrDrNR8W4vuiKNCOVkFJ4RlvELF1C
'' SIG '' DWjF3AD8Jt2Q01AKRVP7919SvMHjRv5kDf0s0pjbPvPK
'' SIG '' jz9GdDzLnqeijdK73u9NQj1xfxjtldK3/GNQUFv2EHJZ
'' SIG '' 7IiEwivBb11nh5vupr5u7B3piJX8FmNfuc0q5Ry8XD7q
'' SIG '' klk85pR3gWVd9fRHon+Z0R91T2iWSjaOlcENlzcy30w2
'' SIG '' nMows9SdpkdSJ/At0Hn7WN93Uq4DC7VQDQNtIdumCRgM
'' SIG '' xbjVixUrlRvclOmdtYoemAUgLOPm51wgsUNP9j0duQIx
'' SIG '' 70LmRMCNX/Zqp3+3Q8w9SC1rQVm91wLIZQtUM5m6Yb5N
'' SIG '' 17nPoXPzsRgPaCem+yo3PjQ9tWp88o4BCCCfYy3LaRiG
'' SIG '' t9lT/qQMGdI+/waCaViLo1p/MGgmZWxa2B2xooLcCToA
'' SIG '' 6nfncdQNKG3Bf9yj1jBYuPAoqWvZ9BEV+hcdKkqqhWRA
'' SIG '' wkdFpdGzBJQOsZucCahClUOcSTWZfNaAPozKfo546KiO
'' SIG '' End signature block
