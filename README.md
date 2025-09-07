# imac-cs8409-dkms-wrapper

**DKMS package name:** `cs8409-dkms`  
**Kernel module built/installed:** `snd-hda-codec-cs8409` (Cirrus Logic codec for Apple machines like the iMac 2019)

This repository is a clean wrapper to build and install the **Cirrus CS8409 HDA codec** as an **out-of-tree DKMS module**.  
The GitHub repo is named `cs8409-dkms-wrapper`, while the DKMS package that gets registered on your system is `cs8409-dkms`.  
That keeps your local DKMS namespace short and conventional, while the repo name makes the intent clear.

⚠️ This project intentionally focuses **only on the DKMS driver**. It does **not** touch your audio stack (ALSA/PipeWire), does **not** add suspend/resume hooks, and does **not** change boot parameters. Those topics can be handled separately once the module itself works.

---

## Table of Contents

- [cs8409-dkms-wrapper](#cs8409-dkms-wrapper)
  - [Table of Contents](#table-of-contents)
  - [Dependencies](#dependencies)
  - [Installation](#installation)
    - [One-click (wget / curl)](#-one-click-wget--curl)
    - [Git clone](#-git-clone)
  - [Uninstallation](#uninstallation)
  - [How it works](#how-it-works)
  - [Repository layout](#repository-layout)
  - [Verification](#verification)
  - [Notes & Troubleshooting](#notes--troubleshooting)
  - [License](#license)

---

## Dependencies

The installer will automatically check for and install missing tools using the detected package manager (`apt-get`, `dnf`, `zypper`, `pacman`).  

**Required:**
- `wget`,`curl` 
- `git`, `dkms`, `rsync`, `sed`  
  *(auto-installed if a supported package manager is found)*  
- **Kernel headers** for your current kernel  
  *(these are **not** installed automatically — you must install them manually!)*

     **Debian/Ubuntu/Mint:**
     ```bash
     sudo apt-get update
     sudo apt-get install -y linux-headers-$(uname -r)
     sudo apt install wget curl
     ```

---

## Installation

Two options are supported:

### 🔹 One-click (wget / curl)

```bash
# Install
bash <(curl -fsSL https://raw.githubusercontent.com/frogro/imac-cs8409-dkms-wrapper/main/install.sh)

# or with wget:
wget -qO- https://raw.githubusercontent.com/frogro/imac-cs8409-dkms-wrapper/main/install.sh | bash
```

### 🔹 Git clone

```bash
git clone https://github.com/frogro/imac-cs8409-dkms-wrapper.git
cd cs8409-dkms-wrapper
sudo ./install.sh
```

---

## Uninstallation

```bash
# One-click
bash <(curl -fsSL https://raw.githubusercontent.com/frogro/imac-cs8409-dkms-wrapper/main/uninstall.sh)

# or via git clone
cd cs8409-dkms-wrapper
sudo ./uninstall.sh
```

The uninstaller:
- unloads the module if loaded  
- removes all DKMS instances of `snd-hda-codec-cs8409`  
- deletes `/usr/src/snd-hda-codec-cs8409-*`  
- cleans up `/var/lib/dkms/snd-hda-codec-cs8409/`  
- refreshes the module dependency database (`depmod`)  

System packages (git/dkms/rsync/sed) are **not removed**.

---

## How it works

1. The installer clones the **upstream repository** [`davidjo/snd_hda_macbookpro`](https://github.com/davidjo/snd_hda_macbookpro) into a temporary `upstream/` folder.
2. Sources are mirrored to `/usr/src/snd-hda-codec-cs8409-<version>/`.  
   - `<version>` = `1.0+<date>-<git-sha>` (e.g. `1.0+20250905-ab12c34`)
3. A `dkms.conf` is placed there (from this repo, if upstream does not provide one).  
   The version field is dynamically adjusted.  
4. DKMS runs `add → build → install`, compiling the module against your current kernel.
5. The module is installed under `/lib/modules/$(uname -r)/kernel/sound/pci/hda/` and loaded via `modprobe`.
6. The temporary `upstream/` folder is deleted after installation.

---

## Repository layout

This repository itself contains **no driver sources**.  
It only provides:

- `install.sh` → one-click installer  
- `uninstall.sh` → clean removal  
- `dkms.conf` → DKMS configuration template  

⚠️ **Note:** The actual Cirrus Logic driver code is **not redistributed here**.  
It is fetched at install time from the upstream project [`davidjo/snd_hda_macbookpro`](https://github.com/davidjo/snd_hda_macbookpro).  
This keeps licensing clear and avoids duplicating upstream work.

---

## Verification

After installation:

```bash
# Check module info
sudo modinfo snd_hda_codec_cs8409 | grep -E 'filename|version'

# Check DKMS status
sudo dkms status
```

---

## Notes & Troubleshooting

- **No sound after suspend/resume**  
  → This wrapper does not install resume hooks. You may need additional udev/systemd scripts.  

- **Build fails**  
  → Ensure kernel headers match your running kernel (`uname -r`).  

- **Multiple kernels installed**  
  → DKMS automatically builds the module for all installed kernels.  

- **Upstream changes**  
  → Each install run pulls the latest upstream sources, so you always build against the current driver.

---

## License

This wrapper is provided under the MIT license (or your preferred license).  

The **driver code itself** is owned and licensed by its upstream authors and is fetched directly from their repository.  
This project does **not** redistribute the driver, only automates building and installing it via DKMS.
