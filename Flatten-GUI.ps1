# Flatten-GUI.ps1
# Simple Windows Forms GUI wrapper around Flatten-CodeRepo.ps1
# Place this next to Flatten-CodeRepo.ps1 or use "Find Script..." to browse to it.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Embedded icon (Base64-encoded .ico) ---
$IconBase64 = @'
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
'@

function Set-FormIcon {
  param([System.Windows.Forms.Form]$Form)
  $ms = $null
  try {
    $bytes = [Convert]::FromBase64String($IconBase64)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $icon = New-Object System.Drawing.Icon($ms)
    $Form.Icon = $icon
  } catch {
    # ignore icon issues
  } finally {
    if ($ms) { $ms.Dispose() }
  }
}

function New-Label($text, [int]$x, [int]$y) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $text
  $l.AutoSize = $true
  $l.Location = New-Object System.Drawing.Point($x,$y)
  return $l
}

function New-Textbox([int]$x, [int]$y, [int]$w) {
  $t = New-Object System.Windows.Forms.TextBox
  $t.Location = New-Object System.Drawing.Point($x,$y)
  $t.Size = New-Object System.Drawing.Size($w, 24)
  $t.Anchor = 'Top,Left,Right'
  return $t
}

function New-Button($text, [int]$x, [int]$y, [int]$w=90) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text
  $b.Location = New-Object System.Drawing.Point($x,$y)
  $b.Size = New-Object System.Drawing.Size($w,28)
  $b.Anchor = 'Top,Right'
  return $b
}

function New-Checkbox($text, [int]$x, [int]$y, [bool]$checked=$false) {
  $c = New-Object System.Windows.Forms.CheckBox
  $c.Text = $text
  $c.Location = New-Object System.Drawing.Point($x,$y)
  $c.AutoSize = $true
  return $c
}

function New-Combo([int]$x, [int]$y, [int]$w, [string[]]$items) {
  $c = New-Object System.Windows.Forms.ComboBox
  $c.Location = New-Object System.Drawing.Point($x,$y)
  $c.Size = New-Object System.Drawing.Size($w,24)
  $c.DropDownStyle = 'DropDownList'
  $c.Anchor = 'Top,Right'
  [void]$c.Items.AddRange($items)
  return $c
}

function New-Num([int]$x,[int]$y,[int]$w,[int]$min,[int]$max,[int]$val) {
  $n = New-Object System.Windows.Forms.NumericUpDown
  $n.Location = New-Object System.Drawing.Point($x,$y)
  $n.Size = New-Object System.Drawing.Size($w,24)
  $n.Minimum = [decimal]$min
  $n.Maximum = [decimal]$max
  $n.Value   = [decimal]$val
  $n.ThousandsSeparator = $false
  $n.Anchor = 'Top,Right'
  return $n
}

# Load/save settings
$SettingsDir = Join-Path $env:APPDATA 'posh-flattener'
$SettingsPath = Join-Path $SettingsDir 'gui.settings.json'
if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir | Out-Null }

function Save-Settings {
  $o = [ordered]@{
    RepoPath = $txtRepo.Text
    OutputFile = $txtOut.Text
    MapFile = $txtMap.Text
    Include = $txtInclude.Text
    ExcludeDirs = $txtExDirs.Text
    ExcludeFilePatterns = $txtExFiles.Text
    Extensions = $txtExt.Text
    IncludeDotfiles = $chkDot.Checked
    CodeFences = $chkFences.Checked
    LineNumbers = $chkLines.Checked
    Append = $chkAppend.Checked
    Quiet = $chkQuiet.Checked
    AsciiTree = $chkAscii.Checked
    Index = $chkIndex.Checked
    ApiSummary = $chkApi.Checked
    FileMetrics = $chkMetrics.Checked
    IndexJson = $chkIndexJson.Checked
    MaxFileUnit = $cmbUnit.SelectedItem
    MapScope = $cmbScope.SelectedItem
    MaxFileBytes = [int]$numMax.Value
    ScriptPath = $txtScript.Text
  }
  $o | ConvertTo-Json | Set-Content -Path $SettingsPath -Encoding UTF8
}

