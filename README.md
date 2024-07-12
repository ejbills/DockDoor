<p align="center">
<img height="256" src="https://github.com/ejbills/DockDoor/raw/main/DockDoor/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png">
</p>

<h1 align="center">DockDoor</h1>

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/releases/latest/download/DockDoor.dmg)
![GitHub All Releases](https://img.shields.io/github/downloads/ejbills/DockDoor/total?label=Total%20Downloads)
[![GitHub stars](https://img.shields.io/github/stars/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/network/members)
[![GitHub issues](https://img.shields.io/github/issues/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/issues)
[![GitHub license](https://img.shields.io/github/license/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/blob/main/LICENSE)
[![Contributors](https://img.shields.io/github/contributors/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/graphs/contributors)

Want to support development? [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-ffdd00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/keplercafe)

DockDoor is a macOS application developed with Swift and SwiftUI that allows users to manage and interact with application windows on their desktop. It emphasizes ease of use and seamless integration with the macOS environment. This project is open-source, inviting contributions from developers to enhance its functionality and user experience.

[Download the latest release here](https://github.com/ejbills/DockDoor/releases/latest/download/DockDoor.dmg).

[Help translate the app here](https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115).

## Usage

- **How do I use the alt-tab functionality?**
  - By default, use Cmd + Tab to open the window switcher, continue pressing Tab to increment forwards, Shift + Tab to go back. Letting go of command will select the window.
  - Disabling the default Cmd + Tab keybind, will allow a user to set a custom keybind
      - User selects one of the modifiers presented on the screen
      - User presses `Record Keybind` button
      - User presses a singular key on the keyboard
      - Keybind is now set! 

      ![Set keybind](./resources/setKeybind.gif)
- **How do I use the dock peeking functionality?**
  - Simply hover over any application with active windows in the dock.
- **What are the traffic light buttons that appear in the preview window?**
  - 🟣 Quit the window's app. You can hold the Option (⌥) key while clicking to **force** quit.
  - 🔴 Close the window
  - 🟡 Minimize the window
  - 🟢 Enter the window to full screen

### FAQ

- I disabled the menu bar icon and now I can't access settings
  - When DockDoor initially opens, the menu icon will be visible for 10 seconds, until it disappears. This way, you can access the settings even with the icon disabled. Just relaunch the app and click it before it disappears.
- I click on the purple quit button in the preview and the app doesn't close
  - You can hold the Option (⌥) key while clicking to force quit.
 
## Installation (for contributors)

### Prerequisites

- macOS 14.0 or later.
- Xcode installed on your machine.

### Setting Up the Project

1. Fork the repository.
2. Clone your forked repository to your local machine.
3. Open the project in Xcode.
4. Build and run the project.

## How to Contribute

Contributions to DockDoor are welcome! Here’s how you can get started:

### Prerequisites

- Basic knowledge of Swift and SwiftUI.

### Contribution Guide

1. **Branching:**
    - Base all new features off of `main`.
    - Create a new branch for each feature or bug fix: `git checkout -b feature/your-feature-name`.
2. **Coding Standards:**
    - Follow Swift coding conventions and style guidelines.
    - Aim for clear, concise, and expressive code.
3. **Documentation:**
    - Document your code using comments to explain complex logic or functionality.
4. **Testing:**
    - Write unit tests for new features or changes.
    - Ensure existing tests pass before submitting a pull request.
