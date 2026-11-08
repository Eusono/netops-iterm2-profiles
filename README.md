# iTerm2 NetOps Logic Engine

This project automates iTerm2 profile switching and real-time CLI syntax highlighting for Network Engineers. It uses a lightweight ZSH wrapper to detect device types (Cisco IOS/IOS-XE/NX-OS, Fortinet FortiOS/FMG/FAZ/FAC) at `ssh` invocation, switches to a vendor-tuned highlight profile via iTerm2 OSC 50 escape sequences, optionally logs sessions to `~/.ssh/logs/`, and reverts to your `Default` profile on exit.

## ✨ Key Features
* **Zero Latency**: Switches profiles only when you hit `Enter` on an `ssh` command.
* **No Key Conflicts**: Prevents accidental profile switches when viewing local configs or running local commands.
* **Auto-Revert**: Automatically snaps back to your `Default` profile and resets your tab title the moment you `exit` a session.
* **Vendor-Tuned Highlighting**:
  * **Cisco (`profiles/Cisco.json`)**: 23 non-greedy triggers for IOS/IOS-XE/NX-OS interfaces (`Gi`, `Te`, `Tw`, `Fo`, `Hu`, `Eth`, `Po`, `Tu`, `Lo`), BGP/OSPF/EIGRP neighbors, syslog headers, image files (`.bin`/`.pkg`/`.conf`), status transitions, and instant high-contrast danger badges (`write erase`, `delete`, `format`).
  * **Fortinet (`profiles/Fortinet.json`)**: 17 triggers for FortiOS prompts (including VDOM/sub-context prompts), interfaces (`port`, `x1`–`x8`, `ha`, `sdwan`, `fortilink`, `portX.Y` VLAN subinterfaces), HA/SD-WAN SLA states (`primary`, `in-sync`, `alive`), unified IP/MAC coloring, and instant danger badges (`delete`, `reboot`, `shutdown`, `factoryreset`).

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
1. **Prompts for Hostname Patterns & Logging** (or press `Enter` to accept standard NetOps defaults):
   * **Fortinet regex** *(default: `(fw|fgt|fmg|faz|fac|forti)`)*
   * **Cisco regex** *(default: `(sw|rt|rtr|core|dist|agg|wan|isr|asr|c9[0-9]{3}|n[3579]k)`)*
   * **Session audit logging** to `~/.ssh/logs/<hostname>_<YYYY-MM-DD>.log` *(`[Y/n]`)*
2. **Enables iTerm2 OSC 50 Escape Sequences**: Sets `PreventEscapeSequenceChangeProfile = false` via `defaults write`.
3. **Installs the `Cisco` & `Fortinet` Profiles**: Writes a hot-reloading bundle to `~/Library/Application Support/iTerm2/DynamicProfiles/netops-iterm2-profiles.json` (or updates existing `Cisco`/`Fortinet` profiles in place if already imported).
4. **Updates `~/.zshrc` Safely**: Creates a timestamped backup (`~/.zshrc.bak.<timestamp>`) and injects an idempotent managed block (`# >>> netops-iterm2-profiles >>>`).

### Installer Flags
```zsh
./install.sh --defaults   # Non-interactive install using standard NetOps defaults
./install.sh --uninstall  # Cleanly remove the ~/.zshrc block and DynamicProfile bundle
./install.sh --help       # Show installer options
```

---

## 🛠️ Manual Setup (Optional)

If you prefer to configure iTerm2 and `~/.zshrc` manually instead of running `./install.sh`:

1. **Enable Escape Sequences**:
   * Open **iTerm2 Settings** ($\text{\⌘}$ + **,**).
   * Go to the **Advanced** tab and search for `escape`.
   * Set **"Prevent control sequences from changing the current profile?"** to **No**.
2. **Import Profiles**:
   * Go to **Settings > Profiles > Other Actions... > Import JSON Profiles...** and import `profiles/Cisco.json` and `profiles/Fortinet.json`.
3. **Add the ZSH Wrapper to `~/.zshrc`**:

> **Note**: Customize `NETOPS_FORTINET_REGEX` and `NETOPS_CISCO_REGEX` below to match your organization's hostname naming standards.

```zsh
# >>> netops-iterm2-profiles >>>
# iTerm2 NetOps Profile & Session Logging Engine
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
# <<< netops-iterm2-profiles <<<
```

---

## 💻 Usage

Use `ssh` as normal—the wrapper handles profile switching, window titling, and session logging automatically:

* `ssh admin@dc-n9k-core01` → Switches to **Cisco** profile.
* `ssh admin@edge-fw01` → Switches to **Fortinet** profile.
* `ssh admin@corp-nac01` → Stays in **Default** profile.
* `exit` → Automatically reverts to **Default** profile.
