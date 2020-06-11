param (
    [string]$Tags,
    [switch]$UpdateTags
)

Import-Module $PSScriptRoot\ouroboros.psm1 -Force
Import-Module $PSScriptRoot\..\utils.psm1 -Force

$OUROBOROS_PATH = Get-OuroborosPath

function Create-ShortcutInQueriesIfNonExisting($post, $querypath) {
    $shortcut = Get-FileDestination $querypath $post
    if (!(Test-Path "$shortcut.lnk")) {
        $target = Get-FileDestination $OUROBOROS_PATH\posts $post
        Set-Shortcut -Location "$shortcut.lnk" -Target $target
    }
}

$QuerySet = $false
foreach ($Tag in $Tags -split ' ') {
    if ($Tag.StartsWith('set:')) {
        $QuerySet = $true
        break
    }
}
Write-Host "Obtaining post information."
if ($QuerySet) {
    $AllPosts = Get-PostsFromSet $Tags
} else {
    $AllPosts = Get-Posts $Tags
}
Write-Host "$($AllPosts.Count) posts found."

$tags = $tags -replace ':','='
$QUERY_PATH = "$OUROBOROS_PATH\queries\$tags"
if (!(Test-Path -LiteralPath "$QUERY_PATH")) {
    New-Item "$QUERY_PATH" -ItemType Directory
}

$NewPosts = New-Object System.Collections.ArrayList
$NewPostLocations = New-Object System.Collections.ArrayList
foreach ($Post In $AllPosts) {
    $root = "$OUROBOROS_PATH\$tags"
    $postOnLocal = Get-FileDestination "$OUROBOROS_PATH\posts" $Post
    if (!(Test-Path $postOnLocal)) {
        $NewPosts.Add($Post) | Out-Null
        $NewPostLocations.Add($postOnLocal) | Out-Null
    }
}
if ($NewPosts.Count) {
    $size = ($NewPosts.file.size | Measure-Object -Sum).Sum
    $downloaded = 0
    Write-Host "$($NewPosts.Count) new posts ($size bytes) will be downloaded."
    For ($i = 0; $i -lt $NewPosts.Count; $i++ ) {
        if ($NewPosts[$i].file.url) {
            Invoke-WebRequest $NewPosts[$i].file.url -OutFile $NewPostLocations[$i]
            Create-ShortcutInQueriesIfNonExisting $NewPosts[$i] $QUERY_PATH
            $downloaded++
        }
    }
    Write-Host "$($downloaded.Count) new posts downloaded."
} else {
    Write-Host "Nothing to download."
}

if ($UpdateTags) {
    $NewTags = 0
    $AllPosts | foreach {
        $NewTagCount = Update-Tags $_
        $TotalNewTagCount += $NewTagCount
    }
    Write-Output "$NewTags new tags found."
}

Start-Sleep 1  # respect the rate limit
