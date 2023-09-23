<#
.SYNOPSIS
	This is a wrapper script around whatever data was injected into it when it was built.

.DESCRIPTION
	This is a wrapper script around whatever data was injected into it when it was built.
	To inspect what is contained, run this script with the "-ExpandTo" parameter pointing at the folder where to extract it to.
	The "run.ps1" file in the root folder is what is being executed after unwrapping it if executed without parameters.

.PARAMETER ExpandTo
	Expand the wrapped code, rather than execute it.
	Specify the folder you want it exported to.

.PARAMETER NoChildProcess
	Run the bootstrapped code in the current powershell context.
	By default, a new powerShell process is launched to execute the code.
	Note: If this parameter is used some files might get locked (e.g. DLL files of modules used), preventing the cleanup of some temp files.

.EXAMPLE
	PS C:\> .\%scriptname%

	Execute the wrapped code.

.EXAMPLE
	PS C:\> .\%scriptname% -ExpandTo C:\temp

	Export the wrapped code to C:\temp without executing it.
#>
[CmdletBinding()]
param (
	[string]
	$ExpandTo,

	[switch]
	$NoChildProcess
)

# The actual code to deploy
$payload = '%data%'

$tempPath = Join-Path -Path ([System.Environment]::GetFolderPath("LocalApplicationData")) -ChildPath 'Temp'
$name = "Bootstrap-$(Get-Random)"
$tempFile = Join-Path -Path $tempPath -ChildPath "$name.zip"

$bytes = [Convert]::FromBase64String($payload)
[System.IO.File]::WriteAllBytes($tempFile, $bytes)

if ($ExpandTo) {
	Expand-Archive -Path $tempFile -DestinationPath $ExpandTo
	Remove-Item -Path $tempFile -Force
	return
}

$tempFolder = New-Item -Path $tempPath -Name $name -ItemType Directory -Force
Expand-Archive -Path $tempFile -DestinationPath $tempFolder.FullName

$configFile = Join-Path -Path $tempFolder.FullName -ChildPath __Psmd_Bootstrap.clixml
$config = Import-Clixml -LiteralPath $configFile

$launchPath = Join-Path -Path $tempFolder.FullName -ChildPath $config.RunFile
try {
	$psPath = (Get-Process -id $pid).Path
	if ($psPath -notmatch 'powershell.exe$|pwsh.exe$') {
		if ($PSVersionTable.PSVersion.Major -gt 5) { $psPath = 'pwsh.exe' }
		else { $psPath = 'powershell.exe' }
	}

	if ($NoChildProcess) { & $launchPath }
	else { Start-Process $psPath -Wait -ArgumentList '-NoProfile', '-File', $launchPath }
}
finally {
	Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
	Remove-Item -Path $tempFolder.FullName -Force -Recurse -ErrorAction SilentlyContinue
}