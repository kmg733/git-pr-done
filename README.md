# git-pr-done

> PR/MR 머지 완료 후 로컬 브랜치를 한 번에 안전하게 정리하는 bash 스크립트

PR이 원격에서 머지되고 나면, 로컬에는 쓸모없어진 피처 브랜치와 stale한 원격 참조가 남습니다. `git-pr-done`은 이 4단계를 안전장치와 함께 한 번에 처리합니다.

```bash
git remote prune origin      # 원격에서 삭제된 참조 정리
git checkout develop          # 타겟 브랜치로 이동
git pull --ff-only            # 최신 커밋 동기화
git branch -d <feature>       # 머지된 브랜치 삭제
```

## 특징

- **플래그 기반 인터페이스** — 괄호/한글 포함 브랜치명도 안전하게 처리
- **안전장치** — dirty tree 감지, 보호 브랜치 블랙리스트, 실제 머지 여부 검증
- **Dry-run 모드** — 실행 전 시뮬레이션 가능
- **`git pr-done` 서브커맨드** — git 명령처럼 자연스럽게 호출
- **의존성 없음** — 순수 bash (git 외 추가 도구 불필요)

## 설치

### 원라이너

```bash
curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/git-pr-done \
  -o ~/.local/bin/git-pr-done && chmod +x ~/.local/bin/git-pr-done
```

`~/.local/bin`이 PATH에 포함되어 있는지 확인하세요:

```bash
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### 수동 설치

```bash
git clone https://github.com/kmg733/git-pr-done.git
cd git-pr-done
install -m 755 git-pr-done ~/.local/bin/git-pr-done
```

## 사용법

### 기본 사용

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

# 특정 브랜치 삭제 (다른 브랜치 체크아웃 상태에서도 가능)
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
- **머지 미확인** — `--force` 없이는 실제 머지된 브랜치만 삭제 (squash/rebase 머지 시 `--force` 필요)

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

## 요구사항

- Bash 3.2+ (macOS 기본 내장 bash 호환)
- Git 2.x+

## 라이선스

[MIT](LICENSE)
