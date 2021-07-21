#!/usr/bin/swift

import Cocoa

// ffmpeg -r 1 -i trim.mov -r 1 output_%04d.bmp

let contents = try? FileManager.default.contentsOfDirectory(atPath: ".")

let images = contents?.filter({ $0.contains(".bmp") }).sorted()

guard let images = images, !images.isEmpty else {
    fatalError("Empty list")
}

// Assuming 60 fps constant rate
let timeBetweenFrames: Double = 1/60.0 // seconds
var currentTimestamp: Double = 0 // seconds

var leftCount = 0
var rightCount = 0
var droppedCount = 0

var currentIndex = 0

var leftFramesInfo = [(String, Double)]()
var rightFramesInfo = [(String, Double)]()

for imagePath in images {

    currentTimestamp = Double(currentIndex) * timeBetweenFrames
    currentIndex += 1

    guard let image = NSImage(contentsOfFile: imagePath) else {
        print("\(imagePath) dropped")
        droppedCount += 1
        continue
    }

    var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)

    // These points and colors are specific for this video. They will look different
    // for frames that should be on the right and frames that should be on the left.
    guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil),
          let colors = cgImage.colors(at: [CGPoint(x: 1660, y: 1160), CGPoint(x: 1530, y: 1070), CGPoint(x: 1630, y: 1160), CGPoint(x: 1500, y: 1070)])
    else {
        print("\(imagePath) dropped")
        droppedCount += 1
        continue
    }

    let isLeft = colors[0].redComponent > 0.9 || colors[1].redComponent > 0.9
    let isRight = colors[2].redComponent > 0.9 || colors[3].redComponent > 0.9

    if isRight && isLeft {
        print("\(imagePath) ambiguous")
        droppedCount += 1
        continue
    }

    if isRight {
        print("\(imagePath) right")
        let newPath = String(format: "right_%04d.bmp", rightCount)
        rightFramesInfo.append((newPath, currentTimestamp))
        rightCount += 1
        try? FileManager.default.moveItem(atPath: imagePath, toPath: newPath)
    } else if isLeft {
        print("\(imagePath) left")
        let newPath = String(format: "left_%04d.bmp", leftCount)
        leftFramesInfo.append((newPath, currentTimestamp))
        leftCount += 1
        try? FileManager.default.moveItem(atPath: imagePath, toPath: newPath)
    } else {
        print("\(imagePath) dropped")
        droppedCount += 1
    }
}

print("Left: \(leftCount) Right: \(rightCount) Dropped: \(droppedCount)")

var leftConcatString = "ffconcat version 1.0"

// We're dropping the very last frame
for i in 0 ..< leftFramesInfo.count - 1 {
    let (fileName, timestamp) = leftFramesInfo[i]
    let (_, nextTimestamp) = leftFramesInfo[i + 1]
    leftConcatString += "\nfile \(fileName)\nduration \(nextTimestamp - timestamp)"
}

try? leftConcatString.write(toFile: "left.ffconcat", atomically: true, encoding: .utf8)

var rightConcatString = "ffconcat version 1.0"

// We're dropping the very last frame
for i in 0 ..< rightFramesInfo.count - 1 {
    let (fileName, timestamp) = rightFramesInfo[i]
    let (_, nextTimestamp) = rightFramesInfo[i + 1]
    rightConcatString += "\nfile \(fileName)\nduration \(nextTimestamp - timestamp)"
}

try? rightConcatString.write(toFile: "right.ffconcat", atomically: true, encoding: .utf8)

// ffmpeg -i left.ffconcat -r 30 -c:v libx264 -preset slow -crf 23 -vsync 2 left.mp4

// ffmpeg -i right.ffconcat -r 30 -c:v libx264 -preset slow -crf 23 -vsync 2 right.mp4

extension CGImage {
    func colors(at: [CGPoint]) -> [NSColor]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo),
            let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return at.map { p in
            let i = bytesPerRow * Int(p.y) + bytesPerPixel * Int(p.x)

            let a = CGFloat(ptr[i + 3]) / 255.0
            let r = (CGFloat(ptr[i]) / a) / 255.0
            let g = (CGFloat(ptr[i + 1]) / a) / 255.0
            let b = (CGFloat(ptr[i + 2]) / a) / 255.0

            return NSColor(red: r, green: g, blue: b, alpha: a)
        }
    }
}
