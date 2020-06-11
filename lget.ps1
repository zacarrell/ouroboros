param ([parameter(mandatory=$true)][string[]]$tags)

Import-Module $PSScriptRoot\ouroboros.psm1 -Force
Import-Module $PSScriptRoot\..\utils.psm1 -Force

$OUROBOROS_PATH = Get-OuroborosPath

$oldroot = $PSScriptRoot

Set-Location "$OUROBOROS_PATH\tags"
$names = ((gci $tags).Name | group | where Count -eq $tags.Length).Name

$tempdir = New-TemporaryDirectory

Set-Location "$OUROBOROS_PATH\tags\$($tags[0])"
(gci $names).FullName | foreach { Copy-Item $_ -Destination $tempdir }

Invoke-Item $tempdir

Set-Location $oldroot
