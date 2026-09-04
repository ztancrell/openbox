# AI assistance policy

Openbox Patchwork uses AI tools to help inspect code, develop patches, write
tests, and improve documentation. The current patch set has received
assistance from OpenCode and OpenAI Codex.

AI-generated output is treated as an untrusted proposal, not as evidence that
a change is correct or secure. The repository owner chooses the work to pursue,
reviews the resulting diff, tests it, and decides what is published.

## Acceptance checklist

Before a patch is presented as ready for use:

1. Tie it to a reproducible bug, a concrete unsafe condition, or measured
   unnecessary work.
2. Compare the changed behavior with upstream Openbox.
3. Keep the diff focused and preserve X11 and Openbox compatibility.
4. Complete a clean build and run `make check`.
5. Add or perform a targeted regression test when practical.
6. Test desktop-facing behavior in a real X11 session before release.
7. Record regressions and revise or remove the responsible patch.

## Disclosure and limitations

- This fork is unofficial and has not been independently security audited.
- Passing tests demonstrates only the behavior those tests exercise.
- Changes may interact differently with applications, drivers, compositors,
  distributions, and unusual X11 clients.
- Users should retain a packaged Openbox session as a recovery option while
  evaluating Patchwork.
- Bugs introduced by this patch set belong in the Patchwork issue tracker, not
  the upstream Openbox tracker.

The project publishes its source and preserves upstream Git history so users
can inspect every modification and decide whether the patch set fits their
systems.
