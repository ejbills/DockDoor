# DockDoor

Want to support development? [Buy me a coffee here, thank you!](https://www.buymeacoffee.com/keplercafe)

DockDoor is a macOS application developed with Swift and SwiftUI that allows users to manage and interact with application windows on their desktop. It emphasizes ease of use and seamless integration with the macOS environment. This project is open-source, inviting contributions from developers to enhance its functionality and user experience.

[Download the latest release here](https://github.com/ejbills/DockDoor/releases).

## Usage

- **How do I use the alt-tab functionality?**
  - Ctrl + Tab to open the menu, continue pressing tab to increment forwards, shift + tab to go back. Letting go of control will select the window.
- **How do I use the dock peeking functionality?**
  - Simply hover over any application with active windows in the dock.
- **What are the traffic light buttons that appear in the preview window?**
  - 🟣 Quit the window's app. You can hold the Option (⌥) key while clicking to **force** quit.
  - 🔴 Close the window
  - 🟡 Minimize the window
  - 🟢 Enter the window to full screen
  
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

**Help**
- I disabled the menu bar icon and now I can't access settings
  - When DockDoor initially opens, the menu icon will be visible for 10 seconds, until it disappears. This way, you can access the settings even with the icon disabled. Just relaunch the app and click it before it disappears.
- I click on the purple quit button in the preview and the app doesn't close
  - You can hold the Option (⌥) key while clicking to force quit.
