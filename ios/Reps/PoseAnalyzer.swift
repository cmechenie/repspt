import Foundation
import AVFoundation
import Vision
import CoreGraphics

/// Reads every frame of a video file, runs Apple Vision body-pose, and returns
/// a list of PoseFrame in display-oriented image coordinates (origin top-left).
///
/// Portrait-video fix
/// ──────────────────
/// The AVCaptureMovieFileOutput stores raw sensor pixels (landscape) and records
/// the rotation intent as a preferredTransform on the track — the pixel buffer
/// itself is never rotated. Without correcting for this:
///   • Vision sees a sideways person → neck and hip at the same Y, far apart in X
///   • leanDeg() returns atan2(huge_dx, ~0) ≈ 90° for every rep
///   • Coordinate scaling uses wrong width/height
///
/// Fix: load preferredTransform, derive the CGImagePropertyOrientation for Vision
/// (so it corrects the buffer internally and returns upright coordinates), then
/// scale by the display dimensions (swapped for ±90° rotations).
struct PoseAnalyzer {

    static func analyze(videoURL: URL,
                        progress: ((Double) -> Void)? = nil) async throws -> [PoseFrame] {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw NSError(domain: "RepsPT", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }
        let naturalSize      = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let totalDuration    = CMTimeGetSeconds(try await asset.load(.duration))

        // ── Orientation-aware display dimensions ────────────────────────────
        // For ±90° rotated tracks (portrait), width and height are swapped.
        let isRotated90 = abs(preferredTransform.a) < 0.5 && abs(preferredTransform.d) < 0.5
        let displayWidth:  CGFloat = isRotated90 ? naturalSize.height : naturalSize.width
        let displayHeight: CGFloat = isRotated90 ? naturalSize.width  : naturalSize.height

        // Tell Vision how the raw pixel buffer is oriented so it returns
        // coordinates in the corrected (upright) coordinate space.
        let visionOrientation = cgOrientation(from: preferredTransform)

        // ── Reader setup ────────────────────────────────────────────────────
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let request = VNDetectHumanBodyPoseRequest()
        var frames: [PoseFrame] = []
        var idx = 0

        while let sample = output.copyNextSampleBuffer() {
            defer { idx += 1 }
            guard let pixel = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            let t = CMTimeGetSeconds(pts)

            // Pass the correct orientation so Vision compensates for the raw buffer rotation.
            let handler = VNImageRequestHandler(cvPixelBuffer: pixel,
                                                orientation: visionOrientation,
                                                options: [:])
            try? handler.perform([request])
            guard let obs = (request.results ?? []).first else {
                frames.append(PoseFrame(frameIndex: idx, timeSeconds: t, joints: [:], confidences: [:]))
                continue
            }

            var joints: [Joint: CGPoint] = [:]
            var confs: [Joint: Float] = [:]
            if let recognized = try? obs.recognizedPoints(.all) {
                for j in Joint.allCases {
                    if let vname = visionName(j), let p = recognized[vname], p.confidence > 0.05 {
                        // Vision returns normalized coords in the DISPLAY (upright) space.
                        // Scale by display dimensions (not raw naturalSize).
                        let x = p.location.x * displayWidth
                        let y = (1.0 - p.location.y) * displayHeight   // flip Vision's y=0-at-bottom
                        joints[j] = CGPoint(x: x, y: y)
                        confs[j] = p.confidence
                    }
                }
            }
            frames.append(PoseFrame(frameIndex: idx, timeSeconds: t, joints: joints, confidences: confs))

            if let progress = progress, totalDuration > 0, idx % 30 == 0 {
                await MainActor.run { progress(min(t / totalDuration, 1.0)) }
            }
        }

        return frames
    }

    // MARK: - Helpers

    /// Maps a track's preferredTransform to the CGImagePropertyOrientation that
    /// Vision needs so it returns coordinates in the display (upright) space.
    ///
    /// The transform describes how to rotate raw pixels to display correctly:
    ///   90° CCW transform  (a=0, b=1)  → raw is 90° CW → Vision .right (EXIF 6)
    ///   90° CW  transform  (a=0, b=-1) → raw is 90° CCW → Vision .left  (EXIF 8)
    ///   180°    transform  (a=-1,b=0)  → raw is upside-down → Vision .down
    ///   0°      transform  (a=1, b=0)  → no rotation → Vision .up
    private static func cgOrientation(from t: CGAffineTransform) -> CGImagePropertyOrientation {
        let angle = (Int((atan2(t.b, t.a) * 180 / .pi).rounded()) + 360) % 360
        switch angle {
        case 90:  return .right   // portrait, back camera
        case 180: return .down
        case 270: return .left    // portrait upside-down / some front-camera combos
        default:  return .up      // landscape
        }
    }

    private static func visionName(_ j: Joint) -> VNHumanBodyPoseObservation.JointName? {
        switch j {
        case .nose:      return .nose
        case .neck:      return .neck
        case .lShoulder: return .leftShoulder
        case .rShoulder: return .rightShoulder
        case .lElbow:    return .leftElbow
        case .rElbow:    return .rightElbow
        case .lWrist:    return .leftWrist
        case .rWrist:    return .rightWrist
        case .lHip:      return .leftHip
        case .rHip:      return .rightHip
        case .lKnee:     return .leftKnee
        case .rKnee:     return .rightKnee
        case .lAnkle:    return .leftAnkle
        case .rAnkle:    return .rightAnkle
        }
    }
}
