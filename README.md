# posh-flattener — Flatten a repo to a single text file + tree map

`Flatten-CodeRepo.ps1` scans a repository, collects code/text files, and produces:

- **Flat file**: one concatenated `.txt` with optional **code fences** and **line numbers**
- **Tree map**: a clean Unicode or ASCII directory tree of the repository (or just the included subset)
- **Skip report**: size limits, binary‑like files, and non‑code files are summarized at the end

It’s mainly ideal for pasting code into LLMs, but could also be useful for code reviews, audits, retention/backups, or quick offline browsing.

---

## Highlights

- **Smart language fences** (`powershell`, `csharp`, `python`, etc.) based on file extension/name
- **Selective include**: focus on `src/*`, `README.md`, or arbitrary patterns
- **Clean map generation**: maps **only included files by default** when `-Include` is used
- **Binary guard**: avoids obviously binary files and large files by size
- **Dotfiles support**: opt in via `-IncludeDotfiles`
- **Dual PS support**: PowerShell 7+ and Windows PowerShell 5.1

---

## Installation

Just drop `Flatten-CodeRepo.ps1` anywhere on your system and run it from PowerShell.

```powershell
# Optional: unblock if downloaded from the internet
Unblock-File .\Flatten-CodeRepo.ps1
```

You can also add the script’s folder to your `PATH` for easier use.

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
                       [-AsciiTree]               # default: $false (Unicode). Pass -AsciiTree:$true for ASCII
                       [-MapScope <All|Included>] # default: 'All' unless -Include is used (see below)
