<#
.SYNOPSIS
    Renames student photos from their "Govt Code 2" file name to their
    "Import Identifier" file name, using a CSV mapping, so the photos can be
    imported into the Student Information System (SIS).

.DESCRIPTION
    By default this script works inside its OWN folder: it looks for the mapping
    CSV there and renames the photos there. For every photo whose file name
    (ignoring the extension) matches a "Govt Code 2" value in the CSV, the photo
    is renamed to the matching "Import Identifier", keeping the original
    extension.

    A dated log file (rename_log_*.csv) is written recording every rename, so the
    operation can be audited or reversed if needed.

.PARAMETER CsvPath
    Optional. Path to the mapping CSV. If omitted, the script uses the single
    *.csv found in its own folder (ignoring any rename_log_*.csv).

.PARAMETER PhotoFolder
    Optional. Folder containing the photos. Defaults to the script's own folder.

.PARAMETER GovtColumn
    CSV column holding the CURRENT photo name. Default: "Govt Code 2".

.PARAMETER IdColumn
    CSV column holding the DESIRED photo name. Default: "Import Identifier".

.PARAMETER DryRun
    Preview mode. Shows what WOULD be renamed without changing any files.
#>

param(
    [string]$CsvPath,
    [string]$PhotoFolder,
    [string]$GovtColumn = 'Govt Code 2',
    [string]$IdColumn   = 'Import Identifier',
    [switch]$DryRun
)

# ---------------------------------------------------------------------------
# Default the photo folder to the script's own location
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($PhotoFolder)) {
    $PhotoFolder = $PSScriptRoot
}
if (-not (Test-Path -LiteralPath $PhotoFolder -PathType Container)) {
    Write-Error "Photo folder not found: $PhotoFolder"; exit 1
}

# ---------------------------------------------------------------------------
# Auto-detect the CSV if one wasn't supplied
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $candidates = @(Get-ChildItem -LiteralPath $PhotoFolder -File -Filter *.csv |
                    Where-Object { $_.Name -notlike 'rename_log_*.csv' })

    if ($candidates.Count -eq 0) {
        Write-Error "No mapping CSV found in '$PhotoFolder'. Put the CSV in this folder, or pass -CsvPath."
        exit 1
    }
    if ($candidates.Count -gt 1) {
        Write-Error ("Found more than one CSV in '$PhotoFolder': {0}. Remove the extras or pass -CsvPath to choose one." -f (($candidates.Name) -join ', '))
        exit 1
    }
    $CsvPath = $candidates[0].FullName
    Write-Host "Using CSV: $($candidates[0].Name)" -ForegroundColor Cyan
}
elseif (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"; exit 1
}

# ---------------------------------------------------------------------------
# Load the mapping from the CSV
# ---------------------------------------------------------------------------
$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -eq 0) {
    Write-Error "The CSV appears to be empty."; exit 1
}

$headers = $rows[0].PSObject.Properties.Name
foreach ($col in @($GovtColumn, $IdColumn)) {
    if ($headers -notcontains $col) {
        Write-Error "Column '$col' not found in CSV. Columns present: $($headers -join ', ')"
        exit 1
    }
}

# Build a lookup:  Govt Code 2  ->  Import Identifier
$map = @{}
foreach ($row in $rows) {
    $govt = ('' + $row.$GovtColumn).Trim()
    $id   = ('' + $row.$IdColumn).Trim()
    if ($govt -eq '' -or $id -eq '') { continue }
    if ($map.ContainsKey($govt)) {
        Write-Warning "Duplicate '$govt' in '$GovtColumn' - keeping first Import Identifier ('$($map[$govt])'), ignoring '$id'."
        continue
    }
    $map[$govt] = $id
}

Write-Host "Loaded $($map.Count) mapping(s) from CSV." -ForegroundColor Cyan
if ($DryRun) { Write-Host "DRY RUN - no files will actually be changed." -ForegroundColor Yellow }
Write-Host ""

# ---------------------------------------------------------------------------
# Process the photos (image files only, so the script/CSV/logs are ignored)
# ---------------------------------------------------------------------------
$imageExt = '.jpg','.jpeg','.png','.gif','.bmp','.tif','.tiff','.webp'

$renamed = 0; $skippedNoMatch = 0; $alreadyNamed = 0; $collisions = 0
$logEntries = @()

$photos = Get-ChildItem -LiteralPath $PhotoFolder -File |
          Where-Object { $imageExt -contains $_.Extension.ToLower() }

foreach ($photo in $photos) {
    $base = $photo.BaseName
    $ext  = $photo.Extension

    if (-not $map.ContainsKey($base)) { $skippedNoMatch++; continue }

    $newName = $map[$base] + $ext
    $newPath = Join-Path $photo.DirectoryName $newName

    if ($newName -eq $photo.Name) { $alreadyNamed++; continue }

    if (Test-Path -LiteralPath $newPath) {
        Write-Warning "SKIP  $($photo.Name)  ->  $newName   (target already exists)"
        $collisions++; continue
    }

    if ($DryRun) {
        Write-Host "WOULD RENAME  $($photo.Name)  ->  $newName"
    }
    else {
        Rename-Item -LiteralPath $photo.FullName -NewName $newName
        Write-Host "RENAMED  $($photo.Name)  ->  $newName" -ForegroundColor Green
    }

    $logEntries += [pscustomobject]@{
        OldName          = $photo.Name
        NewName          = $newName
        GovtCode2        = $base
        ImportIdentifier = $map[$base]
    }
    $renamed++
}

# ---------------------------------------------------------------------------
# Audit / undo log (only on a real run that changed something)
# ---------------------------------------------------------------------------
if (-not $DryRun -and $logEntries.Count -gt 0) {
    $stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $logPath = Join-Path $PhotoFolder "rename_log_$stamp.csv"
    $logEntries | Export-Csv -LiteralPath $logPath -NoTypeInformation
    Write-Host ""
    Write-Host "Audit log written to: $logPath" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$verb = if ($DryRun) { 'would be renamed' } else { 'renamed' }
Write-Host ""
Write-Host "==================== Summary ====================" -ForegroundColor Cyan
Write-Host ("Photos {0,-18}: {1}" -f $verb, $renamed)
Write-Host ("Already correctly named : {0}" -f $alreadyNamed)
Write-Host ("No matching CSV row     : {0}" -f $skippedNoMatch)
Write-Host ("Skipped (name clash)    : {0}" -f $collisions)
Write-Host "================================================" -ForegroundColor Cyan
