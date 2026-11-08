#!/usr/bin/env zsh
# ==============================================================================
# iTerm2 NetOps Logic Engine - Automated Installer
# https://github.com/Eusono/netops-iterm2-profiles
# ==============================================================================
set -euo pipefail

REPO_DIR="${0:A:h}"
PROFILES_DIR="$REPO_DIR/profiles"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
DYNAMIC_FILE="$DYNAMIC_DIR/netops-iterm2-profiles.json"
PLIST_PATH="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

BLOCK_START="# >>> netops-iterm2-profiles >>>"
BLOCK_END="# <<< netops-iterm2-profiles <<<"

[[ -f "$REPO_DIR/.netops.env" ]] && source "$REPO_DIR/.netops.env"
DEFAULT_FORTINET_REGEX="${NETOPS_FORTINET_REGEX:-"(fw|fgt|fmg|faz|fac|forti)"}"
DEFAULT_CISCO_REGEX="${NETOPS_CISCO_REGEX:-"(sw|rt|rtr|core|dist|agg|wan|isr|asr|c9[0-9]{3}|n[3579]k)"}"

MODE="interactive"

usage() {
    cat << 'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  -y, --defaults     Run non-interactively with standard NetOps defaults
  -u, --uninstall    Remove the NetOps SSH block from ~/.zshrc and DynamicProfiles
  -h, --help         Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--defaults)
            MODE="defaults"
            shift
            ;;
        -u|--uninstall)
            MODE="uninstall"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

remove_zshrc_block() {
    if [[ -f "$ZSHRC_PATH" ]] && grep -q "$BLOCK_START" "$ZSHRC_PATH"; then
        python3 - "$ZSHRC_PATH" "$BLOCK_START" "$BLOCK_END" << 'PY'
import sys, re
path, start, end = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r") as f:
    text = f.read()
pattern = re.compile(r"\n?" + re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.DOTALL)
new_text = pattern.sub("\n", text)
with open(path, "w") as f:
    f.write(new_text)
PY
        return 0
    fi
    return 1
}

if [[ "$MODE" == "uninstall" ]]; then
    echo "==> Uninstalling iTerm2 NetOps Logic Engine..."
    if remove_zshrc_block; then
        echo "  [OK] Removed NetOps block from $ZSHRC_PATH"
    else
        echo "  [--] No managed NetOps block found in $ZSHRC_PATH"
    fi
    if [[ -f "$DYNAMIC_FILE" ]]; then
        rm -f "$DYNAMIC_FILE"
        echo "  [OK] Removed Dynamic Profile bundle: $DYNAMIC_FILE"
    fi
    echo "==> Uninstall complete. Run: source $ZSHRC_PATH"
    exit 0
fi

echo "============================================================"
echo "  iTerm2 NetOps Logic Engine - Setup"
echo "============================================================"

FORTINET_REGEX="$DEFAULT_FORTINET_REGEX"
CISCO_REGEX="$DEFAULT_CISCO_REGEX"
ENABLE_LOGGING="y"

if [[ "$MODE" == "interactive" ]]; then
    echo ""
    echo "1) Fortinet hostname regex (matches FortiGate, FMG, FAZ, FAC)"
    printf "   [Default: %s]: " "$DEFAULT_FORTINET_REGEX"
    read -r input_forti
    [[ -n "${input_forti// }" ]] && FORTINET_REGEX="$input_forti"

    echo ""
    echo "2) Cisco hostname regex (matches IOS/IOS-XE/NX-OS switches & routers)"
    printf "   [Default: %s]: " "$DEFAULT_CISCO_REGEX"
    read -r input_cisco
    [[ -n "${input_cisco// }" ]] && CISCO_REGEX="$input_cisco"

    echo ""
    printf "3) Enable automatic SSH session audit logging to ~/.ssh/logs/? [Y/n]: "
    read -r input_log
    if [[ "${input_log:l}" == n* ]]; then
        ENABLE_LOGGING="n"
    fi
fi

echo ""
echo "==> Step 1: Enabling iTerm2 OSC 50 profile switching..."
if [[ "$OSTYPE" == darwin* ]]; then
    defaults write com.googlecode.iterm2 PreventEscapeSequenceChangeProfile -bool false 2>/dev/null || true
    echo "  [OK] Set PreventEscapeSequenceChangeProfile = false"
else
    echo "  [--] Non-macOS system detected; skipping iTerm2 defaults write."
fi

echo "==> Step 2: Installing Cisco & Fortinet iTerm2 profiles..."
if [[ "$OSTYPE" == darwin* ]]; then
    python3 - "$PROFILES_DIR" "$PLIST_PATH" "$DYNAMIC_DIR" "$DYNAMIC_FILE" << 'PY'
import sys, os, json, plistlib, subprocess

profiles_dir, plist_path, dyn_dir, dyn_file = sys.argv[1:5]

with open(os.path.join(profiles_dir, "Cisco.json")) as f:
    cisco = json.load(f)
with open(os.path.join(profiles_dir, "Fortinet.json")) as f:
    fortinet = json.load(f)