```

> **Default MapScope behavior:**  
> - If **`-Include` is provided** and **`-MapScope` is not explicitly set**, the script now defaults to **`Included`**.
> - Otherwise, it defaults to **`All`**.
>
> You can always override: `-MapScope All` to force a full tree even when `-Include` is set.

---

## Parameters (most used)

- **`-Path` (required)**: Repository root to scan.
- **`-OutputFile`**: Target flat file (UTF‑8 with BOM). Default: `.<repo>.flatten.<timestamp>\<repo>.flat.txt`.
- **`-MapFile`**: Target map file (UTF‑8 with BOM). Default: `.<repo>.flatten.<timestamp>\<repo>.map.txt`.
- **`-Extensions`**: Case‑insensitive list of allowed code extensions. Comes with a broad, sensible default.
- **`-ExcludeDirs`**: Directories to skip anywhere in the tree (e.g., `.git`, `node_modules`, `bin`, `obj`, …).
- **`-ExcludeFilePatterns`**: Filename globs to skip (e.g., `*.min.js`, `*.dll`, images, archives).
- **`-Include`**: Restrict to specific repo‑relative patterns (see **Include patterns** below).
- **`-IncludeDotfiles`**: Include hidden/dotfiles.
- **`-LineNumbers`**: Prefix each line with a right‑aligned line number column.
- **`-CodeFences`**: Wrap each file with a fenced code block using a detected language tag.
- **`-Append`**: Append to an existing flat file (useful for combining multiple repos).
- **`-MaxFileBytes`**: Skip files larger than this (default `2MB`).
- **`-Quiet`**: Suppress log chatter.
- **`-AsciiTree`**: ASCII tree when `$true`. Set `-AsciiTree:$false` for Unicode (`├──`, `└──`) (default).  
- **`-MapScope`**: `All` or `Included`. See defaulting rule above.

### Include patterns (repo‑relative; case‑insensitive)
- **Single file:** `-Include src\lib\util.ps1`
- **Directory (recursive):** `-Include src\*` or `-Include src\` or `-Include src`  
  (folders are treated as recursive; `dir/*` works too)
- **Wildcard by leaf name:** `-Include *.ps1,README.*`
- You can pass a **comma‑separated string** or an **array**: `-Include "src/*,README.md"` or `-Include src/*,README.md`

### Language fences
Fences are chosen via an internal map (e.g., `.ps1`→`powershell`, `.cs`→`csharp`, `.py`→`python`, `.ts`→`typescript`, `.json`→`json`, `.md`→`markdown`, etc.). Common “code‑by‑name” files (like `Dockerfile`, `Makefile`, `CMakeLists.txt`, `.gitignore`) are also handled. Unknowns default to `text`.

---

## Output format

Each file is wrapped with file markers; when enabled, code fences and line numbers are applied inside the block:

```text
# ==== FILE: src\Public\Test-RiDVirtualization.ps1 (size: 3,697 bytes; sha256: EBA19B...) ====
```powershell
     1 | function Test-RiDVirtualization {
     2 |     <# .SYNOPSIS ... #>
     3 |     ...
```

At the end of the flat file you’ll see a summary with counts and details for skipped files (too large, binary‑like, or filtered out as “not code”).
```
# Included files: 2
# Skipped files:  0
```

The map file starts with the repository root and timestamp, followed by a directory tree. Example (ASCII):

```text
./
+-- src/
|   +-- Public/
|   |   +-- Test-RiDVirtualization.ps1
|   |   \-- Sync-RiDScripts.ps1
|   \-- Private/
\-- README.md
```

Unicode tree output (default):

```text
./
├── src/
│   ├── Public/
│   │   ├── Test-RiDVirtualization.ps1
│   │   └── Sync-RiDScripts.ps1
│   └── Private/
└── README.md
```

---

## Examples

### 1) Basic
```powershell
.\Flatten-CodeRepo.ps1 -Path C:\src\my-repo
```

### 2) Custom outputs + code fences + line numbers
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -OutputFile out\repo.flat.txt `
  -MapFile out\repo.map.txt `
  -CodeFences -LineNumbers
```

### 3) Specific extensions + include dotfiles + larger size cap
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -Extensions ps1,psm1,cs,csproj,sln `
  -IncludeDotfiles `
  -MaxFileBytes 5242880
```

### 4) Include only a subset (new default: map just those)
```powershell
.\Flatten-CodeRepo.ps1 -Path . -Include src/*,README.md -CodeFences
# Map will default to Included (subset) unless you override -MapScope
```

### 5) Include a subset, but force a full map
```powershell
.\Flatten-CodeRepo.ps1 -Path . -Include src/*,README.md -MapScope All
```

### 6) ASCII tree output
```powershell
.\Flatten-CodeRepo.ps1 -Path . -AsciiTree:$true
```

### 7) Append to an existing flat file
```powershell
.\Flatten-CodeRepo.ps1 -Path C:\src\repoA -OutputFile .\combined.flat.txt -Append
.\Flatten-CodeRepo.ps1 -Path C:\src\repoB -OutputFile .\combined.flat.txt -Append
```

---

## Notes & behavior

- **Binary‑like detection:** Reads the first chunk of each file; files containing NUL bytes are treated as binary‑like and skipped.
- **Code filter:** Only files matching known **extensions** or **known code filenames** are included; others are reported as “not a code file by filter”.
- **Size cap:** Files larger than `-MaxFileBytes` are skipped to keep outputs manageable.
- **Relative paths:** All patterns and reports are **repo‑relative** (e.g., `src\Public\X.ps1`). Paths are normalized to `\` on Windows.
- **Windows PS vs PS7:** Works on both. Uses a reflection check for `Path.GetRelativePath` when available; otherwise falls back to a URI method.

---

## Troubleshooting

- **My map looks empty/minimal:** If you used `-Include`, the map now defaults to just those files. Pass `-MapScope All` for a full tree.
- **A file was skipped as “not code”:** Add its extension via `-Extensions` or rename accordingly. Some special names are recognized automatically (e.g., `Dockerfile`).
- **Output encoding:** Files are written as UTF‑8 with BOM for broad compatibility.

---

## License

This project is offered under **The Unlicense** (public domain dedication) — do whatever you want, for any purpose, without restriction. See `LICENSE`.

---

## Credits

- Original concept and implementation **by iStokee**  
- Pair‑engineering, docs, and refinements with **ChatGPT (GPT‑5 Thinking)**

Happy flattening!
