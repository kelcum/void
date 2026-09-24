## VOID 1.3 🕳️

**New: VOID for Mac is now a real app.** Download `VOID-macOS.dmg`, drag VOID into Applications, done.

### ⬇️ Downloads

| | |
|---|---|
| 🍎 **macOS** | `VOID-macOS.dmg`: open it, drag **VOID** to **Applications** |
| 🪟 **Windows** | `VOID-windows.zip`: unzip, double-click **Install VOID.cmd** |

Or install with one line: see the [README](https://github.com/kelcum/void#-install).

### ✨ What's in it
- **Clean junk**: temp files, caches, crash dumps, update leftovers, the lot, with sizes shown before anything goes
- **Uninstall apps** plus a sweep for the folders they leave behind
- **Fix stuck apps** (Windows) / **Fix launch items** (macOS)
- **Old installers**, **Dev junk** (`node_modules`, venvs, build caches), **Disk space**, **Optimize**, **Update everything**
- **Live status** dashboard with a health score
- **Speed test** (new): download, upload, latency and jitter with live graphs, powered by [cloudflare-speed-cli](https://github.com/kavehtehrani/cloudflare-speed-cli)
- **Toolbox** of open-source GitHub tools, installed when you pick them
- **Suspicious scan**, **Virus scan**, **History**
- animated intro, six themes, arrow-key menus

### 🍎 First time opening the Mac app
VOID is free and open source, so it isn't notarized by Apple (that needs a paid developer account). The first time:
1. Open VOID. macOS says it can't check it for malware. Click **Done**.
2. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
3. When VOID asks to control **Terminal**, click **Allow**, since that's where its menu runs.

After that it opens like any other app. Terminal fans can run `xattr -dr com.apple.quarantine /Applications/VOID.app` instead.

### 🪟 First time on Windows
If SmartScreen says *"Windows protected your PC"* when you run `Install VOID.cmd`, click **More info → Run anyway**.

> The macOS version is still **beta**. Every release is tested on a real Mac by the build workflow, but if something looks off, [open an issue](https://github.com/kelcum/void/issues).
