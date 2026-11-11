# iTerm2 NetOps Logic Engine

This project automates iTerm2 profile switching, session audit logging, and fuzzy SSH device selection for Network Engineers. It uses a lightweight ZSH wrapper and `fzf` picker (`s`) to select devices from your SSH configs, detect vendor platforms (Cisco IOS/IOS-XE/NX-OS, Fortinet FortiOS/FMG/FAZ/FAC), switch to a vendor-tuned highlight profile via iTerm2 OSC 50 escape sequences, log sessions to `~/.ssh/logs/`, and revert to your `Default` profile on exit.

## ✨ Key Features
* **Fuzzy NetOps Device Picker (`s`)**: Type `s` in your terminal to fuzzy-search all host aliases across `~/.ssh/config`, `~/.ssh/session-manager`, and `~/.ssh/config.d/*` via `fzf` and connect immediately.
* **Zero Latency Profile Switching**: Switches iTerm2 profiles only when you launch an `ssh` connection.
* **No Key Conflicts**: Prevents accidental profile switches when viewing local configs or running local commands.
* **Auto-Revert & Session Audit Logging**: Logs sessions to `~/.ssh/logs/<hostname>_<YYYY-MM-DD>.log`, sets your tab title to the active device, and snaps back to `Default` the moment you `exit`.
* **Vendor-Tuned Highlighting**:
  * **Cisco (`profiles/Cisco.json`)**: 23 non-greedy triggers for IOS/IOS-XE/NX-OS interfaces (`Gi`, `Te`, `Tw`, `Fo`, `Hu`, `Eth`, `Po`, `Tu`, `Lo`), BGP/OSPF/EIGRP neighbors, syslog headers, image files (`.bin`/`.pkg`/`.conf`), status transitions, and instant high-contrast danger badges (`write erase`, `delete`, `format`).
  * **Fortinet (`profiles/Fortinet.json`)**: 17 triggers for FortiOS prompts (including VDOM/sub-context prompts), interfaces (`port`, `x1`–`x8`, `ha`, `sdwan`, `fortilink`, `portX.Y` VLAN subinterfaces), HA/SD-WAN SLA states (`primary`, `in-sync`, `alive`), unified IP/MAC coloring, and instant danger badges (`delete`, `reboot`, `shutdown`, `factoryreset`).

---

## 📋 Prerequisites

