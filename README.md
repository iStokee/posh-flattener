# Flatten Code Repository

`posh-flattener` is a PowerShell utility that flattens the source code of a repository into a single text file, and optionally generates a tree-style map of the folder structure.

It’s designed mainly for aiding AI ingestion, but also helps with code reviews, offline archiving, and producing a single searchable artifact from a large codebase.

---

## Features

- **Flatten source code** into a single `.txt` with optional:
  - Code fences for syntax highlighting
  - Line numbers for easy referencing
- **Generate a directory map** with Unicode or ASCII branches
- **Flexible filtering**:
  - Include by extension or known code filenames (e.g., `Dockerfile`, `.gitignore`)
  - Exclude directories and filename patterns
  - **Target specific files/folders** with `-Include`
  - Limit by maximum file size
- **Binary-like files skipped** automatically
- **Optionally include dotfiles** with `-IncludeDotfiles`
- **Deterministic output** — sorted, stable formatting
- Works on **Windows PowerShell 5.1+** and **PowerShell 7+** (includes a relative-path polyfill for older runtimes)

---

## Installation

No install needed — download the script and run it in PowerShell.

```powershell
# Example: run from the script's folder
.\Flatten-CodeRepo.ps1 -Path "C:\path\to\repo"
```

---

## Usage Examples

### 1) Basic
```powershell
.\Flatten-CodeRepo.ps1 -Path C:\src\my-repo
```
Creates:
- `my-repo.flat.txt` (flattened code)
- `my-repo.map.txt` (tree map)  
in a timestamped output folder.

---

### 2) Custom output paths + formatting
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -OutputFile out\repo.flat.txt `
  -MapFile out\repo.map.txt `
  -CodeFences `
  -LineNumbers
```
Adds syntax highlighting and line numbers to the flattened file.

---

### 3) ASCII tree mode
```powershell
.\Flatten-CodeRepo.ps1 -Path . -AsciiTree
```
Uses ASCII instead of Unicode for the tree map.

---

### 4) Filter by extension & exclude common build dirs
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -Extensions ps1,psm1,cs,csproj `
  -ExcludeDirs .git,.github,bin,obj
```

---

### 5) **Include only** specific files/folders (`-Include`)
```powershell
# Everything under "tests/" + one specific file in src/
.\Flatten-CodeRepo.ps1 -Path . `
  -Include tests/*,src/ridctl.psm1
```

```powershell
# README + all .ps1 files in a subfolder
.\Flatten-CodeRepo.ps1 -Path . `
  -Include README.md,scripts/*.ps1
```

`-Include` matching rules (repo‑relative):

| Pattern         | Matches                                                     |
|-----------------|-------------------------------------------------------------|
| `tests/*`       | All files in and under `tests/` (recursive)                 |
| `docs/`         | Entire `docs/` folder recursively                           |
| `src/Util.psm1` | Exactly that file                                           |
| `*.ps1`         | Any `.ps1` anywhere                                         |
| `README.*`      | Any README variant (e.g., `.md`, `.rst`)                    |

> When `-Include` is specified, only matching files are considered for flattening and (optionally) for the map if you set `-MapScope Included`.

---

### 6) Control what the map shows (`-MapScope`)
```powershell
# Default: map the full repo for extra context
.\Flatten-CodeRepo.ps1 -Path . -MapScope All
```

```powershell
# Map only the included files and their parent folders
.\Flatten-CodeRepo.ps1 -Path . `
  -Include tests/*,src/ridctl.psm1 `
  -MapScope Included
```
`All` (default) shows the whole project structure.  
`Included` prunes the map down to only folders that lead to included files, plus the files themselves.

---

### 7) Increase max file size
```powershell
.\Flatten-CodeRepo.ps1 -Path . -MaxFileBytes 5242880   # 5 MB
```

---

### 8) Append to an existing flattened file
```powershell
.\Flatten-CodeRepo.ps1 -Path ./lib `
  -OutputFile merged.flat.txt `
  -Append
```

---

## Parameters

| Parameter               | Description |
|-------------------------|-------------|
| `-Path`                 | **Required.** Root path of the repository to flatten |
| `-OutputFile`           | Path for flattened code output file |
| `-MapFile`              | Path for tree map output file |
| `-Extensions`           | File extensions to include (no dot, case-insensitive) |
| `-ExcludeDirs`          | Directories to skip (applies anywhere in the tree) |
| `-ExcludeFilePatterns`  | Glob patterns to skip by **filename** (e.g., `*.min.js`) |
| `-Include`              | Only include files matching these **repo-relative** patterns (wildcards allowed) |
| `-IncludeDotfiles`      | Include hidden/dotfiles in the search |
| `-LineNumbers`          | Add line numbers to the flattened output |
| `-CodeFences`           | Wrap file contents in Markdown code fences |
| `-Append`               | Append to existing output file instead of overwriting |
| `-MaxFileBytes`         | Skip files larger than this size (default: 2 MB) |
| `-Quiet`                | Suppress console logging |
| `-AsciiTree`            | Use ASCII instead of Unicode for the tree map |
| `-MapScope`             | `All` (default) maps the entire repo; `Included` maps only included files + their parent folders |

---

## Output Examples

**Tree Map (`.map.txt`):**
```
./
├── docs/
│   ├── README.md
│   └── USAGE.md
├── src/
│   ├── Public/
│   │   └── MyScript.ps1
│   └── Private/
│       └── Helpers.ps1
└── tests/
    └── Example.Tests.ps1
```

**Flattened File (`.flat.txt` with `-CodeFences -LineNumbers`):**
```
# ==== FILE: src/Public/MyScript.ps1 (size: 120 bytes; sha256: abc123...) ====
     1 | function Get-HelloWorld {
     2 |     "Hello, world!"
     3 | }
# ==== END FILE: src/Public/MyScript.ps1
```

---

## Notes

- Output files are **UTF‑8 with BOM** for better Windows editor compatibility.
- Unicode tree branches display best in UTF‑8‑capable editors/consoles; use `-AsciiTree` for legacy consoles.
- A compatibility polyfill is used when `[System.IO.Path]::GetRelativePath` isn’t available (e.g., Windows PowerShell 5.1).

Generated with assistance from ChatGPT (GPT‑5) ❤️

---

## License

MIT License — see [LICENSE](LICENSE) for details.
