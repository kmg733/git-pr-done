# git-pr-done

> A bash script that safely cleans up local branches after a PR/MR is merged.

**English** | **[한국어](README.ko.md)**

---

After a PR is merged on the remote, your local clone is left with an obsolete feature branch and stale remote-tracking references. `git-pr-done` handles this cleanup in one shot, with safety checks baked in.

```bash
git remote prune origin      # Prune deleted remote refs
git checkout develop          # Switch to the target branch
git pull --ff-only            # Sync latest commits
git branch -d <feature>       # Delete the merged branch
```

## Quick Start

### 1. Install (macOS & Linux)

```bash
mkdir -p ~/.local/bin && \
  curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done && \
  chmod +x ~/.local/bin/git-pr-done
```

Windows (Git Bash):

```bash
mkdir -p ~/bin && \
  curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/bin/git-pr-done && \
  chmod +x ~/bin/git-pr-done
```

### 2. Use

```bash
# After your PR is merged on the remote:
git pr-done
```

That's it. The script will prune remote refs, checkout `develop`, pull, and delete your merged branch — with safety checks.

### 3. Common Options

```bash
git pr-done --dry-run           # Preview only
git pr-done -t master           # Target branch = master
git pr-done --force             # For squash/rebase merges
git pr-done -h                  # Show help
```

> **Tip**: Use `git pr-done -h` (not `--help`) — git intercepts `--help` for man pages.

See below for detailed installation, options, and safety guards.

---

## Features

- **Flag-based interface** — Safely handles branch names with parentheses or Unicode characters
- **Safety guards** — Dirty tree detection, protected-branch blacklist, actual-merge verification
- **Dry-run mode** — Simulate before executing
- **`git pr-done` subcommand** — Invoke naturally like any git command
- **No dependencies** — Pure bash (only requires git)

## Requirements

- Bash 3.2+
- Git 2.x+

## Installation

### macOS

macOS ships with bash and git. If git is missing, install via `xcode-select --install` or [Homebrew](https://brew.sh).

```bash
# 1) Download and install
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) Ensure ~/.local/bin is on PATH
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 3) Reload shell and verify
source ~/.zshrc
git pr-done --version
```

Alternative location: `/usr/local/bin/git-pr-done` (Homebrew layout; no sudo needed if owned).

### Linux

Most distributions include bash and git by default. If not:

```bash
# Debian/Ubuntu
sudo apt install git

# RHEL/Fedora/CentOS
sudo dnf install git

# Arch
sudo pacman -S git
```

Install the script:

```bash
# 1) Download and install
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) Ensure ~/.local/bin is on PATH
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# 3) Reload shell and verify
source ~/.bashrc
git pr-done --version
```

If you use zsh, replace `~/.bashrc` with `~/.zshrc`.

### Windows

On Windows you need **Git Bash** (bundled with Git for Windows) or **WSL**. It does not run in PowerShell or CMD.

#### Option 1: Git Bash (Recommended)

1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Launch **Git Bash**
3. Run:

```bash
# 1) Download and install
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/bin/git-pr-done
chmod +x ~/bin/git-pr-done

# 2) Git Bash auto-adds ~/bin to PATH — no further setup needed
git pr-done --version
```

> **Note**: Git Bash automatically prepends `~/bin` (= `C:\Users\<USER>\bin`) to PATH.

#### Option 2: WSL (Ubuntu)

If you have WSL (Windows Subsystem for Linux), follow the **Linux** section as-is.

```powershell
# From PowerShell
wsl

# Then follow the Linux install steps
```

#### Option 3: Manual (Git Bash)

```bash
cd ~/Downloads
git clone https://github.com/kmg733/git-pr-done.git
cp git-pr-done/git-pr-done ~/bin/
chmod +x ~/bin/git-pr-done
```

## Usage

### Basic

```bash
# After your current branch is merged into develop:
git pr-done
```

### Options

| Flag | Purpose | Default |
|------|---------|---------|
| `-t, --target <BRANCH>` | Target branch | `develop` |
| `-b, --branch <BRANCH>` | Branch to delete | current branch |
| `-n, --dry-run` | Simulate without executing | `false` |
| `-f, --force` | Force delete (for squash/rebase merges) | `false` |
| `-y, --yes` | Skip confirmation prompt | `false` |
| `-h, --help` | Show help | — |
| `-V, --version` | Show version | — |

### Examples

```bash
# Default: delete current branch, switch to develop
git pr-done

# Specify target branch
git pr-done --target master
git pr-done -t release/2026-H1

# Delete a specific branch
git pr-done --branch 'feature-name(ISSUE-123)'

# Dry-run only
git pr-done --dry-run

# Force-delete a squash/rebase-merged branch
git pr-done --force

# Skip confirmation
git pr-done -y
```

> **Note**: Git intercepts `git <cmd> --help` and opens a man page. Use `git pr-done -h` or `git-pr-done --help` instead.

## Safety Guards

The script aborts automatically when:

- **Dirty tree** — there are uncommitted changes
- **Protected branch** — attempting to delete `master`, `main`, `develop`, `production`, `staging`, `release/*`, or `hotfix/*`
- **Target == deletion target** — you can't delete the branch you're switching to
- **Branch missing** — target or deletion target doesn't exist
- **Detached HEAD** — not on a named branch
- **Not actually merged** — without `--force`, only truly merged branches get deleted

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generic error (not a git repo, missing branch, etc.) |
| `2` | Pre-flight validation failed (dirty tree, protected branch, etc.) |
| `3` | User canceled |
| `4` | Git command failed during execution |

## Recommended Workflow

```bash
# 1. Work on a feature branch
git checkout -b feature/awesome-feature
# ... edit, commit, push ...

# 2. Open a PR/MR and get it reviewed
gh pr create   # or GitLab MR

# 3. Once merged on the remote
git pr-done    # One-liner cleanup
```

## License

[MIT](LICENSE)
