<style>
  h1:first-of-type {
    display: none;
  }
  .my-5 {
    margin: unset !important;
  }
  .markdown-body img {
    max-width: 50%;
  }
  @media (prefers-color-scheme: dark) {
    body {
      color-scheme: dark;
      color: white;
      background: transparent;
    }
    a, :link {
      color: #419cff;
    }
    a:active, link:active {
      color: #ff1919;
    }
  }
</style>

<a name="v1.1.5"></a>
# [v1.1.5](https://github.com/ejbills/DockDoor/releases/tag/v1.1.5) - 02 Aug 2024

# Changelog
## Features
- Introducing ability to track & navigate to windows from all applications across all spaces, along with support for window previews on minimized and hidden windows. [@hasansultan92](https://github.com/hasansultan92) & [@ejbills](https://github.com/ejbills) 
- - Note: This is the initial rollout of this feature and things may be buggy. Please report any bugs you encounter. It works as follows: as you navigate, window states are tracked and stored across spaces, allowing support for windows in other spaces, along with tracking minimized and hidden windows (which are displayed in a faded-greyed out look in the window preview).
- Restart the app when needed instead of just quitting [@ShlomoCode](https://github.com/ShlomoCode)
- Open app settings by relaunch [@ShlomoCode](https://github.com/ShlomoCode)
- Add ability to choose traffic light buttons position [@ShlomoCode](https://github.com/ShlomoCode)
- Add quit button [@ShlomoCode](https://github.com/ShlomoCode)
## Fixes
- Disable fullscreen button in settings window [@ShlomoCode](https://github.com/ShlomoCode)
- Use decimalFormatter in 'preview hover delay' setting [@ShlomoCode](https://github.com/ShlomoCode)
## Chore
- Sync localizations with Crowdin [@ejbills](https://github.com/ejbills)
- Clearer wording in settings [@ShlomoCode](https://github.com/ShlomoCode)
- GitHub issue template enforcement [@ejbills](https://github.com/ejbills)
- Add manual run ability to stale issues action [@ejbills](https://github.com/ejbills)
- Create pull request template [@ejbills](https://github.com/ejbills)
- Add Homebrew installation instructions [@ejbills](https://github.com/ejbills)
- Show copy button for brew command [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.5]


<a name="v1.1.4"></a>
# [v1.1.4](https://github.com/ejbills/DockDoor/releases/tag/v1.1.4) - 16 Jul 2024

# Changelog

## Fixes
- No longer filter out windows with empty titles
- Blurry window preview images
- Traffic light buttons visibility picker width ([#193](https://github.com/ejbills/DockDoor/issues/193)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Clearer wording in settings ([#194](https://github.com/ejbills/DockDoor/issues/194)) [@ShlomoCode](https://github.com/ShlomoCode)
- Typo in settings ([#197](https://github.com/ejbills/DockDoor/issues/197)) [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.4]


<a name="v1.1.3"></a>
# [v1.1.3](https://github.com/ejbills/DockDoor/releases/tag/v1.1.3) - 16 Jul 2024

# Changelog

## Features
- Add option to select window title visibility (whenOveringPreview/alwaysVisible) ([#188](https://github.com/ejbills/DockDoor/issues/188)) [@ShlomoCode](https://github.com/ShlomoCode)
- [SharedPreviewWindowCoordinator] add fall back ([#186](https://github.com/ejbills/DockDoor/issues/186)) [@chrisharper22](https://github.com/chrisharper22)
- Center Dock Tile Preview horizontally/vertically to icon ([#182](https://github.com/ejbills/DockDoor/issues/182)) [@chrisharper22](https://github.com/chrisharper22)
- Clearer wording ([#181](https://github.com/ejbills/DockDoor/issues/181)) [@ShlomoCode](https://github.com/ShlomoCode)
- Suggest users contribute translations ([#178](https://github.com/ejbills/DockDoor/issues/178)) [@ShlomoCode](https://github.com/ShlomoCode)
- Improve settings layout ([#175](https://github.com/ejbills/DockDoor/issues/175)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add app icon to readme ([#176](https://github.com/ejbills/DockDoor/issues/176)) [@ShlomoCode](https://github.com/ShlomoCode)

## Fixes
- Lingering full screen preview in certain scenarios
- Minimized and hidden windows showing empty squircle

## Refactor
- HoverTimerActions -> PreviewHoverAction ([#173](https://github.com/ejbills/DockDoor/issues/173))

## Chore
- License change from MIT to GPL-3.0 ([#191](https://github.com/ejbills/DockDoor/issues/191))
- Add release publish to crowdin sync action
- Sync localizations with Crowdin [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)

[Changes][v1.1.3]


<a name="v1.1.2"></a>
# [v1.1.2](https://github.com/ejbills/DockDoor/releases/tag/v1.1.2) - 12 Jul 2024

# Changelog

## Features
- Preview window hover actions, with time and action customizations ([#171](https://github.com/ejbills/DockDoor/issues/171))
- ![popup preview](https://github.com/user-attachments/assets/bd6ee1c8-3cff-492a-8d60-b4c40157f908)
- More localizations! You can now contribute to the translation here: https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115
- Make more strings localizable ([#168](https://github.com/ejbills/DockDoor/issues/168)) [@ShlomoCode](https://github.com/ShlomoCode)
- Settings: scale pickers and add number fields next to sliders ([#170](https://github.com/ejbills/DockDoor/issues/170)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add top right window title position option ([#150](https://github.com/ejbills/DockDoor/issues/150)) [@ShlomoCode](https://github.com/ShlomoCode)
- Crowdin localization and automation ([#155](https://github.com/ejbills/DockDoor/issues/155))
- Add Crowdin localization support and actions ([#151](https://github.com/ejbills/DockDoor/issues/151))

## Fixes
- Local labels are cutting ([#169](https://github.com/ejbills/DockDoor/issues/169)) [@ShlomoCode](https://github.com/ShlomoCode) [@ejbills](https://github.com/ejbills)
- Better setting names for preview hover action items
- Release notes loading ([#148](https://github.com/ejbills/DockDoor/issues/148)) [@ShlomoCode](https://github.com/ShlomoCode)
- Invalid formatting in changelog ([#147](https://github.com/ejbills/DockDoor/issues/147)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Sync localizations with Crowdin ([#165](https://github.com/ejbills/DockDoor/issues/165)) [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)
- Set commit_message in crowdin-sync.yml ([#158](https://github.com/ejbills/DockDoor/issues/158)) [@ShlomoCode](https://github.com/ShlomoCode)
- Initialize workflow file on main branch
- Revert "fix: invalid formatting in changelog ([#147](https://github.com/ejbills/DockDoor/issues/147))" ([#149](https://github.com/ejbills/DockDoor/issues/149))
- Patch: Update crowdin-sync.yml to not run based on push to main (was creating loop) ([#167](https://github.com/ejbills/DockDoor/issues/167))
- New Crowdin translations by GitHub Action ([#156](https://github.com/ejbills/DockDoor/issues/156)) [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)

[Changes][v1.1.2]


<a name="v1.1.1"></a>
# [v1.1.1](https://github.com/ejbills/DockDoor/releases/tag/v1.1.1) - 11 Jul 2024

# Changelog

## Features
- Update app icon to new design (Thanks to the awesome artwork by [@VisualisationExpo](https://github.com/VisualisationExpo))
- Traffic light button display customization options
- Make traffic lights symbols dark in light theme ([#135](https://github.com/ejbills/DockDoor/issues/135)) [@ShlomoCode](https://github.com/ShlomoCode)
- Added customization options for Window Titles ([#128](https://github.com/ejbills/DockDoor/issues/128)) [@chrisharper22](https://github.com/chrisharper22)
- Improve release notes style ([#125](https://github.com/ejbills/DockDoor/issues/125)) [@ShlomoCode](https://github.com/ShlomoCode)
- Show changelog in in-app update ([#120](https://github.com/ejbills/DockDoor/issues/120)) [@ShlomoCode](https://github.com/ShlomoCode)
- Localize to FR ([#115](https://github.com/ejbills/DockDoor/issues/115)) [@illavoluntas](https://github.com/illavoluntas)
- Focus when unminimized ([#118](https://github.com/ejbills/DockDoor/issues/118)) [@UnknownCrafts](https://github.com/UnknownCrafts)

## Fixes
- Incorrect placement of traffic light setting
- Window should not be draggable
- Accidentally deleted download link from readme
- Chrome PWA's ([#126](https://github.com/ejbills/DockDoor/issues/126)) [@ShlomoCode](https://github.com/ShlomoCode)
- Sparkle release notes in dark mode ([#124](https://github.com/ejbills/DockDoor/issues/124)) [@ShlomoCode](https://github.com/ShlomoCode)

## Refactor
- Replace numeric enums with named enums; reword keys and variables ([#141](https://github.com/ejbills/DockDoor/issues/141)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Update he localization ([#143](https://github.com/ejbills/DockDoor/issues/143)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add readme badges
- Remove useless maxwidth
- Create xcscheme file ([#127](https://github.com/ejbills/DockDoor/issues/127)) [@ShlomoCode](https://github.com/ShlomoCode)
- Create pr-lint.yml ([#122](https://github.com/ejbills/DockDoor/issues/122)) [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.1]


<a name="v1.1.0"></a>
# [v1.1.0](https://github.com/ejbills/DockDoor/releases/tag/v1.1.0) - 09 Jul 2024

## Features
- Add Hover App Title Styling options ([#101](https://github.com/ejbills/DockDoor/pull/101)) ([@chrisharper22](https://github.com/chrisharper22))
- - ![image](https://github.com/ejbills/DockDoor/assets/74191134/1e34a398-2f6f-4a6b-ba23-6893f6e2d17a)
- - ![image](https://github.com/ejbills/DockDoor/assets/74191134/eec2c1a2-912e-40d1-9ca3-f1f87dfc7c3c)
- Window title alignment option
- Use "hidden" word for window title hidden style ([#112](https://github.com/ejbills/DockDoor/pull/112)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Subtle traffic light buttons
- Add an "Appearance" tab in app settings ([#106](https://github.com/ejbills/DockDoor/pull/106)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Make more strings localizable ([#105](https://github.com/ejbills/DockDoor/pull/105), [#102](https://github.com/ejbills/DockDoor/pull/102)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Localize Hebrew ([#100](https://github.com/ejbills/DockDoor/pull/100)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Close preview when dock icon is clicked ([#62](https://github.com/ejbills/DockDoor/pull/62)) ([@ShlomoCode](https://github.com/ShlomoCode))

## Fixes
- Show menu bar icon only on app reopen, not on interact ([#98](https://github.com/ejbills/DockDoor/pull/98)) ([@ShlomoCode](https://github.com/ShlomoCode))
- OpenDelay display format ([#99](https://github.com/ejbills/DockDoor/pull/99)) ([@ShlomoCode](https://github.com/ShlomoCode))

## Other
- Remove xcuserdata files ([#113](https://github.com/ejbills/DockDoor/pull/113)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Scale effect

[Changes][v1.1.0]


<a name="v1.0.17"></a>
# [v1.0.17](https://github.com/ejbills/DockDoor/releases/tag/v1.0.17) - 08 Jul 2024

- Fixes bug: Impossible to use Tab with default MacOS keybind activated (https://github.com/ejbills/DockDoor/issues/92) [@hasansultan92](https://github.com/hasansultan92) 
- Adds option to not use uniform window radius, so that you can see an entire window preview without it getting cropped. (https://github.com/ejbills/DockDoor/pull/93) [@ShlomoCode](https://github.com/ShlomoCode) 

[Changes][v1.0.17]


<a name="v1.0.16"></a>
# [v1.0.16](https://github.com/ejbills/DockDoor/releases/tag/v1.0.16) - 08 Jul 2024

- Adds window switcher key bind customization (thanks to [@hasansultan92](https://github.com/hasansultan92))
- Show menu bar icon when app icon is clicked (thanks to [@ShlomoCode](https://github.com/ShlomoCode))
- Fixes the title label UI flashing on hover

[Changes][v1.0.16]


<a name="v1.0.15"></a>
# [v1.0.15](https://github.com/ejbills/DockDoor/releases/tag/v1.0.15) - 06 Jul 2024

### Quick patch for:
- Windows that are on separate monitors not showing up
- Some users were experiencing blurry windows (not sure if this is fully fixed)

[Changes][v1.0.15]


<a name="v1.0.14"></a>
# [v1.0.14](https://github.com/ejbills/DockDoor/releases/tag/v1.0.14) - 05 Jul 2024

- Initial support for hidden apps (CMD+H). If an app is hidden, its windows will show up as ‘hidden’ and will be displayed similarly to minimized windows. If you click a hidden window from the window preview, the owning application will be marked as unhidden, and that window will be brought to the front.
- More changes to update page [@ShlomoCode](https://github.com/ShlomoCode) 

[Changes][v1.0.14]


<a name="v1.0.13"></a>
# [v1.0.13](https://github.com/ejbills/DockDoor/releases/tag/v1.0.13) - 04 Jul 2024

# Changelog

## New features:
- Feat: add quit app button to preview window ([#51](https://github.com/ejbills/DockDoor/issues/51)) [@ShlomoCode](https://github.com/ShlomoCode) 
- Feat: change sizingMultiplier setting without restarting the app ([#50](https://github.com/ejbills/DockDoor/issues/50)) [@ShlomoCode](https://github.com/ShlomoCode) 

## Misc.
- Update page overhaul
- Fixes title UI inconsistencies for small window sizing
- Moves window title to bottom
- Update README.md documentation for new traffic light button
- Fixes jagged gradient animation
- Fully finish transition to ScreenCaptureKit in preparation for macOS Sequoia (remove CoreGraphics usage)
- Removes unnecessary ".00" in Window Cache Lifespan
- Enhances window filtering for certain applications ([issue 1](https://github.com/ejbills/DockDoor/issues/55) [issue 2](https://github.com/ejbills/DockDoor/issues/36))

[Changes][v1.0.13]


<a name="v1.0.12"></a>
# [v1.0.12](https://github.com/ejbills/DockDoor/releases/tag/v1.0.12) - 02 Jul 2024

- Only shows window's title when you hover over the window
- Reduces animations to make it feel more polished
- Customizable screenshot caching timer (you can set it to 0 so window previews are always fresh)
- Adds support for maximizing a window from the window preview (thanks to [@ShlomoCode](https://github.com/ShlomoCode))
- Migrates screenshot manager to new ScreenCaptureKit API to prevent deprecated warning in macOS sequoia


What's upcoming?
- Full size window previews on hover
- Window switcher keybind customization
- Homebrew releases

[Changes][v1.0.12]


<a name="v1.0.11"></a>
# [v1.0.11](https://github.com/ejbills/DockDoor/releases/tag/v1.0.11) - 30 Jun 2024

- Adds window title to window previews
- Adds ability to minimize window via window previews
- Hides window when dock icon is clicked
- Hides window when dock item is right clicked
- UI tweaks
- Sets minimum width for settings pane to fix jagged resizing (thanks [@ShlomoCode](https://github.com/ShlomoCode))
- Fixes button to open recording preferences (thanks [@ShlomoCode](https://github.com/ShlomoCode))

[Changes][v1.0.11]


<a name="v1.0.10"></a>
# [v1.0.10](https://github.com/ejbills/DockDoor/releases/tag/v1.0.10) - 30 Jun 2024

- Adds option to disable menu bar icon

Note:
When DockDoor initially opens, the menu icon will be visible for 10 seconds, until it disappears. This way, you can access the settings even with the icon disabled. Just relaunch the app and click it before it disappears if you need to change some settings.

[Changes][v1.0.10]


<a name="v1.0.9"></a>
# [v1.0.9](https://github.com/ejbills/DockDoor/releases/tag/v1.0.9) - 30 Jun 2024

- Adds option to disable window switcher entirely (so you can use more mature apps, like AltTab, alongside DockDoor) - thanks [@hasansultan92](https://github.com/hasansultan92) 

[Changes][v1.0.9]


<a name="v1.0.7patch2"></a>
# [v1.0.8 patch (v1.0.7patch2)](https://github.com/ejbills/DockDoor/releases/tag/v1.0.7patch2) - 27 Jun 2024

- Patches the tab menu incorrectly showing desktop widgets

[Changes][v1.0.7patch2]


<a name="v1.0.7"></a>
# [v1.0.7 patch](https://github.com/ejbills/DockDoor/releases/tag/v1.0.7) - 26 Jun 2024

- Fixes window buffer being on the wrong axis while the dock is on the bottom
- Better memory management code

[Changes][v1.0.7]


<a name="v1.0.6"></a>
# [v1.0.6](https://github.com/ejbills/DockDoor/releases/tag/v1.0.6) - 26 Jun 2024

- Fixes localized apps not showing their windows
- Adds option "window buffer" which can be used to tweak the hover window location (if it's too far away, for example)
- Adds donation link in settings

[Changes][v1.0.6]


<a name="v1.0.5"></a>
# [v1.0.5](https://github.com/ejbills/DockDoor/releases/tag/v1.0.5) - 25 Jun 2024

- Quick patch to fix window previews for chromium browsers

[Changes][v1.0.5]


<a name="v1.0.4"></a>
# [v1.0.4](https://github.com/ejbills/DockDoor/releases/tag/v1.0.4) - 25 Jun 2024

- Introduces minimized window support. Minimized windows will show up in a little box which will show you all of the hidden windows for that given application. It is scrollable (horizontally if the dock is on the left or right, vertically if on bottom.)
- Hopefully remedies the selected window not being brought to front in browsers
- UI Tweaks

[Changes][v1.0.4]


<a name="v1.0.3"></a>
# [v1.0.3](https://github.com/ejbills/DockDoor/releases/tag/v1.0.3) - 24 Jun 2024

- Adjustments to app text label UI (you can now read it)
- Added option to delay hover window opening, up to 2 seconds
- Added option to disable the hover window sliding animation

[Changes][v1.0.3]


<a name="v1.0.1"></a>
# [v1.0.1](https://github.com/ejbills/DockDoor/releases/tag/v1.0.1) - 23 Jun 2024

This release is a quick patch to (hopefully) fix DMG notarization.

[Changes][v1.0.1]


<a name="releases"></a>
# [v1.0 (releases)](https://github.com/ejbills/DockDoor/releases/tag/releases) - 23 Jun 2024

v1.0

[Changes][releases]


[v1.1.5]: https://github.com/ejbills/DockDoor/compare/v1.1.4...v1.1.5
[v1.1.4]: https://github.com/ejbills/DockDoor/compare/v1.1.3...v1.1.4
[v1.1.3]: https://github.com/ejbills/DockDoor/compare/v1.1.2...v1.1.3
[v1.1.2]: https://github.com/ejbills/DockDoor/compare/v1.1.1...v1.1.2
[v1.1.1]: https://github.com/ejbills/DockDoor/compare/v1.1.0...v1.1.1
[v1.1.0]: https://github.com/ejbills/DockDoor/compare/v1.0.17...v1.1.0
[v1.0.17]: https://github.com/ejbills/DockDoor/compare/v1.0.16...v1.0.17
[v1.0.16]: https://github.com/ejbills/DockDoor/compare/v1.0.15...v1.0.16
[v1.0.15]: https://github.com/ejbills/DockDoor/compare/v1.0.14...v1.0.15
[v1.0.14]: https://github.com/ejbills/DockDoor/compare/v1.0.13...v1.0.14
[v1.0.13]: https://github.com/ejbills/DockDoor/compare/v1.0.12...v1.0.13
[v1.0.12]: https://github.com/ejbills/DockDoor/compare/v1.0.11...v1.0.12
[v1.0.11]: https://github.com/ejbills/DockDoor/compare/v1.0.10...v1.0.11
[v1.0.10]: https://github.com/ejbills/DockDoor/compare/v1.0.9...v1.0.10
[v1.0.9]: https://github.com/ejbills/DockDoor/compare/v1.0.7patch2...v1.0.9
[v1.0.7patch2]: https://github.com/ejbills/DockDoor/compare/v1.0.7...v1.0.7patch2
[v1.0.7]: https://github.com/ejbills/DockDoor/compare/v1.0.6...v1.0.7
[v1.0.6]: https://github.com/ejbills/DockDoor/compare/v1.0.5...v1.0.6
[v1.0.5]: https://github.com/ejbills/DockDoor/compare/v1.0.4...v1.0.5
[v1.0.4]: https://github.com/ejbills/DockDoor/compare/v1.0.3...v1.0.4
[v1.0.3]: https://github.com/ejbills/DockDoor/compare/v1.0.1...v1.0.3
[v1.0.1]: https://github.com/ejbills/DockDoor/compare/releases...v1.0.1
[releases]: https://github.com/ejbills/DockDoor/tree/releases

<!-- Generated by https://github.com/rhysd/changelog-from-release v3.7.2 -->
