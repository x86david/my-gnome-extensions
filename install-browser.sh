#!/bin/bash
set -e

echo "📦 Installing Tor Browser Launcher..."
# This package manages the download and updates automatically
sudo apt update
sudo apt install -y torbrowser-launcher

echo "🎨 Integrating with GNOME menu..."
# This triggers the initial download and icon creation for the current user
# If run as root, it sets up the system-wide framework.
# The actual browser is downloaded to the user's home on first launch for security.
update-desktop-database 2>/dev/null

echo "✅ Tor Browser Launcher installed."
echo "💡 To finish setup, search for 'Tor Browser' in your GNOME menu and launch it."
