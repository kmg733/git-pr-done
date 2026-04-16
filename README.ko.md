# git-pr-done

> PR/MR 머지 완료 후 로컬 브랜치를 한 번에 안전하게 정리하는 bash 스크립트

**[English](README.md)** | **한국어**
---
![Git](https://img.shields.io/badge/Git-F05032?logo=git&logoColor=white)
![Shell](https://img.shields.io/badge/-Shell-4EAA25?logo=gnu-bash&logoColor=white)

---

PR이 원격에서 머지되고 나면, 로컬에는 쓸모없어진 피처 브랜치와 stale한 원격 참조가 남습니다. `git-pr-done`은 아래 4단계를 안전장치와 함께 한 번에 처리합니다.

```bash
git remote prune origin      # 원격에서 삭제된 참조 정리
git checkout develop          # 타겟 브랜치로 이동
git pull --ff-only            # 최신 커밋 동기화
git branch -d <feature>       # 머지된 브랜치 삭제
```

## 빠른 시작

### 1. 설치 (macOS & Linux)

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

### 2. 사용

```bash
# 원격에서 PR이 머지된 후:
git pr-done
```

이것으로 끝. 원격 참조 정리, `develop` 체크아웃, pull, 머지된 브랜치 삭제를 안전하게 한 번에 수행합니다.

### 3. 자주 쓰는 옵션

```bash
git pr-done --dry-run           # 시뮬레이션만
git pr-done -t master           # 타겟 변경
git pr-done --force             # squash 머지 대응
git pr-done -h                  # 도움말
```

> **팁**: git은 `--help`를 man 페이지용으로 가로채므로 `git pr-done -h`를 사용하세요.

자세한 설치/옵션/안전장치 설명은 아래를 참조하세요.

---

## 특징

- **플래그 기반 인터페이스** — 괄호/한글 포함 브랜치명도 안전하게 처리
- **안전장치** — dirty tree 감지, 보호 브랜치 블랙리스트, 실제 머지 여부 검증
- **Dry-run 모드** — 실행 전 시뮬레이션 가능
- **`git pr-done` 서브커맨드** — git 명령처럼 자연스럽게 호출
- **의존성 없음** — 순수 bash (git 외 추가 도구 불필요)

## 요구사항

- Bash 3.2+
- Git 2.x+

## 설치

### macOS

macOS는 기본으로 bash와 git이 설치되어 있습니다. git이 없다면 `xcode-select --install` 또는 [Homebrew](https://brew.sh)로 설치하세요.

```bash
# 1) 스크립트 다운로드 및 설치
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) PATH 확인 (~/.local/bin이 없으면 zshrc에 추가)
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 3) 셸 재시작 후 확인
source ~/.zshrc
git pr-done --version
```

대체 경로: `/usr/local/bin/git-pr-done` (Homebrew 사용자, sudo 필요 없음)

### Linux

대부분의 배포판에 bash와 git이 기본 포함됩니다. 없다면:

```bash
# Debian/Ubuntu
sudo apt install git

# RHEL/Fedora/CentOS
sudo dnf install git

# Arch
sudo pacman -S git
```

스크립트 설치:

```bash
# 1) 스크립트 다운로드 및 설치
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) PATH 확인 (~/.local/bin이 없으면 bashrc에 추가)
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# 3) 셸 재시작 후 확인
source ~/.bashrc
git pr-done --version
```

zsh 사용 시: `~/.bashrc` 대신 `~/.zshrc` 사용.

### Windows

Windows에서는 **Git Bash**(Git for Windows에 포함) 또는 **WSL**을 사용해야 합니다. PowerShell/CMD에서는 동작하지 않습니다.

#### 옵션 1: Git Bash (권장)

1. [Git for Windows](https://git-scm.com/download/win) 설치 (Git Bash 포함)
2. **Git Bash** 실행
3. 아래 명령 실행:

```bash
# 1) 스크립트 다운로드 및 설치
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/bin/git-pr-done
chmod +x ~/bin/git-pr-done

# 2) Git Bash는 ~/bin을 PATH에 자동 포함 → 추가 설정 불필요
git pr-done --version
```

> **참고**: Git Bash는 `~/bin`(= `C:\Users\<USER>\bin`)을 자동으로 PATH에 포함합니다.

#### 옵션 2: WSL (Ubuntu)

WSL(Windows Subsystem for Linux)이 설치되어 있다면 **Linux 섹션** 지침을 그대로 따르세요.

```bash
# PowerShell에서 WSL 실행
wsl

# 이후 Linux 섹션 설치 명령 실행
```

#### 옵션 3: 수동 설치 (Git Bash)

```bash
cd ~/Downloads
git clone https://github.com/kmg733/git-pr-done.git
cp git-pr-done/git-pr-done ~/bin/
chmod +x ~/bin/git-pr-done
```

## 사용법

### 기본

```bash
# 현재 브랜치를 develop에 머지한 후:
git pr-done
```

### 옵션

| 플래그 | 용도 | 기본값 |
|--------|------|--------|
| `-t, --target <BRANCH>` | 타겟 브랜치 | `develop` |
| `-b, --branch <BRANCH>` | 삭제할 브랜치 | 현재 브랜치 |
| `-n, --dry-run` | 시뮬레이션 (실제 실행 없음) | `false` |
| `-f, --force` | 강제 삭제 (squash/rebase 머지 대응) | `false` |
| `-y, --yes` | 확인 프롬프트 스킵 | `false` |
| `-h, --help` | 도움말 출력 | — |
| `-V, --version` | 버전 출력 | — |

### 예시

```bash
# 기본: 현재 브랜치 삭제 후 develop으로 이동
git pr-done

# 타겟 브랜치 지정
git pr-done --target master
git pr-done -t release/2026-H1

# 특정 브랜치 삭제
git pr-done --branch 'feature-name(ISSUE-123)'

# 시뮬레이션만 (실제 변경 없음)
git pr-done --dry-run

# squash/rebase 머지된 브랜치 강제 정리
git pr-done --force

# 확인 프롬프트 없이 즉시 실행
git pr-done -y
```

> **참고**: git은 `git <cmd> --help`를 man 페이지로 가로챕니다. 도움말은 `git pr-done -h` 또는 `git-pr-done --help`를 사용하세요.

## 안전장치

스크립트는 다음 상황에서 자동으로 중단합니다:

- **Dirty tree** — 커밋되지 않은 변경사항이 있을 때
- **보호 브랜치 삭제 시도** — `master`, `main`, `develop`, `production`, `staging`, `release/*`, `hotfix/*`
- **타겟 == 삭제 대상** — 자기 자신을 삭제할 수 없음
- **브랜치 미존재** — 타겟 또는 삭제 대상 브랜치가 없음
- **Detached HEAD** — 정상 브랜치 상태가 아님
- **머지 미확인** — `--force` 없이는 실제 머지된 브랜치만 삭제

## Exit Codes

| 코드 | 의미 |
|------|------|
| `0` | 성공 |
| `1` | 일반 에러 (git repo 아님, 브랜치 없음 등) |
| `2` | 사전 검증 실패 (dirty tree, 보호 브랜치 등) |
| `3` | 사용자 취소 |
| `4` | git 명령 실행 실패 |

## 권장 워크플로우

```bash
# 1. 피처 브랜치에서 작업
git checkout -b feature/awesome-feature
# ... 작업, 커밋, 푸시 ...

# 2. PR/MR 생성 및 리뷰
gh pr create   # 또는 GitLab MR

# 3. 원격에서 머지 완료 후
git pr-done    # 한 줄로 정리 완료
```

## 라이선스

[MIT](LICENSE)
