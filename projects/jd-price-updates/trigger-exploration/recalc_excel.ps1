# Recalculate the build_excel.py workbooks in Excel, save them with values, and report formula errors per sheet.
# Usage: powershell -File recalc_excel.ps1 <folder>
param([Parameter(Mandatory = $true)][string]$Folder)
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
    foreach ($f in Get-ChildItem $Folder -Filter *.xlsx) {
        $wb = $xl.Workbooks.Open($f.FullName)
        $xl.CalculateFull()
        foreach ($ws in $wb.Worksheets) {
            $n = 0
            try { $n = $ws.UsedRange.SpecialCells(-4123, 16).Count } catch { $n = 0 }   # xlCellTypeFormulas, xlErrors
            "{0} | {1}: {2} formula errors" -f $f.Name, $ws.Name, $n
        }
        $wb.Save(); $wb.Close($false)
    }
} finally {
    $xl.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
