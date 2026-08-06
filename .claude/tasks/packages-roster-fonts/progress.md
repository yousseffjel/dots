# Progress — packages-roster-fonts

## Status
`in-progress`

## Steps
- [x] 1. Verify each candidate on packages.fedoraproject.org (14 packages + 2 Nerd Fonts). Record the method.
- [x] 2. Add verified names to `extra.lst` under the existing category comments; drop `kitty`.
- [x] 3. Adopt `~/.config/starship/starship.toml`, replacing the ASCII placeholder.
- [x] 4. Swap the `󰣇` Arch logo for a Fedora one (U+F30A, nf-linux-fedora).
- [x] 5. Measure prompt render time as-adopted vs `right_format` trimmed; report both numbers.
- [x] 6. Verify: `tests/pkglist.sh`, `tests/lint.sh`, starship parses and renders.

## Step 6 verification results

| Check | Result |
|---|---|
| `tests/pkglist.sh` | ✅ format, duplicates, core/extra overlap all ok |
| `tests/lint.sh` | ✅ after fixing one shfmt violation it caught (repo uses `-bn`, binary ops at line start) |
| `shellcheck -x install-pkg.sh` | ✅ clean |
| starship parses adopted config | ✅ `print-config` ok |
| starship renders | ✅ Fedora glyph leads; directory/branch/status colours intact |
| Fedora glyph landed | ✅ U+F30A confirmed by codepoint; zero occurrences of the Arch glyph |
| Installer dry-run | ✅ all 14 new packages listed, `kitty` absent |
| starship branch: already-installed | ✅ "already installed: starship (/usr/bin/starship)" |
| starship branch: dry-run | ✅ reports target dir, touches nothing |
| starship branch: curl absent | ✅ yellow warning, **run continues to "✓ package stage complete"** |
| Manifest hygiene | ✅ zero starship rows in the sandbox manifest; zero `/tmp/` rows in the real one |

`install-pkg.sh` hard-exits without `dnf`, so exercising it on this Arch host
required a sandbox with a stubbed `dnf`/`sudo`/`rpm` and a `/usr/bin` mirror
that omits `starship` and `curl` (so `command -v` genuinely fails for them).
All four XDG vars overridden per the `installer-test-sandbox-xdg` memory; the
real manifest was checked clean afterwards.

**Not verified here:** that the packages actually install. That needs a real
Fedora box — the CI `install-dry-run` job validates names against live repos,
and CLAUDE.md already tracks "never run end-to-end on real hardware" as open.

## Step 1 verification results

Method: packages.fedoraproject.org search + direct package pages (no `dnf` on
this Arch host). Checked 2026-08-06 against Fedora 43/44/Rawhide.

| Package | Verdict | Notes |
|---|---|---|
| `alacritty` | ✅ F43/44/Rawhide | "Fast, cross-platform, OpenGL terminal emulator" |
| `zoxide` | ✅ F43/44/Rawhide + EPEL 8/9 | |
| `fastfetch` | ✅ F43/44/Rawhide + all EPEL | |
| `firefox` | ✅ F43/44/Rawhide | |
| `maim` | ✅ F43/44/Rawhide | |
| `slop` | ✅ F43/44/Rawhide | |
| `xss-lock` | ✅ F43/44/Rawhide + all EPEL | |
| `unar` | ✅ F43/44/Rawhide | confirms locked decision 8 — no RPM Fusion needed |
| `thunar-volman` | ✅ F43/44/Rawhide | |
| `ffmpegthumbnailer` | ✅ F43/44/Rawhide | |
| `catfish` | ✅ F43/44/Rawhide | |
| `bluez` | ✅ F43/44/Rawhide + all EPEL | |
| `blueman` | ✅ F43/44/Rawhide | |
| `cascadia-code-nf-fonts` | ✅ F43/44/Rawhide | 2407.24; CaskaydiaCove == Cascadia Code upstream |
| `starship` | ❌ **not packaged** | see D1 |
| JetBrains Mono Nerd Font | ❌ **not packaged** | see D2 |

## Deviations

**D1 — `starship` is not in Fedora's official repos.** Zero results across
every release; it was dropped around F37 and the canonical route is now the
COPR `atim/starship` (`dnf copr enable atim/starship && dnf install
starship`). CLAUDE.md rule 4 therefore forbids putting it in `extra.lst` — it
needs a header note plus a closing yellow reminder. Two problems follow:

1. The yellow reminder belongs in `scripts/install-pkg.sh`, which is outside
   this plan's `## Allowed` (`packages`, `config/starship`).
2. This is not cosmetic. Sub-task 1 already made starship the prompt, and this
   sub-task adopts the user's 405-line config. On a fresh Fedora box the
   `(( $+commands[starship] ))` guard in `99-prompt.zsh` fails, the shell
   silently falls back to `prompt adam1`, and the adopted config sits unused.

**D2 — there is no JetBrains Mono Nerd Font in Fedora.** The only `-nf-fonts`
package family is Cascadia (`cascadia-code-nf-fonts` with ligatures,
`cascadia-mono-nf-fonts` without). `jetbrains-mono-fonts` produces only
`jetbrains-mono-fonts-all` and `jetbrains-mono-nl-fonts`, neither carrying
nerd glyphs. Locked decision 14's "both Nerd Fonts" is therefore only half
satisfiable from official repos.

**D1 resolution (user decision, 2026-08-06):** install starship via its
official script (`https://starship.rs/install.sh`) rather than a COPR. The
trade-offs were stated when the option was offered and chosen anyway: it pipes
a remote script to a shell, and it installs outside dnf, so dnf cannot upgrade
or remove it. Mitigations applied: hardened curl flags
(`--proto '=https' --tlsv1.2 -sSf`), an idempotent `command -v starship` guard,
dry-run support, best-effort failure handling (yellow warning, never aborts),
and a manifest row so `uninstall.sh` can still remove the binary.

**Scope extension, entailed by that choice:** `scripts/install-pkg.sh` added to
`## Scope` and `## Allowed`. starship cannot be expressed in `packages/*.lst`
at all — it is not a dnf package — so the install has to live in the stage
script. Recorded here rather than drifting silently.

**D2 resolution:** ship `cascadia-code-nf-fonts` as the glyph font and keep the
existing `jetbrains-mono-fonts-all` for UI surfaces. This preserves the split
the user asked for (Caskaydia in the terminal, JetBrains Mono in the UI);
nothing in the UI needs nerd glyphs, and fontconfig falls back to Caskaydia for
any that appear. Stated in-thread; no objection.

## Step 5 measurement — the right_format concern was unfounded

Timed with `starship prompt --status=0`, 20 renders per figure:

| Scenario | As-adopted (~60 modules) | Trimmed (8 modules) |
|---|---:|---:|
| Plain dir, no git | 3.7 ms | — |
| 13 language markers present (worst case) | 9.2 ms | 7.3 ms |
| Inside the dots repo (real git history) | 8.4 ms | — |

Trimming `right_format` buys **~1.9 ms per prompt** — imperceptible, and aimed
at the wrong thing: `git_status` alone costs ~4.7 ms, about 2.5x what all sixty
language modules cost together. starship only runs a module's detector when the
directory matches, and those detectors are cheap file-existence checks.

**Outcome: no trim.** The config ships exactly as the user wrote it. The
planning-stage worry recorded in the scope file is retracted, not deferred.

## Blockers
_(none)_
