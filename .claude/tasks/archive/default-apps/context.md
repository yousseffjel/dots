# Context — default-apps

## Background
User asked for default apps: browser, zip/rar, images, video, Sublime Text. Choices (AskUserQuestion, 2026-10-13):
Sublime via official repo as default editor; mpv; nsxiv from source; Firefox unchanged.

## Prior Decisions
- Rule 4: third-party repos only with explicit authorisation (clipmenu COPR, Flathub). This adds a third.
- Locked decision 8: unar for RAR (no RPM Fusion) — archives already default to file-roller, unchanged.
- mimeapps.list is COPIED, write-if-absent (install-restore-apps.sh deploy_app_file).

## References
- nsxiv v34: https://codeberg.org/nsxiv/nsxiv/archive/v34.tar.gz sha256 eee8e947a0a4103d41d892c8b0c5ef1e5364a29a62821aab47feeb9c71a96474
- Sublime repo: https://download.sublimetext.com/rpm/stable/<arch>/sublime-text.repo (gpgkey sublimehq-pub.gpg)

## Notes
- nsxiv is NOT in Fedora (mdapi 400 on f43/f44/rawhide); sxiv/imv/ristretto are. mpv, imlib2-devel, libexif-devel: 200 on f43+f44.
- nsxiv.desktop: NoDisplay=true, Exec=nsxiv %F, MimeType includes svg (keep svg on firefox).
