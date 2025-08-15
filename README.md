# posh-flattener — Flatten a repo to a single text file + tree map

`Flatten-CodeRepo.ps1` scans a repository, collects code/text files, and produces:

- **Flat file**: one concatenated `.txt` with optional **code fences** and **line numbers**.
- **Quick Index**: a top-of-file index (`filename → absolute line range`) so agents (and you) can jump fast.
- **Public API surface** *(PowerShell repos)*: one‑line signatures of exported cmdlets and their parameters.
- **Tree map**: a clean ASCII/Unicode directory tree of the repository (entire repo or just the `-Include` subset).
- **Sidecar JSON index**: machine‑readable index (`.index.json`) for tools.
- **Skip report**: size‑limited, binary‑like, or non‑code files listed at the end of the flat file.

---

## Highlights

- **Smart language fences** (`powershell`, `csharp`, `python`, etc.) based on file extension/name.
- **Selective include**: focus on `src/*`, `README.md`, or arbitrary patterns.
- **Map scope**: show **all** folders or **only the ones containing included files**.
- **Integrity & drift checks**: per‑file **SHA‑256** and **line counts** in each file banner.
- **Anchors**: per‑file anchors like `[F01]` in the flat file for quick searching.

---

## Install

Just copy `Flatten-CodeRepo.ps1` into your repo (or somewhere on `PATH`).

PowerShell 5.1+ or PowerShell 7+ is supported.

---

## Usage

```powershell
.\Flatten-CodeRepo.ps1 -Path <repo-root>
                       [-OutputFile <flat.txt>]
                       [-MapFile <map.txt>]
                       [-Extensions <ext1,ext2,...>]
                       [-ExcludeDirs <dir1,dir2,...>]
                       [-ExcludeFilePatterns <glob1,glob2,...>]
                       [-Include <pattern1,pattern2,...>]
                       [-IncludeDotfiles]
                       [-LineNumbers]
                       [-CodeFences]
                       [-Append]
                       [-MaxFileBytes <bytes>]
                       [-Quiet]
                       [-AsciiTree]
                       [-MapScope <All|Included>]
                       [-Index] [-ApiSummary] [-FileMetrics] [-IndexJson]
```

> **Default MapScope behavior:**  
> If **`-Include` is provided** and **`-MapScope` is not explicitly set**, the map defaults to **`Included`**.  
> Otherwise it defaults to **`All`**. You can always override with `-MapScope All`.

### New switches

- **`-Index`** *(default: on)* — Write the **QUICK INDEX** block at the top of the flat file with **absolute line ranges**.
- **`-ApiSummary`** *(default: on)* — If a PowerShell module is detected, add a **PUBLIC API SURFACE** section using the module
  manifest (`FunctionsToExport`) and AST‑parsed parameter lists.
- **`-FileMetrics`** *(default: on)* — Add `lines: N` to each per‑file banner, alongside size and sha256.
- **`-IndexJson`** *(default: on)* — Emit a `<flat>.index.json` sidecar with `{ path, start, end, lines, sha256, lang, num }`.

> **Note on `-Append`:**  
> Appending to an existing flat file does **not** rewrite the top of the file. To keep things fast and safe,
> when `-Append` is used the script **skips the top-of-file Quick Index and JSON sidecar** for that run.

---

## Examples

**Basic**
```powershell
.\Flatten-CodeRepo.ps1 -Path C:\src\my-repo
```

**Custom outputs, code fences, and line numbers**
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -OutputFile out\repo.flat.txt -MapFile out\repo.map.txt `
  -CodeFences -LineNumbers
```

**Only specific content, include dotfiles, bigger limit**
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -Extensions ps1,psm1,cs,csproj,sln `
  -Include src/*,README.md -IncludeDotfiles `
  -MaxFileBytes 5242880
```

**ASCII tree and include‑only map**
```powershell
.\Flatten-CodeRepo.ps1 -Path . -Include src/* -AsciiTree -MapScope Included
```

---

## Output format

Each file is wrapped with markers; with code fences and line numbers if requested.  
Now includes **anchors** and **line counts**:

```text
# [F03] ==== FILE: src\Public\New-RiDVM.ps1 (size: 5,400 bytes; lines: 123; sha256: EEA64F49...) ====
```powershell
  1 | function New-RiDVM {{
  2 |   ...
```

**Top-of-file QUICK INDEX** example:

```text
# QUICK INDEX (absolute line ranges)
01 src\Public\New-RiDVM.ps1....................  12-245   (123)  [sha EEA64F49]
02 src\Public\Start-RiDVM.ps1.................. 246-310    (65)  [sha AAC29B10]
...
```

**PUBLIC API SURFACE** example:

```text
# PUBLIC API SURFACE (PowerShell)
New-RiDVM(Name*, DestinationPath*, CpuCount=2, MemoryMB=4096, DiskGB=60, IsoPath?, Method=auto|vmcli|vmrest|vmrun, TemplateVmx?, TemplateSnapshot?, Apply)
Start-RiDVM(VmxPath*, Apply)
Stop-RiDVM(VmxPath*, Hard, Apply)
...
```

**Sidecar JSON** (`repo.flat.index.json`) snippet:

```json
[
  {
    "num": 3,
    "path": "src\\Public\\New-RiDVM.ps1",
    "start": 12,
    "end": 245,
    "lines": 123,
    "sha256": "EEA64F49…",
    "lang": "powershell"
  }
]
```
---

## FAQ

**Q: Where do the API signatures come from?**  
From your module’s `.psd1` `FunctionsToExport` and static parsing of `src\Public\*.ps1`
to extract parameter names, defaults, and which are mandatory.

**Q: What if I don’t want the index/API?**  
Use `-Index:$false -ApiSummary:$false -IndexJson:$false`.

---

## Troubleshooting

- **Map seems too small:** If you used `-Include` and didn’t set `-MapScope`, the map defaults to the **included subset**.
  Pass `-MapScope All` to force the full tree.
- **Index missing:** You used `-Append`. The script doesn’t rewrite the top-of-file in append mode.
- **ObjectDisposedException on exit (“Cannot write to a closed TextWriter”):** This happens if the script disposes the file writers in the main block and then the `finally` tries to flush them again. Fixed by disposing defensively in `finally` (and setting `$flatWriter = $null` after disposing).

---

## License

MIT — do whatever you want, just keep the copyright and license text.

