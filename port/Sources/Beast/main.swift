import AppKit

// Beast 1.0 (1989, Chuck Shotton / BIAP Systems), ported to AppKit.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
