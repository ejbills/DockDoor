<p align="center">
<img height="256" src="https://github.com/ejbills/DockDoor/raw/main/DockDoor/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png">
</p>

<h1 align="center"><a href="https://dockdoor.net">DockDoor</a></h1>
<h2 align="center"><i>A new way of interacting with the Dock.</i></h1>

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/releases/latest/download/DockDoor.dmg)
![GitHub All Releases](https://img.shields.io/github/downloads/ejbills/DockDoor/total?label=Total%20Downloads)
[![GitHub stars](https://img.shields.io/github/stars/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/network/members)
[![GitHub issues](https://img.shields.io/github/issues/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/issues)
[![GitHub license](https://img.shields.io/github/license/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/blob/main/LICENSE)
[![Contributors](https://img.shields.io/github/contributors/ejbills/DockDoor)](https://github.com/ejbills/DockDoor/graphs/contributors)

Want to support development? [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee!-ffdd00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/keplercafe)

Want to translate the app in your own language? [![Help translate the app here](https://img.shields.io/badge/Help%20translate%20here!-lightskyblue?style=flat)](https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115)

DockDoor is a macOS application developed with Swift and SwiftUI that allows users to manage and interact with application windows on their desktop. It emphasizes ease of use and seamless integration with the macOS environment. This project is open-source, inviting contributions from developers to enhance its functionality and user experience.


## Installation

[Download the latest release here](https://github.com/ejbills/DockDoor/releases/latest/download/DockDoor.dmg).

#### Using Homebrew

You can also install DockDoor through [Homebrew](https://brew.sh/)! Just type the following command into the Terminal:
```bash
brew install --cask dockdoor
```

## Usage

- **How to use the Alt-Tab feature?**
  - To switch between windows, hold down the `Command` key (<strong>&#8984;</strong>) and press the `Tab` key (<strong>&RightArrowBar;</strong>) repeatedly until the desired window is highlighted. To go back, press `Shift` in addition to `Tab`. Release both keys to switch to the selected window.
  - Disabling the default `Cmd + Tab` keybind will allow the user to set a custom keybind.
      - User chooses one of the modifier keys presented on the screen (`Command`, `Option` or `Control`);
      - User clicks on `Start Recording Keybind`;
      - User presses the key they want to associate with the previously selected modifier key;
      - Keybind is now set!

- **How to use the dock peeking feature?**
  - Simply hover over any application with active windows in the Dock.
- **What are the traffic light buttons that appear in the preview window?**
  - 🟣 **Quit** the window’s app. You can hold the Option (⌥) key while clicking to **force quit**.
  - 🔴 **Close** the window
  - 🟡 **Minimize** the window
  - 🟢 Enter the window to **full screen**

### FAQ

- I disabled the menu bar icon and now I can’t access settings
  - Simply search for "DockDoor" using the macOS built-in Spotlight and open the application. The settings window should appear.
- I click on the purple quit button in the preview and the app doesn’t close
  - You can hold the Option (⌥) key while clicking to **force quit**.
 
## Installation (for contributors)

### Prerequisites

- macOS 13.0 or later.
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
