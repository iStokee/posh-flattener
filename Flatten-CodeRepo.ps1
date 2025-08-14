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

  # New features
  [switch]$Index = $true,
  [switch]$ApiSummary = $true,
  [switch]$FileMetrics = $true,
  [switch]$IndexJson = $true,


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

  [switch]$AsciiTree = $false,
  
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
  } catch {
    return $false
  } finally {
    try { if ($fs) { $fs.Dispose() } } catch {}
  }
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
    $tee  = if ($AsciiTree) { '+-- ' } else { [char]0x251C + [char]0x2500 + [char]0x2500 + ' ' }
    $ell  = if ($AsciiTree) { '\-- ' } else { [char]0x2514 + [char]0x2500 + [char]0x2500 + ' ' }
    $pipe = if ($AsciiTree) { '|   ' } else { [char]0x2502 + '   ' }
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


function Get-PsApiSurface {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Root
  )

  $Root = (Resolve-Path -Path $Root).Path

  # Helpers
  function Parse-FunctionSignature {
    param([System.Management.Automation.Language.FunctionDefinitionAst]$func)
    $params = @()
    foreach ($p in $func.Parameters) {
      $name = $p.Name.VariablePath.UserPath
      $isMandatory = $false
      foreach ($attr in $p.Attributes) {
        if ($attr.TypeName.GetReflectionType().Name -eq 'ParameterAttribute') {
          # NamedArguments may list Mandatory = $true
          foreach ($na in $attr.NamedArguments) {
            if ($na.ArgumentName -eq 'Mandatory' -and $na.Argument.Value -eq $true) { $isMandatory = $true }
          }
        }
      }
      $default = $null
      if ($p.DefaultValue) { $default = $p.DefaultValue.Extent.Text.Trim() }
      $suffix = if ($isMandatory) { '*' } elseif ($default) { "=$default" } else { '' }
      $params += ($name + $suffix)
    }
    $sig = if ($params.Count) { $func.Name + '(' + ($params -join ', ') + ')' } else { $func.Name + '()' }
    return $sig
  }

  # 1) Manifest (psd1) check
  $psd1 = Get-ChildItem -Path $Root -Filter *.psd1 -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($psd1) {
    try {
      $manifest = Import-PowerShellDataFile -Path $psd1.FullName -ErrorAction Stop
      if ($manifest.FunctionsToExport -and $manifest.FunctionsToExport.Count -gt 0) {
        # Try to locate corresponding files and parse their AST for params (best-effort)
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($fn in $manifest.FunctionsToExport) {
          # locate a file with that function name under likely module folders
          $candidates = Get-ChildItem -Path (Join-Path $Root '*') -Include "$fn.ps1","$fn.psm1","$fn.psd1" -Recurse -ErrorAction SilentlyContinue
          $astParsed = $false
          foreach ($c in $candidates) {
            try {
              $tokens = $null; $errors = $null
              $ast = [System.Management.Automation.Language.Parser]::ParseFile($c.FullName,[ref]$tokens,[ref]$errors)
              $func = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true)
              if ($func) { $out.Add((Parse-FunctionSignature -func $func)); $astParsed = $true; break }
            } catch { }
          }
          if (-not $astParsed) { $out.Add("$fn (signature unknown)") }
        }
        return $out
      }
    } catch { Write-Verbose "Manifest parse failed: $_" }
  }

  # 2) Look for *.psm1, prefer repo root src/ or top-level
  $psm1 = Get-ChildItem -Path $Root -Filter *.psm1 -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($psm1) {
    try {
      $text = Get-Content -Path $psm1.FullName -Raw -ErrorAction Stop
      # look for explicit Export-ModuleMember -Function
      if ($text -match 'Export-ModuleMember\s*-Function\s*\@?\(?') {
        # naive extract: find array/list in the call; then parse function names
        $matches = [regex]::Matches($text, 'Export-ModuleMember\s*-Function\s*(?:@\(|\(|\s+)\s*([^\)\n]+)\)', 'Singleline')
        $names = @()
        foreach ($m in $matches) {
          $list = $m.Groups[1].Value
          # strip @(...), quotes, commas
          $list = $list -replace '@\(|\)|`n|`r','' -replace '[\`"''\[\]]','' -replace ',',' ' 
          $names += ($list -split '\s+' | Where-Object { $_ -ne '' })
        }
        if ($names.Count -gt 0) {
          $out = [System.Collections.Generic.List[string]]::new()
          foreach ($fn in $names) {
            # try to parse its source like above (search for file, parse AST)
            $candidate = Get-ChildItem -Path $Root -Filter "$fn.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidate) {
              $tokens = $null; $errors = $null
              $ast = [System.Management.Automation.Language.Parser]::ParseFile($candidate.FullName,[ref]$tokens,[ref]$errors)
              $func = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true)
              if ($func) { $out.Add((Parse-FunctionSignature -func $func)); continue }
            }
            $out.Add("$fn (signature unknown)")
          }
          return $out
        }
      }

      # 2b) look for loader pattern dot-sourcing Public/
      if ($text -match "Get-ChildItem.*Public" -or $text -match "Join-Path.*'Public'") {
        $publicDir = Get-ChildItem -Path (Join-Path $psm1.Directory.FullName 'Public') -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
        if ($publicDir) {
          $out = [System.Collections.Generic.List[string]]::new()
          foreach ($f in $publicDir) {
            try {
              $tokens = $null; $errors = $null
              $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
              $func = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
              if ($func) { $out.Add((Parse-FunctionSignature -func $func)) } else { $out.Add( (Split-Path $f.Name -LeafBase) + ' (no function AST found)') }
            } catch { $out.Add( (Split-Path $f.Name -LeafBase) + ' (parse failed)') }
          }
          return $out
        }
      }
    } catch { Write-Verbose "psm1 parse failed: $_" }
  }

  # 3) If a Public/ dir exists anywhere under root, use it (common convention)
  $possiblePublic = Get-ChildItem -Path $Root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Public$' } | Select-Object -First 1
  if ($possiblePublic) {
    $out = [System.Collections.Generic.List[string]]::new()
    $ps = Get-ChildItem -Path $possiblePublic.FullName -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
    foreach ($f in $ps) {
      try {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
        $func = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        if ($func) { $out.Add((Parse-FunctionSignature -func $func)) } else { $out.Add( (Split-Path $f.Name -LeafBase) + ' (no function AST found)') }
      } catch { $out.Add( (Split-Path $f.Name -LeafBase) + ' (parse failed)') }
    }
    return $out
  }

  # 4) Fallback: scan all *.ps1 for advanced functions (CmdletBinding)
  $allPs1 = Get-ChildItem -Path $Root -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
  $candidates = [System.Collections.Generic.List[string]]::new()
  foreach ($f in $allPs1) {
    try {
      $tokens = $null; $errors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
      $funcs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
      foreach ($fn in $funcs) {
        # prefer functions that have [CmdletBinding] or Parameter attributes that look public-ish
        $hasCmdlet = $fn.Body.Extent.Text -match '\[CmdletBinding\]' -or ($fn.Parameters | Where-Object { $_.Attributes } )
        if ($hasCmdlet) { $candidates.Add((Parse-FunctionSignature -func $fn)) }
      }
    } catch { }
  }

  if ($candidates.Count -gt 0) { return $candidates }
  return @("No exported/public functions detected automatically. Consider adding a module manifest (*.psd1) or using Export-ModuleMember in your .psm1. As fallback, run the script with -ApiSummary:$false and inspect candidate functions manually.")
}


