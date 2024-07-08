# DockDoor

Want to support development? [Buy me a coffee here, thank you!](https://www.buymeacoffee.com/keplercafe)

DockDoor is a macOS application developed with Swift and SwiftUI that allows users to manage and interact with application windows on their desktop. It emphasizes ease of use and seamless integration with the macOS environment. This project is open-source, inviting contributions from developers to enhance its functionality and user experience.

[Download the latest release here](https://github.com/ejbills/DockDoor/releases/latest/download/DockDoor.dmg).

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
