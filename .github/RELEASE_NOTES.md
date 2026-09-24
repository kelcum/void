## VOID 1.4 🕳️

### 🍎 A much deeper uninstaller on macOS
- **Finds every app**: your Applications folders *and* anything Spotlight knows about (apps living in Downloads, subfolders...), with size and **when you last used it**, oldest first
- **Deep leftover scan** after uninstalling, like the paid cleaners:
  - 30+ locations: Caches, Preferences (+ ByHost), Saved Application State, Containers, Group Containers, Application Support (+ vendor subfolders), HTTPStorages, WebKit, Cookies, Logs, crash reports, LaunchAgents/Daemons, PrivilegedHelperTools, audio plug-ins, macOS temp folders, `~/.config`...
  - matches by **bundle ID**, app name *and* the app's internal name (VS Code's data lives in `Code`)
  - look-alike apps are left alone: uninstalling Discord won't touch Discord Canary
  - a Spotlight sweep for anything else named after the app (unticked, for you to review)
  - installer **receipts** and **login items** too
  - everything goes to the Trash, and background helpers are stopped first

### ⬇️ Downloads
| | |
|---|---|
| 🍎 **macOS** | `VOID-macOS.dmg`: open it, drag **VOID** to **Applications** |
| 🪟 **Windows** | `VOID-windows.zip`: unzip, double-click **Install VOID.cmd** |

Or install with one line: see the [README](https://github.com/kelcum/void#-install).

### 🍎 First time opening the Mac app
VOID isn't notarized by Apple (that needs a paid developer account). The first time, open it, click **Done**, then go to **System Settings → Privacy & Security → Open Anyway**, and allow it to control **Terminal**. Terminal fans: `xattr -dr com.apple.quarantine /Applications/VOID.app`