* **macOS** with **[iTerm2](https://iterm2.com/)**
* **[Homebrew](https://brew.sh/)** *(Required to install `fzf` for the interactive `s` device picker; `install.sh` checks for Homebrew first and stops with instructions if it is not installed yet.)*

---

## 🚀 Quick Install (Automated)

Clone the repository and run the interactive installer:

```zsh
git clone https://github.com/Eusono/netops-iterm2-profiles.git
cd netops-iterm2-profiles
./install.sh
source ~/.zshrc
```

### What `./install.sh` Does Automatically:
1. **Preflight Check (`Homebrew` & `fzf`)**:
   * Verifies that **Homebrew** is installed (if missing, stops cleanly without modifying your system and prints the official Homebrew install command).
   * Automatically installs **`fzf`** via Homebrew if it is not already installed.
2. **Prompts for Hostname Patterns & Logging** (or press `Enter` to accept standard NetOps defaults):
   * **Fortinet regex** *(default: `(fw|fgt|fmg|faz|fac|forti)`)*
   * **Cisco regex** *(default: `(sw|rt|rtr|core|dist|agg|wan|isr|asr|c9[0-9]{3}|n[3579]k)`)*
   * **Session audit logging** to `~/.ssh/logs/<hostname>_<YYYY-MM-DD>.log` *(`[Y/n]`)*
3. **Enables iTerm2 OSC 50 Escape Sequences**: Sets `PreventEscapeSequenceChangeProfile = false` via `defaults write`.
4. **Installs the `Cisco` & `Fortinet` Profiles**: Writes a hot-reloading bundle to `~/Library/Application Support/iTerm2/DynamicProfiles/netops-iterm2-profiles.json` (or updates existing `Cisco`/`Fortinet` profiles in place if already imported).
5. **Updates `~/.zshrc` Safely**: Creates a timestamped backup (`~/.zshrc.bak.<timestamp>`) and injects an idempotent managed block (`# >>> netops-iterm2-profiles >>>`) containing both the `ssh()` wrapper and the `s` (`ssh_selector`) fuzzy picker.

### Installer Flags
```zsh
./install.sh --defaults   # Non-interactive install using standard NetOps defaults
./install.sh --uninstall  # Cleanly remove the ~/.zshrc block and DynamicProfile bundle
./install.sh --help       # Show installer options
```

---

## 🛠️ Manual Setup (Optional)

If you prefer to configure iTerm2 and `~/.zshrc` manually instead of running `./install.sh`:

1. **Install `fzf` via Homebrew**:
   ```zsh
   brew install fzf
   ```
2. **Enable Escape Sequences**:
   * Open **iTerm2 Settings** ($\text{\⌘}$ + **,**).
   * Go to the **Advanced** tab and search for `escape`.
   * Set **"Prevent control sequences from changing the current profile?"** to **No**.
3. **Import Profiles**:
   * Go to **Settings > Profiles > Other Actions... > Import JSON Profiles...** and import `profiles/Cisco.json` and `profiles/Fortinet.json`.
4. **Add the ZSH Wrapper & Fuzzy Picker to `~/.zshrc`**:

> **Note**: Customize `NETOPS_FORTINET_REGEX` and `NETOPS_CISCO_REGEX` below to match your organization's hostname naming standards.

```zsh
# >>> netops-iterm2-profiles >>>
# iTerm2 NetOps Profile, Logging & Fuzzy Selector Engine
export NETOPS_FORTINET_REGEX='(fw|fgt|fmg|faz|fac|forti)'
export NETOPS_CISCO_REGEX='(sw|rt|rtr|core|dist|agg|wan|isr|asr|c9[0-9]{3}|n[3579]k)'

function ssh() {
    local full_dest="${@: -1}"
    local pure_host="${full_dest#*@}"
    local ldest="${pure_host:l}"

    local log_dir="$HOME/.ssh/logs"
    local date_stamp=$(date "+%Y-%m-%d")
    local log_file="${ldest}_${date_stamp}.log"
    local full_path="$log_dir/$log_file"

    printf "\e]0;%s\a" "$ldest"
    [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"

    {
      echo -e "\n\n------------------------------------------------------------"
      echo -e ">>> SESSION START: $(date "+%H:%M:%S")"
      echo -e "------------------------------------------------------------\n"
    } >> "$full_path"

    if [[ "$ldest" =~ "${NETOPS_FORTINET_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Fortinet\a"
    elif [[ ! "$ldest" =~ "nac" && "$ldest" =~ "${NETOPS_CISCO_REGEX}" ]]; then
        echo -ne "\033]50;SetProfile=Cisco\a"
    fi

    printf "\e[1;34mLogging session to:\e[0m %s\n" "$full_path"
    command ssh -t "$@" | tee -ai "$full_path"

    {
      echo -e "\n------------------------------------------------------------"
      echo -e "<<< SESSION END:    $(date "+%H:%M:%S")"
      echo -e "------------------------------------------------------------"
    } >> "$full_path"

    echo -ne "\033]50;SetProfile=Default\a"
    printf "\e]0;Terminal\a"
}

# Fuzzy SSH Device Picker (Requires fzf)
ssh_selector() {
    local -a ssh_files
    [[ -f "$HOME/.ssh/config" ]] && ssh_files+=("$HOME/.ssh/config")
    [[ -f "$HOME/.ssh/session-manager" ]] && ssh_files+=("$HOME/.ssh/session-manager")
    for f in "$HOME/.ssh/config.d/"*(N); do
        [[ -f "$f" ]] && ssh_files+=("$f")
    done

    if (( ${#ssh_files[@]} == 0 )); then
        echo "No SSH config files found in ~/.ssh/config or ~/.ssh/session-manager" >&2
        return 1
    fi

    local target=$(awk '
      tolower($1) == "host" {
        for (i = 2; i <= NF; i++) {
          if ($i ~ /^#/) break
          if ($i !~ /[*?!\[]/) print $i
        }
      }
    ' "${ssh_files[@]}" | sort -u | fzf \
      --height 40% \
      --reverse \
      --border \
      --header="NetOps Device Picker" \
      --prompt=" " \
      --color="header:italic:cyan")

    if [[ -n "$target" ]]; then
        ssh "$target"
    fi
}
alias s='ssh_selector'
# <<< netops-iterm2-profiles <<<
```

---

## 💻 Usage

* **`s`** → Opens the interactive **NetOps Device Picker** (`fzf` menu of your SSH hosts) and connects to the selected device.
* **`ssh admin@dc-n9k-core01`** → Switches to **Cisco** profile, titles tab, and logs session.
* **`ssh admin@edge-fw01`** → Switches to **Fortinet** profile, titles tab, and logs session.
* **`ssh admin@corp-nac01`** → Stays in **Default** profile.
* **`exit`** → Automatically reverts to **Default** profile and resets tab title.
