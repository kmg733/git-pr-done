#!/usr/bin/env bash
#
# git-pr-done 설치 스크립트
#
#   설치·업데이트 : curl -fsSL https://raw.githubusercontent.com/kmg733/git-pr-done/main/install.sh | bash
#   제거          : curl -fsSL .../install.sh | bash -s -- --uninstall
#
# 파이프(curl | bash)로 실행되므로 사용자 입력을 기다리지 않는다.
#
set -euo pipefail

readonly REPO="kmg733/git-pr-done"
readonly SCRIPT_NAME="git-pr-done"

REF="${PR_DONE_REF:-main}"
INSTALL_DIR="${PR_DONE_DIR:-}"
SETUP_PATH=true
UNINSTALL=false

if [[ -t 1 ]]; then
    C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'; C_RED=$'\033[0;31m'
    C_BOLD=$'\033[1m';     C_DIM=$'\033[2m';       C_NC=$'\033[0m'
else
    C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''; C_DIM=''; C_NC=''
fi

say()  { echo "  $*"; }
ok()   { echo "${C_GREEN}✓${C_NC} $*"; }
warn() { echo "${C_YELLOW}⚠${C_NC} $*" >&2; }
die()  { echo "${C_RED}✗${C_NC} $*" >&2; exit 1; }

usage() {
    cat <<EOF
${C_BOLD}${SCRIPT_NAME} 설치 스크립트${C_NC}

${C_BOLD}사용법${C_NC}
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- [옵션]

${C_BOLD}옵션${C_NC}
    --dir <경로>     설치 위치 (기본: ~/.local/bin, Git Bash 는 ~/bin)
    --ref <브랜치>   내려받을 git 참조 (기본: main)
    --no-path        셸 설정 파일을 건드리지 않음
    --uninstall      설치된 파일 제거
    -h, --help       이 도움말

${C_BOLD}환경변수${C_NC}
    PR_DONE_DIR      --dir 과 동일
    PR_DONE_REF      --ref 과 동일

${C_BOLD}설치 후 업데이트${C_NC}
    git pr-done --upgrade
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)       [[ $# -ge 2 ]] || die "--dir 에 경로가 필요합니다"; INSTALL_DIR="$2"; shift 2 ;;
        --ref)       [[ $# -ge 2 ]] || die "--ref 에 값이 필요합니다";   REF="$2";         shift 2 ;;
        --no-path)   SETUP_PATH=false; shift ;;
        --uninstall) UNINSTALL=true;   shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "알 수 없는 옵션: $1  (--help 참조)" ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# 설치 위치
# ─────────────────────────────────────────────────────────────

# Git Bash 는 ~/bin 을 PATH 에 자동으로 넣어주므로 그쪽을 쓴다.
default_install_dir() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*) printf '%s\n' "$HOME/bin" ;;
        *)                    printf '%s\n' "$HOME/.local/bin" ;;
    esac
}

[[ -n "$INSTALL_DIR" ]] || INSTALL_DIR="$(default_install_dir)"
TARGET="$INSTALL_DIR/$SCRIPT_NAME"

# ─────────────────────────────────────────────────────────────
# 제거
# ─────────────────────────────────────────────────────────────
if $UNINSTALL; then
    if [[ -e "$TARGET" ]]; then
        rm -f "$TARGET"
        ok "제거했습니다: ${TARGET}"
        say "${C_DIM}셸 설정에 추가된 PATH 줄은 그대로 둡니다. 필요하면 직접 지우세요.${C_NC}"
    else
        ok "설치되어 있지 않습니다: ${TARGET}"
    fi
    exit 0
fi

# ─────────────────────────────────────────────────────────────
# 다운로드
# ─────────────────────────────────────────────────────────────
download() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
    else
        die "curl 또는 wget 이 필요합니다."
    fi
}

# 내려받은 파일이 정말 git-pr-done 인지 확인한다.
# 404 HTML 페이지나 잘린 응답을 그대로 설치하면 안 된다.
looks_like_git_pr_done() {
    local file="$1"
    head -1 "$file" | grep -q '^#!.*bash' || return 1
    grep -q '^readonly SCRIPT_NAME="git-pr-done"' "$file" || return 1
    grep -q '^readonly VERSION=' "$file" || return 1
}

