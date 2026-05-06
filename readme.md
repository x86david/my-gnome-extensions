# 📘 **README — GNOME-Core Bootstrap for Debian (FlexOS Edition)**

## 🧩 Overview

This repository provides a **custom bootstrap for Debian + GNOME-Core**, designed to transform a minimal Debian installation into a clean, modern, optimized GNOME environment with curated extensions, a custom shell theme, and a recommended panel configuration.

The entry point is:

```
bootstrap.sh
```

This script must be executed **as root**, immediately after the first login, using the one‑liner provided below.

---

## 🖥️ Installation Requirements

During Debian installation, when tasksel appears, select **only**:

### ✔ Standard system utilities  
### ❌ Do NOT select GNOME  
### ❌ Do NOT select Desktop Environment  
### ❌ Do NOT select anything else  

The bootstrap installs **GNOME-Core minimal**, avoiding the heavy, bloated default Debian GNOME meta-package.

---

## 🚀 One‑liner Bootstrap Command

After the first login as root

```bash
apt update && apt install curl && curl -fsSL https://tinyurl.com/debianx86
```

This downloads and executes the full GNOME-Core bootstrap.

---

## ⚙️ What the Bootstrap Does

### 🟦 1. Installs base system components
- sudo  
- git  
- NetworkManager  
- GNOME-Core minimal  

### 🟦 2. Cleans `/etc/network/interfaces`
Leaves only loopback and hands full control to NetworkManager.

### 🟦 3. Clones this repository into:
```
/usr/local/share/my-gnome-extensions
```

### 🟦 4. Installs GNOME extensions
Includes:
- Official extensions from APT  
- Local extensions bundled in the repo  

### 🟦 5. Installs a custom GNOME Shell theme
Theme: **Flat Remux Dark Fullpanel**  
Automatically copied to all users.

### 🟦 6. Imports the custom Dash‑to‑Panel configuration
A pre-tuned layout for a clean, modern top panel.

### 🟦 7. Enables default extensions for **all new users**
A script in `/etc/profile.d/` ensures that any newly created user receives the full preset on their first login.

### 🟦 8. Adds all existing users to the sudo group
Ensures the system is usable immediately.

### 🟦 9. Automatically creates a new recommended user
After the first login, the bootstrap:

- Creates a new user (you will be prompted for the username)  
- Sets its password  
- Adds it to the sudo group  

This user becomes your **real daily account**.

---

## ❗ What the Bootstrap Does NOT Do

To avoid overwriting user preferences or breaking existing setups, the bootstrap **does not**:

### ❌ Enable extensions for the user created during Debian installation  
This user (e.g., `dperez`) logs into a **vanilla GNOME session**.  
This is intentional: it acts as an **initial setup user**, similar to macOS or Android.

### ❌ Overwrite existing dconf settings  
Only new users receive the preset automatically.

### ❌ Force themes or panel settings if the user has already customized them  
User choices always take priority.

---

## 👤 Recommended Workflow (Best Experience)

For the intended FlexOS experience:

### 1️⃣ Install Debian minimal  
Only with *standard system utilities*.

### 2️⃣ Log in as the installation user (e.g., `dperez`)  
This user is temporary and uses GNOME defaults.

### 3️⃣ Run the bootstrap one‑liner  
The system is fully prepared.

### 4️⃣ Let the bootstrap create your real user  
This new user automatically receives:

- All GNOME extensions enabled  
- Dash‑to‑Panel configuration  
- Custom theme installed  
- Clean GNOME-Core environment  

### 5️⃣ Log in as your new user  
Enjoy the full FlexOS GNOME experience.

### 6️⃣ Delete the installation user  
Once everything is set up, the initial user is no longer needed.

---

## 🎨 Recommended Post‑Setup Tweaks

To complete the intended look and feel:

### ✔ Enable the custom Shell theme  
GNOME Tweaks → Appearance → Shell Theme →  
**Flat Remux Dark Fullpanel**

### ✔ In Dash‑to‑Panel settings, disable:
- **Date Menu → Visible**  
- **System Menu → Visible**

These are already provided by the top panel layout.

### ✔ Verify extensions are enabled  
The preset includes:

- Dash‑to‑Panel  
- Caffeine  
- GPaste  
- Drive Menu  
- System Monitor  
- Tiling Assistant  
- Vertical Workspaces  
- Hibernate Status  
- User Theme  
- Desktop Icons NG  
- Local widgets and utilities  

---

## 🧱 Repository Structure

```
my-gnome-extensions/
 ├─ bootstrap.sh                ← Entry point
 ├─ setup-extensions.sh
 ├─ install.zsh.sh
 ├─ dash_to_panel.config        ← Custom panel configuration
 ├─ flat-remux-dark-fullpanel/  ← GNOME Shell theme
 └─ local-extensions/           ← User extensions included in the repo
```

---

## 🧩 Project Goal

This project aims to deliver a **minimal, fast, clean, reproducible GNOME environment** with:

- A modern top panel  
- Essential extensions  
- A dark, elegant theme  
- A consistent experience for all new users  
- Zero bloat  
- Zero unnecessary packages  