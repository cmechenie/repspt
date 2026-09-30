// posetool: run Apple Vision body-pose estimation on a video, output annotated MP4 + CSV.
//
// Usage: swift run posetool <input.mov> <output_prefix>
//   produces: <output_prefix>_annotated.mp4
//             <output_prefix>_joints.csv  (frame,time,joint,x,y,confidence)

import Foundation
import AVFoundation
import Vision
import CoreImage
import CoreGraphics
import AppKit
import VideoToolbox

// ---- args ----
let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: posetool <input.mov> <output_prefix>\n".data(using: .utf8)!)
    exit(2)
}
let inputURL = URL(fileURLWithPath: args[1])
let outPrefix = args[2]
let outVideoURL = URL(fileURLWithPath: "\(outPrefix)_annotated.mp4")
let outCSVURL   = URL(fileURLWithPath: "\(outPrefix)_joints.csv")
try? FileManager.default.removeItem(at: outVideoURL)
try? FileManager.default.removeItem(at: outCSVURL)

// joints we care about (subset; full set is fine but this keeps CSV readable)
let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
    .nose, .neck,
    .leftShoulder, .rightShoulder,
    .leftElbow, .rightElbow,
    .leftWrist, .rightWrist,
    .leftHip, .rightHip,
    .leftKnee, .rightKnee,
    .leftAnkle, .rightAnkle,
    .root
]

// skeleton edges for drawing (pairs of joint names)
let skeletonEdges: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
    (.nose, .neck),
    (.neck, .leftShoulder), (.neck, .rightShoulder),
    (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
    (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
    (.neck, .root),
    (.root, .leftHip), (.root, .rightHip),
    (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
    (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
]

// ---- AVAssetReader ----
let asset = AVAsset(url: inputURL)
guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
    fatalError("no video track")
}
let naturalSize = try await videoTrack.load(.naturalSize)
let preferredTransform = try await videoTrack.load(.preferredTransform)
let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
let totalDuration = try await asset.load(.duration)
print("video: \(Int(naturalSize.width))x\(Int(naturalSize.height)) @ \(nominalFrameRate)fps, \(CMTimeGetSeconds(totalDuration))s")

let reader = try AVAssetReader(asset: asset)
let readerOutput = AVAssetReaderTrackOutput(
    track: videoTrack,
    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
)
readerOutput.alwaysCopiesSampleData = false
reader.add(readerOutput)
reader.startReading()

// ---- AVAssetWriter (annotated output) ----
let writer = try AVAssetWriter(outputURL: outVideoURL, fileType: .mp4)
let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(naturalSize.width),
    AVVideoHeightKey: Int(naturalSize.height),
])
writerInput.expectsMediaDataInRealTime = false
writerInput.transform = preferredTransform
let pbAdaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: writerInput,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: Int(naturalSize.width),
        kCVPixelBufferHeightKey as String: Int(naturalSize.height),
    ]
)
writer.add(writerInput)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

// ---- CSV ----
let csvHandle = FileHandle(forWritingAtPath: outCSVURL.path) ?? {
    FileManager.default.createFile(atPath: outCSVURL.path, contents: nil)
    return FileHandle(forWritingAtPath: outCSVURL.path)!
}()
csvHandle.write("frame,time_s,joint,x,y,confidence\n".data(using: .utf8)!)

// ---- pose request ----
let poseRequest = VNDetectHumanBodyPoseRequest()

// ---- frame loop ----
let ciContext = CIContext()
var frameIdx = 0
var detectedFrames = 0

