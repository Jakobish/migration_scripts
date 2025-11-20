$files = @(
    "gui-migrate.ps1",
    "GuiHelpers.psm1",
    "GuiStateHelpers.psm1"
)

foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot $file
    Write-Host "Checking syntax of $file..."
    
    $err = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$err)
    
    if ($err) {
        Write-Host "Syntax errors found in $file`:" -ForegroundColor Red
        foreach ($e in $err) {
            Write-Host "  Line $($e.Extent.StartLineNumber): $($e.Message)"
        }
    }
    else {
        Write-Host "  OK" -ForegroundColor Green
    }
}