# ----- main -----
$root = Resolve-AbsolutePath $Path
# If -Include is provided and -MapScope was not explicitly set, default to 'Included'
if ($Include -and -not $PSBoundParameters.ContainsKey('MapScope')) { $MapScope = 'Included' }


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
  $mapWriter  = New-Object System.IO.StreamWriter($MapFile, $false, $utf8WithBom)

# Enumerate files (unchanged)
  $allFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force:$IncludeDotfiles -ErrorAction SilentlyContinue | Where-Object {
      -not (Is-ExcludedDir $_.DirectoryName $ExcludeDirs) -and
      -not (Is-ExcludedFile $_ $ExcludeFilePatterns) -and
      (Is-IncludedFile $_ $Include $root)
    } | Sort-Object FullName)

  # Build sets for Included scope
  $IncludedRelSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
  $IncludedDirSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
  $included = 0
  $skipped  = New-Object System.Collections.Generic.List[string]

  

  # Prepare temp flat content writer and tracking for index
  $tmpFlat = [System.IO.Path]::GetTempFileName()
  $contentWriter = New-Object System.IO.StreamWriter($tmpFlat, $false, $utf8WithBom)
  $absLine = 1
  $fileIndex = New-Object System.Collections.Generic.List[object]
  $fileCounter = 1
  $skipped  = New-Object System.Collections.Generic.List[string]
  $included = 0

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
    $relNorm = _Norm-Rel $rel
    [void]$IncludedRelSet.Add($relNorm)
    $relDir = Split-Path -Parent $relNorm
    while ($relDir) {
      [void]$IncludedDirSet.Add($relDir)
      $relDir = Split-Path -Parent $relDir
    }
    $hashObj = Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    $hash = if ($hashObj) { $hashObj.Hash } else { "n/a" }
    $lang = Get-FenceLang $f

    # Read file once for counting + writing
    $text = Get-Content -LiteralPath $f.FullName -Raw
    $lines = $text -split '\r?\n'
    if ($lines[-1] -eq '') { $fileLineCount = ($lines.Length - 1) } else { $fileLineCount = $lines.Length }

    $anchorTag = ('F{0}' -f $fileCounter.ToString('00'))
    $metricsPart = if ($FileMetrics) { "; lines: $fileLineCount" } else { "" }
    $contentWriter.WriteLine( ("# [{0}] ==== FILE: {1} (size: {2} bytes{3}; sha256: {4}) ====" -f $anchorTag, $rel, $f.Length.ToString('N0'), $metricsPart, $hash) )
    $start = $absLine
    $absLine++

    if ($CodeFences) { $contentWriter.WriteLine([string]::Concat('```', $lang)); $absLine++ }

    if ($LineNumbers) {
      $ln = 1
      foreach ($line in $lines) {
        $contentWriter.WriteLine(("{0,6} | {1}" -f $ln, $line))
        $ln++; $absLine++
      }
    } else {
      $contentWriter.WriteLine($text)
      $absLine += $fileLineCount
    }

    if ($CodeFences) { $contentWriter.WriteLine('```'); $absLine++ }

    $contentWriter.WriteLine( ("# ==== END FILE: {0}" -f $rel) ); $absLine++
    $contentWriter.WriteLine(); $absLine++

    $fileIndex.Add([pscustomobject]@{
      Num    = $fileCounter
      Path   = $rel
      Start  = $start
      End    = $absLine - 1
      Lines  = $fileLineCount
      Sha256 = $hash
      Lang   = $lang
    })

    $included++
    $fileCounter++
  }

  # Footer / summary (in content)
  $contentWriter.WriteLine("# Included files: $included")
  $contentWriter.WriteLine("# Skipped files:  $($skipped.Count)")
  if ($skipped.Count -gt 0) {
    $contentWriter.WriteLine("# Skipped detail:")
    foreach ($s in $skipped) { $contentWriter.WriteLine("#   - $s") }
  }

  Write-Tree -Root $root `
  -Writer $mapWriter `
  -ExDirs $ExcludeDirs `
  -IncludeHidden:$IncludeDotfiles `
  -MapScope $MapScope `
  -IncludedRelSet $IncludedRelSet `
  -IncludedDirSet $IncludedDirSet

  
  $contentWriter.Flush(); $contentWriter.Dispose()

  # Build header (banner, index, API surface)
  $headerSb = New-Object System.Text.StringBuilder
  [void]$headerSb.AppendLine("# Flattened repository for: $root")
  [void]$headerSb.AppendLine("# Generated: $((Get-Date).ToString('u'))")
  [void]$headerSb.AppendLine("# Max file size: {0:N0} bytes" -f $MaxFileBytes)
  [void]$headerSb.AppendLine("")

  $apiLines = @()
  if ($ApiSummary) {
    try { $apiLines = Get-PsApiSurface -Root $root } catch { $apiLines = @() }
  }

  # Pre-compute header line count to offset absolute ranges
  $headerBaseLines = 4  # 3 banner lines + 1 blank
  $indexLines = if ($Index) { 1 + $fileIndex.Count + 1 } else { 0 }  # header + entries + blank
  $apiLinesCount = if ($ApiSummary -and $apiLines.Count -gt 0) { 1 + $apiLines.Count + 1 } else { 0 }
  $headerLines = $headerBaseLines + $indexLines + $apiLinesCount

  $fileIndexAdj = foreach ($fi in $fileIndex) {
    [pscustomobject]@{
      Num=$fi.Num; Path=$fi.Path; Start=($fi.Start + $headerLines); End=($fi.End + $headerLines); Lines=$fi.Lines; Sha256=$fi.Sha256; Lang=$fi.Lang
    }
  }

  if ($Index) {
    [void]$headerSb.AppendLine("# QUICK INDEX (absolute line ranges)")
    $pathWidth = ($fileIndexAdj | Measure-Object -Property Path -Maximum).Maximum.Length
    if (-not $pathWidth) { $pathWidth = 25 }
    $pathWidth = [Math]::Max(25, [Math]::Min(100, $pathWidth))
    foreach ($fi in $fileIndexAdj) {
      $num = $fi.Num.ToString('00')
      $range = "{0}-{1}" -f $fi.Start, $fi.End
      $lineInfo = "({0})" -f $fi.Lines
      $shaShort = if ($fi.Sha256.Length -ge 8) { $fi.Sha256.Substring(0,8) } else { $fi.Sha256 }
      [void]$headerSb.AppendLine(("{0} {1}  {2,-12} {3,6}  [sha {4}]" -f $num, $fi.Path.PadRight($pathWidth,'.'), $range, $lineInfo, $shaShort))
    }
    [void]$headerSb.AppendLine("")
  }

  if ($ApiSummary -and $apiLines.Count -gt 0) {
    [void]$headerSb.AppendLine("# PUBLIC API SURFACE (PowerShell)")
    foreach ($l in $apiLines) { [void]$headerSb.AppendLine($l) }
    [void]$headerSb.AppendLine("")
  }

  # Stitch final output
  if ($Append) {
    Write-Log "Append mode detected: index and JSON sidecar are skipped."
    $flatWriter = New-Object System.IO.StreamWriter($OutputFile, $true, $utf8WithBom)
    $flatWriter.WriteLine("")
    $flatWriter.Write($headerSb.ToString())
    $flatWriter.Write((Get-Content -LiteralPath $tmpFlat -Raw))
    $flatWriter.Flush(); $flatWriter.Dispose(); $flatWriter = $null
  } else {
    $flatWriter = New-Object System.IO.StreamWriter($OutputFile, $false, $utf8WithBom)
    $flatWriter.Write($headerSb.ToString())
    $flatWriter.Write((Get-Content -LiteralPath $tmpFlat -Raw))
    $flatWriter.Flush(); $flatWriter.Dispose(); $flatWriter = $null
  }
  Remove-Item $tmpFlat -ErrorAction SilentlyContinue

  if ($IndexJson -and -not $Append) {
    $jsonPath = [System.IO.Path]::ChangeExtension($OutputFile, ".index.json")
    $json = $fileIndexAdj | ConvertTo-Json -Depth 5
    Set-Content -Path $jsonPath -Value $json -Encoding utf8
  }

  if (-not $Quiet) {
    Write-Host ""
    Write-Host "Done."
    Write-Host " - Flattened: $OutputFile"
    Write-Host " - Map:       $MapFile"
    if ($IndexJson -and -not $Append) { Write-Host " - Index:     $jsonPath" }
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
  try { if ($flatWriter) { $flatWriter.Dispose(); $flatWriter = $null } } catch {}
  try { if ($mapWriter)  { $mapWriter.Dispose();  $mapWriter  = $null } } catch {}
}