while let sample = readerOutput.copyNextSampleBuffer() {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
    let timeSec = CMTimeGetSeconds(pts)

    // run pose
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
    var observation: VNHumanBodyPoseObservation? = nil
    do {
        try handler.perform([poseRequest])
        observation = (poseRequest.results ?? []).first
    } catch {
        // swallow per-frame errors
    }

    // build dict joint -> (point, confidence) in image coords
    var jointPts: [VNHumanBodyPoseObservation.JointName: (CGPoint, Float)] = [:]
    if let obs = observation {
        detectedFrames += 1
        if let recognized = try? obs.recognizedPoints(.all) {
            for jn in trackedJoints {
                if let p = recognized[jn], p.confidence > 0.05 {
                    // Vision returns normalized coords with origin at bottom-left.
                    let x = p.location.x * naturalSize.width
                    let y = (1.0 - p.location.y) * naturalSize.height
                    jointPts[jn] = (CGPoint(x: x, y: y), p.confidence)

                    let line = String(format: "%d,%.3f,%@,%.2f,%.2f,%.3f\n",
                                      frameIdx, timeSec, jointName(jn), x, y, p.confidence)
                    csvHandle.write(line.data(using: .utf8)!)
                }
            }
        }
    }

    // draw skeleton onto the frame
    let annotatedPB = drawSkeleton(on: pixelBuffer, joints: jointPts,
                                   width: Int(naturalSize.width),
                                   height: Int(naturalSize.height),
                                   ciContext: ciContext)

    // wait until writer is ready
    while !writerInput.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.005)
    }
    pbAdaptor.append(annotatedPB, withPresentationTime: pts)

    frameIdx += 1
    if frameIdx % 60 == 0 {
        print("  frame \(frameIdx) t=\(String(format: "%.2f", timeSec))s detected=\(detectedFrames)")
    }
}

writerInput.markAsFinished()
await writer.finishWriting()
csvHandle.closeFile()

print("done. frames=\(frameIdx) detected=\(detectedFrames) (\(frameIdx > 0 ? Int(100 * detectedFrames / frameIdx) : 0)%)")
print("  annotated: \(outVideoURL.path)")
print("  csv:       \(outCSVURL.path)")

// ---- helpers ----
func jointName(_ jn: VNHumanBodyPoseObservation.JointName) -> String {
    return jn.rawValue.rawValue
}

func drawSkeleton(on pixelBuffer: CVPixelBuffer,
                  joints: [VNHumanBodyPoseObservation.JointName: (CGPoint, Float)],
                  width: Int, height: Int,
                  ciContext: CIContext) -> CVPixelBuffer {
    // Make a CGImage from the source frame, then draw on it via CGContext.
    let ci = CIImage(cvPixelBuffer: pixelBuffer)
    guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return pixelBuffer }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                | CGBitmapInfo.byteOrder32Little.rawValue) else {
        return pixelBuffer
    }
    // Note: CGContext origin is bottom-left, but we computed joint y as top-left.
    // Easier: draw the image normally then flip y when stroking.
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

    func flipY(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: CGFloat(height) - p.y) }

    // edges
    ctx.setLineWidth(4)
    ctx.setStrokeColor(NSColor.systemGreen.cgColor)
    for (a, b) in skeletonEdges {
        guard let pa = joints[a], let pb = joints[b], pa.1 > 0.3, pb.1 > 0.3 else { continue }
        let p1 = flipY(pa.0), p2 = flipY(pb.0)
        ctx.move(to: p1)
        ctx.addLine(to: p2)
    }
    ctx.strokePath()

    // joints
    ctx.setFillColor(NSColor.systemRed.cgColor)
    for (_, val) in joints where val.1 > 0.3 {
        let p = flipY(val.0)
        ctx.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
    }

    guard let outImage = ctx.makeImage() else { return pixelBuffer }

    // make a new pixel buffer
    var out: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                        kCVPixelFormatType_32BGRA,
                        attrs as CFDictionary, &out)
    guard let outPB = out else { return pixelBuffer }

    CVPixelBufferLockBaseAddress(outPB, [])
    let outCtx = CGContext(
        data: CVPixelBufferGetBaseAddress(outPB),
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(outPB),
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue)
    outCtx?.draw(outImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(outPB, [])
    return outPB
}
