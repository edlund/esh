<#

.SYNOPSIS Setup a build environment.

.PARAMETER Toolchain The name of the GCC toolchain; "Arm" or "Avr".
.PARAMETER BuildToolsJson Relative path to a Build Tools JSON file
    (from the PSScriptRoot of this script).

#>

param(
    [Parameter(Mandatory=$true)][String] $Toolchain = "-",
    [String] $BuildToolsJson = "BuildTools.json"
)

Function Add-BinPackage
{
    param(
        [Parameter(Mandatory=$true)][String] $Path,
        [Parameter(Mandatory=$true)][String] $Name,
        [Parameter(Mandatory=$true)][String] $Type,
        [Parameter(Mandatory=$true)][bool] $CcPaths
    )
    If ($Type -Ne "Compiler" -Or ($Type -Eq "compiler" -And $Name -Eq $Toolchain)) {
        Get-ChildItem -Path "$Path" -Recurse -Directory -Include "bin" | ForEach-Object {
            $BinPath = ";$_"
            If (!$Env:Path.Contains($BinPath)) {
                $Env:Path += $BinPath
            }
        }
        If ($CcPaths) {
            $Env:IncludePath += ";" + (Get-DirectoryPaths -Path $Path -Name "include")
            $Env:LibraryPath += ";" + (Get-DirectoryPaths -Path $Path -Name "lib")
        }
        Write-Host "Bin package ""$Path"" added"
    }
}

Function Get-BinPackage
{
    param(
        [Parameter(Mandatory=$true)][String] $FileUri,
        [Parameter(Mandatory=$true)][String] $FilePath,
        [Parameter(Mandatory=$true)][String] $FileHash
    )
    If (!(Test-Path $FilePath)) {
        Invoke-WebRequest "$FileUri" -OutFile "$FilePath"
    }
    $HashAlgorithm, $HashExpected = $FileHash.Split(":")
    $HashActual = (Get-FileHash -Path $FilePath -Algorithm $HashAlgorithm).Hash
    If ($HashActual -Ne $HashExpected) {
        throw "$FilePath $HashAlgorithm checksum mismatch"
    }
    $DirectoryPath = Update-LastSubstring -Haystack $FilePath -Needle ".zip" -Replacement ""
    If (!(Test-Path $DirectoryPath)) {
        Expand-Archive -Path $FilePath -DestinationPath $DirectoryPath -Force
    }
    Write-Host "Bin package ""$FilePath"" handled"
    return $DirectoryPath
}

Function Get-DirectoryPaths
{
    param(
        [Parameter(Mandatory=$true)][String] $Path,
        [Parameter(Mandatory=$true)][String] $Name
    )
    $DirectoryPaths = New-Object System.Collections.Generic.List[String]
    Get-ChildItem -Path $Path -Recurse -Directory -Include $Name | ForEach-Object {
        $DirectoryPaths.Add($_)
    }
    return [System.String]::Join(";", $DirectoryPaths)
}

Function Get-PrettyPathString
{
    param(
        [Parameter(Mandatory=$true)][String] $Name,
        [Parameter(Mandatory=$true)][String] $Path
    )
    $Pretty = "- $($Name):`r`n"
    $Path.Split(";") | ForEach-Object {
        If ($_) {
            $Pretty += "-- $($_)`r`n"
        }
    }
    return $Pretty
}

function Update-LastSubstring
{
    param(
        [Parameter(Mandatory=$true)][String] $Haystack,
        [Parameter(Mandatory=$true)][String] $Needle,
        [String] $Replacement
    )
    $LastIndex = $Haystack.LastIndexOf($Needle)
    return $Haystack.Remove($LastIndex, $Needle.Length).Insert($LastIndex, $Replacement)
}

$EnvRoot = "$PSScriptRoot\root"
$BuildTools = Get-Content -Raw -Path "$PSScriptRoot\$BuildToolsJson" | ConvertFrom-Json
$Toolchain = "Gcc$Toolchain"
$Env:IncludePath = ""
$Env:LibraryPath = ""

If ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "PowerShell v5 or greater required"
}

If (!(Test-Path $EnvRoot)) {
    New-Item -Path "$PSScriptRoot" -Name "root" -ItemType "directory"
}

Write-Host "Running with params"
Write-Host "Toolchain: $Toolchain"
Write-Host "BuildToolsJson: $BuildToolsJson"

foreach ($Entry in $BuildTools | Get-Member) {
    $Member = $BuildTools.$($Entry.Name)
    If ($Member.GetType() -Eq [System.Management.Automation.PSCustomObject]) {
        $Path = Get-BinPackage `
            -FileUri $Member.Uri `
            -FilePath "$EnvRoot\$($Member.Name)" `
            -FileHash $Member.Hash
        Add-BinPackage `
            -Path $Path `
            -Name $Entry.Name `
            -Type $Member.Type `
            -CcPaths $Member.CcPaths
    }
}

$Env:Toolchain = $Toolchain

Write-Host "Printing Environment Information"
Write-Host -NoNewline (Get-PrettyPathString -Name "Path" -Path $Env:Path)
Write-Host -NoNewline (Get-PrettyPathString -Name "IncludePath" -Path $Env:IncludePath)
Write-Host -NoNewline (Get-PrettyPathString -Name "LibraryPath" -Path $Env:LibraryPath)
Write-Host "Starting Development PowerShell"
Start-Process -FilePath "powershell" -Wait
