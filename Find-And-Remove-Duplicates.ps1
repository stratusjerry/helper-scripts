# Find-And-Remove-Duplicates.ps1
# Finds duplicate NES ROM zip files by:
#   1. MD5 hash of the .zip file itself (exact zip duplicates)
#   2. Content hash of files inside each .zip (same ROM, different zip wrapper)
#   3. Name pattern (same game title, different region/revision tags)
# Generates a removal script with inline comments and a report before deleting anything.

param(
    [string]$Path = $PSScriptRoot,
    [switch]$DryRun,       # Show what would be deleted without deleting
    [switch]$AutoDelete,   # Skip confirmation prompt and delete immediately
    [ValidateSet("MD5","SHA1")]
    [string]$ContentHashAlgorithm = "MD5"  # Algorithm used for ZIP content hashing
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$files = Get-ChildItem -Path $Path -Filter "*.zip" -File

Write-Host "`n=== NES Duplicate Finder ===" -ForegroundColor Cyan
Write-Host "Scanning: $Path"
Write-Host "Total files: $($files.Count)`n"

# ---------------------------------------------------------------------------
# 1. MD5 Hash duplicates (hash of the .zip container itself)
# ---------------------------------------------------------------------------
Write-Host "Computing MD5 hashes of zip files..." -ForegroundColor Yellow
$hashGroups = @{}
$i = 0
foreach ($file in $files) {
    $i++
    Write-Progress -Activity "Hashing files" -Status $file.Name -PercentComplete (($i / $files.Count) * 100)
    $hashObj = Get-FileHash -Path $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue
    if (-not $hashObj) { continue }
    $hash = $hashObj.Hash
    if (-not $hashGroups.ContainsKey($hash)) { $hashGroups[$hash] = @() }
    $hashGroups[$hash] += $file
}
Write-Progress -Activity "Hashing files" -Completed

$md5Duplicates = @{}
foreach ($entry in $hashGroups.GetEnumerator()) {
    if ($entry.Value.Count -gt 1) {
        $md5Duplicates[$entry.Key] = $entry.Value
    }
}

# ---------------------------------------------------------------------------
# 2. ZIP Content duplicates (same ROM inside, different zip wrapper)
#    Opens each zip, hashes every entry's byte stream, sorts and joins the
#    per-entry hashes into a stable fingerprint for the archive's contents.
# ---------------------------------------------------------------------------
function Get-ZipContentFingerprint {
    param([System.IO.FileInfo]$file, [string]$Algorithm)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
        $entryHashes = [System.Collections.Generic.List[string]]::new()
        foreach ($entry in $zip.Entries) {
            # Skip directory entries (zero-length name suffix or zero size)
            if ($entry.Length -eq 0 -and $entry.CompressedLength -eq 0) { continue }
            $stream = $entry.Open()
            $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
            $bytes  = $hasher.ComputeHash($stream)
            $stream.Dispose()
            $hasher.Dispose()
            $entryHashes.Add(([BitConverter]::ToString($bytes) -replace '-', ''))
        }
        $zip.Dispose()
        if ($entryHashes.Count -eq 0) { return $null }
        # Sort so entry order in the archive doesn't matter
        return ($entryHashes | Sort-Object) -join "|"
    } catch {
        return $null
    }
}

Write-Host "Computing ZIP content hashes ($ContentHashAlgorithm)..." -ForegroundColor Yellow
$contentHashGroups = @{}
$i = 0
foreach ($file in $files) {
    $i++
    Write-Progress -Activity "Hashing ZIP contents" -Status $file.Name -PercentComplete (($i / $files.Count) * 100)
    $fp = Get-ZipContentFingerprint -file $file -Algorithm $ContentHashAlgorithm
    if (-not $fp) { continue }
    if (-not $contentHashGroups.ContainsKey($fp)) { $contentHashGroups[$fp] = @() }
    $contentHashGroups[$fp] += $file
}
Write-Progress -Activity "Hashing ZIP contents" -Completed

$contentDuplicates = @{}
foreach ($entry in $contentHashGroups.GetEnumerator()) {
    if ($entry.Value.Count -gt 1) {
        $contentDuplicates[$entry.Key] = $entry.Value
    }
}

# ---------------------------------------------------------------------------
# 3. Name-pattern duplicates (same base title, different tags)
# Tags stripped: (Rev N), (Rev A-Z), (Beta), (Proto), region codes, [T-En ...], etc.
# Files with identical normalized names are grouped; shortest filename kept.
# ---------------------------------------------------------------------------
function Get-NormalizedName {
    param([string]$name)
    # Remove extension
    $n = [System.IO.Path]::GetFileNameWithoutExtension($name)
    # Remove revision/version tags
    $n = $n -replace '\s*\(Rev\s+\w+\)', ''
    # Remove prototype/beta/demo tags
    $n = $n -replace '\s*\((Beta|Proto|Demo|Sample|Promo|Alt|Alt \d+)\)', ''
    # Remove region tags
    $n = $n -replace '\s*\((USA|Europe|Japan|World|En|Fr|De|Es|It|Pt|Nl|Sv|No|Da|Fi|Ko|Zh|En,.*?)\)', ''
    # Remove translation tags like [T-En by Gorgyrip v1.0]
    $n = $n -replace '\s*\[.*?\]', ''
    # Normalize punctuation: remove periods that aren't decimal points
    $n = $n -replace '(?<!\d)\.(?!\d)', ''
    # Collapse multiple spaces
    $n = $n -replace '\s+', ' '
    return $n.Trim().ToLower()
}

