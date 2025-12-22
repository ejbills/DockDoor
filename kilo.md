# DockDoor Codebase Analysis

## Overview
DockDoor is a macOS application that enhances window management by providing window peeking functionality similar to Windows and Linux environments. It allows users to hover over dock icons to see previews of open windows, and provides advanced Alt+Tab and Cmd+Tab switching capabilities.

## Architecture

### Main Entry Point
- **main.swift**: Standard macOS app entry point that creates the NSApplication and sets up the AppDelegate
- **AppDelegate.swift**: Manages application lifecycle, initializes core components, and handles first-time setup

### Core Components

#### 1. DockObserver (`DockDoor/Utilities/DockObserver.swift`)
- Monitors macOS Dock using Accessibility APIs
- Detects when users hover over dock items
- Fetches window information for hovered applications
- Handles dock click behavior (minimize/hide actions)
- Manages scroll gestures on dock icons
- Supports Cmd+Right-click to quit applications

#### 2. Window Management (`DockDoor/Utilities/Window Management/`)
- **WindowUtil.swift**: Comprehensive utility for window discovery, caching, sorting, and actions
- **WindowInfo.swift**: Data model representing window information
- **SpaceWindowCacheManager.swift**: Manages window caching across spaces
- **LiveWindowCapture.swift**: Handles live video previews of windows

#### 3. KeybindHelper (`DockDoor/Utilities/KeybindHelper.swift`)
- Manages keyboard shortcuts for window switching
- Supports customizable Alt+Tab style switching
- Enhances Cmd+Tab with additional functionality
- Handles arrow key navigation and search functionality

#### 4. SharedPreviewWindowCoordinator (`DockDoor/Views/Hover Window/Shared Components/`)
- Coordinates the display of preview windows
- Manages window switcher state
- Handles search functionality
- Coordinates between different preview types

### UI Structure

#### Views
- **Hover Window**: Main preview interface
  - Window previews with thumbnails
  - Special app integrations (Music, Calendar)
  - Traffic light buttons for window actions
  - Search functionality
- **Intro**: First-time setup flow
- **Settings**: Comprehensive configuration interface

#### Components
- Reusable UI elements (buttons, gradients, etc.)
- Fluid gradient animations
- Permission checking views
- Settings components

### Key Features

#### Window Previews
- Hover over dock icons to see window previews
- Support for minimized and hidden windows
- Live video previews (optional)
- Customizable preview quality and sizing

#### Window Switcher
- Alt+Tab style switching with customizable keybinds
- Cmd+Tab enhancements
- Search functionality (press / to search)
- Arrow key navigation
- Support for different invocation modes (all windows, active app only, etc.)

#### Special App Integrations
- **Music Controls**: Hover over Music/Spotify to see playback controls
- **Calendar**: Hover over Calendar app to see upcoming events
- **Pinnable Widgets**: Right-click to pin controls as desktop widgets

#### Advanced Features
- Aero Shake (shake window to minimize others)
- Trackpad gestures for window management
- Window filtering and sorting options
- Compact list view mode
- Fuzzy search with customizable fuzziness
- Active app dock indicator

### Configuration System
- Extensive settings using the `Defaults` framework
- Separate appearance settings for dock previews, window switcher, and Cmd+Tab
- Customizable keybinds and gestures
- Filter system for excluding specific apps or windows
- Gradient color palette customization

### Technical Implementation

#### Window Discovery
- Uses ScreenCaptureKit (SCK) for modern window capture
- Falls back to Accessibility APIs (AXUIElement) for compatibility
- Caches window information for performance
- Handles multiple spaces and displays

#### Accessibility Integration
- Requires accessibility permissions for core functionality
- Uses AXObserver to monitor dock changes
- Implements AXUIElement interactions for window management

#### Performance Optimizations
- Window caching with configurable lifespans
- Debounced window processing
- Background task management for window updates
- Memory-efficient image handling

#### Privacy & Security
- Respects macOS privacy settings
- Screen recording permission for live previews
- Accessibility permission for window management
- No data collection or external communications

### Build System
- Swift-based macOS application
- Uses SwiftUI for modern UI
- Integrates with Sparkle for updates
- Supports multiple architectures
- Includes localization support

### Development Notes
- Extensive use of async/await for concurrency
- Comprehensive error handling
- Modular architecture with clear separation of concerns
- Active development with frequent updates (latest version 1.29)
- Open-source GPL-3.0 license

This analysis covers the major architectural components and features of DockDoor. The codebase is well-structured with clear separation between UI, business logic, and system integration layers.