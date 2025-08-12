# Flatten Code Repository

`Flatten-CodeRepo.ps1` is a PowerShell utility that flattens the source code of a repository into a single text file, and optionally generates a tree-style map of the folder structure.  
It’s designed for tasks like code reviews, AI ingestion, or archiving, where having all relevant source in one file is useful.

## Features

- **Flatten source code** into a single `.txt` file with optional:
  - Code fences for syntax highlighting
  - Line numbers for easier referencing
- **Generate a directory map** with Unicode or ASCII tree branches
- **Filter files** by:
  - Extension list
  - Known code filenames (e.g., `Dockerfile`, `.gitignore`)
  - Excluded directories and file patterns
  - Maximum file size
- **Skip binary-like files** automatically
- **Handles dotfiles** when `-IncludeDotfiles` is specified
- **Deterministic output** — sorted file lists, consistent formatting

---

## Installation

No installation required — simply download the script and run it in PowerShell 5.1+ or PowerShell Core.

```powershell
# Example: Run from the script's folder
.\Flatten-CodeRepo.ps1 -Path "C:\path\to\repo"
```

---

## Usage

### Basic
```powershell
.\Flatten-CodeRepo.ps1 -Path C:\src\my-repo
```
Generates:
- A flattened `.flat.txt` file
- A `.map.txt` tree map file  
Both are saved in a timestamped output folder.

### With Custom Outputs
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -OutputFile out\repo.flat.txt `
  -MapFile out\repo.map.txt `
  -CodeFences `
  -LineNumbers
```

### Using ASCII Tree Characters
```powershell
.\Flatten-CodeRepo.ps1 -Path . -AsciiTree
```
Useful when viewing in environments without UTF-8 support.

### Filtering
```powershell
.\Flatten-CodeRepo.ps1 -Path . `
  -Extensions ps1,psm1,cs,csproj `
  -ExcludeDirs .git,.github,bin,obj `
  -MaxFileBytes 5242880
```

---

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Path` | **(Required)** Root path of the repository to flatten |
| `-OutputFile` | Path for flattened code output file |
| `-MapFile` | Path for tree map output file |
| `-Extensions` | File extensions to include (no `.`) |
| `-ExcludeDirs` | Directories to skip anywhere in the tree |
| `-ExcludeFilePatterns` | Glob patterns to skip by filename |
| `-IncludeDotfiles` | Include hidden/dotfiles in search |
| `-LineNumbers` | Add line numbers to flattened output |
| `-CodeFences` | Wrap file contents in markdown code fences |
| `-Append` | Append to existing output file instead of overwriting |
| `-MaxFileBytes` | Skip files larger than this size (default: 2 MB) |
| `-Quiet` | Suppress console logging |
| `-AsciiTree` | Use ASCII instead of Unicode for tree map |

---

## Output Example

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

**EXMAPLE: Flattened File (`.flat.txt` with `-CodeFences -LineNumbers`):**
```
# ==== FILE: src/Public/MyScript.ps1 (size: 120 bytes; sha256: abc123...) ====
     1 | function Get-HelloWorld {
     2 |     "Hello, world!"
     3 | }
	 
...etc
```
---

**Notes**

- The script writes files with **UTF-8 BOM** for compatibility with Windows editors.
- Unicode tree branches display best in UTF-8-capable editors and consoles.
- ASCII tree mode is recommended for legacy console environments.

Generated with assistance from ChatGPT (GPT-5) ❤️

---

## License

MIT License — see [LICENSE](LICENSE) for details.
