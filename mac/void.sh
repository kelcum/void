#!/bin/bash
#
#  VOID for macOS - send your junk to the void
#  Same look and tools as the Windows version, rebuilt on stock macOS commands.
#  Written for the bash 3.2 that ships with macOS, so: no bash 4 features.
#
#    void             open the menu
#    void <command>   jump straight to a tool   (void help for the list)

VOID_VERSION="1.3"
VOID_HOME="${VOID_HOME:-$HOME/.void}"
HISTORY_FILE="$VOID_HOME/history.log"
THEME_FILE="$VOID_HOME/theme"
BACKUP_DIR="$VOID_HOME/backups"
export LC_ALL=en_US.UTF-8     # character counts and substrings must be UTF-8 aware
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
shopt -s extglob nullglob

COMMANDS=(clean uninstall fix installers purge status disk optimize update tools scan virus history remove)
COMMAND_DESC=("clean junk files" "uninstall apps + their leftovers" "remove launch items whose app is gone"
              "old installers in Downloads / Desktop" "dev junk: node_modules, venvs, build caches"
              "live system dashboard" "what's eating your storage" "flush DNS, free memory, rebuild caches..."
              "update everything with Homebrew" "GitHub power tools (btop, dua, Stats...)"
              "suspicious launch agents + login items" "malware second opinion" "what VOID has done" "uninstall VOID itself")

CMD=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z'); CMD=${CMD#--}
if [[ $CMD == help || $CMD == h || $CMD == '?' ]]; then
    printf '\n  VOID - send your junk to the void\n\n  %-18s%s\n' void "open the menu"
    for i in "${!COMMANDS[@]}"; do printf '  %-18s%s\n' "void ${COMMANDS[i]}" "${COMMAND_DESC[i]}"; done
    echo; exit 0
fi
if [[ -n $CMD && $CMD != __render && $CMD != __selftest ]]; then
    known=0; for c in "${COMMANDS[@]}"; do [[ $c == "$CMD" ]] && known=1; done
    (( known )) || { echo "  unknown command '$CMD' - try: void help"; exit 1; }
fi
if [[ $(uname) != Darwin && -z $VOID_TEST ]]; then
    echo "  this is VOID for macOS - on Windows use the PowerShell version (see the README)"; exit 1
fi
mkdir -p "$VOID_HOME"

# ── look ───────────────────────────────────────────────────────────────
E=$'\e'
R="${E}[0m"; BOLD="${E}[1m"; TRACK="${E}[38;2;58;58;78m"
C_TEXT="${E}[38;2;235;235;245m"; C_DIM="${E}[38;2;120;120;145m"; C_WHITE="${E}[38;2;255;255;255m"
C_GOOD="${E}[38;2;74;222;128m";  C_WARN="${E}[38;2;250;204;21m";  C_BAD="${E}[38;2;248;113;113m"

THEME_NAMES=(void inferno matrix ice sakura toxic)
THEME_A=("168 85 247" "255 60 60" "0 255 120" "100 140 255" "255 90 170" "170 255 0")
THEME_B=("34 211 238" "255 190 40" "0 140 70" "190 245 255" "255 195 225" "0 225 190")

set_theme() {
    local i=0 k
    THEME=void
    for k in "${!THEME_NAMES[@]}"; do [[ ${THEME_NAMES[k]} == "$1" ]] && { i=$k; THEME=$1; }; done
    set -- ${THEME_A[i]}; A_R=$1; A_G=$2; A_B=$3
    set -- ${THEME_B[i]}; B_R=$1; B_G=$2; B_B=$3
    C_ACC="${E}[38;2;${B_R};${B_G};${B_B}m"
    C_PUR="${E}[38;2;${A_R};${A_G};${A_B}m"
    SEL_BG="${E}[48;2;$((A_R * 22 / 100));$((A_G * 22 / 100));$((A_B * 22 / 100))m"
    PILL="${E}[48;2;${B_R};${B_G};${B_B}m${E}[38;2;14;14;24m${BOLD}"
}
set_theme "$(cat "$THEME_FILE" 2>/dev/null)"

BLOCK_W=72
SPARK_CHARS='▁▂▃▄▅▆▇█'
NOISE_CHARS='░▒▓█▚▞▀▄'
SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
TAGLINE='s e n d   y o u r   j u n k   t o   t h e   v o i d'
LOGO=(
    '██╗   ██╗ ██████╗ ██╗██████╗ '
    '██║   ██║██╔═══██╗██║██╔══██╗'
    '██║   ██║██║   ██║██║██║  ██║'
    '╚██╗ ██╔╝██║   ██║██║██║  ██║'
    ' ╚████╔╝ ╚██████╔╝██║██████╔╝'
    '  ╚═══╝   ╚═════╝ ╚═╝╚═════╝ '
)
LOGO_W=29

term_size() { COLS=$(tput cols 2>/dev/null || echo 100); ROWS=$(tput lines 2>/dev/null || echo 30); }
pad_for() { local n=$(( (COLS - $1) / 2 )); (( n < 0 )) && n=0; printf -v PAD '%*s' "$n" ''; }
spaces() { printf -v SP '%*s' "$(( $1 > 0 ? $1 : 0 ))" ''; }
rep() { local s; printf -v s '%*s' "$(( $2 > 0 ? $2 : 0 ))" ''; REP=${s// /$1}; }
vislen() { local t=${1//${E}\[*([0-9;])m/}; VL=${#t}; }
cls() { printf '\e[H\e[2J'; }
at_row() { printf '\e[%d;1H' "$(( $1 + 1 ))"; }

# theme gradient across the text; shine adds a white glow centred on that column  -> GRAD
grad() {
    local text=$1 off=${2:-0} span=${3:-0} shine=${4:--99}
    local n=${#text} i ch p cr cg cb d g out=''
    (( span == 0 )) && span=$n
    local den=$(( span > 1 ? span - 1 : 1 ))
    for (( i = 0; i < n; i++ )); do
        ch=${text:i:1}
        if [[ $ch == ' ' ]]; then out+=' '; continue; fi
        p=$(( (i + off) * 1000 / den )); (( p > 1000 )) && p=1000
        cr=$(( A_R + (B_R - A_R) * p / 1000 )); cg=$(( A_G + (B_G - A_G) * p / 1000 )); cb=$(( A_B + (B_B - A_B) * p / 1000 ))
        if (( shine > -99 )); then
            d=$(( i + off - shine )); (( d < 0 )) && d=$(( -d ))
            if (( d < 5 )); then
                g=$(( (5 - d) * 200 ))
                cr=$(( cr + (255 - cr) * g / 1000 )); cg=$(( cg + (255 - cg) * g / 1000 )); cb=$(( cb + (255 - cb) * g / 1000 ))
            fi
        fi
        out+="${E}[38;2;${cr};${cg};${cb}m${ch}"
    done
    GRAD="$out$R"
}

# 0-100 bar: theme gradient when fine, yellow when high, red when critical; 3rd arg 1 = high is good  -> METER
meter() {
    local pct=${1%.*} w=$2 good=${3:-0} fill lvl f t
    [[ $pct =~ ^-?[0-9]+$ ]] || pct=0
    (( pct < 0 )) && pct=0; (( pct > 100 )) && pct=100
    fill=$(( (w * pct + 50) / 100 )); lvl=$pct; (( good )) && lvl=$(( 100 - pct ))
    rep '━' "$fill"; f=$REP; rep '━' "$(( w - fill ))"; t=$REP
    if (( lvl >= 90 )); then METER="$C_BAD$f$R"
    elif (( lvl >= 75 )); then METER="$C_WARN$f$R"
    elif (( good )); then METER="$C_GOOD$f$R"
    else grad "$f" 0 "$w"; METER=$GRAD; fi
    METER="$METER$TRACK$t$R"
}

spark() {  # values... -> SPARK
    local v i out=''
    for v in "$@"; do
        v=${v%.*}; [[ $v =~ ^[0-9]+$ ]] || v=0
        i=$(( v * 8 / 100 )); (( i > 7 )) && i=7
        if (( v >= 90 )); then out+="$C_BAD"; elif (( v >= 60 )); then out+="$C_WARN"; else out+="$C_ACC"; fi
        out+=${SPARK_CHARS:i:1}
    done
    SPARK="$out$R"
}

# rounded panel with a gradient border -> BOX array; body lines should fit in width-4
box() {
    local title=$1 w=$2; shift 2
    local inner=$(( w - 2 )) line head left right
    BOX=()
    if [[ -n $title ]]; then
        grad '╭─ ' 0 "$w"; head=$GRAD
        rep '─' "$(( inner - 3 - ${#title} ))"; grad " $REP╮" "$(( ${#title} + 3 ))" "$w"
        BOX+=("$head$BOLD$C_TEXT$title$R$GRAD")
    else
        rep '─' "$inner"; grad "╭$REP╮"; BOX+=("$GRAD")
    fi
    left="${E}[38;2;${A_R};${A_G};${A_B}m│$R"; right="${E}[38;2;${B_R};${B_G};${B_B}m│$R"
    for line in "$@"; do
        vislen "$line"; spaces "$(( w - 4 - VL ))"
        BOX+=("$left $line$SP $right")
    done
    rep '─' "$inner"; grad "╰$REP╯"; BOX+=("$GRAD")
}

keys() {  # key label key label ... -> KEYS (little buttons)
    KEYS=''
    while (( $# >= 2 )); do KEYS+="$PILL $1 $R $C_DIM$2$R   "; shift 2; done
}

selrow() {  # text width -> SELROW (whole row in the selection colour)
    vislen "$1"; spaces "$(( $2 - VL ))"
    SELROW="$SEL_BG${1//"$R"/$R$SEL_BG}$SP$R"
}

limit() {  # text n -> LIMIT (cut with … or pad to n)
    local s=$1 n=$2
    if (( ${#s} > n )); then LIMIT="${s:0:$(( n - 1 ))}…"; else spaces "$(( n - ${#s} ))"; LIMIT="$s$SP"; fi
}

fmt_kb() {  # kilobytes -> SIZE
    local k=${1%.*}; [[ $k =~ ^[0-9]+$ ]] || k=0
    if   (( k >= 1073741824 )); then SIZE="$(( k / 1073741824 )).$(( k % 1073741824 * 10 / 1073741824 )) TB"
    elif (( k >= 1048576 ));    then SIZE="$(( k / 1048576 )).$(( k % 1048576 * 10 / 1048576 )) GB"
    elif (( k >= 1024 ));       then SIZE="$(( k / 1024 )) MB"
    elif (( k > 0 ));           then SIZE="$k KB"
    else SIZE="0 MB"; fi
}
fmt_rate() {  # bytes per second -> RATE
    local b=${1%.*}; [[ $b =~ ^[0-9]+$ ]] || b=0
    if (( b >= 1048576 )); then RATE="$(( b / 1048576 )).$(( b % 1048576 * 10 / 1048576 )) MB/s"
    elif (( b >= 1024 )); then RATE="$(( b / 1024 )) KB/s"; else RATE="$b B/s"; fi
}
fmt_age() {  # epoch seconds -> AGE
    local d=$(( ($(date +%s) - $1) / 86400 ))
    if (( d < 1 )); then AGE=today; elif (( d < 2 )); then AGE=yesterday
    elif (( d < 31 )); then AGE="$d days ago"
    elif (( d < 365 )); then (( d / 30 == 1 )) && AGE='1 month ago' || AGE="$(( d / 30 )) months ago"
    else AGE="$(( d / 365 )).$(( d % 365 * 10 / 365 )) years ago"; fi
}
du_kb() {  # paths... -> KB (total size)
    local p total=0 k
    for p in "$@"; do
        [[ -e $p ]] || continue
        k=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
        [[ $k =~ ^[0-9]+$ ]] && total=$(( total + k ))
    done
    KB=$total
}
free_kb() { df -kP "$(data_volume)" 2>/dev/null | awk 'NR==2 {print $4 + 0}'; }
data_volume() { [[ -d /System/Volumes/Data ]] && echo /System/Volumes/Data || echo /; }

say()  { printf '%s  %s%s%s %s%s%s\n' "$P" "$2" "$1" "$R" "$C_TEXT" "$3" "$R"; }
ok()   { say '◆' "$C_GOOD" "$1"; }
warn() { say '▲' "$C_WARN" "$1"; }
fail() { say '■' "$C_BAD" "$1"; }
info() { say '▸' "$C_ACC" "$1"; }
note() { printf '%s  %s%s%s\n' "$P" "$C_DIM" "$1" "$R"; }
log_it() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M')" "$1" >> "$HISTORY_FILE" 2>/dev/null; }

# ── terminal + keys ────────────────────────────────────────────────────
OLD_STTY=''
screen_on()  { OLD_STTY=$(stty -g 2>/dev/null); stty -echo -icanon min 0 time 1 2>/dev/null; printf '\e[?1049h\e[?25l'; }
screen_off() { [[ -n $OLD_STTY ]] && stty "$OLD_STTY" 2>/dev/null; OLD_STTY=''; printf '\e[0m\e[?25h\e[?1049l'; }
cooked() { [[ -n $OLD_STTY ]] && stty "$OLD_STTY" 2>/dev/null; printf '\e[?25h'; }   # for sudo / brew / other tools
raw()    { stty -echo -icanon min 0 time 1 2>/dev/null; printf '\e[?25l'; }

# one byte from the keyboard, or nothing after 0.1s (stty time 1). bash 3.2's read can't time out
# in fractions of a second, so this uses dd, which honours the terminal's timeout.
readbyte() { BYTE=$(dd bs=1 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'); }
getkey() {  # -> KEY: up down left right pgup pgdn home end enter esc space backspace, or the character
    KEY=''
    readbyte; [[ -z $BYTE ]] && return 1
    case $BYTE in
        1b) readbyte; local b1=$BYTE; readbyte; local b2=$BYTE
            case "$b1$b2" in
                5b41|4f41) KEY=up ;;   5b42|4f42) KEY=down ;;  5b43|4f43) KEY=right ;; 5b44|4f44) KEY=left ;;
                5b48|4f48) KEY=home ;; 5b46|4f46) KEY=end ;;
                5b35) readbyte; KEY=pgup ;; 5b36) readbyte; KEY=pgdn ;;
                '') KEY=esc ;; *) KEY=other ;;
            esac ;;
        0a|0d) KEY=enter ;;
        20) KEY=space ;;
        7f|08) KEY=backspace ;;
        *) printf -v KEY "\\x$BYTE" ;;
    esac
    return 0
}
wait_key() { until getkey; do :; done; }