$nameGroups = @{}
foreach ($file in $files) {
    $key = Get-NormalizedName $file.Name
    if (-not $nameGroups.ContainsKey($key)) { $nameGroups[$key] = @() }
    $nameGroups[$key] += $file
}

$nameDuplicates = @{}
foreach ($entry in $nameGroups.GetEnumerator()) {
    if ($entry.Value.Count -gt 1) {
        $nameDuplicates[$entry.Key] = $entry.Value
    }
}

# ---------------------------------------------------------------------------
# Build deletion sets, tracking reason per file
# ---------------------------------------------------------------------------
# $deleteMap: path -> @{ Reason; Keeper; Hash (optional) }
$deleteMap = @{}

function Pick-Keeper {
    param([System.IO.FileInfo[]]$group)
    $usa = $group | Where-Object { $_.Name -match '\(USA\)' }
    if ($usa) { $group = $usa }
    return ($group | Sort-Object { $_.Name.Length } | Select-Object -First 1)
}

$md5DeleteFiles     = [System.Collections.Generic.List[string]]::new()
$contentDeleteFiles = [System.Collections.Generic.List[string]]::new()
$nameDeleteFiles    = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $md5Duplicates.GetEnumerator()) {
    $group  = $entry.Value
    $keeper = Pick-Keeper $group
    foreach ($f in $group) {
        if ($f.FullName -ne $keeper.FullName -and -not $deleteMap.ContainsKey($f.FullName)) {
            $deleteMap[$f.FullName] = @{
                Reason = "MD5_HASH"
                Hash   = $entry.Key
                Keeper = $keeper.Name
                Group  = ($group | ForEach-Object { $_.Name }) -join " | "
            }
            $md5DeleteFiles.Add($f.FullName)
        }
    }
}

foreach ($entry in $contentDuplicates.GetEnumerator()) {
    $group  = $entry.Value
    $keeper = Pick-Keeper $group
    foreach ($f in $group) {
        if ($f.FullName -ne $keeper.FullName -and -not $deleteMap.ContainsKey($f.FullName)) {
            $deleteMap[$f.FullName] = @{
                Reason    = "ZIP_CONTENT"
                Hash      = $entry.Key
                Keeper    = $keeper.Name
                Group     = ($group | ForEach-Object { $_.Name }) -join " | "
                Algorithm = $ContentHashAlgorithm
            }
            $contentDeleteFiles.Add($f.FullName)
        }
    }
}

foreach ($entry in $nameDuplicates.GetEnumerator()) {
    $group  = $entry.Value
    $keeper = Pick-Keeper $group
    foreach ($f in $group) {
        if ($f.FullName -ne $keeper.FullName -and -not $deleteMap.ContainsKey($f.FullName)) {
            $deleteMap[$f.FullName] = @{
                Reason = "FILENAME"
                Key    = $entry.Key
                Keeper = $keeper.Name
                Group  = ($group | ForEach-Object { $_.Name }) -join " | "
            }
            $nameDeleteFiles.Add($f.FullName)
        }
    }
}

