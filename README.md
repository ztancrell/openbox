# Openbox

A fork of [danakj's Openbox](https://github.com/danakj/openbox) with stability patches: crash hardening, an out-of-bounds read fix, a session coordinate bug, O(n) session loading, wider window-title support, and build scripts.

Reviewed and optimized with [OpenCode AI](https://opencode.ai).

Standards-compliant, highly configurable X11 window manager.

Based on **Openbox 3.7**, upstream commit [`3a2fbc65`](https://github.com/danakj/openbox/commit/3a2fbc65186c54855915490ec3d0b4b2ddc079ea). Full upstream history is preserved — `git log` and `git blame` still attribute every line to whoever wrote it.

```sh
./bootstrap          # only from a git checkout
./configure
make
sudo make install
```

Or use the included script:

```sh
./install-openbox.sh --install-path /usr/local
```

### Fork Features

- **Crash hardening** — six `g_assert()` calls on code paths that can legitimately fail at runtime, converted to logged early-returns. A failed X11 round trip against a destroyed window no longer aborts the window manager and takes the session with it
- **Bounded property reads** — `convert_text_property()` walked text properties with `strlen()`, reading past the end of the buffer when a client sets a property that is not NUL-terminated. Now bounds-checked with `strnlen()`
- **Session coordinate fix** — `session_save_to_file()` stored `pre_fullscreen_area.x` into the saved *y* coordinate. Windows restored from a session that had been fullscreened came back at the wrong vertical position. One character, real bug
- **O(n) session loading** — duplicate saved-window detection was a nested loop comparing every state against every other. Replaced with a single `GHashTable` pass keyed on session id, falling back to the command string
- **Wider title support** — `_NET_WM_NAME` and `_NET_WM_ICON_NAME` are now accepted in any encoding, not only `UTF8_STRING`, before falling back to the legacy `WM_NAME` / `WM_ICON_NAME`
- **Stale-window cleanup** — client validation now verifies that each XID still names a live window. A short, coalesced post-launch sweep removes dead Proton/Wine clients automatically; Alt-Tab and close requests also validate them, and `_NET_CLIENT_LIST` is republished for taskbars
- **Build scripts** — a full bootstrap-to-install pipeline, plus a verification-first variant that refuses to build unless every patch below is actually present in the tree
- **Debug visibility** — every new guard logs through `ob_debug()`, so all of these conditions remain observable under `openbox --debug`

### Crash Hardening

| File | Function | Change |
|------|----------|--------|
| `openbox/frame.c` | `check_32bit_client()` | Dropped `g_assert(ret != BadDrawable)` / `g_assert(ret != BadWindow)`. Returns `NULL` on a failed query or a `None` window |
| `openbox/client.c` | `client_get_area()` | Dropped `g_assert(ret != BadWindow)`. Returns early on a failed geometry query |
| `openbox/client.c` | `client_try_configure()` | Dropped `g_assert(*w > 0)` / `g_assert(*h > 0)`. Logs and restores the current valid geometry on a non-positive computed size |
| `openbox/client.c` | `client_fullscreen()` | Dropped the `pre_fullscreen_area` assert. Logs and returns instead of aborting on corrupt restored geometry |
| `openbox/client.c` | `client_maximize()` | Dropped two `pre_max_area` asserts. Same treatment |
| `obrender/image.c` | `ResizeImage()` | Dropped four dimension asserts. Returns `NULL` on a zero source or destination extent |

### Details

`g_assert()` aborts the process. That is correct for a violated invariant, but several of these conditions are not invariants — an X server round trip against a window that a client destroyed a microsecond ago legitimately fails, and geometry read back from a truncated session file is legitimately garbage. Aborting the window manager over either one loses every open window, not just the offending one.

The trade is deliberate: availability over strictness. An assertion that fires is telling you something is wrong, and converting it to a return can let a genuine upstream bug pass quietly. That is an acceptable trade for a daily-driver desktop and **not** obviously the right call for upstream, which is one reason these live in a fork.

The out-of-bounds read in `obt/prop.c` is the one change here that is unambiguously a bug fix rather than a trade, since the length is attacker-controlled by any client that can set a property:

```c
gsize remain = (gchar*)tprop->value + tprop->nitems - p;
gsize slen = strnlen(p, remain);
if (slen == remain) break;   /* not null-terminated */
p += slen + 1;
```

### Scripts

| Script | Purpose |
|--------|---------|
| `install-openbox.sh` | Full build: dependency check, `bootstrap`, `configure --enable-debug`, parallel `make`, `sudo make install`, version verification. Supports `--install-path`, `--build-dir`, `--rebuild`, `--dry-run`, `--verbose`. Refuses to run as root |
| `install-openbox-minimal.sh` | Verification-first installer for an already-configured tree. Greps the source to confirm each patch above is present, aborts if any is missing, then builds and installs |

### Not Included

Four changes were written for this fork and then rejected during review. Documenting them matters as much as the changelog:

- **No `po/` changes** — a regeneration pass rebuilt the translation catalogs against a stale 2014 `.pot` template, silently dropping 3 Bulgarian and 8 Esperanto translated strings. Fully reverted; the translations here are upstream's, untouched
- **No image-cache changes** — a refactor of `obrender/imagecache.c` attached `GDestroyNotify` callbacks that dereferenced their argument as `CachedImage *`, when the tables actually store `RrImageSet *`. Type confusion, double-free on every eviction, and redundant besides — `RrImageSet` lifetime is already handled by explicit refcounting in `obrender/image.c`. Reverted
- **No renderer changes** — a "GPU cache" in `obrender/render.c` amounted to five declarations and a function that nothing in the tree ever read, wrote, or called. Reverted
- **No new features** — this fork fixes crashes. That is all it does

### AI Disclosure

**Every source change in this fork was written by [OpenCode AI](https://opencode.ai), not hand-written by me.** I chose the targets, reviewed the output, run the result as my daily window manager, and made the final call on what ships.

The four items under [Not Included](#not-included) are the AI's rejected work. Two of them — the double-free and the lost translations — were worse than the bugs they were meant to fix, and **all four were caught by review, not by the AI.** Extend the surviving patches proportionate skepticism: they are small, they are tested on one machine, and no upstream maintainer has looked at them.

**None of this has been submitted to or accepted by upstream Openbox.** Do not report bugs in this fork to the Openbox maintainers.

### Credits

Openbox is the work of many people over two decades and **7,661 commits**. This fork contributes roughly 100 changed lines to a project of over 52,000 lines of C. The credit belongs upstream; the bugs in this fork are mine.

| Contributor | Commits |
|-------------|---------|
| **Dana Jansens** — original author and maintainer; Openbox as it exists today is largely her work | 6,399 |
| **Mikael Magnusson** | 819 |
| **Scott Moynes** | 127 |
| **Derek Foreman** | 84 |
| **Marius Nita** | 82 |

...and everyone else in [`AUTHORS`](AUTHORS) and `git shortlog -sn`, including every translator whose work lives in `po/` — which is precisely why the accidental translation regression above was reverted rather than shipped.

- Upstream repository: <https://github.com/danakj/openbox>
- Project website: <http://openbox.org>

### License

GNU General Public License, version 2 or later — inherited from Openbox and unchanged. See [`COPYING`](COPYING).

Copyright for all pre-existing Openbox code remains with its original authors. The modifications described here are released under the same license.
