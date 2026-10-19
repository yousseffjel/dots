# Progress — live-docs

## Status
`in-progress`

## Steps
- [x] 1. `--help` prints the header's full usage text, read from the script itself
- [x] 2. docs/live-answers.example
- [x] 3. docs/LIVE-INSTALL.md
- [x] 4. tests/live-docs.sh
- [x] 5. README, CHANGELOG, CLAUDE.md
- [x] 6. VM matrix {UEFI,BIOS}×{plain,LUKS}
- [x] 7. Lint + tests (2026-10-19, after the ly fix: lint ok, live-docs ok, ly-theme ok, run-tests 91 OK / 0 FAIL)

## Deviations
- Step 4: shipped example is refused by the parser twice (invalid + missing USER_PASSWORD_HASH); the test expects both lines.

## Notes
- Mutation check of tests/live-docs.sh on scratch copies: 8/8 caught, each for the right reason (doc row dropped, required flipped, new key in code, example key dropped, example ships a hash, bad tz, new flag in code, flag missing in doc).
- Full suite (tests/run-tests.sh): 91 OK, exit 0. tests/lint.sh passes.
- Matrix plan: j3 UEFI plain (answers, the shipped example filled as the page says) → j3 UEFI LUKS (dialog) → j3b BIOS plain (dialog) → j3b BIOS LUKS (answers + LUKS_PASSFILE). User password `dots` (hash salt dotsJ5vm).
- Quick start verified on the ISO (2026-10-16): `xbps-install -Syu xbps`, `xbps-install -y git`, `git ls-remote https://github.com/yousseffjel/dots` all exit 0.
- Run 1 dry-run with the filled example: "every check passed".

## Blockers
- **Run 1 — UEFI, plain, answers (the shipped example, filled per the page): PASS.** install-live.sh exit 0. First boot: ly; `dots doctor` rc=0, no failures, 1 warning (spice-vdagent, VNC). vda1 dots-esp /boot/efi, vda2 dots-boot /boot, vda3 dots-root /; /swapfile 1.8G prio 10, zram0 1.9G prio 32767; kernel 6.18.57_1. NetworkManager's first lease carries hostname `voidbox` (the dhcpcd lease from the ISO shows `-`), confirming the page's caveat. A first ly login "failed" only because the driver typed before ly focused the password field (ly.log: one PamAuthError at the moment of a stray Enter); tty1 login with the same password worked, and a second ly login started the desktop.
- **Run 2 — UEFI, LUKS, dialog menus: PASS.** Every menu answered over the serial console (defaults for hostname `void`, timezone, keymap, locale; user ysf; root left empty; disk picked and `/dev/vda` typed; encryption Yes via Tab; passphrase twice); the plan showed `encrypt / is LUKS2 (argon2id)`. Done → "Reboot now?" answered No; `/mnt` unmounted and the mapping closed (`/dev/mapper` holds only `control`). First boot: one dracut prompt, then ly; `dots doctor` rc=0, 1 warning (spice-vdagent); vda3 → luks-<UUID> on /, rd.luks.uuid= in /proc/cmdline, swapfile + zram active. Also seen: an Esc that reached the encrypt question cancelled with "Cancelled. Nothing was written." (a Left-arrow escape split over the serial link).
- **Open: the first ly login after first boot was refused twice (runs 1 and 2)** with the right password: ly.log `PamAuthError`. tty1 accepts it, and a second ly attempt into a cleared field logs in. Under investigation.

## Pause — 2026-10-16
Paused after step 5 (steps 1-5 done; step 7 lint + full suite green at that point). Next: finish step 6, then the doc caveat below, re-run step 7, audit-loop, reviewer.
Reason: intentional suspend (user asked for a handoff at 17:56 UTC).

