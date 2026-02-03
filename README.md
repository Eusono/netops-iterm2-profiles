ersion**: When you `exit` the device, iTerm2 detects the loss of the session tag and snaps back to your `Default` profile.

---

## 🛠 Setup Instructions

### 1. Install Shell Integration
For iTerm2 to track your location and handle profile switching, you **must** install Shell Integration on your local machine.

* Open iTerm2.
* Go to the top menu bar and select **iTerm2 > Install Shell Integration**.
* Follow the prompts to update your shell profile (e.g., `.zshrc` or `.bash_profile`).
* **Restart iTerm2** after installation.

### 2. Import Master Profiles
The `.json` files in the `/Profiles` folder contain all the highlighting triggers, colors, and word-boundary protections.

* Download the desired `.json` files from the `/Profiles` folder in this reposit# netops-iterm2-profiles

**iTerm2 is not a session manager; it’s a logic engine.**

This repository contains a collection of iTerm2 profiles and triggers designed for Network Operations. Instead of maintaining hundreds of static session files, this framework uses **Automatic Profile Switching (APS)** to detect your environment and apply optimized, non-greedy regex highlighting on the fly.

---

## 🚀 How it Works

1.  **Detection**: Your `Default` profile monitors terminal output for specific patterns (like an `ssh` command).
2.  **Tagging**: Once a pattern is matched, a trigger "reports" a generic session tag (e.g., `net-ios`).
3.  **Switching**: iTerm2 sees the tag and automatically swaps the active tab to the corresponding Master Profile.
4.  **Revory.
* In iTerm2, open **Settings > Profiles**.
* Click the **Other Actions** (cog icon) at the bottom of the profile list.
* Select **Import JSON Profiles...** and choose the downloaded files.

### 3. Configure the Detection Trigger
You must tell your `Default` profile when to trigger a switch.

* Go to **Settings > Profiles > Default > Advanced > Triggers**.
* Click **Edit** and add a new trigger:
    * **Regular Expression**: `(?i)ssh\s+.*(?:sw|rt|n[579]k)[a-zA-Z0-9.-]*` (Adjust these keywords to match your device naming convention).
    * **Action**: Select `Report User and Host` from the dropdown.
    * **Parameter**: In the empty text box that appears below the Action dropdown, type `cisco-session` (Match this to the tag used in your imported profile).
* Go to **Settings > Profiles > Default > Advanced**.
* In the **Automatic Profile Switching** section, add a single asterisk `*` to the list. This acts as the "fallback" to return you to the Default profile upon exiting a session.

---

## 🔍 Features

* **Non-Greedy Highlighting**: Regex patterns are optimized to highlight specific keywords without "bleeding" into usernames or hashes.
* **Whole-Word Protection**: Uses `\b` boundaries so that short status words like `on` or `up` don't trigger inside words like "authentication".
* **Instant Prompts**: Prompt triggers are set to "Instant" (check the **Instant** box in Triggers) to ensure your hostname is highlighted on the current line as you work.

---

## ⚖️ License
This project is licensed under the **MIT License**. You are free to fork, modify, and share these configurations, provided you include the original non-warranty clause.
