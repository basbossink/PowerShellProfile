function Get-PackageVersions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,
                  Position=0)]
        [string]
        $packageId,

        [Parameter(Mandatory=$False)]
        [Switch]
        $IncludePreRelease=$False
    )

    Find-Package $packageId `
      -IncludePreRelease:$IncludePreRelease `
      -AllVersions `
      -ExactMatch `
      -Source "https://www.myget.org/F/divverence/api/v3/index.json" |
      Select-Object -ExpandProperty Versions |
      Select-Object -ExpandProperty OriginalVersion
}

New-Alias -Name gpvs Get-PackageVersions
