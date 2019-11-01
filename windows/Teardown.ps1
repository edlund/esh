
$EnvRoot = "$PSScriptRoot\root"

If (Test-Path $EnvRoot) {
    Remove-Item -Path "$EnvRoot" -Recurse
}
