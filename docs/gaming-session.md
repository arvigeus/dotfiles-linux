# Gaming session

The canonical gaming architecture, exact upstream research revisions, feature
classifications, power strategy, rejection ledger, refresh procedure, and
hardware test checklist live in
[`modules/gaming/README.md`](../modules/gaming/README.md).

Operationally, choose **Steam Gaming Mode** in Plasma Login Manager. It starts
the repository-owned `/usr/local/bin/system-gaming-session` wrapper, which runs
Steam Gamepad UI as Gamescope's child process. Exiting Steam ends the session
and returns to the greeter. Autologin is intentionally opt-in.
