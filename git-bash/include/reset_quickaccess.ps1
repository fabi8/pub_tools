# This script pins all folders which are configured in the environmnet variables and 
# start with prefix 'quickaccess_' to the Quick access in Windows Explorer.

$objShell = New-Object -ComObject Shell.Application

$favItems = @()
foreach ($item in $objShell.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items()) {
    if ($item.IsFolder -eq $true) {
        $favItems += $item
    }
}

Get-ChildItem Env: | Where-Object { $_.Name -clike 'quickaccess_*' } | ForEach-Object {
    $folderPath = $_.Value
    if (Test-Path $folderPath -PathType Container) {
        $folder = $objShell.Namespace((Split-Path $folderPath -Parent)).ParseName((Split-Path $folderPath -Leaf))

        $alreadyInFav = $false
        foreach ($fav in $favItems) {
            if ($fav.Path -eq $folderPath) {
                $alreadyInFav = $true
                break
            }
        }
        if ($alreadyInFav) {
            Write-Host "$folderPath is already in Quick access."
            continue
        }

        if ($folder) {
            # $folder.InvokeVerb('Pin to Quick access') | Out-Null

            $verbs = $folder.Verbs()
            $pinned = $false
            foreach ($verb in $verbs) {
                if ($verb.Name.Replace('&','') -match 'Pin to Quick access') {
                    $verb.DoIt()
                    $pinned = $true
                    Write-Host "Pinned $folderPath to Quick access."
                    break
                }
            }
            if (-not $pinned) {
                Write-Host "$folderPath can not be pinned. Verb for that is not found."
            }
        } else {
            Write-Host "Could not access folder's COM object: $folderPath"
        }
    }
    else {
        Write-Host "Folder does not exists: $folderPath"
    }
}


