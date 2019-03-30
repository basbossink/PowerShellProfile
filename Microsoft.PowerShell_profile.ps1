if (-not (Test-Path env:INSIDE_EMACS)) {
    # Load posh-git example profile
    Import-Module "C:\tools\poshgit\dahlbyk-posh-git-9bda399\src\posh-git"
    function global:prompt {
        $realLASTEXITCODE = $LASTEXITCODE

        Write-Host($pwd.ProviderPath) -nonewline

        Write-VcsStatus

        $global:LASTEXITCODE = $realLASTEXITCODE
        return "> "
    }

    # Start posh-git's SSH Agent.
    Set-Alias ssh-agent "C:\Program Files\git\usr\bin\ssh-agent.exe"
    Set-Alias ssh-add "C:\Program Files\git\usr\bin\ssh-add.exe"
    Start-SshAgent -Quiet
}

$HistoryFilePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) .ps_history
Register-EngineEvent PowerShell.Exiting -Action { Get-History | Export-Clixml $HistoryFilePath } | out-null
if (Test-path $HistoryFilePath) { Import-Clixml $HistoryFilePath | Add-History }

function Get-LastTag {
    git tag --sort=committerdate | Select-Object -Last 1
}

New-Alias -name lasttag -Value Get-LastTag

function Invoke-Emacs {
    C:\Users\bas\PortableApps\emacs\bin\emacsclientw.exe $args
}

function Invoke-NanoEmacs {
    C:\Users\bas\PortableApps\microemacs\ne32.exe $args
}
New-Alias -Name edit -Value Invoke-Emacs

function Invoke-Notepad2 {
    C:\Users\bas\PortableApps\PortableApps\Notepad2-modPortable\Notepad2-modPortable.exe $args
}
New-Alias -Name np2 -Value Invoke-Notepad2

function Show-PunchClock {
    ledger.exe -f ~/Dropbox/Personal/journals/timelog --date-format "%Y-%m-%d" --no-color $args
}

New-Alias -Name punch -Value Show-PunchClock

function Show-WeekPunchCard {
    Show-PunchClock reg -n --period 'this week' --daily
}

New-Alias -Name wpc -Value Show-WeekPunchCard

function Show-MonthTotal {
    Show-PunchClock reg -ns --period 'this month'
}

New-Alias -Name mpc -Value Show-MonthTotal

function Parse-LedgerTime([string] $line) {
    switch -Wildcard ($line) {
        "*m" { return [TimeSpan]::FromMinutes(($line -split 'm' |Select-Object -First 1))}
        "*h" { return [TimeSpan]::FromHours(($line -split 'h' |Select-Object -First 1))}
    }
}

function Format-TimeSpan([TimeSpan] $timeSpan) {
    $days = "{0:dd}" -f $timeSpan
    $hours = "{0:hh}" -f $timeSpan
    $mins = "{0:mm}" -f $timeSpan
    $timeSpanString = ""
    if ($timeSpan.TotalMinutes -lt 0) {
        $timeSpanString += "-"
    }
    if([Math]::Abs($timeSpan.TotalDays) -ge 1) {
        $timeSpanString += "$days days "
    }
    if (1 -le [Math]::Abs($timeSpan.TotalHours)) {
        $timeSpanString += "$hours hours "
    }
    $timeSpanString += "$mins minutes"
    return $timeSpanString
}

function Show-Overtime($end = ((Get-Date) + [TimeSpan]::FromDays(1))) {
    $currentYear = (Get-Date).Year
    $beginStr = "$currentYear-01-01"
    $endStr = "{0:yyyy-MM-dd}" -f  $end
    $billableFilter = "!(/Expense:Bas/)"
    $workDays = (Show-PunchClock -n --begin $beginStr --end $endStr --daily csv $billableFilter | measure-object).Count
    $hoursWorkedStr = ((Show-PunchClock -n --begin $beginStr --end $endStr bal $billableFilter) -split '\s+' | Select-Object -Skip 1 | Select-Object -First 1)
    $hoursWorkedTodayStr = ((Show-PunchClock -s -n --period "today" reg $billableFilter) -split '\s+' | Select-Object -Last 1)
    $worked = Parse-LedgerTime $hoursWorkedStr
    $workedToday = Parse-LedgerTime $hoursWorkedTodayStr
    $toWork = [TimeSpan]::FromHours(8*$workDays) - $worked
    $leaveTime = (Get-Date).Add($toWork)
    $toWorkTillEight = [TimeSpan]::FromHours(8.0).Subtract($workedToday)
    $leaveTimeEight = (Get-Date) + $toWorkTillEight
    if ((Get-Date).Hour -lt 13) {
        $leaveTime = $leaveTime.AddHours(0.5)
    }
    $toWorkString = Format-TimeSpan $toWork #"$([Math]::Floor($toWork.TotalHours)) hours $($toWork.Minutes) minutes"
    $toWorkTillEightString = Format-TimeSpan $toWorkTillEight
    $workedTodayString = Format-TimeSpan $workedToday
    "" |Select-Object -Property @{Name="No.Work days";Expression={$workDays}},
    @{Name="Worked"; Expression={$worked}},
    @{Name="Worked today"; Expression={$workedTodayString}},
    @{Name="Still to work today"; Expression={$toWorkString}},
    @{Name="Still to work today (8hrs)"; Expression={$toWorkTillEightString}},
    @{Name="Time to leave";Expression={"{0:yyyy-MM-dd HH:mm}" -f $leaveTime}},
    @{Name="Time to leave (8hrs today)";Expression={"{0:HH:mm}" -f $leaveTimeEight}} | Format-List
}