### Matrix state
- Run 1 UEFI plain (answers) PASS; run 2 UEFI LUKS (dialog) PASS — both above.
- **Run 3 BIOS plain (dialog) was installing on `dots-live-j3b` at pause** (all menus answered, encrypt No, plan confirmed ~17:55). On resume check its console: `python3 console.py dots-live-j3b 30 run 'tail -5 /root/run3.log'`. If it reached "Reboot now?", answer No (`keys $'\t'`, then `keys '\r'`). If the VM was stopped, redo the run (`setup.sh` re-boots it from the ISO; the repo disk already holds snapshot 03f0a4f). Then `./todisk.sh dots-live-j3b`, destroy, start, check first boot.
- Run 4 BIOS LUKS (answers): same `dots-live-j3b`, the shipped example filled as in run 1 plus `LUKS_PASSFILE=/root/luks-pass` made with `(umask 077; printf '%s\n' 'dots-luks-5' >/root/luks-pass)`. Passphrase at boot: `dots-luks-5`.
- The snapshot on the repo disk is of the slot at 03f0a4f-time content. If the slot changes before runs 3/4, rebuild: setup.sh only snapshots when `repo.img` is absent — make a new dir/name rather than `rm` (the rm of a variable path is blocked).

### VM tooling (session scratchpad, survives until host reboot)
`/tmp/claude-1001/-home-ysf-dev-dots/9de84f18-caad-4085-a8e0-7f1367bf2a0e/scratchpad/vm/`: console.py (serial driver), typ.py (send-key typer + Enter), typn.py (no Enter), setup.sh `<slot-dir> <dom>` (snapshot once + ISO boot), todisk.sh `<dom>`, hash5 (password `dots`, salt dotsJ5vm), `<dom>-disk.xml`/`-iso.xml`. Copies of console.py/typ.py also in the J-4 scratchpad `…/2a5f0147-…/scratchpad/vm/`. Lessons: over serial, Tab (not Left-arrow, which arrives split as Esc = cancel) selects Yes in a yes/no; a `keys` wait regex must not match "failed" (install-void prints "1 failed load(s)"); wait on `Reboot now\?`.

### Finding to act on: first-boot ly login
The first ly login after a fresh install fails with "authentication error" (runs 1 and 2). Cause, confirmed from config, to be confirmed on screen at run 3's first boot: ly's `default_input = login` (tests/fixtures/ly-config-1.4.0.ini:158) starts the cursor on the login line, a user selector, until a successful login is saved (`save = true`). Typed characters go nowhere and Enter submits an EMPTY password → PamAuthError. Later boots start on the password field (fast login on boot 2+ worked). To confirm: at run 3's first ly screen, `typn.py dots-live-j3b dots` and screenshot (expect no asterisks); then Down/Tab, type, Enter → desktop.
**Decision for the user (do not pick silently):** (a) document it in docs/LIVE-INSTALL.md "Known caveats" ("on the first boot press Down to reach the password field"), or (b) also set ly's `default_input = password` in install-services-ly.sh / ly-theme (code change, out of this slot's Scope — would need a plan deviation). Recommend (a) now, (b) as a follow-up.

### Still to do after the matrix
1. docs/LIVE-INSTALL.md caveat per the decision above; note in the page that the `--skip-dots` dhcpcd-hostname caveat was verified (NM lease carried `voidbox`).
2. Re-run step 7 (tests/lint.sh, tests/live-docs.sh, tests/run-tests.sh) — all green at 17:1x before the matrix.
3. audit-loop (Medium+: 4 sweeps), fill review.md, reviewer subagent (prompt must forbid worktree edits), then /test, /commit. Records fold (MASTER_PLAN J-4 + J-5, scope-j status, CURRENT_AUDIT) is a main-side chore after merge.
4. Follow-up to log in the change log: the J-4 open bug (after `timeout -s INT`, install-void.sh continues inside xchroot with sudo revoked).

