# Progress — live-luks

## Status
`in-progress`

## Steps
- [x] 1. Choice + secret (new module install-live-luks.sh): answers key LUKS_PASSFILE with a valida…
- [x] 2. Format + open: `cryptsetup luksFormat --type luks2 --pbkdf argon2id` and `open`, with the …
- [x] 3. Resume + close: the resume check accepts a mapper source backed by this disk's dots-root; …
- [x] 4. Target config (before `xbps-reconfigure -fa`): cryptsetup in the target (base.lst, unless …
- [x] 5. Tests: cryptsetup fake in tests/lib/live-disk-env.sh (records calls; asserts the secret is…
- [x] 6. Records + VM: scope file (status, decisions 13-14 recorded at plan time), CHANGELOG, CLAUD…

## Deviations
- Step 4: no /etc/crypttab (user, 2026-10-16). runit-void's crypt.awk luksOpens every crypttab line unconditionally after dracut already opened root via rd.luks.uuid, which would risk a second prompt. Dracut alone unlocks root.
- Step 4: kernel args go in GRUB_CMDLINE_LINUX, not _DEFAULT as the scope row says. Found on the UEFI VM: grub-mkconfig gives _DEFAULT to normal entries only, so the recovery ("single") entries had no rd.luks.uuid=. Type B.
- Step 3: --skip-dots path closes nothing: it unmounts nothing either (the user does `umount -R && reboot`), and reboot tears the mapping down.
- Added rd.vconsole.keymap= and a loadkeys before the dialog passphrase, so the boot prompt and the install-time entry use the same layout. Type B.
- The live mapping is named luks-<UUID> (dracut's boot name), not dots-root, so grub-mkconfig / xgenfstab read the same name the booted system has.

## Blockers
