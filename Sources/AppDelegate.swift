import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let interceptor = ScrollInterceptor()
    var enableMenuItem: NSMenuItem!
    var statusMenuItem: NSMenuItem!
    var permissionsMenuItem: NSMenuItem!
    var sliderView: SpeedSliderView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        checkAndRequestPermissions()
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
            button.toolTip = "SideScroll Converter"
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Status: waiting for permissions…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        enableMenuItem = NSMenuItem(title: "Enable", action: #selector(toggleEnabled), keyEquivalent: "e")
        enableMenuItem.isEnabled = false
        menu.addItem(enableMenuItem)

        permissionsMenuItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(permissionsMenuItem)

        menu.addItem(.separator())

        // Speed slider
        sliderView = SpeedSliderView(value: interceptor.multiplier)
        sliderView.onChanged = { [weak self] newValue in
            self?.interceptor.multiplier = newValue
        }
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // Menu bar icon: mouse + chevrons as a template image
    func makeMenuBarIcon() -> NSImage {
        let size: CGFloat = 20
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let lw = size * 0.09
            ctx.setLineWidth(lw)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Mouse body
            let mw = size * 0.38, mh = size * 0.50
            let mx = (size - mw) / 2, my = size * 0.24
            let mr = mw * 0.44
            ctx.addPath(CGPath(roundedRect: CGRect(x: mx+lw/2, y: my+lw/2, width: mw-lw, height: mh-lw),
                               cornerWidth: mr, cornerHeight: mr, transform: nil))
            ctx.strokePath()

            // Scroll wheel
            let ww = size * 0.10, wh = size * 0.20
            let wx = (size - ww) / 2, wy = my + mh * 0.44
            ctx.addPath(CGPath(roundedRect: CGRect(x: wx+lw/2, y: wy+lw/2, width: ww-lw, height: wh-lw),
                               cornerWidth: ww/2, cornerHeight: ww/2, transform: nil))
            ctx.strokePath()

            // Up chevron
            let cx = size / 2, cw = size * 0.24, ch = size * 0.10
            let ucy = my + mh + size * 0.07
            ctx.move(to: CGPoint(x: cx - cw/2, y: ucy - ch/2))
            ctx.addLine(to: CGPoint(x: cx,     y: ucy + ch/2))
            ctx.addLine(to: CGPoint(x: cx + cw/2, y: ucy - ch/2))
            ctx.strokePath()

            // Down chevron
            let dcy = my - size * 0.07
            ctx.move(to: CGPoint(x: cx - cw/2, y: dcy + ch/2))
            ctx.addLine(to: CGPoint(x: cx,     y: dcy - ch/2))
            ctx.addLine(to: CGPoint(x: cx + cw/2, y: dcy + ch/2))
            ctx.strokePath()

            return true
        }
        img.isTemplate = true
        return img
    }

    func updateUI() {
        if interceptor.isEnabled {
            statusMenuItem.title = "Active — side wheel → vertical"
            enableMenuItem.title = "Disable"
            enableMenuItem.state = .off   // no checkmark — title already makes state clear
            permissionsMenuItem.isHidden = true
        } else {
            let hasAccess = AXIsProcessTrusted()
            if hasAccess {
                statusMenuItem.title = "Disabled"
                enableMenuItem.title = "Enable"
                enableMenuItem.state = .off
                permissionsMenuItem.isHidden = true
            } else {
                statusMenuItem.title = "Needs Accessibility permission"
                enableMenuItem.title = "Enable"
                enableMenuItem.state = .off
                permissionsMenuItem.isHidden = false
            }
        }
    }

    // MARK: - Actions

    @objc func toggleEnabled() {
        if interceptor.isEnabled {
            interceptor.disable()
        } else {
            let ok = interceptor.enable()
            if !ok { showPermissionsAlert() }
        }
        updateUI()
    }

    @objc func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Permissions

    func checkAndRequestPermissions() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            let ok = interceptor.enable()
            if !ok { statusMenuItem.title = "Failed to create event tap" }
            enableMenuItem.isEnabled = true
        } else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    let ok = self.interceptor.enable()
                    self.enableMenuItem.isEnabled = true
                    if !ok { self.statusMenuItem.title = "Failed to create event tap" }
                    self.updateUI()
                }
            }
        }
        updateUI()
    }

    func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "SideScroll needs Accessibility access to intercept scroll events.\n\nGo to System Settings → Privacy & Security → Accessibility and enable SideScrollConverter."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
    }

    // MARK: - Launch at Login

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @objc func toggleLaunchAtLogin() {
        guard let item = statusItem.menu?.items.first(where: { $0.action == #selector(toggleLaunchAtLogin) }) else { return }
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    item.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    item.state = .on
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Launch at Login Error"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}
