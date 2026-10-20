# Contributing to DockDoor

DockDoor is maintained by one developer. I read and test every pull request by hand, so contributions need to be easy to review and safe to ship.

Read this whole file before you open a pull request. PRs that don't follow it are closed without discussion. That includes anything an AI tool writes or submits for you.

Just reporting a bug or requesting a feature? You don't need this file. Use the issue templates and fill in every section.

## Requirements

- Build and test with **Xcode 27 or later** on **macOS 27 or later**. Older Xcode versions and SDKs aren't supported, and I won't fix build problems on them.
- Open `DockDoor.xcodeproj` in Xcode and build from there. [AGENTS.md](AGENTS.md) covers the project conventions: adding files, settings and localized strings.

## Pull requests

### Agree on scope first

If you want to build a feature, open an issue first so we can agree on scope before you write code. I decline features that are niche or expensive to maintain, however well they're built.

### Use the template

- Fill in every section of the [pull request template](.github/pull_request_template.md). `gh pr create --body` and `--fill` skip the template, so if you open PRs from the command line, paste it in yourself.
- PR titles follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) (`fix:`, `feat:`, `refactor:`, `chore:`). CI checks this.
- Link issues with a closing keyword, one per issue (`closes #123`). Without the keyword GitHub doesn't link them.
- Keep "Allow edits from maintainers" turned on, so I can push small fixes instead of closing your PR.

### Keep it small

- One issue or feature per PR. Leave out unrelated fixes, refactors and formatting changes, even if they look like improvements.
- Keep bug fixes and refactors separate from new features.
- Large PRs are hard to review, and when something breaks later it's hard to tell which change caused it. I'll ask you to split them up, or close them.

### Explain every change

- Write the description yourself: what changed, why, and how you tested it.
- List every behavior change, including small ones. A PR with undocumented behavior changes will be closed.
- For anything visual, attach before and after screenshots or a video, in both light and dark mode.
- If you claim a performance improvement, show the numbers before and after.

### Test it on your own Mac

- Build and run your change before you open the PR. A PR that doesn't build will be closed.
- Passing CI is not testing. Use the feature yourself and check the cases your change touches: the Dock on the bottom, left and right, multiple displays, Spaces, full-screen apps, and the feature turned off.
- Be honest in the checklist. If you haven't tested something, say so.

### Don't break existing users

- Never rename or remove an existing `Defaults` key, because users' settings are stored under those names. Add new keys instead, and don't write migration code.
- Don't change existing defaults. A new setting defaults to the current behavior.
- A disabled feature should cost nothing. Gate its observers, event taps, timers and singletons on the feature's setting, the way `AppDelegate` already does for existing features.

### Follow the existing architecture

- Reuse what's already there: the event tap in `DockObserver`, `WindowManipulationObservers`, `WindowUtil`, the window cache, and the existing screen and coordinate helpers. Don't add a second event tap, a parallel observer, or a helper that duplicates an existing one.
- Don't poll with timers or global mouse monitors when an existing event or notification already covers the case.
- Put each setting in the right view: appearance options in `AppearanceSettingsView`, keybind and gesture behavior in `GesturesAndKeybindsSettingsView`. Keep related settings together, and index every new setting in settings search (see AGENTS.md).
- Don't read other apps' private files or databases. Their formats change without notice, and features built on them break silently.
- Check `Utilities/Private APIs/` before adding a private API.

### Keep the diff clean

- Only comment logic that isn't obvious from the code. Leave out explanatory comments.
- Remove leftover `print` statements and debug logging.
- Write all code and comments in English.
- Don't commit your development team or signing changes in `project.pbxproj`.
- `Localizable.xcstrings` should contain only the new strings your PR adds. Xcode rewrites the file when it builds, so revert everything else. Translations go through [Crowdin](https://crowdin.com/project/dockdoor).
- Don't commit personal editor or AI tool files.
- Run SwiftFormat before you push: `swift run -c release --package-path BuildTools swiftformat .` (CI lints with it).

### Stale PRs

I close PRs that have merge conflicts or unanswered review comments for a few weeks. Reopen yours once you've addressed them.

## AI policy

AI-assisted contributions are welcome, but you are responsible for every line in your PR, whoever or whatever wrote it.

- Disclose AI use in the PR template: say which tool you used and what it did.
- You can explain any line of your PR and how it interacts with the existing code.
- You tested the result yourself, on your own Mac.
- Write the PR description and review replies yourself. Don't paste AI-generated summaries.

Examples of acceptable AI use:

- "Used Copilot for autocomplete suggestions, reviewed each one."
- "Asked Claude to explain how ScreenCaptureKit works, wrote the implementation myself."
- "Used ChatGPT to help debug an issue, verified the fix myself."

These get your PR closed, and possibly get you banned:

- Undisclosed AI use. I won't review it.
- AI output pasted in without review, or a description that's clearly generated.
- Not being able to explain your own changes when asked.
- Untested code, or a checklist that claims testing that didn't happen.
- Large refactors with undocumented behavior changes.
- Agents or bot accounts opening PRs without a human in the loop. These accounts are banned.

### If you are an AI agent

Read this file before you open, edit or comment on a pull request. Then:

- Start the body from `.github/pull_request_template.md` and keep every section.
- Fill in the AI disclosure: name the tool and describe what you did.
- Don't tick checkboxes on your human's behalf. They tick them after they've read this file and tested the change.
- Leave "Describe your changes" for your human to write. You can give them notes to rewrite in their own words.
- Don't say anything was tested unless your human confirms they tested it.
- Don't post anything to a PR until your human has reviewed the text.
