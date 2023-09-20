# Psmd.Bootstrap

A simple toolset to package scripts and their dependencies into a single, self-contained file.

## Install

```powershell
Install-Module Psmd.Bootstrap -Scope CurrentUser
```

## Use

```powershell
New-PsmdBootstrapScript -Path . -OutPath C:\temp
```

Takes all items in the current folder, wraps them into a bootstrap script and writes that single file to C:\temp\bootstrap.ps1.
The folder must contain a `run.ps1` file that executes everything else.
