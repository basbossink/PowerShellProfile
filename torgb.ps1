Add-Type -AssemblyName System.Drawing
select-string -Pattern 'fill: #([A-Fa-f0-9]+)' -path .\states.css | %{ 
    $hexRGB =$_.Matches[0].Groups[1].Value.ToLowerInvariant()
    $vals = @(0..2| %{$_*2}|%{[int]::Parse($hexRGB.Substring($_,2), [System.Globalization.NumberStyles]::HexNumber)})
    $color = [Drawing.Color]::FromArgb(255, $vals[0], $vals[1], $vals[2])
    $color
    }