# iTerm2 NetOps Logic Engine

This project automates iTerm2 profile switching for Network Engineers. It uses a ZSH wrapper to detect device types (Cisco, Fortinet, etc.) during an SSH command and updates the terminal theme accordingly.

## ✨ Key Features
* **Zero Latency**: Switches profiles only when you hit `Enter` on an SSH command.
* **No Key Conflicts**: Prevents accidental switches when typing common commands like `show` or `status`.
* **Auto-Revert**: Automatically snaps back to your `Default` profile the moment you `exit` a session.
* **Vendor Intelligence**: Built-in logic to distinguish between Cisco gear and Fortinet/FortiNAC devices.

## 🛠️ iTerm2 Setup (Required)

To allow the script to change your profile, you must enable "Proprietary Escape Sequences" and clear existing automatic rules:

1. **Enable Escape Sequences**:
    * Open **iTerm2 Settings** ($\text{\⌘}$ + **,**).
    * Go to the **Advanced** tab and search for "escape".
    * Set **"Prevent control sequences from changing the current profile?"** to **No**.

2. **Clear APS Rules**:
    * Go to **Profiles > [Your Profile] > Advanced**.
    * Ensure the **Automatic Profile Switching** box at the bottom is **completely empty** (remove any `*` rules).

3. **Cleanup Triggers**:
    * In **Profiles > Default > Advanced > Triggers**, ensure any old regex triggers for profile switching are removed to prevent conflicts.

## 📝 Installation

Add the following function to your `~/.zshrc` file:

> **Note**: Yopu should customize the keywords in the 'if' statements below to match your specific network naming standards (e.g., replace `n7k` or `sw` with your own codes).

```bash
# iTerm2 NetOps Profile Logic Engine
ssh() {
    local dest="${@: -1}"
    local ldest="${dest:l}" # Lowercase for reliable matching

    # 1. Cisco Logic (Matches sw, rt, n5k, n7k, n9k, nbk-wan)
    if [[ "$ldest" =~ "sw" || "$ldest" =~ "rt" || "$ldest" =~ "n5k" || "$ldest" =~ "n7k" || "$ldest" =~ "n9k" || "$ldest" =~ "nbk-wan" ]]; then
        if [[ "$ldest" =~ "nac" ]]; then
            command ssh "$@" # Stay in Default for NAC devices
        else
            # Switches to the "Cisco" profile
            echo -e "\033]50;SetProfile=Cisco\a"
            command ssh "$@"
            # Reverts to "Default" after exit
            echo -e "\033]50;SetProfile=Default\a"
        fi

    # 2. Fortinet Logic (Matches fw, fgt)
    elif [[ "$ldest" =~ "fw" || "$ldest" =~ "fgt" ]]; then
        # Switches to the "Fortinet" profile
        echo -e "\033]50;SetProfile=Fortinet\a"
        command ssh "$@"
        # Reverts to "Default" after exit
        echo -e "\033]50;SetProfile=Default\a"

    # 3. Standard SSH (Fallback)
    else
        command ssh "$@"
    fi
}
\```

## 🚀 Usage

Simply use SSH as normal. The Logic Engine handles the rest:

* `ssh admin@nbk-n7k-c1` → Switches to **Cisco** profile.
* `ssh admin@nbk-fw-01` → Switches to **Fortinet** profile.
* `ssh admin@fortinac` → Stays in **Default**.
* `exit` → Automatically returns to **Default**.
