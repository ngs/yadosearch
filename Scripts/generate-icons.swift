#!/usr/bin/env swift
//
// Renders the app icon into Resources/Assets.xcassets/AppIcon.appiconset.
//
//   swift Scripts/generate-icons.swift
//
// A CoreGraphics render rather than a designer's artwork: it keeps the icon in
// version control as the code that draws it, and it is deliberately simple —
// a roof and a noren, white on the orange the original 2014 app tinted itself
// with. Replace it when there is real artwork.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconSetURL = projectRoot
    .appending(path: "Resources/Assets.xcassets/AppIcon.appiconset")

/// Draws the icon at `size` points on a side.
///
/// Everything is expressed against a 1024 grid and scaled, so the small macOS
/// sizes are the same drawing rather than a downsample of a big one.
func drawIcon(size: Int, rounded: Bool) -> CGImage? {
    let side = CGFloat(size)
    let scale = side / 1_024
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    // macOS icons carry their own rounded rect and margin; iOS is masked for us.
    let inset: CGFloat = rounded ? side * 0.09 : 0
    let plate = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    context.saveGState()
    if rounded {
        let path = CGPath(
            roundedRect: plate,
            cornerWidth: plate.width * 0.225,
            cornerHeight: plate.width * 0.225,
            transform: nil
        )
        context.addPath(path)
        context.clip()
    }

    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [
            CGColor(red: 1.00, green: 0.64, blue: 0.26, alpha: 1),
            CGColor(red: 0.87, green: 0.31, blue: 0.05, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: plate.minX, y: plate.maxY),
        end: CGPoint(x: plate.maxX, y: plate.minY),
        options: []
    )

    // The grid is 1024 with the origin at the top left, which is how the shapes
    // below were laid out; CoreGraphics has it at the bottom.
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: side - y * scale)
    }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))

    // Roof: a chevron with eaves.
    let roof = CGMutablePath()
    roof.move(to: point(96, 452))
    roof.addLine(to: point(512, 196))
    roof.addLine(to: point(928, 452))
    roof.addLine(to: point(820, 452))
    roof.addLine(to: point(512, 314))
    roof.addLine(to: point(204, 452))
    roof.closeSubpath()
    context.addPath(roof)
    context.fillPath()

    // Noren: the rod, then three panels hanging from it.
    let rod = CGRect(
        origin: point(272, 552),
        size: CGSize(width: 480 * scale, height: 40 * scale)
    )
    context.addPath(CGPath(roundedRect: rod, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil))
    context.fillPath()

    let panelWidth: CGFloat = 144
    let panelGap: CGFloat = 24
    for index in 0..<3 {
        let x = 272 + CGFloat(index) * (panelWidth + panelGap)
        let panel = CGRect(
            origin: point(x, 792),
            size: CGSize(width: panelWidth * scale, height: 240 * scale)
        )
        context.addPath(
            CGPath(
                roundedRect: panel,
                cornerWidth: 16 * scale,
                cornerHeight: 16 * scale,
                transform: nil
            )
        )
        context.fillPath()
    }

    context.restoreGState()
    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

struct IconFile {
    let name: String
    let pixels: Int
    let rounded: Bool
}

let files: [IconFile] = [
    IconFile(name: "icon-ios-1024.png", pixels: 1_024, rounded: false)
] + [16, 32, 64, 128, 256, 512, 1_024].map {
    IconFile(name: "icon-mac-\($0).png", pixels: $0, rounded: true)
}

try FileManager.default.createDirectory(at: iconSetURL, withIntermediateDirectories: true)
for file in files {
    guard let image = drawIcon(size: file.pixels, rounded: file.rounded) else {
        FileHandle.standardError.write(Data("could not render \(file.name)\n".utf8))
        exit(1)
    }
    try write(image, to: iconSetURL.appending(path: file.name))
    print("wrote \(file.name)")
}
