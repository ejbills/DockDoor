# 1.0.13 - 04 Jul 04:30
* Feat: add quit app button to preview window (#51) @ShlomoCode
* Feat: change sizingMultiplier setting without restarting the app (#50) @ShlomoCode
* Update page overhaul
* Fixes title UI inconsistencies for small window sizing
* Moves window title to bottom
* Update README.md documentation for new traffic light button
* Fixes jagged gradient animation
* Fully finish transition to ScreenCaptureKit in preparation for macOS Sequoia (remove CoreGraphics usage)
* Removes unnecessary ".00" in Window Cache Lifespan
* Enhances window filtering for certain applications (issue 1, issue 2)

# 1.0.12 - 02 Jul 19:02
* Only shows window's title when you hover over the window
* Reduces animations to make it feel more polished
* Customizable screenshot caching timer (you can set it to 0 so window previews are always fresh)
* Adds support for maximizing a window from the window preview (thanks to @ShlomoCode)
* Migrates screenshot manager to new ScreenCaptureKit API to prevent deprecated warning in macOS sequoia

# 1.0.11 - 30 Jun 22:34
* Adds window title to window previews
* Adds ability to minimize window via window previews
* Hides window when dock icon is clicked
* Hides window when dock item is right clicked
* UI tweaks
* Sets minimum width for settings pane to fix jagged resizing (thanks @ShlomoCode)
* Fixes button to open recording preferences (thanks @ShlomoCode)

# 1.0.10 - 30 Jun 16:49
* Adds option to disable menu bar icon

# 1.0.9 - 30 Jun 15:41
* Adds option to disable window switcher entirely (so you can use more mature apps, like AltTab, alongside DockDoor) - thanks @hasansultan92

# 1.0.8 patch - 27 Jun 14:55
* Patches the tab menu incorrectly showing desktop widgets

# 1.0.7 patch - 26 Jun 16:27
* Fixes window buffer being on the wrong axis while the dock is on the bottom
* Better memory management code

# 1.0.6 - 26 Jun 00:19
* Fixes localized apps not showing their windows
* Adds option "window buffer" which can be used to tweak the hover window location (if it's too far away, for example)
* Adds donation link in settings

# 1.0.5 - 25 Jun 05:44
* Quick patch to fix window previews for chromium browsers

# 1.0.4 - 25 Jun 04:19
* Introduces minimized window support. Minimized windows will show up in a little box which will show you all of the hidden windows for that given application. It is scrollable (horizontally if the dock is on the left or right, vertically if on bottom.)
* Hopefully remedies the selected window not being brought to front in browsers
* UI Tweaks