function Load-Settings {
  if (Test-Path $SettingsPath) {
    try {
      $s = Get-Content -Raw -Path $SettingsPath | ConvertFrom-Json
      $txtRepo.Text = $s.RepoPath
      $txtOut.Text = $s.OutputFile
      $txtMap.Text = $s.MapFile
      $txtInclude.Text = $s.Include
      $txtExDirs.Text = $s.ExcludeDirs
      $txtExFiles.Text = $s.ExcludeFilePatterns
      $txtExt.Text = $s.Extensions
      $chkDot.Checked = [bool]$s.IncludeDotfiles
      $chkFences.Checked = [bool]$s.CodeFences
      $chkLines.Checked = [bool]$s.LineNumbers
      $chkAppend.Checked = [bool]$s.Append
      $chkQuiet.Checked = [bool]$s.Quiet
      $chkAscii.Checked = if ($null -ne $s.AsciiTree) { [bool]$s.AsciiTree } else { $true }
      $chkIndex.Checked = if ($null -ne $s.Index) { [bool]$s.Index } else { $true }
      $chkApi.Checked = if ($null -ne $s.ApiSummary) { [bool]$s.ApiSummary } else { $true }
      $chkMetrics.Checked = if ($null -ne $s.FileMetrics) { [bool]$s.FileMetrics } else { $true }
      $chkIndexJson.Checked = if ($null -ne $s.IndexJson) { [bool]$s.IndexJson } else { $true }
      if ($s.MapScope) { $cmbScope.SelectedItem = $s.MapScope }
      if ($s.MaxFileBytes) { $numMax.Value = [decimal][int]$s.MaxFileBytes }
      if ($s.MaxFileUnit) { $cmbUnit.SelectedItem = [string]$s.MaxFileUnit } else { $cmbUnit.SelectedItem = 'MB' }
      if ($s.ScriptPath) { $txtScript.Text = $s.ScriptPath }
    } catch {
      # ignore bad settings
    }
  }
}