# ── screen pieces ──────────────────────────────────────────────────────
title() {
    cls; term_size; pad_for "$BLOCK_W"; P=$PAD
    grad '◆ VOID'; local left="$GRAD$C_DIM  ›  $R$BOLD$C_TEXT$1$R"
    local right="$C_DIM$(date +%H:%M)  ·  $USER$R" l line
    vislen "$left"; l=$VL; vislen "$right"; spaces "$(( BLOCK_W - 4 - l - VL ))"
    box '' "$BLOCK_W" "$left$SP$right"
    echo; for line in "${BOX[@]}"; do printf '%s%s\n' "$P" "$line"; done; echo
}
wait_back() { echo; keys 'any key' back; printf '%s  %s\n' "$P" "$KEYS"; wait_key; }
confirm() {
    keys y yes n no
    printf '%s  %s?%s %s%s%s   %s' "$P" "$C_WARN" "$R" "$C_TEXT" "$1" "$R" "$KEYS"
    while true; do wait_key; case $KEY in y|Y) echo; return 0 ;; n|N|esc) echo; return 1 ;; esac; done
}
read_line() {  # label -> LINE; returns 1 on esc
    printf '%s  %s%s ▸%s ' "$P" "$C_ACC" "$1" "$R"; printf '\e[?25h'; LINE=''
    while true; do
        wait_key
        case $KEY in
            enter) echo; printf '\e[?25l'; return 0 ;;
            esc) echo; printf '\e[?25l'; return 1 ;;
            backspace) if [[ -n $LINE ]]; then LINE=${LINE%?}; printf '\b \b'; fi ;;
            space) LINE+=' '; printf ' ' ;;
            up|down|left|right|pgup|pgdn|home|end|other) ;;
            *) LINE+=$KEY; printf '%s' "$KEY" ;;
        esac
    done
}

