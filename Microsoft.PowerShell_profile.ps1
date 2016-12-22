
# Load posh-git example profile
#. 'C:\Users\user\Documents\WindowsPowerShell\Modules\posh-git\profile.example.ps1'
function Invoke-NanoEmacs {
    C:\Users\user\PortableApps\microemacs\ne32.exe $args
}
New-Alias -Name edit -Value Invoke-NanoEmacs

function Invoke-Notepad2 {
    C:\Users\user\PortableApps\PortableApps\Notepad2-modPortable\Notepad2-modPortable.exe $args
}
New-Alias -Name np2 -Value Invoke-Notepad2

function Show-PunchClock {
    C:\Users\user\PortableApps\ledger\ledger.exe -f ~/Dropbox/Personal/journals/timelog --date-format "%Y-%m-%d" --no-color $args
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

function Show-Overtime {
    $currentYear = (Get-Date).Year
    $beginStr = "$currentYear-01-01"
    $workDays = (Show-PunchClock -n --begin $beginStr --daily reg | measure-object).Count
    $hoursWorkedStr = ((Show-PunchClock -n --begin $beginStr bal) -split '\s+' | Select-Object -Skip 1 | Select-Object -First 1)
    switch -Wildcard ($hoursWorkedStr) {
        "*m" { $worked = [TimeSpan]::FromMinutes(($hoursWorkedStr -split 'm' |Select-Object -First 1))}
        "*h" { $worked = [TimeSpan]::FromHours(($hoursWorkedStr -split 'h' |Select-Object -First 1))}
    } 
    $overTime = $worked - [TimeSpan]::FromHours(8*$workDays)
    $hours = "{0:hh}" -f $overTime
    $mins = "{0:mm}" -f $overTime
    $overTimeString = ""
    if ($overTime.TotalMinutes -lt 0) {
        $overTimeString += "-"
    }
    if (1 -le [Math]::Abs($overTime.TotalHours)) {
        $overTimeString += "$hours hours "
    }
    $overTimeString += "$mins minutes"
    $leaveTime = (Get-Date).Subtract($overTime)
    if ((Get-Date).Hour -lt 13) {
        $leaveTime = $leaveTime.AddHours(0.5)
    }
    "" |Select-Object -Property @{Name="No.Work days";Expression={$workDays}}, @{Name="Worked"; Expression={$hoursWorked}}, @{Name="Over time";Expression={$overTimeString}}, @{Name="Time to leave";Expression={"{0:HH:mm}" -f $leaveTime}} | Format-List
}

New-Alias -Name over -Value Show-Overtime