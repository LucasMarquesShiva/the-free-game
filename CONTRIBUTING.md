# Contributing to The Free Game

**Lucas Marques, from Shiva**

Fork this repository, create a branch for one change, and open a pull request.
You do not need access to the original hosting account to build or publish your fork.

1. Follow the setup in README.md and confirm the unmodified game runs.
2. Describe the intended player-visible change in your issue or pull request.
3. Keep simulation changes in `game/simulation/`, presentation in
   `game/presentation/`, and interface in `game/ui/` where possible.
4. Run `python tools/dev.py test`. For visual or input changes, also play the
   affected flow in the editor; for web changes, export and test in a browser.
5. Include the commands you ran, results and a screenshot when it helps review.

Preserve the civilian autonomy rules documented in docs/ARCHITECTURE.md. Changes
to save data need migration or a clear compatibility note. Tests that rely on
specific starting resources should be adjusted when those rules intentionally change.

Keep generated `.godot/`, exports, local saves and credentials out of commits.
Keep `.uid` and resource `.import` sidecars; they are useful project metadata.

Submit your own material or material you are allowed to contribute under this
project's licenses. Contributions use MIT for code/docs and CC BY 4.0 for
original artwork unless explicitly documented otherwise. Preserve the project
credit **Lucas Marques, from Shiva** and any required dependency notices.

Bug reports should include the browser or OS, game version, reproduction steps,
expected result and what happened. Do not attach private files or browser profiles.
