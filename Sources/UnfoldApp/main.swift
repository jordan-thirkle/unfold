import AppKit

// Menu bar agent: no Dock icon, no main window. The overlay is the only
// surface the user ever sees.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
