#!/usr/bin/swift
// Generates AppIcon.icns — mouse body with up/down chevrons
import AppKit

/// Draws the mouse+chevron icon into `ctx` on a canvas of `size` points.
/// `fg` is the foreground (stroke) color.
func drawMouseIcon(ctx: CGContext, size: CGFloat, fg: CGColor) {
    let lw = size * 0.038          // line width scales with size
    ctx.setLineWidth(lw)
    ctx.setStrokeColor(fg)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // ── Mouse body ─────────────────────────────────────────────
    let mw = size * 0.380          // mouse width
    let mh = size * 0.500          // mouse height
    let mx = (size - mw) / 2       // left edge
    let my = size * 0.240          // bottom edge (y-up coords)
    let mr = mw * 0.44             // corner radius → very rounded top/bottom

    let mouseRect = CGRect(x: mx + lw/2, y: my + lw/2,
                           width: mw - lw, height: mh - lw)
    ctx.addPath(CGPath(roundedRect: mouseRect, cornerWidth: mr, cornerHeight: mr, transform: nil))
    ctx.strokePath()

    // ── Scroll wheel (pill inside mouse, upper-center) ──────────
    let ww = size * 0.058
    let wh = size * 0.115
    let wx = (size - ww) / 2
    let wy = my + mh * 0.44        // sits in the upper half of the mouse body
    let wheelRect = CGRect(x: wx + lw/2, y: wy + lw/2,
                           width: ww - lw, height: wh - lw)
    ctx.addPath(CGPath(roundedRect: wheelRect, cornerWidth: ww/2, cornerHeight: ww/2, transform: nil))
    ctx.strokePath()

    // ── Up chevron (above mouse) ─────────────────────────────────
    let cw = size * 0.240          // chevron half-span
    let ch = size * 0.100          // chevron height
    let ucx = size / 2
    let ucy = my + mh + size * 0.075   // center of up chevron

    ctx.move(to: CGPoint(x: ucx - cw/2, y: ucy - ch/2))
    ctx.addLine(to: CGPoint(x: ucx,     y: ucy + ch/2))
    ctx.addLine(to: CGPoint(x: ucx + cw/2, y: ucy - ch/2))
    ctx.strokePath()

    // ── Down chevron (below mouse) ────────────────────────────────
    let dcy = my - size * 0.075   // center of down chevron

    ctx.move(to: CGPoint(x: ucx - cw/2, y: dcy + ch/2))
    ctx.addLine(to: CGPoint(x: ucx,     y: dcy - ch/2))
    ctx.addLine(to: CGPoint(x: ucx + cw/2, y: dcy + ch/2))
    ctx.strokePath()
}

/// Full app icon: blue gradient background + white icon
func makeAppIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    defer { img.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.225

    // Clip to macOS rounded-rect icon shape
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()

    // Sky-blue gradient
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [CGColor(red: 0.055, green: 0.647, blue: 0.914, alpha: 1.0),
                  CGColor(red: 0.007, green: 0.435, blue: 0.714, alpha: 1.0)] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: size/2, y: size * 0.95),
                           end:   CGPoint(x: size/2, y: size * 0.05),
                           options: [])

    // White mouse icon
    drawMouseIcon(ctx: ctx, size: size, fg: CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    return img
}

func savePNG(_ img: NSImage, to path: String) {
    guard let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:])
    else { print("PNG encode failed: \(path)"); return }
    try? png.write(to: URL(fileURLWithPath: path))
}

// Build iconset
let fm = FileManager.default
let iconsetDir = "AppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// (canvas px, logical pt, isRetina)
let sizes: [(Int, Int, Bool)] = [
    (16,   16,  false), (32,   16,  true),
    (32,   32,  false), (64,   32,  true),
    (128,  128, false), (256,  128, true),
    (256,  256, false), (512,  256, true),
    (512,  512, false), (1024, 512, true),
]

for (canvas, pt, retina) in sizes {
    let fname = retina
        ? "\(iconsetDir)/icon_\(pt)x\(pt)@2x.png"
        : "\(iconsetDir)/icon_\(pt)x\(pt).png"
    savePNG(makeAppIcon(size: CGFloat(canvas)), to: fname)
    print("  \(fname)")
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", "-o", "AppIcon.icns", iconsetDir]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    try? fm.removeItem(atPath: iconsetDir)
    print("✓ AppIcon.icns")
} else {
    print("iconutil failed")
    exit(1)
}