## Resumed — 2026-10-19
- Host had rebooted: scratchpad VM tooling rebuilt from transcripts (console.py gained a `keys TEXT RE` mode). Run 3 redone from scratch on a fresh snapshot (ed7c21d = slot content as of today).
- Lesson: the plan dialog ("Install Void here?") defaults to YES — Tab there moves to No and cancels ("Cancelled. Nothing was written."). Only the encrypt yes/no is --defaultno.
- **Deviation (user decision, 2026-10-19): "Document + fix in this slot"** for the ly first-boot login. Fix: `scripts/theme/ly-theme.sh` writes `default_input = password` with its other keys (the one writer of ly's config, so restore/manifest come with it); an existing originals file gains the original line of any key it lacks, so `--restore` covers keys added after the first theme. Scope += scripts/theme/ly-theme.sh, tests/ly-theme.sh. Run 3 (old code) confirms the bug on screen; run 4 (new snapshot) proves the fix.
- THEMING.md § login screen: the Fedora %config(noreplace)/.rpmnew upgrade sentence replaced with the Void facts (built from source, LYBUILD rows, a re-run skips the build, uninstall removes config.ini); SELinux label remark dropped there and in ly-theme.sh's header (user request 2026-10-19). Noted, not changed: ly_install skips on any LYBUILD /usr/bin/ly, so a future LY_VERSION bump never rebuilds an existing install — follow-up.
- **Run 3 BIOS plain (dialog), 2026-10-19: PASS** (snapshot ed7c21d, code BEFORE the ly fix). Install exit 0, /mnt unmounted. First boot: ly showed `login < ysf >` focused; typing `dots` put nothing in the password field (screenshot) — **first-boot bug confirmed on screen**. Down + password + Enter → dwm desktop. `dots doctor` rc=0, no failures, 1 warning (spice-vdagent, VNC). vda1 1M dots-bios, vda2 1G dots-boot /boot, vda3 19G dots-root /; /swapfile 1.9G prio 10, zram0 1.9G prio 32767.

## Follow-ups (carry into the change log's Next Steps, and the MASTER_PLAN Queue at the post-merge fold)
1. **J-4 SIGINT bug** — after `timeout -s INT`, install-void.sh carries on inside xchroot with the temporary sudo rule already revoked.
2. **ly pin bump never reaches an existing install** (found 2026-10-19 while fixing THEMING.md). `ly_install` (scripts/install-services-ly.sh:160) returns "already built and installed by dots" whenever the manifest has `LYBUILD … /usr/bin/ly` and the binary is executable; it never compares the installed version with `LY_VERSION`. Its message even prints the PINNED version ("ly v$LY_VERSION already built"), so after a bump it would claim the new version while the old one runs. So raising `LY_VERSION`/`LY_COMMIT` rebuilds only fresh installs (or after `dots uninstall`); `dots update` keeps the old ly. A fix needs a version record (e.g. the version in the LYBUILD row, or `ly --version` against `LY_VERSION`) and a rebuild that keeps `/etc/ly/config.ini` (ly_place would `cp` the stock one over the themed file — ly-theme.sh re-themes it right after in the services stage, but any user edit would be lost) plus a test in tests/ly-build.sh. Not urgent: 1.4.1 is pinned on purpose (1.5.0 drops keys ly-theme.sh writes).
- **Run 4 BIOS LUKS (answers + LUKS_PASSFILE), 2026-10-19: PASS** (snapshot da98a29, WITH the ly fix). The shipped example filled as the page says (hash, DISK/WIPE, LUKS_PASSFILE root 0600). Install rc 0; mapping closed after (only `control` in /dev/mapper), /mnt unmounted. Boot: ONE prompt "Enter passphrase for /dev/vda3". **First ly screen: cursor on the password field; typing `dots` showed `****` with no Down key — fix verified on screen.** Enter → dwm desktop. `dots doctor` rc=0, no failures, 1 warning (spice-vdagent). vda3 → luks-8ecd1dc2-… crypt on /; /swapfile 1.9G prio 10, zram0 1.9G prio 32767; `rd.luks.uuid=8ecd…` + rd.vconsole in /proc/cmdline; crypttab entries 0; /etc/ly/config.ini `default_input = password`.
- **Matrix complete: 4/4 PASS** (UEFI plain answers, UEFI LUKS dialog, BIOS plain dialog, BIOS LUKS answers).
- VM lesson: typ.py has no `^` mapping either (stops mid-line like `[`); first-zsh zinit clones slow typing — screenshot only after they finish.