# ---------------------------------------------------------------------------
# Console report
# ---------------------------------------------------------------------------
Write-Host "`n--- MD5 Exact Duplicates (identical zip file content) ---" -ForegroundColor Cyan
if ($md5Duplicates.Count -eq 0) {
    Write-Host "  None found."
} else {
    foreach ($entry in $md5Duplicates.GetEnumerator()) {
        $group  = $entry.Value
        $keeper = Pick-Keeper $group
        Write-Host "`n  Hash: $($entry.Key)" -ForegroundColor DarkGray
        Write-Host "  KEEP: $($keeper.Name)" -ForegroundColor Green
        foreach ($f in $group) {
            if ($f.FullName -ne $keeper.FullName) {
                Write-Host "  DEL:  $($f.Name)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n--- ZIP Content Duplicates (same ROM inside, different zip wrapper) [$ContentHashAlgorithm] ---" -ForegroundColor Cyan
if ($contentDuplicates.Count -eq 0) {
    Write-Host "  None found."
} else {
    foreach ($entry in $contentDuplicates.GetEnumerator()) {
        $group  = $entry.Value
        $keeper = Pick-Keeper $group
        Write-Host "`n  Content fingerprint: $($entry.Key.Substring(0, [Math]::Min(64, $entry.Key.Length)))..." -ForegroundColor DarkGray
        Write-Host "  KEEP: $($keeper.Name)" -ForegroundColor Green
        foreach ($f in $group) {
            if ($f.FullName -ne $keeper.FullName) {
                Write-Host "  DEL:  $($f.Name)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n--- Filename-Pattern Duplicates (same title, different tags) ---" -ForegroundColor Cyan
if ($nameDuplicates.Count -eq 0) {
    Write-Host "  None found."
} else {
    foreach ($entry in $nameDuplicates.GetEnumerator()) {
        $group  = $entry.Value
        $keeper = Pick-Keeper $group
        Write-Host "`n  Normalized: '$($entry.Key)'" -ForegroundColor DarkCyan
        Write-Host "  KEEP: $($keeper.Name)" -ForegroundColor Green
        foreach ($f in $group) {
            if ($f.FullName -ne $keeper.FullName) {
                Write-Host "  DEL:  $($f.Name)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Hash matches to delete          : $($md5DeleteFiles.Count)" -ForegroundColor Yellow
Write-Host "  ZIP content matches to delete   : $($contentDeleteFiles.Count)" -ForegroundColor Yellow
Write-Host "  Filename matches to delete      : $($nameDeleteFiles.Count)" -ForegroundColor Yellow
Write-Host "  Total files to delete           : $($deleteMap.Count)" -ForegroundColor Yellow

if ($deleteMap.Count -eq 0) {
    Write-Host "Nothing to do. Exiting." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Write removal script with inline comments explaining each deletion
# ---------------------------------------------------------------------------
$removalScript = Join-Path $Path "Remove-Duplicates-Generated.ps1"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Auto-generated by Find-And-Remove-Duplicates.ps1")
$lines.Add("# Review carefully before running!")
$lines.Add("# Run with: powershell -ExecutionPolicy Bypass -File Remove-Duplicates-Generated.ps1")
$lines.Add("")

# --- Section 1: MD5 hash matches ---
$lines.Add("# ============================================================")
$lines.Add("# SECTION 1: MD5 HASH MATCHES ($($md5DeleteFiles.Count) files)")
$lines.Add("# These zip files have IDENTICAL content to another zip file.")
$lines.Add("# WARNING: Some may be legitimately different games with corrupt/mismatched ROMs.")
$lines.Add("# ============================================================")
$lines.Add("")
foreach ($path in ($md5DeleteFiles | Sort-Object)) {
    $meta   = $deleteMap[$path]
    $escaped = $path -replace "'", "''"
    $lines.Add("# Hash   : $($meta.Hash)")
    $lines.Add("# Group  : $($meta.Group)")
    $lines.Add("# Keeping: $($meta.Keeper)")
    $lines.Add("Remove-Item -LiteralPath '$escaped' -Verbose")
    $lines.Add("")
}

# --- Section 2: ZIP content hash matches ---
$lines.Add("# ============================================================")
$lines.Add("# SECTION 2: ZIP CONTENT MATCHES ($($contentDeleteFiles.Count) files) [$ContentHashAlgorithm]")
$lines.Add("# These zips contain files with identical $ContentHashAlgorithm hashes.")
$lines.Add("# The ROM data inside is the same even though the zip wrappers may differ.")
$lines.Add("# ============================================================")
$lines.Add("")
foreach ($path in ($contentDeleteFiles | Sort-Object)) {
    $meta    = $deleteMap[$path]
    $escaped = $path -replace "'", "''"
    $lines.Add("# $($meta.Algorithm) fingerprint: $($meta.Hash)")
    $lines.Add("# Group  : $($meta.Group)")
    $lines.Add("# Keeping: $($meta.Keeper)")
    $lines.Add("Remove-Item -LiteralPath '$escaped' -Verbose")
    $lines.Add("")
}

# --- Section 3: Filename pattern matches ---
$lines.Add("# ============================================================")
$lines.Add("# SECTION 3: FILENAME PATTERN MATCHES ($($nameDeleteFiles.Count) files)")
$lines.Add("# These files share the same base game title but differ in region/revision tags.")
$lines.Add("# ============================================================")
$lines.Add("")
foreach ($path in ($nameDeleteFiles | Sort-Object)) {
    $meta    = $deleteMap[$path]
    $escaped = $path -replace "'", "''"
    $lines.Add("# Normalized title: $($meta.Key)")
    $lines.Add("# Group  : $($meta.Group)")
    $lines.Add("# Keeping: $($meta.Keeper)")
    $lines.Add("Remove-Item -LiteralPath '$escaped' -Verbose")
    $lines.Add("")
}

$lines | Set-Content -Path $removalScript -Encoding UTF8
Write-Host "`nRemoval script written to: $removalScript" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[DRY RUN] No files deleted." -ForegroundColor Yellow
    exit 0
}

if (-not $AutoDelete) {
    $confirm = Read-Host "`nDelete $($deleteMap.Count) files now? (yes/no)"
    if ($confirm -notmatch '^y(es)?$') {
        Write-Host "Aborted. Run '$removalScript' manually when ready." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nDeleting..." -ForegroundColor Red
$deleted = 0
foreach ($path in $deleteMap.Keys) {
    Write-Host "   $path" -ForegroundColor Red
    #Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not (Test-Path $path)) { $deleted++ }
}
Write-Host "Deleted $deleted / $($deleteMap.Count) files." -ForegroundColor Green
