#!/bin/bash

# Script corrigé pour Wodh AI
echo "🔨 Construction de l'application..."
flutter build linux

echo "📦 Préparation du package..."
PKG_DIR="wodh_ai_pkg"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/share/wodh_ai"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"

echo "📂 Copie des fichiers..."
cp -r build/linux/x64/release/bundle/* "$PKG_DIR/usr/share/wodh_ai/"

echo "🚀 Création du lanceur..."
echo '#!/bin/sh
exec /usr/share/wodh_ai/wodh_ai "$@"' > "$PKG_DIR/usr/bin/wodh-ai"
chmod +x "$PKG_DIR/usr/bin/wodh-ai"

echo "🎨 Création de l'entrée menu..."
echo '[Desktop Entry]
Version=1.0
Type=Application
Name=WODH AI
Exec=wodh-ai
Icon=/usr/share/wodh_ai/data/flutter_assets/assets/logo.png
Comment=Application WODH AI
Categories=Utility;
Terminal=false' > "$PKG_DIR/usr/share/applications/wodh-ai.desktop"

echo "📝 Fichier de contrôle..."
echo "Package: wodh-ai
Version: 2.4.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Vous <votre@email.com>
Description: Application WODH AI" > "$PKG_DIR/DEBIAN/control"

echo "🛠️ Construction du .deb..."
dpkg-deb --build "$PKG_DIR"

echo "✅ Terminé! Package créé: wodh_ai_pkg.deb"
echo "Pour installer:"
echo "sudo dpkg -i wodh_ai_pkg.deb && sudo apt-get install -f"