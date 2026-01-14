#!/bin/bash

# Fetch latest release URL from GitHub API
LATEST_RELEASE=$(curl -s https://api.github.com/repos/namidaco/namida-snapshots/releases/latest | \
  jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url')

# Get the filename from URL
FILENAME=$(basename "$LATEST_RELEASE")

# Extract name without extension for folder name
FOLDERNAME="${FILENAME%.tar.gz}"

# Download the latest release
echo "Downloading $FILENAME..."
# cd ~/Downloads
wget "$LATEST_RELEASE" -O "$FILENAME"

# Extract the tar.gz file
echo "Extracting $FILENAME..."
mkdir -p "$FOLDERNAME"
tar -xzf "$FILENAME" -C "$FOLDERNAME" --strip-components=1 && rm "$FILENAME"

# Change to extracted directory
cd "$FOLDERNAME" || exit

# Install desktop file and icon
echo "Installing application..."
sudo cp ./share/applications/namida.desktop /usr/share/applications/namida.desktop && \
sudo cp ./share/pixmaps/namida.png /usr/share/pixmaps/namida.png && \
sudo chmod +x /usr/share/applications/namida.desktop && \
sudo update-desktop-database


echo "Installation complete! You may need to log out and in again."