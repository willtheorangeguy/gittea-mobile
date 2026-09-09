import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let gradient = NSGradient(starting: NSColor(srgbRed: 0.17, green: 0.66, blue: 0.43, alpha: 1), ending: NSColor(srgbRed: 0.06, green: 0.36, blue: 0.25, alpha: 1))!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -65)
NSColor.white.setStroke()
let handle = NSBezierPath(roundedRect: NSRect(x: 655, y: 395, width: 172, height: 208), xRadius: 80, yRadius: 80)
handle.lineWidth = 52
handle.stroke()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 236, y: 300, width: 480, height: 370), xRadius: 100, yRadius: 100).fill()
let saucer = NSBezierPath()
saucer.move(to: NSPoint(x: 221, y: 243)); saucer.line(to: NSPoint(x: 736, y: 243)); saucer.lineWidth = 36; saucer.lineCapStyle = .round; saucer.stroke()
let green = NSColor(srgbRed: 0.1, green: 0.48, blue: 0.31, alpha: 1)
green.setStroke()
let branch = NSBezierPath()
branch.move(to: NSPoint(x: 427, y: 393)); branch.line(to: NSPoint(x: 427, y: 574))
branch.move(to: NSPoint(x: 427, y: 465)); branch.curve(to: NSPoint(x: 551, y: 574), controlPoint1: NSPoint(x: 550, y: 465), controlPoint2: NSPoint(x: 551, y: 500))
branch.lineWidth = 27; branch.lineCapStyle = .round; branch.stroke()
green.setFill()
for (x,y) in [(427.0,393.0),(427.0,574.0),(551.0,574.0)] { NSBezierPath(ovalIn: NSRect(x: x-28, y: y-28, width: 56, height: 56)).fill() }
NSGraphicsContext.restoreGraphicsState()
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Gitea/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