New-Alias -Name over -Value Show-Overtime

function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd.exe /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}


function Update-Branch($branchName) {
    git merge-base --is-ancestor origin/${branchName} ${branchName}
    if($?) {
        git fetch origin ${branchName}:${branchName}
    }
}

function Get-BranchExists($branchName) {
    git rev-parse --quiet --verify $branchName | Out-Null
    $?
}

function Invoke-FetchAll() {
    $paths = @("F:")
    $paths | ForEach-Object {
        Get-ChildItem -rec -force -Path $_ -Directory | Where-Object {
            $_.Name -eq ".git"
        } | ForEach-Object {
            $repoDir = $_.Parent.FullName
            Push-Location $repoDir
            Write-Host "Updating $($repoDir)."
            git fetch --all
            if(-not $?) {
                Write-host "There was a problem fetching the git repo in $($repoDir)." -ForegroundColor Red
            }
            $branchesToFf = @("master", "develop")
            $currentBranch = git rev-parse --abbrev-ref HEAD
            git merge --ff-only
            foreach($branch in $branchesToFf) {
                if($branch -ne $currentBranch -and (Get-BranchExists origin/$branch) -and (Get-BranchExists $branch)) {
                    Update-Branch $branch
                }
            }
            if(Test-Path build) {
                git submodule update
            }
            if (Test-Path *.sln) {
                dotnet restore
            }
            Pop-Location
        }
    }
}

New-Alias -Name ifa -Value Invoke-FetchAll

function ConvertTo-FileUrl($path) {
    $fi = Get-Item $path
    ("file:///" + $fi.FullName) -replace '\\','/'
}

New-Alias -Name cfu -Value ConvertTo-FileUrl

New-Alias -Name chrome -Value C:\Users\bas\PortableApps\PortableApps\GoogleChromePortable\GoogleChromePortable.exe

function Get-VlowGraphAsSvg($baseUrl) {
    $mermaidTxt = Join-Path $env:TEMP graph.txt
    invoke-webrequest -Uri "$($baseUrl)Graph/Mermaid/Full" -outfile $mermaidTxt
    mmdc.cmd -C F:\Vlow\Support.Web\src\Support.Web\wwwroot\CSS\divv-page.css -i $mermaidTxt
    $svgUri = ConvertTo-FileUrl "$($mermaidTxt).svg"
    chrome $svgUri
}

New-Alias -Name vlowg -Value Get-VlowGraphAsSvg

$env:BITBUCKET_USERNAME = "basbossinkdivverence"
$securePassword = Get-Content ~\.creds\bitbucket-app-pwd.txt | ConvertTo-SecureString
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "dummyUsername", $securePassword
$env:BITBUCKET_APP_PASSWORD = $credential.GetNetworkCredential().Password

function Update-RollingNugetPackages() {
    dotnet nuget locals -c http-cache
    Get-ChildItem -Recurse -Force -Include project.assets.json | Remove-Item
    dotnet restore
}

New-Alias -Name rollf -Value Update-RollingNugetPackages

function Get-PackageReference {
    rg -g *.csproj '<PackageReference\s+Include=\"([^\"]+)\"\s+Version=\"([^\"]+)\"\s*/>' -r '$1 : $2'
}

New-Alias -Name gpr -Value Get-PackageReference

function Find-ProjectAsset([string] $searchTerm) {
    rg -u -g project.assets.json $searchTerm
}

New-Alias -Name fpa -Value Find-ProjectAsset

function Replace-PackageVersion([string]$from, [string]$to) {
    fart -r *.csproj $from $to
}

New-Alias -Name rpv -Value Replace-PackageVersion

function Find-PackageVersion([string]$version) {
    fart -r *.csproj $version
}

New-Alias -Name fpv Find-PackageVersion

function New-PositivityRatioGraph() {
    $journalDir = Join-Path $env:HOME "Dropbox\Personal\journals\"
    Push-Location $journalDir
    & "C:\Program Files\R\R-3.5.3\bin\Rscript.exe" "positivity.r" 2>&1 | Out-Null
    Pop-Location
}

New-Alias -Name nprg New-PositivityRatioGraph

$env:ERL_AFLAGS="-kernel shell_history enabled"
$env:JIRA_API_TOKEN="N59n9EWNFUkjXhSy2tEV6580"

$emacs = Get-Process emacs -ErrorAction SilentlyContinue
if(!$emacs) {
    Start-Process -WorkingDirectory $env:USERPROFILE runemacs.exe
}

function Get-DivDevTimeSpent() {
    Show-PunchClock --period 'last week' bal DIVDEV |
      Where-Object { $_ -match "DIVDEV" } |
      ForEach-Object { $split=$_.Split(@(" "), [StringSplitOptions]::RemoveEmptyEntries); $work=$split[0].Trim();$issue=$split[1].Trim(); New-Object -type PSCustomObject -Property @{Issue=$issue; Worked=$work }}
}

function Get-PortListeners() {
    Get-NetTCPConnection -state Listen |
      Select-Object @{Name="Program";Expression={Get-process -Id $_.OwningProcess|Select-Object -ExpandProperty Name}},LocalPort|
      Sort-Object Program,LocalPort|
      Format-Table -AutoSize
}

if((Get-Service w32time).Status -ne "Running") {
	Start-Service w32time
}

function Set-TimeToNtp() {
	Start-Process -wait -windowstyle hidden -Verb RunAs W32tm -argumentlist "/resync", "/force"
}
