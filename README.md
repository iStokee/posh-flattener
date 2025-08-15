# posh-flattener — Flatten a repo to a single text file + tree map

`Flatten-CodeRepo.ps1` scans a repository (local folder **or** GitHub URL), collects code/text files, and produces:

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

```powershell
# Optional: unblock if downloaded from the internet
Unblock-File .\Flatten-CodeRepo.ps1
```

---

## Usage

```powershell
.\Flatten-CodeRepo.ps1 -Path <repo-root-or-github-url>
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

---

## Parameters (concise)

- **`-Path` (required)**: Repository root **or** GitHub URL (see *URL input*).  
- **`-OutputFile`**: Target flat file (UTF‑8 with BOM). Default: timestamped folder under `.<repo>.flatten\`.
- **`-MapFile`**: Target map file (UTF‑8 with BOM). Default: timestamped folder under `.<repo>.flatten\`.
- **`-Extensions`**: Case‑insensitive list of allowed code extensions. Comes with a broad, sensible default.
- **`-ExcludeDirs`**: Directories to skip anywhere in the tree (e.g., `.git`, `node_modules`, `bin`, `obj`, …).
- **`-ExcludeFilePatterns`**: Filename globs to skip (e.g., `*.min.js`, `*.dll`, images, archives).
- **`-Include`**: Restrict to repo‑relative patterns (files, folders, and wildcards; see *Include patterns* below).
- **`-IncludeDotfiles`**: Include hidden/dotfiles.
- **`-LineNumbers`**: Prefix each line with a right‑aligned line number column.
- **`-CodeFences`**: Wrap each file with a fenced code block using a detected language tag.
- **`-Append`**: Append to an existing flat file (skips rewriting the top‑of‑file index in that run).
- **`-MaxFileBytes`**: Skip files larger than this (default `2MB`).
- **`-Quiet`**: Reduce log output.
- **`-AsciiTree`**: ASCII tree when `$true` (default). Set `-AsciiTree:$false` for Unicode (`├──`, `└──`).  
- **`-MapScope`**: `All` or `Included` (see defaulting rule above).
- **`-Index`** *(default: on)*: Include the **QUICK INDEX** block at the top of the flat file.
- **`-ApiSummary`** *(default: on)*: For PowerShell modules, include **PUBLIC API SURFACE** (exported cmdlets + params).
- **`-FileMetrics`** *(default: on)*: Add `lines: N` to each per‑file banner alongside `size` and `sha256`.
- **`-IndexJson`** *(default: on)*: Emit `<flat>.index.json` with `{ path, start, end, lines, sha256, lang, num }`.

### Include patterns (repo‑relative; case‑insensitive)
- **Single file:** `-Include src\lib\util.ps1`
- **Directory (recursive):** `-Include src\*` or just `-Include src`  
  (folders are treated as recursive; `dir/*` works too)
- **Wildcard by leaf name:** `-Include *.ps1,README.*`
- Accepts **comma‑separated string** or **array**: `-Include "src/*,README.md"` or `-Include src/*,README.md`

### Language fences
Fences are chosen via an internal map (e.g., `.ps1`→`powershell`, `.cs`→`csharp`, `.py`→`python`, `.ts`→`typescript`, `.json`→`json`, `.md`→`markdown`, etc.). Common “code‑by‑name” files (`Dockerfile`, `Makefile`, `CMakeLists.txt`, `.gitignore`) are also handled. Unknowns default to `text`.

---

## URL input (GitHub)

`-Path` accepts either a local folder **or a GitHub URL**. For GitHub, both of the following work:

- Whole repo (default branch):  
  ```powershell
  .\Flatten-CodeRepo.ps1 -Path https://github.com/OWNER/REPO
  ```

- Specific branch and/or subfolder:  
  ```powershell
  .\Flatten-CodeRepo.ps1 -Path https://github.com/OWNER/REPO/tree/feature/my-branch/src
  ```

**How it works**
- If **Git is available**, the script does a shallow clone (`git clone --depth=1`), respecting `/tree/<branch>/<subpath>`.
- If **Git is not available**, the script **downloads a ZIP** from GitHub (`codeload.github.com`) for `main` (fallback `master`), then expands it and targets the optional subpath.

The downloaded/checked-out temp folder is **cleaned up automatically** at the end of the run.

**Requirements**
- For ZIP fallback: PowerShell `Invoke-WebRequest` and `Expand-Archive` must be available (they are on Windows PowerShell 5.1+ and PowerShell 7+).

---

## Output format

Each file is wrapped with markers; with code fences and line numbers if requested.  
Includes **anchors** and **line counts**:

```text
# [F03] ==== FILE: src\Public\New-RiDVM.ps1 (size: 5,400 bytes; lines: 123; sha256: EEA64F49...) ====
```powershell
  1 | function New-RiDVM {{
  2 |   ...
``` 
# ==== END FILE: src\Public\New-RiDVM.ps1
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

**Flatten a GitHub repo to files with fences & numbers**
```powershell
.\Flatten-CodeRepo.ps1 -Path https://github.com/iStokee/ridctl `
  -OutputFile C:\temp\ridctl.flat.txt -MapFile C:\temp\ridctl.map.txt `
  -CodeFences -LineNumbers -ExcludeDirs .git,.github
```

**Flatten a subfolder on a branch**
```powershell
.\Flatten-CodeRepo.ps1 -Path https://github.com/iStokee/ridctl/tree/dev/src `
  -Include src/* -MapScope Included
```

---

## Notes & behavior

- **Binary‑like detection:** Reads the first chunk of each file; files containing NUL bytes are treated as binary‑like and skipped.
- **Code filter:** Only files matching known **extensions** or **known code filenames** are included; others are reported as “not a code file by filter”.
- **Size cap:** Files larger than `-MaxFileBytes` are skipped to keep outputs manageable.
- **Relative paths:** All patterns and reports are **repo‑relative** (e.g., `src\Public\X.ps1`). Paths are normalized to `\` on Windows.
- **Append mode:** When `-Append` is used, the run **does not rewrite** the top‑of‑file Quick Index and JSON sidecar.
- **Windows PS vs PS7:** Works on both. Uses a reflection check for `Path.GetRelativePath` when available; otherwise falls back to a URI method.

---

## FAQ

**Q: Where do the API signatures come from?**  
From your module’s `.psd1` `FunctionsToExport` and static parsing of `src\Public\*.ps1`
to extract parameter names, defaults, and which are mandatory. 

**Q: What if I don’t want the index/API?**  
Use `-Index:$false -ApiSummary:$false -IndexJson:$false`.

**Q: Which languages are supported for API signature output?**  
Only PowerShell is supported at the moment.

---

## Troubleshooting

- **Map seems too small:** If you used `-Include` and didn’t set `-MapScope`, the map defaults to the **included subset**.
  Pass `-MapScope All` to force the full tree.
- **Index missing:** You used `-Append`. The script doesn’t rewrite the top-of-file in append mode.
- **ObjectDisposedException on exit (“Cannot write to a closed TextWriter”):** This happens if the script disposes the file writers in the main block and then the `finally` tries to flush them again. Fixed by disposing defensively in `finally` (and setting `$flatWriter = $null` after disposing).

---

## License

MIT — do whatever you want, just keep the copyright and license text.

---

## Credits

- Original concept and implementation **by iStokee**  
- Pair‑engineering, docs, & refinements with **ChatGPT (GPT‑5 Thinking)**
