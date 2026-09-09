# Contributing guidelines

Thank you for your interest in improving AI agent desktop notifier (`anoti`). Contributions are welcome from bug reports and documentation fixes to new agent adapters and platform improvements.

---

## Code of conduct and standards

- Treat everyone with respect and empathy.
- Keep discussions focused, constructive, and civil.
- Write clear, concise code adhering to the surrounding style and conventions.
- Adhere to sentence case capitalization in documentation, comments, commit messages, and user interfaces (avoid arbitrary capitalization of common nouns).

---

## Multi-platform development rules

Per our core engineering guidelines, this project strictly supports both **Linux** (X11 & Wayland) and **Windows** (10 & 11). Every contributor must uphold the following rules:

1. **No single-OS bias in shared logic**:
   - Shared components must never assume a single operating system.
   - Do not hardcode filesystem paths (e.g. `/home/`, `C:\`), shell syntax, environment variables, or platform-specific tools into shared paths.
   - Use `pathlib.Path` or `os.path` for path manipulations.

2. **Isolate platform-specific logic**:
   - Guard OS-specific calls behind explicit platform checks (e.g., `sys.platform == "win32"` vs `sys.platform.startswith("linux")`).
   - Provide safe, non-crashing fallbacks when an operating system or desktop environment does not support a particular feature.

3. **Synchronize both platforms for installer and configuration changes**:
   - Any modification affecting CLI contracts, hook configurations, or installed artifacts must be implemented in both Linux scripts (`scripts/install.sh`, `scripts/update.sh`, `scripts/uninstall.sh`) and Windows scripts (`scripts/install.ps1`, `scripts/update.ps1`, `scripts/uninstall.ps1`).

4. **Testing across platforms**:
   - Shared unit tests must run successfully on both Linux and Windows.
   - Platform-dependent unit tests must use appropriate mocks or explicit skip conditions (e.g., `@unittest.skipUnless(sys.platform == "win32", "Windows only")`).
   - Never report tests as verified on a real platform unless executed on an actual machine or container with that operating system.

5. **Architectural synchronization**:
   - When modifying core workflows, schemas, or CLI contracts, update `docs/architecture.md`, user guides, and test suites in the same pull request.

---

## Development and testing workflow

### 1. Prerequisites

- **Python**: 3.8 or higher.
- **Linux**: `python3-tk`, `xdotool` (X11), or GNOME Shell extension (Wayland).
- **Windows**: PowerShell 5.1+ or PowerShell 7+, Python with `tkinter` (included with standard Windows Python installer).

### 2. Running unit tests

Run the automated test suite without external dependencies:

```bash
# Run all unit tests
python3 -m unittest discover tests

# Or run tests in verbose mode
python3 -m unittest discover tests -v
```

All 150+ unit tests should pass with 0 failures before any pull request is submitted.

### 3. Running real integration tests (optional)

Integration tests interacting with real window managers are guarded behind environment flags:

```bash
# Real X11 multi-window integration test (Linux X11 with WezTerm/GNOME Terminal)
NOTIFIER_TEST_X11=1 python3 -m unittest tests/test_x11_window_regressions.py -v

# Real WezTerm integration test
NOTIFIER_TEST_WEZTERM=1 python3 -m unittest tests/test_codex_window_regressions.py -v

# Real GNOME Shell Wayland integration test
NOTIFIER_TEST_WAYLAND=1 python3 -m unittest tests/test_codex_window_regressions.py -v
```

---

## Submitting issues and pull requests

### Reporting issues

1. Check existing issues and pull requests before creating a new one.
2. Provide your environment details:
   - Operating system and version (e.g., Ubuntu 24.04, Windows 11 23H2).
   - Display server (X11, Wayland, or Windows desktop).
   - Terminal emulator (e.g., Windows Terminal, WezTerm, Alacritty, GNOME Terminal).
   - AI agent and version (Claude Code, OpenAI Codex, Google Antigravity).
3. Include steps to reproduce and any error messages from `anoti doctor` or `~/.cache/ai-agent-notifier/`.

### Submitting pull requests

1. Fork the repository and create a descriptive feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Implement your changes, keeping the diff clean and focused.
3. Run the automated test suite to verify 100% pass rate:
   ```bash
   python3 -m unittest discover tests
   ```
4. Write clear commit messages using sentence case (e.g., `feat: add support for custom notification sounds`).
5. Open a pull request against the `master` branch with a clear description of what changed, why, and how you verified it on each supported platform.
