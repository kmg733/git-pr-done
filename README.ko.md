# git-pr-done

> PR이 머지된 뒤 내 컴퓨터를 정리하는 명령어 하나.

**[English](README.md)** | **한국어**
---
![Git](https://img.shields.io/badge/Git-F05032?logo=git&logoColor=white)
![Shell](https://img.shields.io/badge/-Shell-4EAA25?logo=gnu-bash&logoColor=white)

---

## 무엇을 해결하나

동료가 GitHub이나 GitLab에서 내 PR을 머지하면, 그 일은 웹사이트에서 일어난다. 내 컴퓨터는 그 사실을 모른다. 그래서 이런 것들이 그대로 남는다.

- 작업이 끝난 내 브랜치
- 서버에서는 이미 지워진 브랜치를 가리키는 링크
- 다들 이미 앞서간 브랜치의 옛날 사본

이걸 손으로 정리하려면 매번 명령어 네 개를 순서대로 쳐야 한다.

```bash
git remote prune origin      # 1
git checkout develop         # 2
git pull --ff-only           # 3
git branch -d my-feature     # 4
```

`git-pr-done`은 이 네 개를 대신 실행한다. 각 단계 전에 안전한 상황인지 확인하고, 이상하면 계속하지 않고 멈춘다.

### 각 단계가 하는 일

| 단계 | 명령어 | 쉽게 말하면 |
|------|--------|------------|
| 1 | `git remote prune origin` | 서버에 더는 없는 브랜치 정보를 잊는다 |
| 2 | `git checkout <타겟>` | 내 작업이 합쳐진 브랜치로 이동한다 |
| 3 | `git pull --ff-only` | 합쳐진 결과를 내려받아 최신으로 맞춘다 |
| 4 | `git branch -d <내 브랜치>` | 다 쓴 내 브랜치를 컴퓨터에서 지운다 |

서버에서 무언가를 지우는 단계는 없다. 전부 내 컴퓨터 안에서 일어나므로, 최악의 경우라도 다시 내려받으면 된다.

### 실행하면 어떤 순서로 진행되나

전반부는 살펴보기만 하고, 후반부에서 실제로 바꾼다. 후반부는 사용자가 진행에 동의하기 전까지 시작하지 않는다.

**전반부 — 확인. 내 것은 아무것도 바뀌지 않는다.**

| | 이런지 확인한다 | 아니면 |
|---|---|---|
| 1 | git 저장소 안에 있는가 | 중단 |
| 2 | 브랜치 위에 서 있는가 | 중단 |
| 3 | 저장하지 않은 변경이 없는가 | 중단하고 목록을 보여준다 |
| 4 | 지우려는 브랜치가 있는가 | 중단 |
| 5 | 그 브랜치가 보호 대상은 아닌가 | 중단 |
| 6 | *(서버에서 최신 브랜치 정보를 읽어온다)* | 알고 있던 정보로 계속 진행 |
| 7 | 어느 브랜치로 갈지 알아냈는가 | 중단하고 물어본다 |
| 8 | 그 브랜치가 지울 브랜치와 다른가 | 중단 |
| 9 | 그 브랜치가 내 컴퓨터에 있는가 | 중단 |
| 10 | 내 작업이 정말 거기 합쳐졌는가 | 중단하고, 내 브랜치에 그대로 남는다 |

10번이 핵심이다. 머지가 안 됐다면 **아무것도 움직이기 전에** 알려주므로, 원래 서 있던 자리에 그대로 있게 된다.

**후반부 — 동의한 뒤 실행.** 위 표의 명령어 네 개.

> 6번은 서버에서 **읽기만** 한다. 동의하기 전에는 지우거나 바꾸는 일이 없으므로, 프롬프트에서 아니오를 고르면 저장소는 실행 전과 완전히 같은 상태로 남는다.

---

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
# PR이 머지된 직후:
git pr-done
```

무엇을 할 것인지 먼저 보여주고, 진행할지 물어본 뒤에 실행한다.

### 3. 자주 쓰는 옵션

```bash
git pr-done --dry-run           # 계획만 보여주고 내 것은 건드리지 않음
git pr-done -t master           # 감지 결과 대신 master로 이동
git pr-done --force             # squash/rebase 머지용 (아래 설명)
git pr-done -h                  # 도움말
```

> **`--dry-run` 에 대해**: 브랜치와 작업 파일은 그대로 둔다. 다만 서버 정보는 새로 읽어온다.
> 그래야 여기서 알려주는 브랜치가 실제 실행 때 쓰일 브랜치와 같아진다.

> **팁**: `--help` 말고 `git pr-done -h`를 쓴다. `--help`는 git이 가로채서 매뉴얼 페이지를 연다.

---

## 어느 브랜치로 이동하나

내 PR이 합쳐진 대상을 **타겟 브랜치**라고 부른다. 보통 `main`, `master`, `develop` 중 하나다.

어느 브랜치인지 직접 알려줄 필요는 없다. `git-pr-done`이 네 가지를 순서대로 시도해서 가장 먼저 나온 답을 쓴다.

| 순서 | 확인하는 곳 | 이 방법이 쓰이는 때 |
|------|------------|-------------------|
| 1 | 이 프로젝트에 저장해 둔 설정 | `git config pr-done.target <브랜치>`를 한 번 실행해 둔 경우 |
| 2 | GitHub / GitLab에 직접 질의 (`gh`, `glab`) | 가장 정확하다. 실제 머지된 PR을 읽는다 |
| 3 | 내 컴퓨터의 git 이력 | `gh`/`glab`이 없거나 로그인되어 있지 않을 때 |
| 4 | 프로젝트 기본 브랜치 (`origin/HEAD`) | 마지막 수단. 그마저도 내 작업이 실제로 거기 머지됐을 때만 |

3번과 4번을 확인하기 전에 서버 정보를 새로 읽어온다. 몇 분 전 웹에서 일어난 머지도 바로 반영된다.

**네 가지가 모두 실패하면 멈추고 물어본다.** 아무 브랜치나 고르지 않는다. 엉뚱한 브랜치로 이동시켜 놓는 것이야말로 되돌리기 성가신 사고이기 때문이다.

그럴 때는 둘 중 하나를 하면 된다.

```bash
# 이번만 지정
git pr-done --target develop

# 또는 이 프로젝트에 저장해서 다시는 신경 쓰지 않기
git config pr-done.target develop
```

### 어느 호스팅인지 알 수 없을 때

GitHub과 GitLab은 완전히 같은 방식으로 다룬다. 리모트 URL의 호스트로 판별하므로 `github.com`, `gitlab.com`은 물론 주소에 그 이름이 들어간 사내 인스턴스도 인식한다. 이름이 전혀 다른 사내 호스트(`git.acme.com`, `ghe.acme.com`)는 추측할 수 없으니 한 번만 알려주면 된다.

```bash
git config pr-done.forge github     # 또는: gitlab
```

지정하지 않아도 2단계를 건너뛰고 3·4단계로 진행할 뿐이다. 호스팅을 잘못 읽어도 해당 CLI가 응답을 거부하므로 잘못된 답이 나오지는 않는다.

### GitHub/GitLab에 물어보는 방법이 정확한 이유

팀이 **squash 머지**나 **rebase 머지**를 쓰면(흔하다) 서버에서 합쳐진 커밋에 새 ID가 붙는다. 내 컴퓨터의 git 이력에는 그 연결고리가 남지 않아서, 이력만으로 추측하는 방법은 실패할 수 있다. GitHub이나 GitLab에 직접 물어보면 이 문제가 없다. 이 방법을 쓰려면 [`gh`](https://cli.github.com) 또는 [`glab`](https://gitlab.com/gitlab-org/cli)이 설치되고 로그인되어 있어야 한다. 필수는 아니다. 없어도 나머지 세 가지 방법은 그대로 동작한다.

---

## 특징

- **타겟 브랜치를 스스로 찾는다** — 가능하면 실제 머지된 PR을 읽는다
- **추측 대신 중단한다** — 틀릴 수 있는 브랜치로 조용히 넘어가지 않는다
- **옮기기 전에 확인한다** — 머지가 안 됐으면 내 브랜치에 그대로 선 채로 알려준다
- **머지 안 된 작업은 지우지 않는다** — `--force` 도 머지 증거를 요구한다
- **안전장치** — 커밋 안 된 작업이 있으면 실행 거부, 보호 브랜치 삭제 거부
- **Dry-run** — 아무것도 바뀌기 전에 전체 계획을 확인
- **`git pr-done`으로 동작** — git 기본 명령어처럼 쓴다
- **의존성이 거의 없다** — bash와 git만 있으면 되고, `gh`/`glab`은 감지 정확도만 높인다

## 요구사항

- Bash 3.2+
- Git 2.x+
- 선택: [`gh`](https://cli.github.com) (GitHub) 또는 [`glab`](https://gitlab.com/gitlab-org/cli) (GitLab) — 가장 정확한 타겟 감지에 사용

## 설치

### macOS

macOS에는 bash와 git이 기본 포함되어 있다. git이 없으면 `xcode-select --install` 또는 [Homebrew](https://brew.sh)로 설치한다.

```bash
# 1) 다운로드 및 설치
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) ~/.local/bin이 PATH에 있는지 확인
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 3) 셸 재시작 후 확인
source ~/.zshrc
git pr-done --version
```

다른 위치: `/usr/local/bin/git-pr-done` (Homebrew 구조, 소유권이 있으면 sudo 불필요)

### Linux

대부분의 배포판에는 bash와 git이 이미 들어 있다. 없다면:

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
# 1) 다운로드 및 설치
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done
chmod +x ~/.local/bin/git-pr-done

# 2) ~/.local/bin이 PATH에 있는지 확인
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# 3) 셸 재시작 후 확인
source ~/.bashrc
git pr-done --version
```