function Get-RepoBaseName([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "repo" }
  try {
    if (Test-Path -LiteralPath $s) {
      $leaf = Split-Path -Leaf $s
      if ($leaf) { return ($leaf -replace '\.git$','') }
    }
  } catch {}
  try {
    $m = [regex]::Match($s, 'github\.com/[^/]+/([^/?#]+)')
    if ($m.Success) { return ($m.Groups[1].Value -replace '\.git$','') }
  } catch {}
  $parts = $s.TrimEnd('/','\').Split('/','\')
  if ($parts.Length -gt 0) {
    $name = $parts[$parts.Length-1] -replace '\.git$',''
    if ($name) { return $name }
  }
  return "repo"
}

function Suggest-Outputs {
  $name = Get-RepoBaseName $txtRepo.Text
  $base = Join-Path 'C:\temp' $name
  if ([string]::IsNullOrWhiteSpace($txtOut.Text)) { $txtOut.Text = ($base + '.flat.txt') }
  if ([string]::IsNullOrWhiteSpace($txtMap.Text)) { $txtMap.Text = ($base + '.map.txt') }
}


# Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "posh-flattener GUI"
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(920, 720)
$form.MinimumSize = New-Object System.Drawing.Size(900, 680)
$form.AutoScaleMode = 'Dpi'
Set-FormIcon -Form $form

# Controls
$marginLeft = 12
$marginRight = 12
$buttonW    = 120
$gutter     = 8

# We'll place and size in Update-Layout so margins are consistent.
# Create controls now (light initial geometry) ---------------------------------

# Row 1: Script + Find Script...
$lblScript = New-Label "Script:" 0 0
$txtScript = New-Textbox 0 0 100
$btnFindScript = New-Button "Find Script..." 0 0 $buttonW
$form.Controls.AddRange(@($lblScript,$txtScript,$btnFindScript))

# Row 2: Repo/URL + Browse...
$lblRepo = New-Label "Repo/URL:" 0 0
$txtRepo = New-Textbox 0 0 100
$btnBrowseRepo = New-Button "Browse..." 0 0 $buttonW
$form.Controls.AddRange(@($lblRepo,$txtRepo,$btnBrowseRepo))

# Row 3: Output + Save As...
$lblOut = New-Label "Output:" 0 0
$txtOut = New-Textbox 0 0 100
$btnBrowseOut = New-Button "Save As..." 0 0 $buttonW
$form.Controls.AddRange(@($lblOut,$txtOut,$btnBrowseOut))

# Row 4: Map + Save As...
$lblMap = New-Label "Map:" 0 0
$txtMap = New-Textbox 0 0 100
$btnBrowseMap = New-Button "Save As..." 0 0 $buttonW
$form.Controls.AddRange(@($lblMap,$txtMap,$btnBrowseMap))

# Row 5: basic toggles
$chkFences = New-Checkbox "CodeFences" 0 0
$chkLines  = New-Checkbox "LineNumbers" 0 0
$chkDot    = New-Checkbox "IncludeDotfiles" 0 0
$chkAppend = New-Checkbox "Append" 0 0
$chkQuiet  = New-Checkbox "Quiet" 0 0
$form.Controls.AddRange(@($chkFences,$chkLines,$chkDot,$chkAppend,$chkQuiet))

# Row 6: Include (full width)
$lblInclude = New-Label "Include:" 0 0
$txtInclude = New-Textbox 0 0 100
$form.Controls.AddRange(@($lblInclude,$txtInclude))

# Row 7: Exclude Dirs (full width)
$lblExDirs = New-Label "Exclude Dirs:" 0 0
$txtExDirs = New-Textbox 0 0 100
$form.Controls.AddRange(@($lblExDirs,$txtExDirs))

# Row 8: Exclude Files (full width)
$lblExFiles = New-Label "Exclude Files:" 0 0
$txtExFiles = New-Textbox 0 0 100
$form.Controls.AddRange(@($lblExFiles,$txtExFiles))

# Row 9: Extensions | MapScope | MaxFileBytes
$lblExt = New-Label "Extensions:" 0 0
$txtExt = New-Textbox 0 0 300
$lblScope = New-Label "MapScope:" 0 0
$cmbScope = New-Combo 0 0 130 @('','All','Included')
$lblMax = New-Label "MaxFileBytes:" 0 0
$numMax = New-Num 0 0 120 0 104857600 2097152
$cmbUnit = New-Combo 0 0 70 @('B','KB','MB','GB')
$form.Controls.AddRange(@($lblExt,$txtExt,$lblScope,$cmbScope,$lblMax,$numMax,$cmbUnit))

# Row 10: defaults
$chkAscii = New-Checkbox "ASCII Tree" 0 0 $true
$chkIndex = New-Checkbox "Index" 0 0 $true
$chkApi   = New-Checkbox "ApiSummary" 0 0 $true
$chkMetrics = New-Checkbox "FileMetrics" 0 0 $true
$chkIndexJson = New-Checkbox "IndexJson" 0 0 $true
$form.Controls.AddRange(@($chkAscii,$chkIndex,$chkApi,$chkMetrics,$chkIndexJson))

# Row 11: buttons
$btnRun   = New-Button "Run Flatten" 0 0 140
$btnCancel= New-Button "Cancel" 0 0 100
$btnSave  = New-Button "Save Settings" 0 0 130
$btnLoad  = New-Button "Load Settings" 0 0 130
$btnReset = New-Button "Reset" 0 0 100
$form.Controls.AddRange(@($btnRun,$btnCancel,$btnSave,$btnLoad,$btnReset))

# Row 12: log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.WordWrap = $false
$form.Controls.Add($txtLog)

# Layout function ---------------------------------------------------------------
function Update-Layout {
  # Base metrics
  [int]$y = 15
  [int]$lineH = 28
  [int]$editLeft = 80

  [int]$clientW = [int]$form.ClientSize.Width
  [int]$clientH = [int]$form.ClientSize.Height

  # Right column buttons
  [int]$rightBtnX = [int]($clientW - $marginRight - $buttonW)

  # Common widths
  [int]$rowEditW_WithButton = [int]($rightBtnX - $gutter - $editLeft)
  [int]$rowEditW_Full       = [int]($clientW - $marginRight - $editLeft)

  # Row 1
  $lblScript.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtScript.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtScript.Size     = New-Object System.Drawing.Size($rowEditW_WithButton,24)
  $btnFindScript.Location = New-Object System.Drawing.Point($rightBtnX,($y-2))
  $y += 36

  # Row 2
  $lblRepo.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtRepo.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtRepo.Size     = New-Object System.Drawing.Size($rowEditW_WithButton,24)
  $btnBrowseRepo.Location = New-Object System.Drawing.Point($rightBtnX,($y-2))
  $y += 36

  # Row 3
  $lblOut.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtOut.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtOut.Size     = New-Object System.Drawing.Size($rowEditW_WithButton,24)
  $btnBrowseOut.Location = New-Object System.Drawing.Point($rightBtnX,($y-2))
  $y += 36

  # Row 4
  $lblMap.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtMap.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtMap.Size     = New-Object System.Drawing.Size($rowEditW_WithButton,24)
  $btnBrowseMap.Location = New-Object System.Drawing.Point($rightBtnX,($y-2))
  $y += 40

  # Row 5 toggles
  [int]$x = $editLeft
  foreach ($cb in @($chkFences,$chkLines,$chkDot,$chkAppend,$chkQuiet)) {
    $cb.Location = New-Object System.Drawing.Point($x,$y)
    $x += ($cb.PreferredSize.Width + 20)
  }
  $y += 32

  # Row 6 Include
  $lblInclude.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtInclude.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtInclude.Size     = New-Object System.Drawing.Size($rowEditW_Full,24)
  $y += 32

  # Row 7 Exclude Dirs
  $lblExDirs.Location  = New-Object System.Drawing.Point($marginLeft,$y)
  $txtExDirs.Location  = New-Object System.Drawing.Point($editLeft,$y)
  $txtExDirs.Size      = New-Object System.Drawing.Size($rowEditW_Full,24)
  $y += 32

  # Row 8 Exclude Files
  $lblExFiles.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtExFiles.Location = New-Object System.Drawing.Point($editLeft,$y)
  $txtExFiles.Size     = New-Object System.Drawing.Size($rowEditW_Full,24)
  $y += 32

  # Row 9 Extensions | MapScope | MaxFileBytes
  [int]$numW    = 120
  [int]$comboW  = 140
  [int]$gap     = 10

  [int]$numX    = [int]($clientW - $marginRight - $numW)
  [int]$lblMaxW = [int]$lblMax.PreferredSize.Width
  [int]$lblScopeW = [int]$lblScope.PreferredSize.Width
  [int]$lblMaxX = [int]($numX - ($lblMaxW + 6))
  [int]$comboX  = [int]($lblMaxX - $gap - $comboW)
  [int]$lblScopeX = [int]($comboX - ($lblScopeW + 6))

  $lblExt.Location  = New-Object System.Drawing.Point($marginLeft,$y)
  $txtExt.Location  = New-Object System.Drawing.Point(($editLeft + 20),$y)
  [int]$extRightStop= [int]($lblScopeX - 12)
  [int]$extWidth    = [int]($extRightStop - ($editLeft + 20))
  if ($extWidth -lt 200) { $extWidth = 200 }
  $txtExt.Size      = New-Object System.Drawing.Size($extWidth,24)

  $lblScope.Location = New-Object System.Drawing.Point($lblScopeX,($y+3))
  $cmbScope.Location = New-Object System.Drawing.Point($comboX,($y-2))
  $cmbScope.Size     = New-Object System.Drawing.Size($comboW,24)

  $lblMax.Location   = New-Object System.Drawing.Point($lblMaxX,($y+3))
  $numMax.Location   = New-Object System.Drawing.Point($numX,($y-4))
  $numMax.Size       = New-Object System.Drawing.Size($numW,24)

  [int]$unitX = [int]($numX + $numW + 6)
  $cmbUnit.Location = New-Object System.Drawing.Point($unitX,($y-2))
  $cmbUnit.Size     = New-Object System.Drawing.Size(60,24)

  $y += 38

  # Row 10 defaults/toggles
  [int]$x = $editLeft
  foreach ($cb in @($chkAscii,$chkIndex,$chkApi,$chkMetrics,$chkIndexJson)) {
    $cb.Location = New-Object System.Drawing.Point($x,$y)
    $x += ($cb.PreferredSize.Width + 20)
  }
  $y += 44

  # Row 11 buttons
  $btnRun.Location    = New-Object System.Drawing.Point($editLeft,$y)
  $btnCancel.Location = New-Object System.Drawing.Point(($editLeft + 150),$y)
  $btnSave.Location   = New-Object System.Drawing.Point(($editLeft + 260),$y)
  $btnLoad.Location   = New-Object System.Drawing.Point(($editLeft + 400),$y)
  $btnReset.Location  = New-Object System.Drawing.Point(($editLeft + 540),$y)
  $y += 48

  # Row 12 log fills the rest
  $txtLog.Location = New-Object System.Drawing.Point($marginLeft,$y)
  $txtLog.Size     = New-Object System.Drawing.Size(($clientW - $marginRight - $marginLeft), ($clientH - $y - 16))
}

# Run initial layout and keep it responsive on resize
$form.add_Resize({ Update-Layout })

# First pass
Update-Layout

# Try auto-detect script path

$defaultScript = Join-Path $PSScriptRoot 'Flatten-CodeRepo.ps1'
if (Test-Path $defaultScript) { $txtScript.Text = $defaultScript }

# Dialog helpers
$folderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
$saveDlg = New-Object System.Windows.Forms.SaveFileDialog
$saveDlg.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
$saveDlg.AddExtension = $true
$saveDlg.DefaultExt = "txt"

$openScriptDlg = New-Object System.Windows.Forms.OpenFileDialog
$openScriptDlg.Filter = "PowerShell (*.ps1)|*.ps1|All files (*.*)|*.*"

# State
$script:Job = $null
$script:LastCount = 0

function Append-Log([string]$msg) {
  if (-not $msg) { return }
  $txtLog.AppendText(($msg -replace "`r?`n","`r`n") + "`r`n")
  $txtLog.SelectionStart = $txtLog.Text.Length
  $txtLog.ScrollToCaret()
}

# Timer to poll job output
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.add_Tick({
  if ($null -eq $script:Job) { return }
  try {
    $data = Receive-Job -Job $script:Job -Keep -ErrorAction SilentlyContinue
    if ($data) {
      $arr = @($data)
      $count = $arr.Count
      if ($count -gt $script:LastCount) {
        $new = $arr[$script:LastCount..($count-1)]
        $new | ForEach-Object { Append-Log ([string]$_) }
        $script:LastCount = $count
      }
    }
    if ($script:Job.State -in 'Completed','Failed','Stopped') {
      $timer.Stop()
      if ($script:Job.State -eq 'Completed') {
        Append-Log "*** Done."
      } elseif ($script:Job.State -eq 'Stopped') {
        Append-Log "*** Cancelled."
      } else {
        Append-Log "*** Failed."
      }
      Remove-Job -Job $script:Job -Force -ErrorAction SilentlyContinue | Out-Null
      $script:Job = $null
      $btnRun.Enabled = $true
      $btnCancel.Enabled = $false
      $form.Cursor = 'Default'
      [System.Windows.Forms.Application]::UseWaitCursor = $false
      Save-Settings
    }
  } catch {
    # ignore polling errors
  }
})

function Build-ArgList {
  $argsList = @()
  if (-not [string]::IsNullOrWhiteSpace($txtRepo.Text)) {
    $argsList += '-Path'; $argsList += $txtRepo.Text
  }

  if ($txtOut.Text) { $argsList += '-OutputFile'; $argsList += $txtOut.Text }
  if ($txtMap.Text) { $argsList += '-MapFile'; $argsList += $txtMap.Text }

  if ($txtExt.Text) { $argsList += '-Extensions'; $argsList += ($txtExt.Text -split '\s*,\s*') }
  if ($txtExDirs.Text) { $argsList += '-ExcludeDirs'; $argsList += ($txtExDirs.Text -split '\s*,\s*') }
  if ($txtExFiles.Text) { $argsList += '-ExcludeFilePatterns'; $argsList += ($txtExFiles.Text -split '\s*,\s*') }
  if ($txtInclude.Text) { $argsList += '-Include'; $argsList += ($txtInclude.Text -split '\s*,\s*') }

  if ($chkDot.Checked)    { $argsList += '-IncludeDotfiles' }
  if ($chkFences.Checked) { $argsList += '-CodeFences' }
  if ($chkLines.Checked)  { $argsList += '-LineNumbers' }
  if ($chkAppend.Checked) { $argsList += '-Append' }
  if ($chkQuiet.Checked)  { $argsList += '-Quiet' }

  # AsciiTree default is true; only pass when user turned it off
  if (-not $chkAscii.Checked) { $argsList += '-AsciiTree:$false' }

  # Defaults that are ON; pass -$false if user unchecked them
  if (-not $chkIndex.Checked)     { $argsList += '-Index:$false' }
  if (-not $chkApi.Checked)       { $argsList += '-ApiSummary:$false' }
  if (-not $chkMetrics.Checked)   { $argsList += '-FileMetrics:$false' }
  if (-not $chkIndexJson.Checked) { $argsList += '-IndexJson:$false' }

  if ($cmbScope.SelectedItem) { $argsList += '-MapScope'; $argsList += $cmbScope.SelectedItem }
  # Convert MaxFileBytes: numeric + unit -> bytes
  $unit = if ($cmbUnit.SelectedItem) { [string]$cmbUnit.SelectedItem } else { 'MB' }
  switch ($unit) { 'GB' { $factor = 1GB } 'MB' { $factor = 1MB } 'KB' { $factor = 1KB } Default { $factor = 1 } }
  if ($numMax.Value -gt 0) {
    [long]$bytes = [long]([decimal]$numMax.Value * [decimal]$factor)
    $argsList += '-MaxFileBytes'; $argsList += ([string]$bytes)
  }

  return ,$argsList
}

# Events
$btnBrowseRepo.Add_Click({
  if ($folderDlg.ShowDialog() -eq 'OK') {
    $txtRepo.Text = $folderDlg.SelectedPath
  }
})

$btnBrowseOut.Add_Click({
  $saveDlg.FileName = "repo.flat.txt"
  if ($saveDlg.ShowDialog() -eq 'OK') {
    $txtOut.Text = $saveDlg.FileName
  }
})

$btnBrowseMap.Add_Click({
  $saveDlg.FileName = "repo.map.txt"
  if ($saveDlg.ShowDialog() -eq 'OK') {
    $txtMap.Text = $saveDlg.FileName
  }
})

$txtRepo.add_TextChanged({ Suggest-Outputs })

$btnFindScript.Add_Click({
  if ($openScriptDlg.ShowDialog() -eq 'OK') {
    $txtScript.Text = $openScriptDlg.FileName
  }
})

$btnSave.Add_Click({ Save-Settings; Append-Log "*** Settings saved." })
$btnLoad.Add_Click({ Load-Settings; Append-Log "*** Settings loaded." })

$btnReset.Add_Click({
  $txtInclude.Text = ""
  $txtExDirs.Text  = ".git,.github,node_modules,bin,obj"
  $txtExFiles.Text = "*.min.js,*.min.css,*.lock,*.dll,*.png,*.jpg,*.jpeg,*.gif,*.bmp,*.webp,*.zip,*.7z,*.rar"
  $txtExt.Text = ""
  $chkDot.Checked = $false
  $chkFences.Checked = $false
  $chkLines.Checked = $false
  $chkAppend.Checked = $false
  $chkQuiet.Checked = $false
  $chkAscii.Checked = $true
  $chkIndex.Checked = $true
  $chkApi.Checked = $true
  $chkMetrics.Checked = $true
  $chkIndexJson.Checked = $true
  $cmbScope.SelectedItem = ''
  $numMax.Value = 2
  $cmbUnit.SelectedItem = 'MB'
  Append-Log "*** Reset to sensible defaults."
})

$btnCancel.Enabled = $false
$form.AcceptButton = $btnRun

$btnRun.Add_Click({
  $txtLog.Clear()

  $scriptPath = $txtScript.Text
  if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
    [void][System.Windows.Forms.MessageBox]::Show("Please set a valid path to Flatten-CodeRepo.ps1","Script not found","OK","Error")
    return
  }
  if (-not $txtRepo.Text) {
    [void][System.Windows.Forms.MessageBox]::Show("Please choose a Repo folder or paste a GitHub URL.","Missing input","OK","Error")
    return
  }

  $argsList = Build-ArgList

  # Ensure output/map directories exist if specified
  foreach ($p in @($txtOut.Text,$txtMap.Text)) {
    if ($p) {
      try { $dir = Split-Path -Parent $p; if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null } } catch {}
    }
  }
  Append-Log ("Running: `"& {0} {1}`"" -f $scriptPath, (($argsList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '))

  $btnRun.Enabled = $false
  $btnCancel.Enabled = $true
  [System.Windows.Forms.Application]::UseWaitCursor = $true
  $form.Cursor = 'WaitCursor'
  $script:LastCount = 0

  # Run the job; merge all streams to output so the log captures everything
  $script:Job = Start-Job -ScriptBlock {
    param($p,$a)
    try {
      & $p @a *>&1
    } catch {
      $_ | Out-String
    }
  } -ArgumentList @($scriptPath, $argsList)

  $timer.Start()
})

$btnCancel.Add_Click({
  if ($script:Job) {
    try { Stop-Job -Job $script:Job -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
  }
})

$form.add_FormClosing({
  if ($script:Job -and $script:Job.State -in 'Running','NotStarted') {
    $null = [System.Windows.Forms.MessageBox]::Show("A job is still running. Stop it before closing (or click Cancel).","Job running")
    $_.Cancel = $true
    return
  }
  Save-Settings
})

# Seed some friendly defaults if first run
if (-not (Test-Path $SettingsPath)) {
  $txtExDirs.Text = ".git,.github,node_modules,bin,obj"
  $txtExFiles.Text = "*.min.js,*.min.css,*.lock,*.dll,*.png,*.jpg,*.jpeg,*.gif,*.bmp,*.webp,*.zip,*.7z,*.rar"
}

Load-Settings
[void]$form.ShowDialog()
