# git-pr-done

> One command to tidy up your computer after your pull request gets merged.

**English** | **[한국어](README.ko.md)**
---
![Git](https://img.shields.io/badge/Git-F05032?logo=git&logoColor=white)
![Shell](https://img.shields.io/badge/-Shell-4EAA25?logo=gnu-bash&logoColor=white)

---

## What problem does this solve?

When a teammate merges your pull request on GitHub or GitLab, that happens on the website. Your own computer has no idea. It is still holding:

- the finished branch you were working on
- links to branches that were already deleted on the server
- an out-of-date copy of the branch everyone else is now working from

Tidying that up by hand means four commands, in the right order, every single time:

```bash
git remote prune origin      # 1
git checkout develop         # 2
git pull --ff-only           # 3
git branch -d my-feature     # 4
```

`git-pr-done` runs those four for you. Before each one it checks that the step is safe, and it stops instead of continuing if anything looks wrong.

### What each step means

| Step | Command | In plain words |
|------|---------|----------------|
| 1 | `git remote prune origin` | Forget about branches that no longer exist on the server |
| 2 | `git checkout <target>` | Move over to the branch your work was merged into |
| 3 | `git pull --ff-only` | Download the merged result so your copy is current |
| 4 | `git branch -d <yours>` | Delete your finished branch from your computer |

None of this deletes anything on the server. It all happens on your own machine, so the
worst case is that you download something again.

### What happens when you run it

The run has two halves. The first half only looks at things. The second half changes them,
and it does not start until you say yes.

**First half — checking. Nothing of yours is changed.**

| | It makes sure that… | If not |
|---|---|---|
| 1 | you are inside a git repository | stops |
| 2 | you are standing on a branch | stops |
| 3 | you have no unsaved changes | stops and lists them |
| 4 | the branch you want to delete exists | stops |
| 5 | that branch is not a protected one | stops |
| 6 | *(reads the current branch list from the server)* | carries on with what it already knew |
| 7 | it knows which branch to move to | stops and asks you |
| 8 | that branch is not the one being deleted | stops |
| 9 | that branch exists on your computer | stops |
| 10 | your work really was merged into it | stops, and you stay on your own branch |

Step 10 is the important one. If your branch was not merged, you find out **before** anything
moves, so you are still standing where you started.

**Second half — doing, after you confirm.** The four commands in the table above.

> Step 6 only *reads* from the server. Nothing is deleted or rewritten before you confirm, so
> answering no at the prompt leaves the repository exactly as it was.

---

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

### 2. Use it

```bash
# Right after your pull request is merged:
git pr-done
```

It shows you exactly what it is about to do, waits for you to say yes, then does it.

### 3. Options you will actually use

```bash
git pr-done --dry-run           # Show the plan, touch nothing of yours
git pr-done -t master           # Move to master instead of the detected branch
git pr-done --force             # For squash/rebase merges (see below)
git pr-done -h                  # Help
```

> **About `--dry-run`**: it leaves your branches and files exactly as they are. It does
> refresh what your computer knows about the server, so that the branch it reports is the
> one the real run would use.

> **Tip**: use `git pr-done -h`, not `--help`. Git grabs `--help` for itself and opens a manual page.

---

## Which branch does it move you to?

The branch your pull request was merged **into** is called the **target branch**. In most projects it is named `main`, `master`, or `develop`.

You do not have to tell `git-pr-done` which one it is. It works this out on its own, trying four things in order and using the first answer it gets:

| Order | Where it looks | When this one wins |
|-------|----------------|--------------------|
| 1 | A setting you saved for this project | You ran `git config pr-done.target <branch>` once |
| 2 | GitHub or GitLab itself, through `gh` or `glab` | Most accurate: it reads your actual merged pull request |
| 3 | Your local git history | `gh`/`glab` is not installed or not logged in |
| 4 | The project's default branch (`origin/HEAD`) | Last resort, and only if your work really was merged there |

Before it checks 3 and 4 it refreshes its knowledge of the server, so a merge that happened
minutes ago on the website is already visible.

**If all four fail, it stops and asks you.** It will not pick a branch at random, because moving you to the wrong branch is exactly the kind of mistake that is annoying to undo.

When that happens you have two ways out:

```bash
# Just this once
git pr-done --target develop

# Or save it for this project, so you never think about it again
git config pr-done.target develop
```

### If it cannot tell which host you are on

GitHub and GitLab are treated exactly the same way. The host is recognised from your remote
URL, which covers `github.com`, `gitlab.com`, and self-hosted instances whose address contains
either name. Company hosts named something else (`git.acme.com`, `ghe.acme.com`) cannot be
guessed, so tell it once:

```bash
git config pr-done.forge github     # or: gitlab
```

Without this it simply skips step 2 and carries on with steps 3 and 4. It never guesses wrong
on purpose: if the host is misread, the command line tool refuses to answer and the step is
skipped.

### Why "through GitHub or GitLab" is the accurate one

If your team uses **squash merge** or **rebase merge** (very common), the merged commits on the server get new IDs. Your local git history has no way to see the connection, so guessing from history alone can fail. Asking GitHub or GitLab directly avoids that. This needs the [`gh`](https://cli.github.com) or [`glab`](https://gitlab.com/gitlab-org/cli) command line tool installed and logged in. It is optional. Without it the other three methods still work.

---

## Features

- **Figures out the target branch by itself** — reads the real merged pull request when it can
- **Stops rather than guesses** — no silent fallback to a branch that may be wrong
- **Checks before it moves you** — if your branch was not merged, it says so while you are
  still on your own branch, having changed nothing
- **Never deletes unmerged work** — even `--force` requires proof that the merge happened
- **Safety guards** — refuses to run on uncommitted work, refuses to delete protected branches
- **Dry-run mode** — see the whole plan before anything changes
- **Works as `git pr-done`** — behaves like a built-in git command
- **Almost no dependencies** — plain bash and git; `gh`/`glab` only make detection better

## Requirements

- Bash 3.2+
- Git 2.x+
- Optional: [`gh`](https://cli.github.com) (GitHub) or [`glab`](https://gitlab.com/gitlab-org/cli) (GitLab) for the most accurate target detection

## Installation

### macOS

macOS ships with bash and git. If git is missing, install it with `xcode-select --install` or [Homebrew](https://brew.sh).

```bash
# 1) Download and install
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) Make sure ~/.local/bin is on PATH
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 3) Reload the shell and check
source ~/.zshrc
git pr-done --version
```

Alternative location: `/usr/local/bin/git-pr-done` (Homebrew layout; no sudo needed if you own it).

### Linux

Most distributions include bash and git already. If not:

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

# 2) Make sure ~/.local/bin is on PATH
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# 3) Reload the shell and check
source ~/.bashrc
git pr-done --version
```

If you use zsh, replace `~/.bashrc` with `~/.zshrc`.

### Windows

You need **Git Bash** (bundled with Git for Windows) or **WSL**. It does not run in PowerShell or CMD.

#### Option 1: Git Bash (recommended)

1. Install [Git for Windows](https://git-scm.com/download/win), which includes Git Bash
2. Open **Git Bash**
3. Run:

```bash
# 1) Download and install
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/bin/git-pr-done
chmod +x ~/bin/git-pr-done

# 2) Git Bash already has ~/bin on PATH, nothing else to do
git pr-done --version
```

> **Note**: Git Bash automatically puts `~/bin` (which is `C:\Users\<USER>\bin`) on PATH.

#### Option 2: WSL (Ubuntu)

If you have WSL, follow the **Linux** section as written.

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
# After your current branch has been merged:
git pr-done
```

### Options

| Flag | Purpose | Default |
|------|---------|---------|
| `-t, --target <BRANCH>` | Branch to move to | auto-detected (see above) |
| `-b, --branch <BRANCH>` | Branch to delete | the branch you are on |
| `-n, --dry-run` | Show the plan, change nothing | `false` |
| `-f, --force` | Delete when git history shows no trace, but the merge is proven | `false` |
| `-y, --yes` | Skip the confirmation prompt | `false` |
| `-h, --help` | Show help | — |
| `-V, --version` | Show version | — |

### Examples

```bash
# Normal use: detect the target, move there, delete the branch you finished
git pr-done

# Choose the target yourself
git pr-done --target master
git pr-done -t release/2026-H1

# Save the target for this project so you never pass -t again
git config pr-done.target develop

# Delete a specific branch while standing somewhere else
git pr-done --branch 'feature-name(ISSUE-123)'

# Look, don't touch
git pr-done --dry-run

# Squash- or rebase-merged branch
git pr-done --force

# No confirmation prompt
git pr-done -y
```

> **Note**: Git intercepts `git <cmd> --help` and opens a manual page. Use `git pr-done -h` or `git-pr-done --help`.

## Safety Guards

The script stops on its own when:

- **You have uncommitted changes** — save or stash them first, so nothing gets lost
- **The target branch could not be determined** — it asks instead of guessing
- **You are deleting a protected branch** — `master`, `main`, `develop`, `production`, `staging`, `release/*`, `hotfix/*`
- **The target and the branch to delete are the same** — you cannot delete the branch you are standing on
- **A branch does not exist** — either the target or the one to delete
- **You are not on a branch** (detached HEAD)
- **The merge cannot be verified** — and this is checked *before* you are moved anywhere

### "It says my branch is not merged"

You will see the commits that are missing from the target branch, and nothing will have
changed — you are still on your own branch.

The most common innocent reason is **squash merge** or **rebase merge**. The server rewrote
your commits, so locally they look like different work. If `gh` or `glab` is installed and
logged in, `git-pr-done` asks the server and confirms it for you:

```bash
git pr-done --force
```

`--force` only skips the *local history* check. It still requires proof that **the commit you
are on right now** was merged. It compares the head commit of the merged pull request with the
tip of your branch, so an older pull request that happened to use the same branch name, or
commits you added after the merge, do not count as proof. With no proof, it refuses and shows
you what would be lost:

```
✗ 머지 증거가 없어 강제 삭제를 거부합니다: 'feat'
  'main' 에 없는 커밋 3개:
    a9e9df7 아직 아무데도 머지 안 된 작업
  위 커밋을 잃어도 괜찮다고 판단되면 직접 실행하세요:
    git branch -D 'feat'
```

Deleting truly unmerged work is left to you, deliberately.

## When it stops, what it is telling you

| Message | What happened | What to do |
|---------|---------------|------------|
| `커밋되지 않은 변경사항이 있습니다` | You have edits that are not saved into git | `git commit -am "..."` or `git stash push -u` |
| `삭제 대상 브랜치가 존재하지 않습니다` | There is no branch by that name | Check the spelling with `git branch` |
| `보호 브랜치는 삭제할 수 없습니다` | You asked it to delete `main`, `develop` and the like | Use `-b` to name the branch you actually meant |
| `머지된 타겟 브랜치를 찾지 못했습니다` | It could not work out where your work went | `--target <branch>`, or save one with `git config pr-done.target <branch>` |
| `타겟 브랜치가 로컬에 존재하지 않습니다` | The target exists on the server but not on your computer | `git fetch origin <branch>:<branch>` |
| `… 에 머지되지 않았습니다` | Your branch has commits the target does not have | Check the pull request really is merged; if it was squash-merged, see `--force` above |
| `머지 증거가 없어 강제 삭제를 거부합니다` | Even `--force` could not prove that *these* commits were merged | The listed commits exist nowhere else. Delete only if you are sure: `git branch -D <branch>` |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generic error (not a git repository, branch missing, and so on) |
| `2` | Pre-flight check failed (uncommitted changes, protected branch, target not detected) |
| `3` | You canceled at the prompt |
| `4` | A git command failed, or a deletion was refused for lack of merge proof |

## Recommended Workflow

```bash
# 1. Work on a feature branch
git checkout -b feature/awesome-feature
# ... edit, commit, push ...

# 2. Open a pull request and get it reviewed
gh pr create   # or a GitLab merge request

# 3. Once it is merged on the server
git pr-done    # one-line cleanup
```

## Upgrading from v1.0

In v1.0, running `git pr-done` with no `-t` always moved you to `develop`, whether or not that was where your work went.

v1.1 detects the real target instead. If detection fails it stops rather than falling back to `develop`. To keep the old behaviour in a given project:

```bash
git config pr-done.target develop
```

Two other changes to be aware of:

- **`--force` is no longer unconditional.** It used to delete whatever you pointed it at. It now
  requires proof that the branch was merged, from git history or from `gh`/`glab`. To delete a
  branch that was genuinely never merged, run `git branch -D <branch>` yourself.
- **Every run refreshes remote information first**, including `--dry-run`.

## Development

Tests use [bats-core](https://github.com/bats-core/bats-core).

```bash
brew install bats-core     # or: npm install -g bats
bats tests/
```

The tests never touch the network or your real repositories. Each one builds a throwaway git repository in a temp directory and replaces `gh`/`glab` with stubs.

## License

[MIT](LICENSE)
