<# 
.SYNOPSIS
  Flattens a repository’s code files into a single text file, and writes a tree map of the folder structure.

.EXAMPLE
  .\Flatten-CodeRepo.ps1 -Path C:\src\my-repo

.EXAMPLE
  .\Flatten-CodeRepo.ps1 -Path . -OutputFile out\repo.flat.txt -MapFile out\repo.map.txt -CodeFences -LineNumbers

.EXAMPLE
  .\Flatten-CodeRepo.ps1 -Path . -Extensions ps1,psm1,cs,csproj,sln -IncludeDotfiles -MaxFileBytes 5242880

.EXAMPLE
  .\Flatten-CodeRepo.ps1 -Path . -Include src/*,README.md
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory, Position=0)]
  [string]$Path,

  [string]$OutputFile,
  [string]$MapFile,

  # Extensions without the dot; case-insensitive
  [string[]]$Extensions = @(
    'ps1','psm1','psd1','bat','cmd','sh','bash','zsh',
    'cs','csproj','sln','vb','fs',
    'c','h','cpp','hpp','cc','hh','ixx',
    'py','ipynb','rb','php','pl','lua','rs','go','java','kt','swift','m','mm',
    'js','jsx','ts','tsx','json','yml','yaml','toml','ini','cfg','conf','xml','xaml','props','targets',
    'html','htm','css','scss','less',
    'sql','cmake','mk','gradle','dockerfile','tf','tfvars',
    'md','markdown','rst','txt','csv','tsv','env','editorconfig','gitattributes','gitignore'
  ),

  # Directories to skip anywhere in the tree
  [string[]]$ExcludeDirs = @('.git','.github','node_modules','bin','obj','.vs','.vscode','dist','build','out','target','packages','.idea'),

  # File patterns to skip (glob against file name only)
  [string[]]$ExcludeFilePatterns = @('*.min.js','*.min.css','*.lock','package-lock.json','yarn.lock','pnpm-lock.yaml','*.dll','*.exe','*.pdb','*.jpg','*.jpeg','*.png','*.gif','*.webp','*.zip','*.7z','*.tar','*.gz','*.pdf','*.mp4','*.mov','*.wav','*.mp3','*.ico'),

  # Only include files matching these patterns (repo-relative).
  # Examples:
  #   -Include tests/*            # everything under tests/ (recursive)
  #   -Include src/ridctl.psm1    # single file
  #   -Include *.ps1,README.*     # glob by name or relpath
  [string[]]$Include,

  [switch]$IncludeDotfiles,
  [switch]$LineNumbers,
  [switch]$CodeFences,
  [switch]$Append,

  # Files larger than this are skipped (default 2 MB)
  [int]$MaxFileBytes = 2MB,

  [switch]$Quiet,

  [switch]$AsciiTree = $true,
  
  [ValidateSet('All','Included')]
  [string]$MapScope = 'All'

)

# ---- normalize list parameters (allow comma-separated single strings) ----
function _Split-IfSingleCommaString([string[]]$arr) {
  if ($arr.Count -eq 1 -and $arr[0] -match ',') {
    return @($arr[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  }
  return $arr
}


# Normalize a repo-relative path to '\' and remove leading .\ if present
function _Norm-Rel([string]$s) {
  if (-not $s) { return $s }
  $s = $s.Replace('/','\')
  if ($s.StartsWith('.\')) { $s = $s.Substring(2) }
  return $s
}

# Quick check: does a normalized relative path fall under a normalized folder prefix?
function _Rel-StartsWithDir([string]$rel, [string]$dir) {
  if (-not $dir) { return $false }
  # exact match (dir itself) OR any child of dir
  return ($rel.Equals($dir, [StringComparison]::OrdinalIgnoreCase)) -or
         ($rel.StartsWith("$dir\", [StringComparison]::OrdinalIgnoreCase))
}

$Extensions          = _Split-IfSingleCommaString $Extensions
$ExcludeDirs         = _Split-IfSingleCommaString $ExcludeDirs
$ExcludeFilePatterns = _Split-IfSingleCommaString $ExcludeFilePatterns
$Include             = _Split-IfSingleCommaString $Include

# If -Include was provided and -MapScope was NOT explicitly set,
# default to 'Included' instead of 'All'.
if ($Include -and $Include.Count -gt 0 -and -not $PSBoundParameters.ContainsKey('MapScope')) {
  $MapScope = 'Included'
}



Set-StrictMode -Version Latest

function Write-Log($msg) {
  if (-not $Quiet) { Write-Host $msg }
}

function Resolve-AbsolutePath([string]$p) {
  $rp = Resolve-Path -LiteralPath $p -ErrorAction Stop
  return $rp.ProviderPath
}

# Some files are "code" even without extensions
$KnownCodeFilenames = @(
  'Dockerfile','Makefile','CMakeLists.txt','.gitignore','.gitattributes','.editorconfig','.env','.env.example'
)

# Map file extension -> code fence language tag
$LangMap = @{
  ps1='powershell'; psm1='powershell'; psd1='powershell';
  sh='bash'; bash='bash'; zsh='zsh';
  cs='csharp'; csproj='xml'; sln='ini'; vb='vbnet'; fs='fsharp';
  c='c'; h='c'; cpp='cpp'; hpp='cpp'; cc='cpp'; hh='cpp'; ixx='cpp';
  py='python'; ipynb='json'; rb='ruby'; php='php'; pl='perl'; lua='lua'; rs='rust'; go='go'; java='java'; kt='kotlin'; swift='swift'; m='objectivec'; mm='objectivec';
  js='javascript'; jsx='jsx'; ts='typescript'; tsx='tsx'; json='json'; yml='yaml'; yaml='yaml'; toml='toml'; ini='ini'; cfg='ini'; conf='ini'; xml='xml'; xaml='xml'; props='xml'; targets='xml';
  html='html'; htm='html'; css='css'; scss='scss'; less='less';
  sql='sql'; cmake='cmake'; mk='makefile'; gradle='groovy'; dockerfile='dockerfile'; tf='hcl'; tfvars='hcl';
  md='markdown'; markdown='markdown'; rst='rst'; txt='text'; csv='csv'; tsv='csv'; env='ini'; editorconfig='ini'; gitattributes='ini'; gitignore='ini'
}

function Get-RelativePath([string]$Base, [string]$Target) {
  $basePath   = (Resolve-Path -LiteralPath $Base).ProviderPath.TrimEnd('\','/')
  $targetPath = (Resolve-Path -LiteralPath $Target).ProviderPath

  # If running on a runtime that has Path.GetRelativePath, use it
  try {
    $mi = [IO.Path].GetMethod('GetRelativePath', [Type[]]@([string],[string]))
    if ($mi) {
      return [IO.Path]::GetRelativePath($basePath, $targetPath)
    }
  } catch { }

  # Fallback for Windows PowerShell / Full Framework
  $sep = [IO.Path]::DirectorySeparatorChar
  $baseUri   = [Uri]("$basePath$sep")  # ensure trailing sep so MakeRelativeUri works for siblings
  $targetUri = [Uri]$targetPath
  $relUri    = $baseUri.MakeRelativeUri($targetUri)
  $rel       = [Uri]::UnescapeDataString($relUri.ToString())
  return $rel -replace '/', $sep
}


function Is-ExcludedDir([string]$FullName, [string[]]$ExDirs) {
  foreach ($d in $ExDirs) {
    $sep = [IO.Path]::DirectorySeparatorChar
    $patMid = [Regex]::Escape("$sep$d$sep")
    $patEnd = [Regex]::Escape("$sep$d$")
    $patStart = [Regex]::Escape("^$d$sep")
    if ($FullName -imatch $patMid -or $FullName -imatch $patEnd -or $FullName -imatch $patStart) { return $true }
  }
  return $false
}

function Is-ExcludedFile([IO.FileInfo]$f, [string[]]$Patterns) {
  foreach ($p in $Patterns) {
    if ($f.Name -like $p) { return $true }
  }
  return $false
}

function Is-IncludedFile([IO.FileInfo]$f, [string[]]$Patterns, [string]$Root) {
  # If no include list, everything is eligible
  if (-not $Patterns -or $Patterns.Count -eq 0) { return $true }

  $rel = _Norm-Rel (Get-RelativePath $Root $f.FullName)

  foreach ($p in $Patterns) {
    if (-not $p) { continue }
    $pat = _Norm-Rel $p

    # Treat patterns that are clearly directories as recursive:
    #   "tests", "tests/", "tests\"
    if ($pat -match '[\\/]\s*$' -or (Test-Path -LiteralPath (Join-Path $Root $pat) -PathType Container)) {
      $dir = $pat.TrimEnd('\','/')
      if (_Rel-StartsWithDir $rel $dir) { return $true }
      continue
    }

    # Treat "dir/*" as "everything under dir (recursive)"
    if ($pat -like '*\*' -and $pat.EndsWith('\*')) {
      $dir = $pat.Substring(0, $pat.Length - 2)  # remove '\*'
      if (_Rel-StartsWithDir $rel $dir) { return $true }
      continue
    }

    # Otherwise, do a filename/relpath wildcard match
    if ($rel -like $pat) { return $true }

    # Also check just the leaf against the pattern (so README.md works)
    if ($f.Name -like $pat) { return $true }
  }

  return $false
}


function Is-KnownCode([IO.FileInfo]$f, [string[]]$Exts, [string[]]$KnownNames) {
  if ($KnownNames -contains $f.Name) { return $true }
  $ext = ($f.Extension.TrimStart('.')).ToLowerInvariant()
  if ($ext) { return $Exts -contains $ext }
  return $false
}

function Is-LikelyText([IO.FileInfo]$f) {
  $fs = $null
  try {
    $fs = [IO.File]::Open($f.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $len = [Math]::Min(4096, [int]$fs.Length)
    $buf = New-Object byte[] $len
    [void]$fs.Read($buf, 0, $len)
    if ($buf -contains 0) { return $false }
    return $true
  } catch { return $false } finally { if ($fs) { $fs.Dispose() } }
}

function Get-FenceLang([IO.FileInfo]$f) {
  $ext = ($f.Extension.TrimStart('.')).ToLowerInvariant()
  if (-not $ext) {
    switch -Regex ($f.Name) {
      '^Dockerfile$' { return 'dockerfile' }
      '^Makefile$'   { return 'makefile' }
      '^CMakeLists\.txt$' { return 'cmake' }
      default { return 'text' }
    }
  }
  if ($LangMap.ContainsKey($ext) -and $LangMap[$ext]) { return $LangMap[$ext] }
  return 'text'
}

function Write-Tree(
  [string]$Root,
  [System.IO.StreamWriter]$Writer,
  [string[]]$ExDirs,
  [bool]$IncludeHidden,
  [string]$MapScope,                                # 'All' or 'Included'
  [System.Collections.Generic.HashSet[string]]$IncludedRelSet,  # files only
  [System.Collections.Generic.HashSet[string]]$IncludedDirSet   # directories containing included files
) {
    $tee  = if ($AsciiTree) { '+-- ' } else { '├── ' }
    $ell  = if ($AsciiTree) { '\-- ' } else { '└── ' }
    $pipe = if ($AsciiTree) { '|   ' } else { '|   ' }
    $sp   = '    '

    $rootDir = Get-Item -LiteralPath $Root -ErrorAction Stop
    $Writer.WriteLine("Repository map for: $($rootDir.FullName)")
    $Writer.WriteLine("Generated: $((Get-Date).ToString('u'))")
    $Writer.WriteLine()
    $Writer.WriteLine("./")   # print root once

    function Recurse([IO.DirectoryInfo]$dir, [string]$prefix, [string]$relDir) {
      # If mapping only included items, prune empty branches
      if ($MapScope -eq 'Included') {
        if ($relDir -and -not $IncludedDirSet.Contains($relDir)) { return }
      }

      $childrenDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -Force:$IncludeHidden -ErrorAction SilentlyContinue |
                      Where-Object { $_ -and ($ExDirs -notcontains $_.Name) } |
                      Sort-Object Name

      $childrenFiles = Get-ChildItem -LiteralPath $dir.FullName -File -Force:$IncludeHidden -ErrorAction SilentlyContinue |
                      Where-Object { $_ } |
                      Sort-Object Name

      $all = @()
      if ($childrenDirs)  { $all += $childrenDirs }
      if ($childrenFiles) { $all += $childrenFiles }

      for ($i = 0; $i -lt $all.Count; $i++) {
        $it = $all[$i]
        if ($null -eq $it) { continue }
        $isLast = ($i -eq $all.Count - 1)
        $branch = if ($isLast) { $ell } else { $tee }

        if ($it -is [IO.DirectoryInfo]) {
          $name = $it.Name
          $childRel = if ($relDir) { Join-Path $relDir $name } else { $name }

          # If Included mode and this dir has nothing included, skip printing it
          if ($MapScope -eq 'Included' -and -not $IncludedDirSet.Contains($childRel)) { continue }

          $Writer.WriteLine("$prefix$branch$name/")
          $nextPrefix = if ($isLast) { $prefix + $sp } else { $prefix + $pipe }
          Recurse -dir $it -prefix $nextPrefix -relDir $childRel
        } else {
          $relFile = _Norm-Rel (Get-RelativePath $Root $it.FullName)
          if ($MapScope -eq 'Included' -and -not $IncludedRelSet.Contains($relFile)) { continue }

          $Writer.WriteLine("$prefix$branch$($it.Name)")
        }
      }
    }

    # start recursion at repo root
    Recurse -dir $rootDir -prefix "" -relDir ""
    $Writer.WriteLine()
  }

# ----- main -----
$root = Resolve-AbsolutePath $Path

# Decide default paths lazily; only create a timestamped dir if we need defaults
if (-not $OutputFile -or -not $MapFile) {
  $repoName       = Split-Path -Leaf $root
  $stamp          = Get-Date -Format 'yyyyMMdd-HHmmss'
  $defaultOutDir  = Join-Path (Get-Location) "$repoName.flatten.$stamp"
}

if (-not $OutputFile) { $OutputFile = Join-Path $defaultOutDir "$repoName.flat.txt" }
if (-not $MapFile)    { $MapFile    = Join-Path $defaultOutDir "$repoName.map.txt" }

# Ensure parent directories exist only for the actual targets we’ll write
$parents = @(
  Split-Path -Parent $OutputFile
  Split-Path -Parent $MapFile
) | Where-Object { $_ } | Sort-Object -Unique

foreach ($p in $parents) {
  if (-not (Test-Path $p)) { [void](New-Item -ItemType Directory -Path $p -Force) }
}

Write-Log "Root:        $root"
Write-Log "Flat file:   $OutputFile"
Write-Log "Map file:    $MapFile"


# Create writers
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
$flatWriter = $null
$mapWriter  = $null

try {
  $flatWriter = New-Object System.IO.StreamWriter($OutputFile, [bool]$Append, $utf8WithBom)
  $mapWriter  = New-Object System.IO.StreamWriter($MapFile, $false, $utf8WithBom)


  # Header
  $flatWriter.WriteLine("# Flattened repository for: $root")
  $flatWriter.WriteLine("# Generated: $((Get-Date).ToString('u'))")
  $flatWriter.WriteLine("# Max file size: {0:N0} bytes" -f $MaxFileBytes)
  $flatWriter.WriteLine()


  # Enumerate files (unchanged)
  $allFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force:$IncludeDotfiles -ErrorAction SilentlyContinue | Where-Object {
      -not (Is-ExcludedDir $_.DirectoryName $ExcludeDirs) -and
      -not (Is-ExcludedFile $_ $ExcludeFilePatterns) -and
      (Is-IncludedFile $_ $Include $root)
    } | Sort-Object FullName)

  # Build sets for Included scope
  $IncludedRelSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
  $included = 0
  $skipped  = New-Object System.Collections.Generic.List[string]

  foreach ($f in $allFiles) {
    $rel = _Norm-Rel (Get-RelativePath $root $f.FullName)
    [void]$IncludedRelSet.Add($rel)
  }

  $IncludedDirSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
  # make sure root is considered present when using Included
  [void]$IncludedDirSet.Add('')
  foreach ($rel in $IncludedRelSet) {
    $dir = Split-Path -Path $rel -Parent
    while ($dir) {
      if (-not $IncludedDirSet.Contains($dir)) { [void]$IncludedDirSet.Add($dir) }
      $parent = Split-Path -Path $dir -Parent
      if ($parent -eq $dir) { break }
      $dir = $parent
    }
  }

  # Now write the map (AFTER sets are ready)
  Write-Tree -Root $root `
    -Writer $mapWriter `
    -ExDirs $ExcludeDirs `
    -IncludeHidden:$IncludeDotfiles `
    -MapScope $MapScope `
    -IncludedRelSet $IncludedRelSet `
    -IncludedDirSet $IncludedDirSet



  foreach ($f in $allFiles) {
    if ($f.Length -gt $MaxFileBytes) { 
      $skipped.Add("$((Get-RelativePath $root $f.FullName)) (too large: $($f.Length.ToString('N0')) bytes)") | Out-Null

      continue 
    }
    if (-not (Is-KnownCode $f $Extensions $KnownCodeFilenames)) {
      $skipped.Add("$((Get-RelativePath $root $f.FullName)) (not a code file by filter)") | Out-Null
      continue
    }
    if (-not (Is-LikelyText $f)) {
      $skipped.Add("$((Get-RelativePath $root $f.FullName)) (binary-like)") | Out-Null
      continue
    }

    $rel = Get-RelativePath $root $f.FullName
    $hashObj = Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    $hash = if ($hashObj) { $hashObj.Hash } else { "n/a" }

    $flatWriter.WriteLine("# ==== FILE: $rel (size: $($f.Length.ToString('N0')) bytes; sha256: $hash) ====")

    if ($CodeFences) {
      $lang = Get-FenceLang $f
      $flatWriter.WriteLine([string]::Concat('```', $lang))
    }

    if ($LineNumbers) {
      $ln = 1
      foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
        $flatWriter.WriteLine(("{0,6} | {1}" -f $ln, $line))
        $ln++
      }
    } else {
      $flatWriter.WriteLine((Get-Content -LiteralPath $f.FullName -Raw))
    }

    if ($CodeFences) { $flatWriter.WriteLine('```') }

    $flatWriter.WriteLine("# ==== END FILE: $rel")
    $flatWriter.WriteLine()
    $included++

  }

  # Footer / summary
  $flatWriter.WriteLine("# Included files: $included")
  $flatWriter.WriteLine("# Skipped files:  $($skipped.Count)")
  if ($skipped.Count -gt 0) {
    $flatWriter.WriteLine("# Skipped detail:")
    foreach ($s in $skipped) { $flatWriter.WriteLine("#   - $s") }
  }


  if (-not $Quiet) {
    Write-Host ""
    Write-Host "Done."
    Write-Host " - Flattened: $OutputFile"
    Write-Host " - Map:       $MapFile"
  }
}
catch {
  Write-Host "Error: $($_.Exception.Message)"
  if ($_.InvocationInfo) {
    Write-Host "At: $($_.InvocationInfo.PositionMessage)"
    Write-Host "In: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)"
  }
}

finally {
  if ($flatWriter) { $flatWriter.Flush(); $flatWriter.Dispose() }
  if ($mapWriter)  { $mapWriter.Flush();  $mapWriter.Dispose() }
}
