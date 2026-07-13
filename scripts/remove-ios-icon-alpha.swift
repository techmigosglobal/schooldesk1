#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments.dropFirst()
guard !arguments.isEmpty else {
  fputs("Pass one or more PNG files.\n", stderr)
  exit(64)
}

for argument in arguments {
  let url = URL(fileURLWithPath: argument)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        let context = CGContext(
          data: nil,
          width: image.width,
          height: image.height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
    fputs("Unable to read \(argument)\n", stderr)
    exit(65)
  }

  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

  guard let flattened = context.makeImage() else {
    fputs("Unable to encode \(argument)\n", stderr)
    exit(70)
  }

  let temporaryURL = url.deletingLastPathComponent()
    .appendingPathComponent(".\(url.lastPathComponent).flattened")
  guard let destination = CGImageDestinationCreateWithURL(
    temporaryURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
  ) else {
    fputs("Unable to create PNG output for \(argument)\n", stderr)
    exit(70)
  }
  CGImageDestinationAddImage(destination, flattened, nil)
  guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to write \(argument)\n", stderr)
    exit(74)
  }
  _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
}