version_of() {
    sed -n 's/^readonly VERSION="\([^"]*\)".*/\1/p' "$1" | head -1
}

URL="https://raw.githubusercontent.com/${REPO}/${REF}/${SCRIPT_NAME}"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

say "${C_DIM}내려받는 중: ${URL}${C_NC}"
download "$URL" "$TMP_FILE" || die "다운로드에 실패했습니다: ${URL}"

looks_like_git_pr_done "$TMP_FILE" \
    || die "내려받은 파일이 ${SCRIPT_NAME} 이 아닙니다. 주소나 --ref 값을 확인하세요."

NEW_VERSION="$(version_of "$TMP_FILE")"
OLD_VERSION=""
[[ -f "$TARGET" ]] && OLD_VERSION="$(version_of "$TARGET" 2>/dev/null || true)"

# ─────────────────────────────────────────────────────────────
# 설치
# ─────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR" || die "설치 폴더를 만들 수 없습니다: ${INSTALL_DIR}"

if [[ -e "$TARGET" && ! -w "$TARGET" ]] || [[ ! -w "$INSTALL_DIR" ]]; then
    die "쓰기 권한이 없습니다: ${TARGET}
  sudo 로 다시 실행하거나 --dir 로 다른 위치를 지정하세요."
fi

if [[ -n "$OLD_VERSION" && "$OLD_VERSION" == "$NEW_VERSION" ]]; then
    ok "이미 최신입니다 (${NEW_VERSION})"
    say "${C_DIM}위치: ${TARGET}${C_NC}"
    exit 0
fi

# 원자적 교체: 임시 파일에 완성한 뒤 옮긴다
cp "$TMP_FILE" "${TARGET}.new"
chmod 755 "${TARGET}.new"
mv -f "${TARGET}.new" "$TARGET"

if [[ -n "$OLD_VERSION" ]]; then
    ok "업데이트 완료: ${C_BOLD}${OLD_VERSION}${C_NC} → ${C_BOLD}${NEW_VERSION}${C_NC}"
else
    ok "${SCRIPT_NAME} ${C_BOLD}${NEW_VERSION}${C_NC} 설치 완료"
fi
say "위치: ${TARGET}"

# ─────────────────────────────────────────────────────────────
# PATH 등록
# ─────────────────────────────────────────────────────────────

# 로그인 셸에 맞는 설정 파일을 고른다. 없으면 ~/.profile 을 쓴다.
shell_rc() {
    case "${SHELL:-}" in
        */zsh)  printf '%s\n' "$HOME/.zshrc" ;;
        */bash) if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
                    printf '%s\n' "$HOME/.bash_profile"
                else
                    printf '%s\n' "$HOME/.bashrc"
                fi ;;
        *)      printf '%s\n' "$HOME/.profile" ;;
    esac
}

path_contains() {
    case ":${PATH}:" in *":$1:"*) return 0 ;; *) return 1 ;; esac
}

if $SETUP_PATH; then
    if path_contains "$INSTALL_DIR"; then
        say "${C_DIM}PATH: 이미 등록되어 있습니다${C_NC}"
    else
        RC="$(shell_rc)"
        LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""
        if [[ -f "$RC" ]] && grep -Fq "$LINE" "$RC"; then
            say "${C_DIM}PATH: ${RC} 에 이미 있습니다${C_NC}"
        else
            printf '\n# git-pr-done\n%s\n' "$LINE" >> "$RC"
            say "PATH: ${RC} 에 등록했습니다"
            warn "새 터미널을 열거나 다음을 실행하세요:  source ${RC}"
        fi
    fi
fi

echo
say "확인:      ${C_BOLD}git pr-done --version${C_NC}"
say "사용법:    ${C_BOLD}git pr-done -h${C_NC}"
say "업데이트:  ${C_BOLD}git pr-done --upgrade${C_NC}"
