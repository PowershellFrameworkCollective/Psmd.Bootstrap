﻿function New-PsmdBootstrapScript {
	<#
	.SYNOPSIS
		Take all contents of a folder and embed them into a bootstrap scriptfile.
	
	.DESCRIPTION
		Take all contents of a folder and embed them into a bootstrap scriptfile.
		The targeted folder must contain a run.ps1 file for executing the bootstrap logic (unless you change that using the -StartScript parameter).

		When executing the resulting file, it will:
		- Create a temp folder
		- Write all contents of the source folder into that temp folder
		- Execute the start script within that temp folder (in a child process, unless calling the resulting file with '-NoChildProcess')
		- Remove the temp folder
	
	.PARAMETER Path
		The source folder containing the content to wrap up.
		Must contain a file named run.ps1, may contain subfolders.
	
	.PARAMETER OutPath
		The path where to write the bootstrap scriptfile to.
		Can be either a folder or the path to the ps1 file itself.
		If a folder is specified, it will create a "bootstrap.ps1" file in that folder.

	.PARAMETER StartScript
		The script file in the root folder that should be run when executing the bootstrap-script resulting from this command.
		Defaults to "run.ps1"
	
	.EXAMPLE
		PS C:\> New-PsmdBootstrapScript -Path . -OutPath C:\temp
		
		Takes all items in the current folder, wraps them into a bootstrap script and writes that single file to C:\temp\bootstrap.ps1
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfValidateScript('PSFramework.Validate.FSPath.Folder', ErrorString = 'PSFramework.Validate.FSPath.Folder')]
		[string]
		$Path,

		[Parameter(Mandatory = $true)]
		[PsfValidateScript('PSFramework.Validate.FSPath.FileOrParent', ErrorString = 'PSFramework.Validate.FSPath.FileOrParent')]
		[string]
		$OutPath,

		[PsfValidatePattern('\.ps1$', ErrorMessage = 'The Start Script must be a ps1 file!')]
		[string]
		$StartScript = 'run.ps1'
	)
	process {
		$runFile = Join-Path -Path $Path -ChildPath $StartScript
		if (-not (Test-Path -Path $runFile)) {
			Stop-PSFFunction -Message "Invalid package! No $StartScript found in source folder $Path." -Target $Path -EnableException $true -Cmdlet $PSCmdlet -Category InvalidData
		}

		#region Generate Bootstrap Payload
		$tempFile = New-PSFTempFile -Name bootstrapzip -Extension zip -ModuleName Psmd.Bootstrap
		$tempDir = New-PSFTempDirectory -Name bootstrapdir -ModuleName Psmd.Bootstrap
		Copy-Item -Path (Join-Path -Path $Path -ChildPath '*') -Destination $tempDir

		# Write config file for bootstrap script
		@{ RunFile = $StartScript } | Export-Clixml -Path "$tempDir\__Psmd_Bootstrap.clixml"

		Compress-Archive -Path "$tempDir\*" -DestinationPath $tempFile -Force
		$bytes = [System.IO.File]::ReadAllBytes($tempFile)
		$encoded = [convert]::ToBase64String($bytes)
		$bytes = $null

		$bootstrapCode = [System.IO.File]::ReadAllText("$script:ModuleRoot\content\bootstrap.ps1")
		$bootstrapCode = $bootstrapCode -replace '%data%', $encoded
		$encoded = $null
		Remove-PSFTempItem -Name bootstrapzip -ModuleName Psmd.Bootstrap
		Remove-PSFTempItem -Name bootstrapdir -ModuleName Psmd.Bootstrap
		#endregion Generate Bootstrap Payload

		#region Export bootstrapped file
		$outFile = Resolve-PSFPath -Path $OutPath -Provider FileSystem -SingleItem -NewChild
		if (Test-Path -Path $OutPath) {
			$item = Get-Item -Path $OutPath
			if ($item.PSIsContainer) {
				$outFile = Join-Path -Path $outFile -ChildPath 'bootstrap.ps1'
			}
		}
		$filename = Split-Path -Path $outFile -Leaf
		$bootstrapCode = $bootstrapCode -replace '%scriptname%', $filename

		$encoding = [System.Text.UTF8Encoding]::new($true)
		[System.IO.File]::WriteAllText($outFile, $bootstrapCode, $encoding)
		#endregion Export bootstrapped file
	}
}