zsh를 쓴다면 `~/.bashrc`를 `~/.zshrc`로 바꾼다.

### Windows

**Git Bash**(Git for Windows에 포함) 또는 **WSL**이 필요하다. PowerShell이나 CMD에서는 실행되지 않는다.

#### 방법 1: Git Bash (권장)

1. [Git for Windows](https://git-scm.com/download/win) 설치 (Git Bash 포함)
2. **Git Bash** 실행
3. 아래 실행:

```bash
# 1) 다운로드 및 설치
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/bin/git-pr-done
chmod +x ~/bin/git-pr-done

# 2) Git Bash는 ~/bin을 PATH에 자동 추가하므로 추가 설정 불필요
git pr-done --version
```

> **참고**: Git Bash는 `~/bin`(= `C:\Users\<USER>\bin`)을 PATH 앞에 자동으로 넣는다.

#### 방법 2: WSL (Ubuntu)

WSL이 있다면 **Linux** 절차를 그대로 따르면 된다.

```powershell
# PowerShell에서
wsl

# 이후 Linux 설치 단계 진행
```

#### 방법 3: 수동 설치 (Git Bash)

```bash
cd ~/Downloads
git clone https://github.com/kmg733/git-pr-done.git
cp git-pr-done/git-pr-done ~/bin/
chmod +x ~/bin/git-pr-done
```

## 사용법

### 기본

```bash
# 현재 브랜치가 머지된 후:
git pr-done
```

### 옵션

| 플래그 | 용도 | 기본값 |
|--------|------|--------|
| `-t, --target <BRANCH>` | 이동할 브랜치 | 자동 감지 (위 설명 참조) |
| `-b, --branch <BRANCH>` | 삭제할 브랜치 | 현재 서 있는 브랜치 |
| `-n, --dry-run` | 계획만 표시, 변경 없음 | `false` |
| `-f, --force` | git 이력에 흔적이 없어도 삭제 (머지 증거는 필요) | `false` |
| `-y, --yes` | 확인 프롬프트 생략 | `false` |
| `-h, --help` | 도움말 | — |
| `-V, --version` | 버전 | — |

### 예시

```bash
# 일반적인 사용: 타겟 감지 → 이동 → 끝난 브랜치 삭제
git pr-done

# 타겟을 직접 지정
git pr-done --target master
git pr-done -t release/2026-H1

# 이 프로젝트의 타겟을 저장해 두고 -t 를 다시 쓰지 않기
git config pr-done.target develop

# 다른 브랜치에 서 있는 채로 특정 브랜치만 삭제
git pr-done --branch 'feature-name(ISSUE-123)'

# 보기만 하고 건드리지 않기
git pr-done --dry-run

# squash/rebase 머지된 브랜치
git pr-done --force

# 확인 프롬프트 없이
git pr-done -y
```

> **참고**: git은 `git <명령> --help`를 가로채 매뉴얼 페이지를 연다. `git pr-done -h` 또는 `git-pr-done --help`를 쓴다.

## 안전장치

아래 상황에서는 스스로 멈춘다.

- **커밋되지 않은 변경이 있을 때** — 작업이 사라지지 않도록 먼저 커밋하거나 stash 한다
- **타겟 브랜치를 알아내지 못했을 때** — 추측하지 않고 물어본다
- **보호 브랜치를 지우려 할 때** — `master`, `main`, `develop`, `production`, `staging`, `release/*`, `hotfix/*`
- **타겟과 삭제 대상이 같을 때** — 지금 서 있는 브랜치는 지울 수 없다
- **브랜치가 없을 때** — 타겟이든 삭제 대상이든
- **브랜치 위에 있지 않을 때** (detached HEAD)
- **머지를 확인할 수 없을 때** — 그리고 이 확인은 **이동하기 전에** 이뤄진다

### "머지했는데 머지 안 됐다고 나온다"

타겟 브랜치에 없는 커밋 목록을 보여주고, 아무것도 바뀌지 않은 채 멈춘다. 내 브랜치에 그대로 서 있다.

가장 흔한 원인은 **squash 머지**나 **rebase 머지**다. 서버가 커밋을 새로 쓰기 때문에 내 컴퓨터에서는 다른 작업처럼 보인다. `gh`나 `glab`이 설치되어 로그인된 상태라면 서버에 물어봐서 대신 확인해 준다.

```bash
git pr-done --force
```

`--force`는 **로컬 이력 검사만 건너뛴다.** **지금 서 있는 이 커밋이** 머지됐다는 증거는 여전히 요구한다. 머지된 PR의 head 커밋과 브랜치 끝을 대조하므로, 같은 이름을 쓴 과거 PR이나 머지 이후에 추가한 커밋은 증거로 인정되지 않는다. 증거가 없으면 거부하고 무엇을 잃게 되는지 보여준다.

```
✗ 머지 증거가 없어 강제 삭제를 거부합니다: 'feat'
  'main' 에 없는 커밋 3개:
    a9e9df7 아직 아무데도 머지 안 된 작업
  위 커밋을 잃어도 괜찮다고 판단되면 직접 실행하세요:
    git branch -D 'feat'
```

정말 머지되지 않은 작업을 지우는 일은 의도적으로 사용자 몫으로 남겨 둔다.

## 멈췄을 때 무슨 뜻인가

| 메시지 | 무슨 일인가 | 어떻게 하나 |
|--------|-------------|-------------|
| `커밋되지 않은 변경사항이 있습니다` | git에 저장하지 않은 수정이 남아 있다 | `git commit -am "..."` 또는 `git stash push -u` |
| `삭제 대상 브랜치가 존재하지 않습니다` | 그런 이름의 브랜치가 없다 | `git branch`로 이름을 확인한다 |
| `보호 브랜치는 삭제할 수 없습니다` | `main`, `develop` 같은 브랜치를 지우려 했다 | `-b`로 실제 지우려던 브랜치를 지정한다 |
| `머지된 타겟 브랜치를 찾지 못했습니다` | 내 작업이 어디로 갔는지 알아내지 못했다 | `--target <브랜치>`, 또는 `git config pr-done.target <브랜치>`로 저장 |
| `타겟 브랜치가 로컬에 존재하지 않습니다` | 서버에는 있지만 내 컴퓨터에는 없다 | `git fetch origin <브랜치>:<브랜치>` |
| `… 에 머지되지 않았습니다` | 타겟에 없는 커밋이 내 브랜치에 있다 | PR이 정말 머지됐는지 확인한다. squash 머지였다면 위 `--force` 설명 참고 |
| `머지 증거가 없어 강제 삭제를 거부합니다` | `--force`로도 *이 커밋들이* 머지됐다는 증거를 찾지 못했다 | 나열된 커밋은 다른 어디에도 없다. 확신할 때만 `git branch -D <브랜치>` |

## 종료 코드

| 코드 | 의미 |
|------|------|
| `0` | 성공 |
| `1` | 일반 에러 (git 저장소 아님, 브랜치 없음 등) |
| `2` | 사전 검증 실패 (커밋 안 된 변경, 보호 브랜치, 타겟 감지 실패) |
| `3` | 프롬프트에서 취소함 |
| `4` | git 명령 실패, 또는 머지 증거가 없어 삭제를 거부함 |

## 권장 워크플로우

```bash
# 1. 기능 브랜치에서 작업
git checkout -b feature/awesome-feature
# ... 수정, 커밋, 푸시 ...

# 2. PR/MR 생성 및 리뷰
gh pr create   # 또는 GitLab MR

# 3. 서버에서 머지된 후
git pr-done    # 한 줄 정리
```

## v1.0에서 올라올 때

v1.0에서는 `-t` 없이 `git pr-done`을 실행하면 내 작업이 어디로 갔든 항상 `develop`으로 이동했다.

v1.1은 실제 타겟을 감지한다. 감지에 실패하면 `develop`으로 넘어가는 대신 멈춘다. 특정 프로젝트에서 예전 동작을 유지하려면:

```bash
git config pr-done.target develop
```

바뀐 점이 두 가지 더 있다.

- **`--force`가 더 이상 무조건적이지 않다.** 예전에는 지목한 브랜치를 그냥 지웠다. 이제는 git 이력이나 `gh`/`glab` 조회로 머지 증거가 확인될 때만 지운다. 정말 머지된 적 없는 브랜치를 지우려면 `git branch -D <브랜치>`를 직접 실행해야 한다.
- **매 실행마다 원격 정보를 먼저 갱신한다.** `--dry-run`도 마찬가지다.

## 개발

테스트는 [bats-core](https://github.com/bats-core/bats-core)를 쓴다.

```bash
brew install bats-core     # 또는: npm install -g bats
bats tests/
```

테스트는 네트워크와 실제 저장소를 건드리지 않는다. 각 테스트가 임시 디렉토리에 일회용 git 저장소를 만들고, `gh`/`glab`은 스텁으로 대체한다.

## 라이선스

[MIT](LICENSE)
