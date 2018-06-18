if (-not (Test-Path env:INSIDE_EMACS)) {
    # Load posh-git example profile
    Import-Module "C:\Users\bas\Documents\WindowsPowerShell\Modules\posh-git"
    function global:prompt {
        $realLASTEXITCODE = $LASTEXITCODE

        Write-Host($pwd.ProviderPath) -nonewline

        Write-VcsStatus

        $global:LASTEXITCODE = $realLASTEXITCODE
        return "> "
    }

    # Start posh-git's SSH Agent.
    Set-Alias ssh-agent "$env:ProgramFiles\git\usr\bin\ssh-agent.exe"
    Set-Alias ssh-add "$env:ProgramFiles\git\usr\bin\ssh-add.exe"
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
    $hours = "{0:hh}" -f $timeSpan
    $mins = "{0:mm}" -f $timeSpan
    $timeSpanString = ""
    if ($timeSpan.TotalMinutes -lt 0) {
        $timeSpanString += "-"
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
    $workDays = (Show-PunchClock -n --begin $beginStr --end $endStr --daily reg | measure-object).Count
    $hoursWorkedStr = ((Show-PunchClock -n --begin $beginStr --end $endStr bal) -split '\s+' | Select-Object -Skip 1 | Select-Object -First 1)
    $hoursWorkedTodayStr = ((Show-PunchClock reg -s -n --period "today") -split '\s+' | Select-Object -Last 1)
    $worked = Parse-LedgerTime $hoursWorkedStr
    $workedToday = Parse-LedgerTime $hoursWorkedTodayStr
    $toWork = [TimeSpan]::FromHours(8*$workDays) - $worked
    $leaveTime = (Get-Date).Add($toWork)
    $toWorkTillEight = [TimeSpan]::FromHours(8.0).Subtract($workedToday)
    $leaveTimeEight = (Get-Date) + $toWorkTillEight
    if ((Get-Date).Hour -lt 13) {
        $leaveTime = $leaveTime.AddHours(0.5)
    }
    $toWorkString = Format-TimeSpan $toWork
    $toWorkTillEightString = Format-TimeSpan $toWorkTillEight
    $workedTodayString = Format-TimeSpan $workedToday
    "" |Select-Object -Property @{Name="No.Work days";Expression={$workDays}},
    @{Name="Worked"; Expression={$worked}},
    @{Name="Worked today"; Expression={$workedTodayString}},
    @{Name="Still to work today"; Expression={$toWorkString}},
    @{Name="Still to work today (8hrs)"; Expression={$toWorkTillEightString}},
    @{Name="Time to leave";Expression={"{0:HH:mm}" -f $leaveTime}},
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


function Invoke-FetchAll() {
    $paths = @("C:\Divv", "C:\DivverenceReleases")
    $paths | ForEach-Object {
        Get-ChildItem -rec -force -Path $_ -Directory | Where-Object {
            $_.Name -eq ".git"
        }  | ForEach-Object {
            $repoDir = $_.Parent.FullName
            Push-Location $repoDir
            git fetch --all --prune --prune-tags --verbose --progress
            if(-not $?) {
                Write-host "There was a problem fetching the git repo in $($repoDir)." -ForegroundColor Red
            }
            git merge --ff-only
            git submodule update
            dotnet restore
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
    mmdc.cmd -C C:\Divv\Vlow\Support.Web\src\Support.Web\wwwroot\CSS\divv-page.css -i $mermaidTxt
    $svgUri = ConvertTo-FileUrl "$($mermaidTxt).svg"
    chrome $svgUri
}

New-Alias -Name vlowg -Value Get-VlowGraphAsSvg
