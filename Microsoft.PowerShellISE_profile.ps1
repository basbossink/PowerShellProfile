#Source http://blogs.technet.com/b/pstips/archive/2015/02/04/don-t-use-aliases-in-your-scripts.aspx

function Expand-Aliases {

       $ast = [System.Management.Automation.PSParser]::Tokenize(
        $psISE.CurrentFile.Editor.Text, [ref]$null)
       $commands = $ast | Where-Object {
        $_.Type -eq [System.Management.Automation.PSTokenType]::Command }
 
       $after = $psISE.CurrentFile.Editor.Text -split [System.Environment]::NewLine
       $aliases = @{}; Get-Alias | ForEach-Object {
           $aliases += @{$_.Name = $_.Definition}
       }
 
       $commands | Sort-Object StartLine, StartColumn -Descending |
        Where-Object { $aliases.Contains($_.Content) } | ForEach-Object {
               $def = $aliases["$($_.Content)"]
               $after[$_.StartLine-1] = ([string]$after[$_.StartLine-1]).Remove($_.StartColumn-1, $_.Length).Insert($_.StartColumn-1, $def)
       }
       $psISE.CurrentFile.Editor.Text = $after -join [System.Environment]::NewLine
}
 
[void]$PSIse.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Expand Aliases", {Expand-Aliases}, 'Control+Alt+A')