target_guids = {cisco["Guid"]: cisco, fortinet["Guid"]: fortinet}
static_found = False

if os.path.exists(plist_path):
    try:
        with open(plist_path, "rb") as f:
            pl = plistlib.load(f)
        bookmarks = pl.get("New Bookmarks", [])
        for i, b in enumerate(bookmarks):
            g = b.get("Guid")
            if g in target_guids or b.get("Name") in ("Cisco", "Fortinet"):
                static_found = True
                src = cisco if (g == cisco["Guid"] or b.get("Name") == "Cisco") else fortinet
                b["Triggers"] = src["Triggers"]
                for k, v in src.items():
                    if "Color" in k or k in ("Use Separate Colors for Light and Dark Mode", "Scrollback Lines", "Allow Title Reporting"):
                        b[k] = v
        if static_found:
            with open(plist_path, "wb") as f:
                plistlib.dump(pl, f)
            subprocess.run(["defaults", "read", "com.googlecode.iterm2"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("  [OK] Updated existing Cisco & Fortinet profiles in com.googlecode.iterm2.plist")
            print("       (Note: If iTerm2 is currently open, re-import profiles/*.json in Settings > Profiles > Other Actions)")
    except Exception as e:
        print(f"  [!] Could not inspect plist ({e}); falling back to DynamicProfiles.")

if not static_found:
    os.makedirs(dyn_dir, exist_ok=True)
    bundle = {"Profiles": [cisco, fortinet]}
    with open(dyn_file, "w") as f:
        json.dump(bundle, f, indent=2)
        f.write("\n")
    print(f"  [OK] Installed hot-reloading DynamicProfiles bundle:\n       {dyn_file}")
PY
fi

echo "==> Step 3: Configuring $ZSHRC_PATH..."
touch "$ZSHRC_PATH"
BACKUP_PATH="${ZSHRC_PATH}.bak.$(date +%Y%m%d%H%M%S)"
cp "$ZSHRC_PATH" "$BACKUP_PATH"
echo "  [OK] Backed up existing .zshrc to $BACKUP_PATH"

remove_zshrc_block || true

if [[ "$ENABLE_LOGGING" == "y" ]]; then
    cat >> "$ZSHRC_PATH" << EOF

$BLOCK_START
# iTerm2 NetOps Profile & Session Logging Engine
export NETOPS_FORTINET_REGEX='${FORTINET_REGEX}'
export NETOPS_CISCO_REGEX='${CISCO_REGEX}'

function ssh() {
    local full_dest="\${@: -1}"
    local pure_host="\${full_dest#*@}"
    local ldest="\${pure_host:l}"

    local log_dir="\$HOME/.ssh/logs"
    local date_stamp=\$(date "+%Y-%m-%d")
    local log_file="\${ldest}_\${date_stamp}.log"
    local full_path="\$log_dir/\$log_file"

    printf "\e]0;%s\a" "\$ldest"
    [[ ! -d "\$log_dir" ]] && mkdir -p "\$log_dir"

    {
      echo -e "\n\n------------------------------------------------------------"
      echo -e ">>> SESSION START: \$(date "+%H:%M:%S")"
      echo -e "------------------------------------------------------------\n"
    } >> "\$full_path"

    if [[ "\$ldest" =~ "\${NETOPS_FORTINET_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Fortinet\a"
    elif [[ ! "\$ldest" =~ "nac" && "\$ldest" =~ "\${NETOPS_CISCO_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Cisco\a"
    fi

    printf "\e[1;34mLogging session to:\e[0m %s\n" "\$full_path"
    command ssh -t "\$@" | tee -ai "\$full_path"

    {
      echo -e "\n------------------------------------------------------------"
      echo -e "<<< SESSION END:    \$(date "+%H:%M:%S")"
      echo -e "------------------------------------------------------------"
    } >> "\$full_path"

    echo -ne "\033]50;SetProfile=Default\a"
    printf "\e]0;Terminal\a"
}
$BLOCK_END
EOF
else
    cat >> "$ZSHRC_PATH" << EOF

$BLOCK_START
# iTerm2 NetOps Profile Engine
export NETOPS_FORTINET_REGEX='${FORTINET_REGEX}'
export NETOPS_CISCO_REGEX='${CISCO_REGEX}'

function ssh() {
    local full_dest="\${@: -1}"
    local pure_host="\${full_dest#*@}"
    local ldest="\${pure_host:l}"

    printf "\e]0;%s\a" "\$ldest"

    if [[ "\$ldest" =~ "\${NETOPS_FORTINET_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Fortinet\a"
    elif [[ ! "\$ldest" =~ "nac" && "\$ldest" =~ "\${NETOPS_CISCO_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Cisco\a"
    fi

    command ssh "\$@"

    echo -ne "\033]50;SetProfile=Default\a"
    printf "\e]0;Terminal\a"
}
$BLOCK_END
EOF
fi

echo "  [OK] Installed NetOps ssh() wrapper into $ZSHRC_PATH"
echo ""
echo "============================================================"
echo "  Setup Complete! Run the following command to activate:"
echo "    source $ZSHRC_PATH"
echo "============================================================"
