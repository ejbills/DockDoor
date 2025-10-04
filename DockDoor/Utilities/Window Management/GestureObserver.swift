import Cocoa

class GestureMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask = [.scrollWheel]
    
    
    init() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event: event)
        }
        
        print("✅ ScrollEventMonitor started.")
    }

    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            print("🛑 ScrollEventMonitor stopped.")
        }
    }
    
    private func handleScrollWheel(_ event: NSEvent) {
        guard event.momentumPhase.rawValue == 0 else { return }
//                    print("Here2 \(event.type)")
        let location = event.locationInWindow
        let window = NSApp.mainWindow

//                    print("/*Here*/")

        // Check if the event is on the title bar
//                    if let window {
//                        let titleBarHeight: CGFloat = 22 // Typical title bar height, can vary by window type.
//                        let titleBarFrame = CGRect(x: 0, y: window.frame.height - titleBarHeight, width: window.frame.width, height: titleBarHeight)
//
//                        if titleBarFrame.contains(location) {
//                            // Here we check if it's a swipe and print out the event type.
//
//                            print("Event detected")
//                        }
//                    }

        guard event.momentumPhase.rawValue == 0 else { return }
        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX

        let horizontal = abs(deltaY) < abs(deltaX)

        // Determine scroll direction
        let verticalDirection = if deltaY > 0 {
            "Up"
        } else if deltaY < 0 {
            "Down"
        } else {
            "None"
        }

        let horizontalDirection = if deltaX > 0 {
            "Right"
        } else if deltaX < 0 {
            "Left"
        } else {
            "None"
        }

        let overall = horizontal ? horizontalDirection : verticalDirection

        // Print event info
        print("""
        Scroll Event Detected: deltaY: \(deltaY) deltaX: \(deltaX) Overall: \(overall)
        """)
    }
    
    /// Handles incoming scroll events.
    private func handle(event: NSEvent) {
        
        switch event.type {
        case .scrollWheel:
            handleScrollWheel(event)
            break
        default:
            break
        }
    }
}
