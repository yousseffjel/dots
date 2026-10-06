# Context — gtk2-theme-template

## Background
"What is next" item 4 (2026-10-06). lxpolkit 0.5.6 on f44 requires
libgtk-x11-2.0.so.0 (mdapi). gnome-themes-extra / adwaita-gtk2-theme exist in
f43 but return 400 for f44 and rawhide (mdapi, checked 2026-10-06).

## Prior Decisions
- extra.lst: gtk-murrine-engine deliberately not listed (GTK2-only engine).
- gtk.css policy: claim if absent, back up + overwrite if pre-existing.
- scope-d decision 8: symmetry test never runs engine post-commands.

## References
- config/theme/templates/always/README.md (three target styles)
- scripts/install-restore-theme.sh theme_claim_gtk_css / theme_backup_preexisting
