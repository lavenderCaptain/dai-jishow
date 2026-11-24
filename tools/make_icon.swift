// make_icon.swift — generate a square AppIcon.icns for the macOS app.
//
// The source is the finished 1024×1024 square master that the designer exported
// for iOS: icons/DaiJishow Exports/DaiJishow-iOS-Default-1024@1x.png. It is
// already a complete, full-bleed square design, so we simply downscale it to the
// ten sizes macOS expects and hand the iconset to `iconutil`.
//
// Usage: swift tools/make_icon.swift [iconset-dir] [icns-out]
// Default: build/AppIcon.iconset  ->  build/AppIcon.icns
// Pass a different source as the first argument:
//   swift tools/make_icon.swift path/to/master.png
// (the source may be any square PNG; it is resized to fit each icon size.)

import AppKit
import Foundation

// Resolve the source master.
let sourcePath: String
if CommandLine.arguments.count > 1 {
    // First arg is the source PNG.
    sourcePath = CommandLine.arguments[1]
} else {
    sourcePath = "icons/DaiJishow Exports/DaiJishow-iOS-Default-1024@1x.png"
}

// Output locations follow the source argument, or use the defaults.
let outDir: String
let icnsOut: String
if CommandLine.arguments.count > 2 {
    outDir = CommandLine.arguments[2]
    icnsOut = CommandLine.arguments[3]
} else if CommandLine.arguments.count == 3 {
    outDir = CommandLine.arguments[2]
    icnsOut = "build/AppIcon.icns"
} else {
    outDir = "build/AppIcon.iconset"
    icnsOut = "build/AppIcon.icns"
}

guard let src = NSImage(contentsOfFile: sourcePath) else {
    FileHandle.standardError.write("Cannot load source image: \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

guard let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Source has no CGImage: \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

let space = CGColorSpaceCreateDeviceRGB()

// Render one iconset size: resize the master, preserve aspect, centre in a
// square (only matters if the source isn't perfectly square).
func render(_ px: Int) -> NSBitmapImageRep? {
    let side = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Centre-fit the (square) master into the target square.
    let imgW = CGFloat(cg.width), imgH = CGFloat(cg.height)
    let s = min(side / imgW, side / imgH)
    let dw = imgW * s, dh = imgH * s
    ctx.draw(cg, in: CGRect(x: (side - dw) / 2, y: (side - dh) / 2, width: dw, height: dh))

    guard let out = ctx.makeImage() else { return nil }
    guard let tiff = NSImage(cgImage: out, size: NSSize(width: px, height: px)).tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// The ten standard macOS iconset sizes (name, pixel size).
let spec: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in spec {
    guard let rep = render(px) else { continue }
    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Iconset written to \(outDir) (\(spec.count) sizes) from \(sourcePath)")