# Arrow-key picker (Mole-style). Fill IT_TEXT (max ~62 visible chars) and IT_ON (1/0) first.
#   picker "title" "hint" multi|single [footer_fn]    -> returns 0 on enter (PICK = cursor), 1 on esc
#   footer_fn gets the cursor index and sets FOOT.
picker() {
    local ttl=$1 hint=$2 mode=$3 footer=$4
    local n=${#IT_TEXT[@]} pos=0 off=0 i row=5 view end mark kb above below all
    PICK=-1
    (( n == 0 )) && return 1
    title "$ttl"
    if [[ -n $hint ]]; then note "$hint"; echo; row=7; fi
    if [[ $mode == single ]]; then keys '↑↓' move enter open esc back
    else keys '↑↓' move space select a all enter go esc back; fi
    kb=$KEYS
    while true; do
        term_size
        view=$(( ROWS - row - 6 )); (( view < 3 )) && view=3
        (( pos < off )) && off=$pos
        (( pos >= off + view )) && off=$(( pos - view + 1 ))
        end=$(( off + view )); (( end > n )) && end=$n
        at_row "$row"
        above=''; (( off > 0 )) && above="▲ $off more"
        printf '%s%s      %s%s\e[K\n' "$P" "$C_DIM" "$above" "$R"
        for (( i = off; i < end; i++ )); do
            if [[ $mode == single ]]; then mark=''
            elif (( IT_ON[i] )); then mark="$C_GOOD●$R  "; else mark="$C_DIM○$R  "; fi
            if (( i == pos )); then
                selrow " $mark${IT_TEXT[i]}" "$(( BLOCK_W - 2 ))"
                printf '%s %s▌%s%s\e[K\n' "$P" "$C_ACC" "$R" "$SELROW"
            else
                printf '%s   %s%s\e[K\n' "$P" "$mark" "${IT_TEXT[i]}"
            fi
        done
        below=''; (( n - end > 0 )) && below="▼ $(( n - end )) more"
        printf '%s%s      %s%s\e[K\n' "$P" "$C_DIM" "$below" "$R"
        FOOT=''; [[ -n $footer ]] && $footer "$pos"
        printf '%s  %s%s%s\e[K\n' "$P" "$C_TEXT" "$FOOT" "$R"
        printf '%s  %s\e[K\e[J' "$P" "$kb"
        wait_key
        case $KEY in
            up|k)   pos=$(( (pos - 1 + n) % n )) ;;
            down|j) pos=$(( (pos + 1) % n )) ;;
            pgup)   pos=$(( pos - view )); (( pos < 0 )) && pos=0 ;;
            pgdn)   pos=$(( pos + view )); (( pos >= n )) && pos=$(( n - 1 )) ;;
            home)   pos=0 ;;
            end)    pos=$(( n - 1 )) ;;
            space)  [[ $mode != single ]] && IT_ON[pos]=$(( 1 - IT_ON[pos] )) ;;
            a|A)    if [[ $mode != single ]]; then
                        all=0; for (( i = 0; i < n; i++ )); do (( IT_ON[i] )) || all=1; done
                        for (( i = 0; i < n; i++ )); do IT_ON[i]=$all; done
                    fi ;;
            enter)  echo; PICK=$pos; return 0 ;;
            esc)    echo; return 1 ;;
        esac
    done
}
footer_size() {  # uses IT_KB: total of the ticked items
    local i t=0; for (( i = 0; i < ${#IT_ON[@]}; i++ )); do (( IT_ON[i] )) && t=$(( t + IT_KB[i] )); done
    fmt_kb "$t"; FOOT="selected: $SIZE"
}

# move to the Trash through Finder, so "Put Back" works and admin-owned apps get a password prompt
to_trash() {
    local q=${1//\\/\\\\}; q=${q//\"/\\\"}
    osascript -e "tell application \"Finder\" to delete POSIX file \"$q\"" >/dev/null 2>&1
    [[ ! -e $1 ]]
}

# ── system data ────────────────────────────────────────────────────────
sys_info() {
    local v major codename
    v=$(sw_vers -productVersion 2>/dev/null); major=${v%%.*}
    case $major in
        26) codename=Tahoe ;; 15) codename=Sequoia ;; 14) codename=Sonoma ;; 13) codename=Ventura ;;
        12) codename=Monterey ;; 11) codename='Big Sur' ;; *) codename='' ;;
    esac
    SYS_OS="macOS $codename $v"; SYS_OS=${SYS_OS//  / }
    SYS_CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    SYS_CPU=${SYS_CPU//(R)/}; SYS_CPU=${SYS_CPU//(TM)/}; SYS_CPU=${SYS_CPU%% @*}
    SYS_CORES=$(sysctl -n hw.ncpu 2>/dev/null); [[ $SYS_CORES =~ ^[0-9]+$ ]] || SYS_CORES=1
    SYS_RAM=$(sysctl -n hw.memsize 2>/dev/null); [[ $SYS_RAM =~ ^[0-9]+$ ]] || SYS_RAM=0
    SYS_RAM=$(( SYS_RAM / 1073741824 ))
    SYS_MODEL=$(sysctl -n hw.model 2>/dev/null)
}

drive_info() {  # DRV_NAME / DRV_SIZE / DRV_FREE (KB): the startup disk plus the first external volume
    DRV_NAME=(); DRV_SIZE=(); DRV_FREE=()
    local dev size usedk avail cap mnt name
    while read -r dev size usedk avail cap mnt name; do
        [[ $size =~ ^[0-9]+$ && $avail =~ ^[0-9]+$ ]] || continue    # skip anything df printed oddly
        DRV_NAME+=("${name:-disk}"); DRV_SIZE+=("$size"); DRV_FREE+=("$avail")
    done < <(df -kP "$(data_volume)" 2>/dev/null | awk 'NR==2 {print $1, $2, $3, $4, $5, "-", "Macintosh HD"}'
             df -kP 2>/dev/null | awk '{ i = index($0, "/Volumes/"); if (i) { print $1, $2, $3, $4, $5, "-", substr($0, i + 9); exit } }')
}

J_NAME=("App caches" "Logs" "Xcode DerivedData" "Xcode device support" "Simulator caches" "npm cache" "Discord cache" "Trash")
J_PATHS=("$HOME/Library/Caches" "$HOME/Library/Logs" "$HOME/Library/Developer/Xcode/DerivedData"
         "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "$HOME/Library/Developer/CoreSimulator/Caches" "$HOME/.npm/_cacache"
         "$HOME/Library/Application Support/discord/Cache|$HOME/Library/Application Support/discord/Code Cache|$HOME/Library/Application Support/discord/GPUCache"
         "$HOME/.Trash")
J_HINT=("apps rebuild these" "" "rebuilds on next build" "re-downloads per device" "" "redownloaded if needed" "" "empties it for good")
J_DEF=(1 1 1 0 1 1 1 0)
J_KB=()

measure_spot() {  # index -> J_KB[index]
    local IFS='|'; local paths=(${J_PATHS[$1]}); IFS=$' \t\n'
    du_kb "${paths[@]}"; J_KB[$1]=$KB
}
junk_total() { local i t=0; for (( i = 0; i < ${#J_NAME[@]}; i++ )); do (( J_DEF[i] )) && t=$(( t + ${J_KB[i]:-0} )); done; JUNK_KB=$t; }

# ── intro / outro ──────────────────────────────────────────────────────
write_logo() {  # row [shine]
    local row=$1 shine=${2:--99} i s
    pad_for "$LOGO_W"
    for (( i = 0; i < ${#LOGO[@]}; i++ )); do
        s=-99; (( shine > -99 )) && s=$(( shine - i * 3 / 2 ))
        grad "${LOGO[i]}" 0 0 "$s"; at_row "$(( row + i ))"; printf '%s%s\e[K' "$PAD" "$GRAD"
    done
}
show_portal() {  # a beam of light opens where the logo will appear
    local row=$1 half line
    pad_for 60
    for (( half = 1; half <= 30; half += 3 )); do
        spaces "$(( 30 - half ))"; rep '━' "$(( half * 2 ))"
        grad "$SP$REP" 0 60 30; at_row "$row"; printf '%s%s\e[K' "$PAD" "$GRAD"; sleep 0.014
    done
}
show_decrypt() {  # the logo decodes out of static
    local row=$1 f i j ch s line frames=18
    pad_for "$LOGO_W"
    for (( f = 0; f <= frames; f++ )); do
        for (( i = 0; i < ${#LOGO[@]}; i++ )); do
            line=${LOGO[i]}; s=''
            for (( j = 0; j < ${#line}; j++ )); do
                ch=${line:j:1}
                if [[ $ch == ' ' ]] || (( RANDOM % frames < f )); then s+=$ch; else s+=${NOISE_CHARS:$(( RANDOM % 8 )):1}; fi
            done
            grad "$s" 0 0 "$(( f * 39 / frames - 5 - i ))"; at_row "$(( row + i ))"; printf '%s%s\e[K' "$PAD" "$GRAD"
        done
        sleep 0.03
    done
}
show_dissolve() {
    local row=$1 f i j ch s line roll frames=14
    pad_for "$LOGO_W"
    for (( f = 0; f <= frames; f++ )); do
        for (( i = 0; i < ${#LOGO[@]}; i++ )); do
            line=${LOGO[i]}; s=''
            for (( j = 0; j < ${#line}; j++ )); do
                ch=${line:j:1}; roll=$(( RANDOM % 100 ))
                if [[ $ch == ' ' ]] || (( roll < f * 80 / frames )); then s+=' '
                elif (( roll < f * 130 / frames )); then s+=${NOISE_CHARS:$(( RANDOM % 8 )):1}
                else s+=$ch; fi
            done
            grad "$s"; at_row "$(( row + i ))"; printf '%s%s\e[K' "$PAD" "$GRAD"
        done
        sleep 0.035
    done
}
show_type() {  # text colour
    local i ch
    pad_for "${#1}"; printf '%s%s' "$PAD" "$2"
    for (( i = 0; i < ${#1}; i++ )); do ch=${1:i:1}; printf '%s' "$ch"; [[ $ch != ' ' ]] && sleep 0.007; done
    printf '%s\n' "$R"
}
show_bar() {  # pct(0-100) label frame  (drawn on BAR_ROW and the row below)
    local w=44 fill spin lab
    fill=$(( w * $1 / 100 ))
    rep '━' "$fill"; grad "$REP" 0 "$w" "$(( ($3 * 2) % (w + 24) - 6 ))"; local bar=$GRAD
    rep '━' "$(( w - fill ))"; bar+="$TRACK$REP$R"
    spin=${SPIN_CHARS:$(( $3 % 10 )):1}
    pad_for "$(( w + 5 ))"; at_row "$BAR_ROW"; printf '%s%s %s%3d%%%s\e[K' "$PAD" "$bar" "$C_TEXT" "$1" "$R"
    lab="$spin $2"; pad_for "${#lab}"; at_row "$(( BAR_ROW + 1 ))"; printf '%s%s%s%s %s%s%s\e[K' "$PAD" "$C_ACC" "$spin" "$R" "$C_DIM" "$2" "$R"
}
show_intro() {
    local top=3 i steps done_pct=0 target frame=0 x lab
    cls; term_size
    show_portal "$(( top + 3 ))"
    show_decrypt "$top"
    write_logo "$top"
    at_row "$(( top + ${#LOGO[@]} + 1 ))"; show_type "$TAGLINE" "$C_DIM"
    BAR_ROW=$(( top + ${#LOGO[@]} + 4 ))
    steps=$(( 3 + ${#J_NAME[@]} ))
    for (( i = 0; i < steps; i++ )); do
        case $i in
            0) lab='reading your hardware'; show_bar "$done_pct" "$lab" "$((frame++))"; sys_info ;;
            1) lab='measuring drives'; show_bar "$done_pct" "$lab" "$((frame++))"; drive_info ;;
            2) lab='counting apps'; show_bar "$done_pct" "$lab" "$((frame++))"; APP_COUNT=$(ls -d /Applications/*.app 2>/dev/null | wc -l | tr -d ' ') ;;
            *) x=$(( i - 3 )); lab="sniffing: $(printf '%s' "${J_NAME[x]}" | tr 'A-Z' 'a-z')"; show_bar "$done_pct" "$lab" "$((frame++))"; measure_spot "$x" ;;
        esac
        target=$(( (i + 1) * 100 / steps ))
        while (( done_pct < target )); do
            done_pct=$(( done_pct + 3 )); (( done_pct > target )) && done_pct=$target
            show_bar "$done_pct" "$lab" "$((frame++))"; sleep 0.008
        done
    done
    for (( x = 0; x < 18; x++ )); do show_bar 100 ready "$((frame++))"; sleep 0.018; done
    junk_total
}
show_outro() {
    cls; term_size; write_logo 3; sleep 0.15; show_dissolve 3
    at_row 6; show_type 'see you in the void.' "$C_ACC"; sleep 0.45
}

# ── main screen ────────────────────────────────────────────────────────
MENU_KEYS=(1 2 3 4 5 6 7 8 9 t s v h '?')
MENU_NAMES=("Clean junk" "Uninstall apps" "Fix launch items" "Old installers" "Dev junk" "Live status" "Disk space"
            "Optimize" "Update everything" "Toolbox" "Suspicious scan" "Virus check" "History" "Commands")
MENU_FN=(do_clean do_uninstall do_fix do_installers do_purge do_status do_disk do_optimize do_update do_tools do_scan do_virus do_history do_commands)
MENU_CMD=(clean uninstall fix installers purge status disk optimize update tools scan virus history '')
MENU_DESC=("app caches, logs, Xcode leftovers, npm + Discord caches, the Trash"
           "search, pick, trash - then sweep what they left in ~/Library"
           "remove launch agents that point at apps you already deleted"
           "dmg / pkg / iso files rotting in Downloads and Desktop"
           "node_modules, venvs, __pycache__ and build caches in your projects"
           "real-time CPU, memory, disk, network, battery + a health score"
           "what's eating your storage - press D inside to explore with dua"
           "flush DNS, free memory, refresh Quick Look, tidy Homebrew"
           "update every Homebrew app and tool at once"
           "GitHub power tools: btop, dua, Stats, Pearcleaner, Mole..."
           "sketchy launch agents, daemons and login items"
           "a second opinion next to XProtect - Malwarebytes or KnockKnock"
           "everything VOID has cleaned, removed and fixed"
           'shortcuts like "void status" you can type in any terminal')
LEFT=(CLEAN 1 2 3 4 5 '' SAFETY s v)
RIGHT=(SYSTEM 6 7 8 9 t '' EXTRA h '?')
NAV_SIDE=(); NAV_ROW=(); NAV_KEY=()
for (( i = 0; i < ${#LEFT[@]}; i++ )); do
    for side in 0 1; do
        if (( side == 0 )); then id=${LEFT[i]}; else id=${RIGHT[i]}; fi
        if [[ -n $id && ! $id =~ ^[A-Z][A-Z]+$ ]]; then NAV_SIDE+=("$side"); NAV_ROW+=("$i"); NAV_KEY+=("$id"); fi
    done
done
SEL=0

menu_index() { local i; MI=-1; for i in "${!MENU_KEYS[@]}"; do [[ ${MENU_KEYS[i]} == "$1" ]] && MI=$i; done; }

move_sel() {
    local cur_side=${NAV_SIDE[SEL]} cur_row=${NAV_ROW[SEL]} i best=-1 bestd=999 d
    case $1 in
        up)   for (( i = ${#NAV_KEY[@]} - 1; i >= 0; i-- )); do
                  (( NAV_SIDE[i] == cur_side && NAV_ROW[i] < cur_row )) && { best=$i; break; }; done
              if (( best < 0 )); then for (( i = ${#NAV_KEY[@]} - 1; i >= 0; i-- )); do (( NAV_SIDE[i] == cur_side )) && { best=$i; break; }; done; fi ;;
        down) for (( i = 0; i < ${#NAV_KEY[@]}; i++ )); do
                  (( NAV_SIDE[i] == cur_side && NAV_ROW[i] > cur_row )) && { best=$i; break; }; done
              if (( best < 0 )); then for (( i = 0; i < ${#NAV_KEY[@]}; i++ )); do (( NAV_SIDE[i] == cur_side )) && { best=$i; break; }; done; fi ;;
        *)    for (( i = 0; i < ${#NAV_KEY[@]}; i++ )); do
                  (( NAV_SIDE[i] == cur_side )) && continue
                  d=$(( NAV_ROW[i] - cur_row )); (( d < 0 )) && d=$(( -d ))
                  (( d < bestd )) && { bestd=$d; best=$i; }
              done ;;
    esac
    (( best >= 0 )) && SEL=$best
}

menu_cell() {  # id selected -> CELL (35 wide)
    local id=$1 w=35 up
    if [[ -z $id ]]; then spaces "$w"; CELL=$SP; return; fi
    if [[ $id =~ ^[A-Z][A-Z]+$ ]]; then rep '─' "$(( w - 5 - ${#id} ))"; CELL="  $BOLD$C_PUR$id$R $TRACK$REP$R  "; return; fi
    menu_index "$id"; up=$(printf '%s' "$id" | tr 'a-z' 'A-Z')
    if (( $2 )); then
        selrow "  $BOLD$C_ACC$up$R  $BOLD$C_WHITE${MENU_NAMES[MI]}$R" "$(( w - 1 ))"; CELL="$C_ACC▌$R$SELROW"
    else
        limit "${MENU_NAMES[MI]}" "$(( w - 6 ))"; CELL="   $C_ACC$up$R  $C_TEXT$LIMIT$R"
    fi
}

main_lines() {  # -> MAIN array
    local i line lp k used
    MAIN=('')
    pad_for "$LOGO_W"; lp=$PAD
    for (( i = 0; i < ${#LOGO[@]}; i++ )); do grad "${LOGO[i]}"; MAIN+=("$lp$GRAD"); done
    pad_for "${#TAGLINE}"; MAIN+=("$PAD$C_DIM$TAGLINE$R" '')
    limit "$SYS_OS" 31; local s1="$BOLD$C_TEXT$LIMIT$R"
    limit "${SYS_CPU:-$SYS_MODEL}" 31; local s2="$C_TEXT$LIMIT$R"
    limit "$SYS_CORES cores · $SYS_RAM GB RAM" 31; local s3="$C_DIM$LIMIT$R"
    local sto=()
    for (( k = 0; k < ${#DRV_NAME[@]} && k < 2; k++ )); do
        used=0; (( DRV_SIZE[k] > 0 )) && used=$(( 100 - DRV_FREE[k] * 100 / DRV_SIZE[k] ))
        meter "$used" 12; fmt_kb "${DRV_FREE[k]}"
        if (( k == 0 )); then limit HD 4; else limit "${DRV_NAME[k]}" 4; fi
        sto+=("$C_TEXT$LIMIT$R $METER $C_DIM$SIZE free$R")
    done
    if (( JUNK_KB > 204800 )); then fmt_kb "$JUNK_KB"; sto+=("$C_WARN$SIZE of junk$R $C_DIM· press 1$R")
    else sto+=("$C_GOOD◆$R ${C_DIM}no junk worth cleaning$R"); fi
    while (( ${#sto[@]} < 3 )); do sto+=(''); done
    (( ${#sto[@]} > 3 )) && sto=("${sto[@]:0:3}")
    box SYSTEM 35 "$s1" "$s2" "$s3"; local bl=("${BOX[@]}")
    box STORAGE 35 "${sto[@]}"; local br=("${BOX[@]}")
    for (( i = 0; i < ${#bl[@]}; i++ )); do MAIN+=("$P${bl[i]}  ${br[i]}"); done
    MAIN+=('')
    local l r
    for (( i = 0; i < ${#LEFT[@]}; i++ )); do
        menu_cell "${LEFT[i]}"  "$(( NAV_SIDE[SEL] == 0 && NAV_ROW[SEL] == i ))"; l=$CELL
        menu_cell "${RIGHT[i]}" "$(( NAV_SIDE[SEL] == 1 && NAV_ROW[SEL] == i ))"; r=$CELL
        MAIN+=("$P$l  $r")
    done
    rep '─' "$BLOCK_W"; MAIN+=("$P$TRACK$REP$R")
    menu_index "${NAV_KEY[SEL]}"; MAIN+=("$P  $C_ACC▸$R $C_TEXT${MENU_DESC[MI]}$R")
    keys '↑↓←→' move enter open c "theme: $THEME" q quit; MAIN+=("$P  $KEYS")
}

show_main() {  # full redraw from the top (no clear, so no flicker)
    local i
    term_size; pad_for "$BLOCK_W"; P=$PAD
    main_lines
    printf '\e[H'
    for (( i = 0; i < ${#MAIN[@]} - 1; i++ )); do printf '%s\e[K\n' "${MAIN[i]}"; done
    printf '%s\e[K\e[J' "${MAIN[${#MAIN[@]}-1]}"
}

read_main_key() {  # waits for a key while a shine sweeps across the logo
    local shine=-10
    while true; do
        getkey && return 0
        (( shine <= LOGO_W + 12 )) && write_logo 1 "$shine"
        shine=$(( shine + 3 )); (( shine > 90 )) && shine=-10
    done
}

do_commands() {
    local i
    title Commands; note 'type these in any terminal to jump straight to a tool'; echo
    printf '%s  %s%-18s%s%s%s%s\n' "$P" "$C_ACC" void "$R" "$C_TEXT" "open the menu" "$R"
    for i in "${!COMMANDS[@]}"; do printf '%s  %s%-18s%s%s%s%s\n' "$P" "$C_ACC" "void ${COMMANDS[i]}" "$R" "$C_TEXT" "${COMMAND_DESC[i]}" "$R"; done
    wait_back
}

# ── 1. clean junk ──────────────────────────────────────────────────────
do_clean() {
    local i before after IFS_OLD p
    title 'Clean junk'; info 'measuring...'
    IT_TEXT=(); IT_ON=(); IT_KB=()
    for i in "${!J_NAME[@]}"; do
        measure_spot "$i"; fmt_kb "${J_KB[i]}"; limit "${J_NAME[i]}" 28; spaces "$(( 9 - ${#SIZE} ))"
        IT_TEXT+=("$C_TEXT$LIMIT$R$C_DIM$SP$SIZE  ${J_HINT[i]}$R"); IT_ON+=("${J_DEF[i]}"); IT_KB+=("${J_KB[i]}")
    done
    picker 'Clean junk' 'pick what to clean - sizes are what VOID found just now' multi footer_size || return
    title 'Clean junk'
    before=$(free_kb)
    for i in "${!J_NAME[@]}"; do
        (( IT_ON[i] )) || continue
        printf '%s  %s▸%s %scleaning %s...%s' "$P" "$C_ACC" "$R" "$C_TEXT" "${J_NAME[i]}" "$R"
        if [[ ${J_NAME[i]} == Trash ]]; then
            osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1
        else
            IFS_OLD=$IFS; IFS='|'; local paths=(${J_PATHS[i]}); IFS=$IFS_OLD
            for p in "${paths[@]}"; do
                [[ -d $p ]] && find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null   # files in use are skipped
            done
        fi
        printf '\r\e[K'; ok "${J_NAME[i]} cleaned"
    done
    after=$(free_kb); fmt_kb "$(( after > before ? after - before : 0 ))"
    echo; ok "freed $SIZE  (anything in use or protected by macOS was skipped)"
    log_it "clean: freed $SIZE"
    for i in "${!J_NAME[@]}"; do measure_spot "$i"; done; junk_total; drive_info
    wait_back
}

# ── 2. uninstall (+ leftovers) ─────────────────────────────────────────
LEFTOVER_DIRS=("Application Support" Caches Preferences "Saved Application State" Containers "Group Containers"
               Logs HTTPStorages WebKit LaunchAgents "Application Scripts" Cookies)

find_leftovers() {  # app_name bundle_id -> appends to LO_PATH / LO_KB
    local name=$1 bid=$2 d entry base lname lbase squashed
    lname=$(printf '%s' "$name" | tr 'A-Z' 'a-z'); squashed=${lname// /}
    for d in "${LEFTOVER_DIRS[@]}"; do
        for entry in "$HOME/Library/$d"/*; do
            base=${entry##*/}; lbase=$(printf '%s' "$base" | tr 'A-Z' 'a-z')
            if [[ -n $bid && $base == *"$bid"* ]] || { (( ${#lname} >= 4 )) && [[ $lbase == "$lname" || $lbase == "$squashed" ]]; }; then
                du_kb "$entry"; LO_PATH+=("$entry"); LO_KB+=("$KB")
            fi
        done
    done
}

do_uninstall() {
    local apps=() names=() bids=() kbs=() a bid i n chosen=() line q lq
    title 'Uninstall apps'; info 'reading your apps...'
    for a in /Applications/*.app "$HOME/Applications"/*.app; do
        bid=$(defaults read "$a/Contents/Info" CFBundleIdentifier 2>/dev/null)
        [[ $bid == com.apple.* ]] && continue      # macOS's own apps stay
        apps+=("$a"); names+=("$(basename "$a" .app)"); bids+=("$bid")
    done
    if (( ${#apps[@]} )); then
        while read -r line; do kbs+=("${line%%[[:space:]]*}"); done < <(du -sk "${apps[@]}" 2>/dev/null)
    fi
    while true; do
        title 'Uninstall apps'
        note 'type part of a name to search, Enter to list everything, Esc to go back'
        note "macOS's own apps aren't listed · bulk job? Pearcleaner is in the Toolbox (T)"; echo
        read_line search || return
        q=$LINE; lq=$(printf '%s' "$q" | tr 'A-Z' 'a-z')
        IT_TEXT=(); IT_ON=(); local idx=()
        for i in "${!apps[@]}"; do
            if [[ -n $lq ]] && [[ $(printf '%s' "${names[i]}" | tr 'A-Z' 'a-z') != *"$lq"* ]]; then continue; fi
            fmt_kb "${kbs[i]:-0}"; limit "${names[i]}" 36; spaces "$(( 9 - ${#SIZE} ))"; local nm=$LIMIT
            limit "${bids[i]}" 15
            IT_TEXT+=("$C_TEXT$nm$R$C_DIM$SP$SIZE  $LIMIT$R"); IT_ON+=(0); idx+=("$i")
        done
        if (( ${#idx[@]} == 0 )); then echo; warn "nothing matches '$q'"; wait_back; continue; fi
        picker 'Uninstall apps' 'select the apps to remove - they go to the Trash' multi || continue
        chosen=(); for i in "${!idx[@]}"; do (( IT_ON[i] )) && chosen+=("${idx[i]}"); done
        (( ${#chosen[@]} )) || continue
        title 'Uninstall apps'
        for i in "${chosen[@]}"; do note "  - ${names[i]}"; done; echo
        confirm "move these ${#chosen[@]} to the Trash?" || continue
        echo
        LO_PATH=(); LO_KB=()
        for i in "${chosen[@]}"; do
            info "removing ${names[i]}"
            [[ -n ${bids[i]} ]] && osascript -e "quit app id \"${bids[i]}\"" >/dev/null 2>&1
            if to_trash "${apps[i]}"; then
                ok "${names[i]} moved to the Trash"; log_it "uninstalled ${names[i]}"
                find_leftovers "${names[i]}" "${bids[i]}"
            else
                fail "${names[i]}: couldn't move it (Terminal may need permission to control Finder)"
            fi
        done
        if (( ${#LO_PATH[@]} )); then
            echo; info "found ${#LO_PATH[@]} leftover item(s)..."; sleep 0.9
            IT_TEXT=(); IT_ON=(); IT_KB=()
            for i in "${!LO_PATH[@]}"; do
                fmt_kb "${LO_KB[i]}"; limit "${LO_PATH[i]/#$HOME/\~}" 50; spaces "$(( 9 - ${#SIZE} ))"
                IT_TEXT+=("$C_TEXT$LIMIT$R$C_DIM$SP$SIZE$R"); IT_ON+=(1); IT_KB+=("${LO_KB[i]}")
            done
            if picker Leftovers 'what the apps left in ~/Library - it goes to the Trash' multi footer_size; then
                title Leftovers; n=0
                for i in "${!LO_PATH[@]}"; do
                    (( IT_ON[i] )) || continue
                    if to_trash "${LO_PATH[i]}"; then ok "trashed ${LO_PATH[i]/#$HOME/\~}"; n=$(( n + 1 )); else fail "${LO_PATH[i]/#$HOME/\~}"; fi
                done
                log_it "leftovers: trashed $n item(s)"
            fi
        fi
        # refresh the list without the removed apps
        for i in "${chosen[@]}"; do [[ -e ${apps[i]} ]] || { names[i]=''; }; done
        local na=() nn=() nb=() nk=()
        for i in "${!apps[@]}"; do [[ -n ${names[i]} ]] && { na+=("${apps[i]}"); nn+=("${names[i]}"); nb+=("${bids[i]}"); nk+=("${kbs[i]}"); }; done
        apps=("${na[@]}"); names=("${nn[@]}"); bids=("${nb[@]}"); kbs=("${nk[@]}")
        wait_back
    done
}

# ── 3. fix launch items ────────────────────────────────────────────────
plist_program() {  # plist -> PROG (the executable it launches)
    PROG=$(/usr/libexec/PlistBuddy -c 'Print :Program' "$1" 2>/dev/null)
    [[ -z $PROG ]] && PROG=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$1" 2>/dev/null)
}
launch_dirs() { LAUNCH_DIRS=("$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons); }

remove_launch_item() {  # plist
    local f=$1
    mkdir -p "$BACKUP_DIR"; cp "$f" "$BACKUP_DIR/" 2>/dev/null
    if [[ $f == "$HOME"/* ]]; then
        launchctl bootout "gui/$(id -u)" "$f" >/dev/null 2>&1
        rm -f "$f"
    else
        cooked
        sudo launchctl bootout system "$f" >/dev/null 2>&1
        sudo rm -f "$f"
        raw
    fi
    [[ ! -e $f ]]
}

do_fix() {
    local d f found=() why=() i
    title 'Fix launch items'; info 'checking launch agents and daemons...'
    launch_dirs
    for d in "${LAUNCH_DIRS[@]}"; do
        for f in "$d"/*.plist; do
            plist_program "$f"
            if [[ $PROG == /* && ! -e $PROG ]]; then found+=("$f"); why+=("app gone: ${PROG##*/}"); fi
        done
    done
    if (( ${#found[@]} == 0 )); then title 'Fix launch items'; ok 'every launch item points at something real'; wait_back; return; fi
    IT_TEXT=(); IT_ON=()
    for i in "${!found[@]}"; do
        limit "$(basename "${found[i]}" .plist)" 34; IT_TEXT+=("$C_TEXT$LIMIT$R  $C_DIM${why[i]}$R"); IT_ON+=(1)
    done
    picker 'Fix launch items' 'startup items whose app is already deleted - backed up first' multi || return
    title 'Fix launch items'
    for i in "${!found[@]}"; do
        (( IT_ON[i] )) || continue
        if remove_launch_item "${found[i]}"; then ok "removed $(basename "${found[i]}")"; log_it "removed launch item $(basename "${found[i]}")"
        else fail "couldn't remove ${found[i]}"; fi
    done
    echo; note "backups: $BACKUP_DIR"
    wait_back
}

# ── 4. old installers ──────────────────────────────────────────────────
do_installers() {
    local files=() f i now ext mt sz
    title 'Old installers'; info 'looking in Downloads and Desktop...'
    while IFS= read -r f; do files+=("$f"); done < <(find "$HOME/Downloads" "$HOME/Desktop" -maxdepth 2 -type f \
        \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.mpkg' -o -iname '*.iso' -o -iname '*.xip' -o -iname '*.zip' \) 2>/dev/null)
    if (( ${#files[@]} == 0 )); then title 'Old installers'; ok 'no installers lying around'; wait_back; return; fi
    IT_TEXT=(); IT_ON=(); IT_KB=(); now=$(date +%s)
    for f in "${files[@]}"; do
        sz=$(stat -f %z "$f" 2>/dev/null || echo 0); mt=$(stat -f %m "$f" 2>/dev/null || echo "$now")
        fmt_kb "$(( sz / 1024 ))"; fmt_age "$mt"; limit "${f##*/}" 34; spaces "$(( 9 - ${#SIZE} ))"
        IT_TEXT+=("$C_TEXT$LIMIT$R$C_DIM$SP$SIZE  $AGE$R"); IT_KB+=("$(( sz / 1024 ))")
        ext=$(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z')
        # pre-tick real installers that are at least a day old; zips might be something you need
        if [[ $ext != zip ]] && (( now - mt >= 86400 )); then IT_ON+=(1); else IT_ON+=(0); fi
    done
    picker 'Old installers' 'setup files you already ran - picked ones go to the Trash' multi footer_size || return
    title 'Old installers'; local n=0
    for i in "${!files[@]}"; do
        (( IT_ON[i] )) || continue
        if to_trash "${files[i]}"; then ok "trashed ${files[i]##*/}"; n=$(( n + 1 )); else fail "${files[i]##*/}"; fi
    done
    log_it "installers: trashed $n file(s)"
    wait_back
}

# ── 5. dev junk ────────────────────────────────────────────────────────
do_purge() {
    local roots=() r d found=() name parent mt now i risky recent
    title 'Dev junk'
    for r in "$HOME/Desktop" "$HOME/Documents" "$HOME/Developer" "$HOME/Projects" "$HOME/projects" "$HOME/code" \
             "$HOME/Code" "$HOME/dev" "$HOME/src" "$HOME/GitHub" "$HOME/repos" "$HOME/workspace"; do
        [[ -d $r ]] && roots+=("$r")
    done
    for r in "${roots[@]}"; do
        printf '\r%s  %s▸%s %sscanning %s%s\e[K' "$P" "$C_ACC" "$R" "$C_TEXT" "${r/#$HOME/\~}" "$R"
        while IFS= read -r d; do
            name=${d##*/}; parent=${d%/*}
            case $name in
                .venv|venv|env) [[ -f $d/pyvenv.cfg ]] || continue ;;
                target)         [[ -f $parent/Cargo.toml ]] || continue ;;
                dist|build)     [[ -f $parent/package.json ]] || continue ;;
            esac
            found+=("$d")
        done < <(find "$r" -mindepth 1 -maxdepth 8 -type d \( \
                    \( -name node_modules -o -name __pycache__ -o -name .pytest_cache -o -name .mypy_cache -o -name .ruff_cache \
                       -o -name .next -o -name .nuxt -o -name .turbo -o -name .parcel-cache -o -name .svelte-kit \
                       -o -name .venv -o -name venv -o -name env -o -name target -o -name dist -o -name build \) -print -prune \
                    -o \( -name '.*' -o -name Library \) -prune \) 2>/dev/null)
    done
    printf '\r\e[K'
    if (( ${#found[@]} == 0 )); then ok 'no node_modules, venvs or build caches found'; wait_back; return; fi
    IT_TEXT=(); IT_ON=(); IT_KB=(); NOTES=(); now=$(date +%s)
    for i in "${!found[@]}"; do
        d=${found[i]}
        printf '\r%s  %s%s%s %smeasuring %d/%d...%s\e[K' "$P" "$C_ACC" "${SPIN_CHARS:$(( i % 10 )):1}" "$R" "$C_TEXT" "$(( i + 1 ))" "${#found[@]}" "$R"
        du_kb "$d"; mt=$(stat -f %m "${d%/*}" 2>/dev/null || echo "$now")
        fmt_kb "$KB"; fmt_age "$mt"; limit "${d/#$HOME/\~}" 38; spaces "$(( 9 - ${#SIZE} ))"
        IT_TEXT+=("$C_TEXT$LIMIT$R$C_DIM$SP$SIZE  $AGE$R"); IT_KB+=("$KB")
        # build output and venvs can be what something runs from - and projects touched this week are probably in use
        risky=0; case ${d##*/} in dist|build|target|.venv|venv|env) risky=1 ;; esac
        recent=0; (( now - mt < 604800 )) && recent=1
        if (( risky )); then NOTES+=('something may run from this - rebuild after'); elif (( recent )); then NOTES+=('project touched this week'); else NOTES+=(''); fi
        (( risky || recent )) && IT_ON+=(0) || IT_ON+=(1)
    done
    printf '\r\e[K'
    picker 'Dev junk' 'rebuildable (npm/pip install brings it back) - deleted for good' multi footer_purge || return
    title 'Dev junk'; local n=0
    for i in "${!found[@]}"; do
        (( IT_ON[i] )) || continue
        rm -rf "${found[i]}" 2>/dev/null
        if [[ -e ${found[i]} ]]; then warn "partly removed: ${found[i]/#$HOME/\~}"; else ok "deleted ${found[i]/#$HOME/\~}"; n=$(( n + 1 )); fi
    done
    log_it "dev junk: deleted $n folder(s)"
    wait_back
}
footer_purge() { footer_size; FOOT+="   $C_WARN${NOTES[$1]}$R"; }

# ── 6. live status ─────────────────────────────────────────────────────
NET_PREV_RX=0; NET_PREV_TX=0; NET_PREV_T=0
status_stats() {
    local vm now rx tx dt line boot
    ST_CPU=$(ps -A -o %cpu= 2>/dev/null | awk -v c="$SYS_CORES" '{s+=$1} END {v=s/(c>0?c:1); if (v>100) v=100; printf "%d", v}')
    vm=$(vm_stat 2>/dev/null)
    ST_MEM_USED=$(printf '%s\n' "$vm" | awk '/page size of/ {ps=$8} /Pages active/ {a=$3} /Pages wired down/ {w=$4}
                  /Pages occupied by compressor/ {c=$5} END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); printf "%d", (a+w+c)*ps/1024}')
    ST_MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null); [[ $ST_MEM_TOTAL =~ ^[0-9]+$ ]] || ST_MEM_TOTAL=1024
    ST_MEM_TOTAL=$(( ST_MEM_TOTAL / 1024 ))
    ST_MEM_PCT=$(( ST_MEM_USED * 100 / (ST_MEM_TOTAL > 0 ? ST_MEM_TOTAL : 1) ))
    local dsize davail
    read -r dsize davail <<< "$(df -kP "$(data_volume)" 2>/dev/null | awk 'NR==2 {print $2, $4}')"
    [[ $dsize =~ ^[0-9]+$ && $davail =~ ^[0-9]+$ ]] && (( dsize > 0 )) || { dsize=1; davail=1; }
    ST_DISK_FREE_PCT=$(( davail * 100 / dsize ))
    line=$(netstat -ibn 2>/dev/null | awk '$1 ~ /^en/ && $3 ~ /Link/ {rx+=$7; tx+=$10} END {printf "%d %d", rx, tx}'); set -- $line
    rx=${1:-0}; tx=${2:-0}; now=$SECONDS; dt=$(( now - NET_PREV_T )); (( dt < 1 )) && dt=1
    if (( NET_PREV_T > 0 )); then ST_DOWN=$(( (rx - NET_PREV_RX) / dt )); ST_UP=$(( (tx - NET_PREV_TX) / dt )); else ST_DOWN=0; ST_UP=0; fi
    (( ST_DOWN < 0 )) && ST_DOWN=0; (( ST_UP < 0 )) && ST_UP=0
    NET_PREV_RX=$rx; NET_PREV_TX=$tx; NET_PREV_T=$now
    ST_LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3, $4}')
    boot=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[ ,]+' '{print $4}')
    [[ $boot =~ ^[0-9]+$ ]] || boot=$(date +%s)
    ST_UP_S=$(( $(date +%s) - boot ))
    line=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%;[^;]+' | head -1)
    ST_BATT=${line%%\%*}; ST_BATT_STATE=${line#*; }
    [[ $ST_BATT =~ ^[0-9]+$ ]] || { ST_BATT=''; ST_BATT_STATE=''; }
    ST_TOP=()
    while IFS= read -r line; do ST_TOP+=("$line"); done < <(ps -Aceo pcpu=,rss=,comm= 2>/dev/null | awk -v cores="$SYS_CORES" '
        { cpu=$1; rss=$2; $1=""; $2=""; sub(/^ +/, ""); c[$0]+=cpu; m[$0]+=rss; n[$0]++ }
        END { for (k in c) printf "%.1f\t%d\t%d\t%s\n", c[k]/(cores>0?cores:1), m[k], n[k], k }' | sort -t$'\t' -k1,1nr -k2,2nr | head -6)
}

health() {  # -> HEALTH, HEALTH_NOTES
    HEALTH=100; HEALTH_NOTES=()
    (( ST_CPU >= 90 )) && { HEALTH=$(( HEALTH - 15 )); HEALTH_NOTES+=('CPU is maxed out'); }
    if (( ST_MEM_PCT >= 90 )); then HEALTH=$(( HEALTH - 20 )); HEALTH_NOTES+=('memory is almost full - close some apps')
    elif (( ST_MEM_PCT >= 75 )); then HEALTH=$(( HEALTH - 8 )); fi
    if (( ST_DISK_FREE_PCT < 10 )); then HEALTH=$(( HEALTH - 20 )); HEALTH_NOTES+=('your disk is almost full')
    elif (( ST_DISK_FREE_PCT < 20 )); then HEALTH=$(( HEALTH - 8 )); HEALTH_NOTES+=('your disk is getting full'); fi
    (( ST_UP_S >= 604800 )) && { HEALTH=$(( HEALTH - 10 )); HEALTH_NOTES+=("no restart in $(( ST_UP_S / 86400 )) days - a restart helps"); }
    if [[ -n $ST_BATT && $ST_BATT_STATE == discharging* ]] && (( ST_BATT < 20 )); then HEALTH=$(( HEALTH - 10 )); HEALTH_NOTES+=('battery is low'); fi
    (( JUNK_KB >= 5242880 )) && { fmt_kb "$JUNK_KB"; HEALTH=$(( HEALTH - 5 )); HEALTH_NOTES+=("$SIZE of junk - run Clean"); }
    (( HEALTH < 0 )) && HEALTH=0
}

stat_row() {  # label pct detail [high-is-good] -> ROW
    local pct=${2%.*}; meter "$pct" 22 "${4:-0}"
    printf -v ROW '%s%s%-5s%s%4d%%  %s  %s%s%s' "$BOLD" "$C_TEXT" "$1" "$R" "$pct" "$METER" "$C_DIM" "$3" "$R"
}

status_lines() {  # history... -> STATUS array
    local hc hw live=() apps=() n t cpu rss cnt name up
    if (( HEALTH >= 80 )); then hc=$C_GOOD; hw=good; elif (( HEALTH >= 60 )); then hc=$C_WARN; hw=okay; else hc=$C_BAD; hw='needs attention'; fi
    if (( ST_UP_S >= 86400 )); then up="$(( ST_UP_S / 86400 ))d $(( ST_UP_S % 86400 / 3600 ))h"; else up="$(( ST_UP_S / 3600 ))h $(( ST_UP_S % 3600 / 60 ))m"; fi
    meter "$HEALTH" 16 1; limit "$hw" 16
    live+=("${BOLD}${C_TEXT}HEALTH$R $BOLD$hc$HEALTH$R$C_DIM/100$R  $hc$LIMIT$R$METER   ${C_DIM}up $up$R")
    for n in "${HEALTH_NOTES[@]}"; do live+=("$C_DIM       · $n$R"); done
    live+=('')
    stat_row CPU "$ST_CPU" "$SYS_CORES cores · load ${ST_LOAD%% *}"; live+=("$ROW")
    spark "$@"; live+=("            $SPARK  ${C_DIM}history$R")
    fmt_kb "$ST_MEM_USED"; local mu=$SIZE; fmt_kb "$ST_MEM_TOTAL"
    stat_row MEM "$ST_MEM_PCT" "$mu / $SIZE"; live+=("$ROW")
    stat_row DISK "$(( 100 - ST_DISK_FREE_PCT ))" "$ST_DISK_FREE_PCT% free"; live+=("$ROW")
    if [[ -n $ST_BATT ]]; then stat_row BATT "$ST_BATT" "$ST_BATT_STATE" 1; live+=("$ROW"); fi
    fmt_rate "$ST_DOWN"; local down=$RATE; fmt_rate "$ST_UP"; limit "$down" 12
    live+=("${BOLD}${C_TEXT}NET$R          $C_ACC▼$R $LIMIT $C_PUR▲$R $RATE")
    printf -v t '%-40s%8s%11s' APP CPU RAM; apps+=("$C_DIM$t$R")
    for t in "${ST_TOP[@]}"; do
        IFS=$'\t' read -r cpu rss cnt name <<< "$t"
        (( cnt > 1 )) && name="$name ×$cnt"
        limit "$name" 40; fmt_kb "$rss"
        apps+=("$C_TEXT$LIMIT$R$C_ACC$(printf '%7s%%' "$cpu")$R$C_DIM$(printf '%11s' "$SIZE")$R")
    done
    STATUS=()
    box LIVE "$BLOCK_W" "${live[@]}"; STATUS+=("${BOX[@]}")
    box 'TOP APPS' "$BLOCK_W" "${apps[@]}"; STATUS+=("${BOX[@]}")
}

do_status() {
    local hist=() tick line leave
    title 'Live status'; info 'warming up sensors...'
    NET_PREV_T=0; status_stats; sleep 1
    title 'Live status'
    while true; do
        status_stats; health
        hist+=("$ST_CPU"); (( ${#hist[@]} > 40 )) && hist=("${hist[@]:1}")
        status_lines "${hist[@]}"
        at_row 5
        for line in "${STATUS[@]}"; do printf '%s%s\e[K\n' "$P" "$line"; done
        keys q back b 'open btop'
        printf '\e[K\n%s  %s%s%s live%s\e[K\e[J' "$P" "$KEYS" "$C_DIM" "${SPIN_CHARS:$(( ${#hist[@]} % 10 )):1}" "$R"
        # listen for keys the whole time between frames (~1s)
        leave=''
        for (( tick = 0; tick < 8; tick++ )); do
            if getkey; then
                case $KEY in q|Q|esc) return ;; b|B) leave=btop; break ;; esac
            fi
        done
        if [[ $leave == btop ]]; then run_tool 0; title 'Live status'; fi
    done
}

# ── 7. disk space ──────────────────────────────────────────────────────
do_disk() {
    local body=() line kb path k used
    title 'Disk space'; drive_info
    for (( k = 0; k < ${#DRV_NAME[@]}; k++ )); do
        used=0; (( DRV_SIZE[k] > 0 )) && used=$(( 100 - DRV_FREE[k] * 100 / DRV_SIZE[k] ))
        meter "$used" 30; fmt_kb "${DRV_FREE[k]}"; local fr=$SIZE; fmt_kb "${DRV_SIZE[k]}"; limit "${DRV_NAME[k]}" 12
        body+=("$BOLD$C_TEXT$LIMIT$R $METER  $C_TEXT$fr free$R$C_DIM / $SIZE$R")
    done
    box DRIVES "$BLOCK_W" "${body[@]}"; for line in "${BOX[@]}"; do printf '%s%s\n' "$P" "$line"; done
    printf '%s  %smeasuring apps...%s\r' "$P" "$C_DIM" "$R"
    body=()
    while read -r kb path; do
        fmt_kb "$kb"; limit "$(basename "$path" .app)" 52; body+=("$C_TEXT$LIMIT$R$C_DIM$(printf '%12s' "$SIZE")$R")
    done < <(du -sk /Applications/*.app 2>/dev/null | sort -rn | head -8)
    printf '\e[K'; box 'BIGGEST APPS' "$BLOCK_W" "${body[@]}"; for line in "${BOX[@]}"; do printf '%s%s\n' "$P" "$line"; done
    printf '%s  %smeasuring your home folder...%s\r' "$P" "$C_DIM" "$R"
    body=()
    while read -r kb path; do
        fmt_kb "$kb"; limit "~/${path##*/}" 52; body+=("$C_TEXT$LIMIT$R$C_DIM$(printf '%12s' "$SIZE")$R")
    done < <(du -sk "$HOME"/* 2>/dev/null | sort -rn | head -6)
    printf '\e[K'; box 'HOME FOLDER' "$BLOCK_W" "${body[@]}"; for line in "${BOX[@]}"; do printf '%s%s\n' "$P" "$line"; done
    (( JUNK_KB > 204800 )) && { fmt_kb "$JUNK_KB"; warn "$SIZE of junk - press 1 on the main menu to clean it"; }
    echo; keys d 'explore with dua' 'any key' back; printf '%s  %s\n' "$P" "$KEYS"
    wait_key; [[ $KEY == d || $KEY == D ]] && run_tool 2
}

# ── 8. optimize ────────────────────────────────────────────────────────
O_NAME=("Flush DNS cache" "Free inactive memory" "Refresh Quick Look" "Homebrew cleanup" "Restart Dock & Finder" "Rebuild Spotlight index" "Rebuild 'Open With' menu")
O_HINT=("fixes sites that won't load" "sudo purge" "fixes stale file previews" "old versions + downloads" "fixes a glitchy Dock" "search is slow for a while" "removes duplicate entries")
O_DEF=(1 1 1 1 0 0 0)
O_SUDO=(1 1 0 0 0 1 0)

run_optimize() {  # index
    case $1 in
        0) sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder ;;
        1) sudo purge ;;
        2) qlmanage -r >/dev/null 2>&1; qlmanage -r cache >/dev/null 2>&1 ;;
        3) command -v brew >/dev/null && { brew cleanup -s; brew autoremove; } ;;
        4) killall Dock Finder ;;
        5) sudo mdutil -E / ;;
        6) /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user ;;
    esac
}

do_optimize() {
    local i need_sudo=0
    IT_TEXT=(); IT_ON=()
    for i in "${!O_NAME[@]}"; do limit "${O_NAME[i]}" 28; IT_TEXT+=("$C_TEXT$LIMIT$R$C_DIM${O_HINT[i]}$R"); IT_ON+=("${O_DEF[i]}"); done
    command -v brew >/dev/null || IT_ON[3]=0
    picker Optimize 'safe maintenance - pick what to run (some ask for your password)' multi || return
    title Optimize
    for i in "${!O_NAME[@]}"; do (( IT_ON[i] && O_SUDO[i] )) && need_sudo=1; done
    cooked
    (( need_sudo )) && { note 'a few of these need your Mac password:'; sudo -v; }
    for i in "${!O_NAME[@]}"; do
        (( IT_ON[i] )) || continue
        info "${O_NAME[i]}..."
        if run_optimize "$i" >/dev/null 2>&1; then ok "${O_NAME[i]} done"; else warn "${O_NAME[i]} didn't finish cleanly"; fi
    done
    raw
    log_it "optimize ran"
    wait_back
}

# ── 9. update everything ───────────────────────────────────────────────
ensure_brew() {
    command -v brew >/dev/null && return 0
    warn "Homebrew isn't installed - it's how VOID updates apps and installs tools"
    note 'brew.sh - the standard package manager for macOS'; echo
    confirm 'install Homebrew now?' || return 1
    cooked; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; raw
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    command -v brew >/dev/null
}

do_update() {
    title 'Update everything'
    ensure_brew || { wait_back; return; }
    info 'checking for updates...'; echo
    cooked; brew update >/dev/null 2>&1; brew outdated; raw
    echo
    if confirm 'update everything listed above?'; then
        echo; cooked; brew upgrade; command -v mas >/dev/null && mas upgrade; raw
        echo; ok done; log_it 'updated everything with Homebrew'
    fi
    note 'macOS itself updates in System Settings > General > Software Update'
    wait_back
}

# ── T. toolbox (open-source GitHub tools, installed on demand with Homebrew) ──
T_NAME=(btop bottom dua fastfetch Stats Pearcleaner dupeGuru KnockKnock Mole)
T_REPO=(aristocratos/btop ClementTsang/bottom Byron/dua-cli fastfetch-cli/fastfetch exelban/stats
        alienator88/Pearcleaner arsenetar/dupeguru objective-see/KnockKnock tw93/Mole)
T_BREW=(btop bottom dua-cli fastfetch "--cask stats" "--cask pearcleaner" "--cask dupeguru" "--cask knockknock" mole)
T_BIN=(btop btm dua fastfetch '' '' '' '' mo)
T_APP=('' '' '' '' Stats Pearcleaner dupeGuru KnockKnock '')
T_KIND=(tui tui tui cli app app app app tui)
T_DESC=("the prettiest full-screen system monitor there is" "graphs for CPU, memory, network, disks and temps"
        "explore folders by size and delete from inside" "your specs as a screenshot-worthy card"
        "system stats right in your menu bar" "drag an app in, it finds every leftover"
        "find duplicate files, music and photos" "see everything that auto-starts (malware check)"
        "the Mac cleaner that inspired VOID")

tool_ready() {  # index
    if [[ -n ${T_BIN[$1]} ]]; then command -v "${T_BIN[$1]}" >/dev/null
    else [[ -d "/Applications/${T_APP[$1]}.app" || -d "$HOME/Applications/${T_APP[$1]}.app" ]]; fi
}

run_tool() {  # index
    local i=$1
    if ! tool_ready "$i"; then
        title "${T_NAME[i]}"
        info "${T_NAME[i]} isn't installed yet"; note "github.com/${T_REPO[i]}"; note "installs with: brew install ${T_BREW[i]}"; echo
        ensure_brew || { wait_back; return; }
        confirm "install ${T_NAME[i]}?" || return
        echo; cooked; brew install ${T_BREW[i]}; raw
        tool_ready "$i" || { fail "couldn't find ${T_NAME[i]} after installing"; wait_back; return; }
        log_it "installed ${T_NAME[i]}"
    fi
    case ${T_KIND[i]} in
        app) open -a "${T_APP[i]}" ;;
        cli) cls; cooked; echo; "${T_BIN[i]}"; raw; wait_back ;;
        *)   cls; cooked
             if [[ ${T_NAME[i]} == dua ]]; then dua i "$HOME"; else "${T_BIN[i]}"; fi
             raw ;;
    esac
}

do_tools() {
    local i state
    while true; do
        IT_TEXT=(); IT_ON=()
        for i in "${!T_NAME[@]}"; do
            if tool_ready "$i"; then state="$C_GOOD● ready$R"; else state="$C_DIM○ get$R"; fi
            limit "${T_NAME[i]}" 14; local nm=$LIMIT; limit "${T_REPO[i]}" 32
            IT_TEXT+=("$BOLD$C_TEXT$nm$R$C_DIM$LIMIT$R  $state"); IT_ON+=(0)
        done
        picker Toolbox 'open-source tools from GitHub - picked ones install via Homebrew' single footer_tools || return
        run_tool "$PICK"
    done
}
footer_tools() { FOOT="$C_ACC▸$R $C_TEXT${T_DESC[$1]}$R"; }

# ── S. suspicious scan ─────────────────────────────────────────────────
is_random() {  # "GIuychYBxsQ" yes, "GitHubDesktop" no
    local s=$1 letters vowels flips
    [[ ${#s} -ge 7 && $s =~ ^[A-Za-z0-9]+$ ]] || return 1
    letters=${s//[^A-Za-z]/}; (( ${#letters} >= 5 )) || return 1
    vowels=${s//[^aeiouAEIOU]/}
    flips=$(printf '%s\n' "$s" | grep -oE '[a-z][A-Z]|[A-Z]{2,}[a-z]' | wc -l | tr -d ' ')
    (( flips >= 2 && ${#vowels} * 100 / ${#letters} < 25 ))
}

do_scan() {
    local d f label part why args i hits=() whys=() kinds=() details=() li
    title 'Suspicious scan'; info 'checking launch agents, daemons and login items...'
    launch_dirs
    for d in "${LAUNCH_DIRS[@]}"; do
        for f in "$d"/*.plist; do
            label=$(basename "$f" .plist); why=''
            for part in ${label//./ }; do is_random "$part" && why='random-looking name'; done
            args=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$f" 2>/dev/null | sed '1d;$d' | tr -s ' \n' ' ')
            plist_program "$f"; args="$PROG $args"
            [[ $args == */tmp/* || $args == */Users/Shared/* || $args == */Downloads/* || $args =~ /\.[A-Za-z0-9] ]] && why="${why:+$why, }runs from a hidden or temp folder"
            [[ $args =~ (curl|wget).*(sh|bash) || $args == *osascript* || $args == *base64* || $args == *python*" -c"* ]] && why="${why:+$why, }launches a hidden script"
            [[ -n $why ]] && { hits+=("$f"); whys+=("$why"); kinds+=(agent); details+=("$args"); }
        done
    done
    while IFS= read -r li; do
        li=${li# }; [[ -z $li ]] && continue
        is_random "${li// /}" && { hits+=("$li"); whys+=('random-looking name'); kinds+=(login); details+=('login item'); }
    done < <(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n')
    if (( ${#hits[@]} == 0 )); then
        title 'Suspicious scan'; ok 'nothing sketchy found'
        note "a quick sniff test, not an antivirus - press V on the menu for a real check"; wait_back; return
    fi
    IT_TEXT=(); IT_ON=(); SCAN_DETAILS=("${details[@]}")
    for i in "${!hits[@]}"; do
        limit "$(basename "${hits[i]}" .plist)" 22; local nm=$LIMIT; limit "${whys[i]}" 30
        IT_TEXT+=("$C_DIM$(printf '%-8s' "${kinds[i]}")$R$C_TEXT$nm$R  $C_WARN$LIMIT$R"); IT_ON+=(0)
    done
    picker 'Suspicious scan' 'not proof of malware - google it first before removing anything' multi footer_scan || return
    title 'Suspicious scan'
    for i in "${!hits[@]}"; do
        (( IT_ON[i] )) || continue
        if [[ ${kinds[i]} == login ]]; then
            osascript -e "tell application \"System Events\" to delete login item \"${hits[i]}\"" >/dev/null 2>&1 \
                && { ok "removed login item ${hits[i]}"; log_it "removed login item ${hits[i]}"; } || fail "couldn't remove ${hits[i]}"
        elif remove_launch_item "${hits[i]}"; then ok "removed $(basename "${hits[i]}") (backed up)"; log_it "removed launch item $(basename "${hits[i]}")"
        else fail "couldn't remove ${hits[i]}"; fi
    done
    wait_back
}
footer_scan() { limit "${SCAN_DETAILS[$1]}" 64; FOOT="$C_DIM$LIMIT$R"; }

# ── V. virus check ─────────────────────────────────────────────────────
do_virus() {
    title 'Virus check'
    note 'macOS already checks every app you open with XProtect - this is a second opinion'; echo
    if [[ -d /Applications/Malwarebytes.app ]]; then
        info 'opening Malwarebytes - hit "Scan" there'; open -a Malwarebytes; wait_back
    else
        info 'KnockKnock (by Objective-See) lists everything that starts automatically -'
        info 'which is where Mac malware hides'
        echo; run_tool 7
    fi
}

# ── H. history ─────────────────────────────────────────────────────────
do_history() {
    local line
    title History
    if [[ ! -s $HISTORY_FILE ]]; then note 'nothing yet - VOID logs everything it cleans, removes and fixes here'; wait_back; return; fi
    while IFS= read -r line; do
        printf '%s  %s%s%s  %s%s%s\n' "$P" "$C_DIM" "${line:0:16}" "$R" "$C_TEXT" "${line:18}" "$R"
    done < <(tail -n 40 "$HISTORY_FILE" | tail -r 2>/dev/null || tail -n 40 "$HISTORY_FILE")
    echo; note "full log: $HISTORY_FILE"
    wait_back
}

# ── void remove ────────────────────────────────────────────────────────
do_remove() {
    local link
    title 'Remove VOID'; note 'deletes VOID, the void command, the desktop launcher, history and backups'; echo
    confirm 'remove VOID from this Mac?' || return
    for link in /opt/homebrew/bin/void /usr/local/bin/void "$HOME/.local/bin/void"; do
        [[ -L $link && $(readlink "$link") == "$VOID_HOME"/* ]] && rm -f "$link"
    done
    rm -f "$HOME/Desktop/VOID.command"
    [[ ${VOID_HOME##*/} == .void ]] && rm -rf "$VOID_HOME"
    echo; ok 'VOID removed - see you in the void.'; sleep 2
}

# ── demo frames for the README (run from the repo with VOID_TEST=1) ────
if [[ $CMD == __render ]]; then
    COLS=100; ROWS=40; pad_for "$BLOCK_W"; P=$PAD
    SYS_OS='macOS Sequoia 15.4'; SYS_CPU='Apple M3 Pro'; SYS_CORES=12; SYS_RAM=36
    DRV_NAME=('Macintosh HD'); DRV_SIZE=(976490576); DRV_FREE=(401234567); JUNK_KB=9437184
    echo '=== mac-main ==='; SEL=1; main_lines; printf '%s\n' "${MAIN[@]}"
    ST_CPU=18; ST_MEM_USED=22020096; ST_MEM_TOTAL=37748736; ST_MEM_PCT=58; ST_DISK_FREE_PCT=41; ST_DOWN=2400000; ST_UP=180000
    ST_LOAD='2.41 2.10 1.98'; ST_UP_S=273600; ST_BATT=84; ST_BATT_STATE='charging'
    ST_TOP=($'7.9\t2411724\t31\tGoogle Chrome Helper' $'4.2\t812300\t1\tWindowServer' $'2.6\t1623400\t9\tCode Helper'
            $'1.1\t905220\t6\tDiscord Helper' $'0.6\t402112\t1\tSpotify' $'0.3\t198004\t1\tFinder')
    health; status_lines 8 12 10 18 25 22 30 41 38 29 24 33 47 52 44 36 28 31 26 23 19 24 35 61 77 58 42 33 27 18
    echo '=== mac-status ==='
    for line in "${STATUS[@]}"; do printf '%s%s\n' "$P" "$line"; done
    exit 0
fi

# ── self test: runs the real data collectors once (used by the release workflow on a Mac) ──
if [[ $CMD == __selftest ]]; then
    COLS=100; ROWS=40; pad_for "$BLOCK_W"; P=$PAD
    echo "bash:   $BASH_VERSION"
    sys_info;   echo "sys:    $SYS_OS | $SYS_CPU | $SYS_CORES cores | $SYS_RAM GB | $SYS_MODEL"
    drive_info; for k in "${!DRV_NAME[@]}"; do fmt_kb "${DRV_FREE[k]}"; f=$SIZE; fmt_kb "${DRV_SIZE[k]}"; echo "drive:  ${DRV_NAME[k]} - $f free of $SIZE"; done
    for i in "${!J_NAME[@]}"; do measure_spot "$i"; fmt_kb "${J_KB[i]}"; echo "junk:   ${J_NAME[i]} = $SIZE"; done
    junk_total
    status_stats; sleep 1; status_stats; health
    echo "status: cpu $ST_CPU% · mem $ST_MEM_PCT% · disk free $ST_DISK_FREE_PCT% · up ${ST_UP_S}s · load $ST_LOAD · battery '${ST_BATT}' · health $HEALTH"
    for line in "${ST_TOP[@]}"; do echo "top:    ${line//$'\t'/ | }"; done
    launch_dirs; n=0; for d in "${LAUNCH_DIRS[@]}"; do for f in "$d"/*.plist; do plist_program "$f"; n=$(( n + 1 )); done; done
    echo "launch: read $n launch items"
    for i in "${!T_NAME[@]}"; do if tool_ready "$i"; then s=ready; else s=get; fi; echo "tool:   ${T_NAME[i]} $s"; done
    is_random GIuychYBxsQ && echo "random: GIuychYBxsQ -> flagged"; is_random GitHubDesktop || echo "random: GitHubDesktop -> fine"
    main_lines; status_lines 10 20 30
    echo "render: ${#MAIN[@]} main lines, ${#STATUS[@]} status lines"
    for line in "${MAIN[@]}" "${STATUS[@]}"; do vislen "$line"; (( VL > COLS )) && { echo "FAIL: line wider than the screen ($VL)"; exit 1; }; done
    echo "selftest ok"
    exit 0
fi

# ── go ─────────────────────────────────────────────────────────────────
if [[ $CMD == remove ]]; then screen_on; trap screen_off EXIT; do_remove; exit 0; fi
screen_on
trap 'screen_off' EXIT
trap 'exit 130' INT TERM
show_intro
if [[ -n $CMD ]]; then
    for i in "${!MENU_CMD[@]}"; do [[ ${MENU_CMD[i]} == "$CMD" ]] && "${MENU_FN[i]}"; done
    exit 0
fi
cls; show_main
while true; do
    read_main_key
    case $KEY in
        q|Q|esc) break ;;
        up|down|left|right) move_sel "$KEY"; show_main ;;
        c|C)
            for i in "${!THEME_NAMES[@]}"; do [[ ${THEME_NAMES[i]} == "$THEME" ]] && k=$i; done
            set_theme "${THEME_NAMES[$(( (k + 1) % ${#THEME_NAMES[@]} ))]}"
            printf '%s' "$THEME" > "$THEME_FILE"; show_main ;;
        *)
            want=$KEY; [[ $KEY == enter ]] && want=${NAV_KEY[SEL]}
            want=$(printf '%s' "$want" | tr 'A-Z' 'a-z')
            menu_index "$want"
            if (( MI >= 0 )); then
                for i in "${!NAV_KEY[@]}"; do [[ ${NAV_KEY[i]} == "$want" ]] && SEL=$i; done
                "${MENU_FN[MI]}"
                cls; show_main
            fi ;;
    esac
done
show_outro
