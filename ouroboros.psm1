Add-Type -AssemblyName System.Web

Import-Module "$PSScriptRoot\..\utils.psm1"

$MAX_LIMIT = 320
$OUROBOROS_PATH = "$HOME\Downloads\ouroboros"
$TAGS_PATH = Join-Path $OUROBOROS_PATH "tags"

function Update-Tags($Post) {
    $NewTags = New-Object System.Collections.ArrayList
    foreach ($tag in ConvertTo-FlatTagsList $post.tags) {
        If (!(Test-ValidFileNameCharacters $tag)) { Continue }
        If (!(Test-Path -LiteralPath "$TAGS_PATH\$tag")) {
            New-Item -ItemType Directory -Path "$TAGS_PATH\$tag" | Out-Null
            $NewTags.Add($tag) | Out-Null
        }
        $shortcut = Get-FileDestination $TAGS_PATH\$tag $post
        if (!(Test-Path "$shortcut.lnk")) {
            $target = Get-FileDestination $OUROBOROS_PATH\posts $post
            Set-Shortcut -Location "$shortcut.lnk" -Target $target
        }
    }
    return $NewTags.Count
}

function Get-OuroborosPath {
    return $OUROBOROS_PATH
}

function Get-ApiUrl {
param(
    [string]$Method,
    [hashtable]$Parameters
    )
    $EncodedParameters = @()
    foreach ($Parameter In $Parameters.GetEnumerator()) {
        $ParameterKey = [System.Web.HttpUtility]::UrlEncode($Parameter.Name)
        $ParameterValue = [System.Web.HttpUtility]::UrlEncode($Parameter.Value)
        $EncodedParameters += "$ParameterKey=$ParameterValue"
    }
    return "https://e621.net/$Method.json?" + ($EncodedParameters -join '&')
}

function Get-ApiData {
param(
    [string]$Method,
    [hashtable]$Parameters
    )
    $Response = Invoke-WebRequest -Uri $(Get-ApiUrl -Method $Method -Parameters $Parameters)
    $Result = $Response.Content | ConvertFrom-Json
    return $Result
}

function Get-PostDetails {
param(
    [string]$ID,
    [string]$MD5
    )
    $method = "posts"
    if ($ID) {
        $params = @{tags="id:$ID"}
    } elseif ($MD5) {
        $params = @{tags="md5:$MD5"}
    }
    (Get-ApiData $method $params).posts[0]
}

function Get-PostAndOpen {
param(
    [string]$ID,
    [string]$MD5
    )
    if ($ID) {
        $post = Get-PostDetails -ID $ID
    } elseif ($MD5) {
        $post = Get-PostDetails -MD5 $MD5
    }
    $path = [System.IO.Path]::GetTempPath() + '\' + $post.file.md5 + '.' + $post.file.ext
    Invoke-WebRequest -Uri $post.file.url -OutFile $path
    Invoke-Item $path
}

Function Get-FileDestination($TargetDir, $Post) {
    $Path = Join-Path $TargetDir "$($Post.id).$($Post.file.ext)"
    return $Path
}
function Get-TagShortcuts($Post) {
    $tags = $Post.tags -split ' '
    $tagLinks = @()
    foreach ($tag in $tags) {
        if (!(Test-ValidFileNameCharacters $tag)) {
            continue
        }
        $tagDir = Join-Path $TAGS_PATH $tag
        $tagLinks += $(Get-FileDestination $tagDir $Post) + '.lnk'
    }
    return $tagLinks
}

function Test-ValidFileNameCharacters ($string) {
    if ($string.Contains('\') -or
        $string.Contains('/') -or
        $string.Contains(':') -or
        $string.Contains('*') -or
        $string.Contains('?') -or
        $string.Contains('"') -or
        $string.Contains('<') -or
        $string.Contains('>') -or
        $string.Contains('|')) {
        return $false
        }
    return $true
}

function Get-Posts($Tags) {
    $AllPosts = @()
    $params = @{tags=$tags; limit=$MAX_LIMIT; page=1}
    do {
        $Posts = (Get-ApiData -Method "posts" -Parameters $params).posts
        $AllPosts += $Posts
        $before_id = $Posts[-1].id
        $params.page = "b$before_id"
    } while ($Posts.Count -eq $MAX_LIMIT)
    return $AllPosts
}

function Get-PostsFromSet($Tags) {
    $AllPosts = @()
    $params = @{tags="order:set_asc $Tags"; limit=$MAX_LIMIT; page=1}
    do {
        $Posts = (Get-ApiData -Method "posts" -Parameters $params).posts
        $AllPosts += $Posts
        $params.page += 1
    } while ($Posts.Count -eq $MAX_LIMIT)
    return $AllPosts
}

function Get-UnusedTags {
    $unused = @()
    dir $TAGS_PATH | foreach {
        if (0 -eq (gci $_.FullName).Count) {
            $unused += $_
        }
    }
    return $unused
}

function ConvertTo-FlatTagsList($TagsObject) {
    $AllTags = New-Object System.Collections.ArrayList
    $AllTags.AddRange($TagsObject.general) | Out-Null
    $AllTags.AddRange($TagsObject.species) | Out-Null
    $AllTags.AddRange($TagsObject.character) | Out-Null
    $AllTags.AddRange($TagsObject.copyright) | Out-Null
    $AllTags.AddRange($TagsObject.artist) | Out-Null
    $AllTags.AddRange($TagsObject.invalid) | Out-Null
    $AllTags.AddRange($TagsObject.lore) | Out-Null
    $AllTags.AddRange($TagsObject.meta) | Out-Null
    $AllTags
}
