import Foundation
import AVFoundation
import Vision
import CoreGraphics

// MARK: - GestureDetector
//
// Processes live camera frames during a recording session and fires
// onConfirmed when the user performs the end-of-set gesture.
//
// Two detection modes, selected per-exercise via GestureKind:
//
//   .thumbsUp  — VNDetectHumanHandPoseRequest
//                Confirmed after 5 consecutive processed frames (~0.8 s)
//                with thumb tip clearly above the knuckle line.
//
//   .headNod   — VNDetectHumanBodyPoseRequest (already in PoseAnalyzer;
//                reused here for live frames).
//                Two deliberate downward dips of the neck relative to the
//                shoulders, within a 2.5 s window. Measuring the relative
//                neck–shoulder Y eliminates false triggers from whole-body
//                squat oscillation (both joints move together).
//
// Only every 5th sample buffer is analysed (~6 fps from a 30 fps stream),
// keeping CPU overhead low.
//
// Thread safety: captureOutput is called on a private AVFoundation queue.
// All mutable state is accessed only on that queue (serialised by the
// AVCaptureVideoDataOutput dispatch queue set by CameraRecorder).
// The onConfirmed callback is dispatched to the main thread.

final class GestureDetector: NSObject {

    // MARK: - Configuration

    var gestureKind:  GestureKind = .thumbsUp
    var orientation:  CGImagePropertyOrientation = .up   // set by CameraRecorder on start

    /// Called once on the main thread when the gesture is confirmed.
    /// Parameter is the CACurrentMediaTime() of the FIRST frame that
    /// showed the gesture (used as trim point in stopAndAnalyze).
    var onConfirmed: ((_ firstSeenAt: Double) -> Void)?

    // MARK: - Control

    /// Flip to true when recording starts; false when it stops or fires once.
    var isActive: Bool = false

    // MARK: - Private: frame subsampling

    private var frameCounter: Int = 0
    private let frameStep: Int = 5   // process every 5th frame

    // MARK: - Private: thumbs-up state

    private var tuConsecutive:   Int = 0
    private var tuFirstSeenAt:   Double? = nil
    private let tuRequiredFrames = 5     // ~0.8 s at 6 fps
    private let tuThumbAboveMCP  = 0.08  // thumb tip must be this far above knuckle line
    private let tuCurlTolerance  = 0.06  // fingertip may sit this far above its MCP and still count as curled
    private let tuMinCurledFingers = 3   // of the 4 non-thumb fingers
    private let handConfidenceMin: Float = 0.4

    // MARK: - Private: head-nod state

    // Relative measurement: neckY − shoulderMidY in Vision normalised coords.
    // Vision y=0 is at bottom, y=1 at top.
    // When the head nods DOWN, neck descends → relative value decreases.
    // Whole-body exercise oscillation moves both joints together → no change.

    private var nodBaselineSamples: [Double] = []
    private let nodBaselineCount = 12           // frames to establish resting baseline
    private var nodBaseline:  Double? = nil

    private var nodInDip:     Bool   = false
    private var nodDipTimes:  [Double] = []     // timestamps of confirmed dip-starts
    private let nodDipThresh: Double = 0.035    // fraction of frame height
    private let nodWindowS:   Double = 2.5
    private let nodRequired:  Int    = 2
    private var nodFirstSeenAt: Double? = nil
    private let nodBaselineEMAWeight = 0.02  // slow adaptation to posture shifts
    private let bodyConfidenceMin: Float = 0.3

    // MARK: - Requests (reused per frame)

    private let handRequest = VNDetectHumanHandPoseRequest()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()

    override init() {
        super.init()
        handRequest.maximumHandCount = 2
    }

    // MARK: - Reset between sets

    func reset() {
        frameCounter   = 0
        tuConsecutive  = 0
        tuFirstSeenAt  = nil
        nodBaselineSamples = []
        nodBaseline    = nil
        nodInDip       = false
        nodDipTimes    = []
        nodFirstSeenAt = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension GestureDetector: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isActive else { return }

        frameCounter += 1
        guard frameCounter % frameStep == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        switch gestureKind {
        case .thumbsUp: detectThumbsUp(pixelBuffer: pixelBuffer)
        case .headNod:  detectHeadNod(pixelBuffer: pixelBuffer)
        }
    }

    // MARK: - Thumbs-up detection

    private func detectThumbsUp(pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        try? handler.perform([handRequest])

        let obs = handRequest.results ?? []
        let detected = obs.contains { isThumbsUp(observation: $0) }

        if detected {
            if tuFirstSeenAt == nil { tuFirstSeenAt = CACurrentMediaTime() }
            tuConsecutive += 1
            if tuConsecutive >= tuRequiredFrames {
                fire(firstSeenAt: tuFirstSeenAt!)
            }
        } else {
            // Only reset if we drop out cleanly (allow 1-frame gap to tolerate
            // brief detection hiccups without restarting the counter).
            tuConsecutive = max(tuConsecutive - 2, 0)
            if tuConsecutive == 0 { tuFirstSeenAt = nil }
        }
    }

    /// Returns true when the hand observation looks like a thumbs-up:
    ///   thumb tip is significantly above the average MCP (knuckle) line,
    ///   while all other finger tips are below or near that line (curled).
    private func isThumbsUp(observation obs: VNHumanHandPoseObservation) -> Bool {
        guard let recognized = try? obs.recognizedPoints(.all) else { return false }

        func y(_ name: VNHumanHandPoseObservation.JointName) -> Double? {
            guard let p = recognized[name], p.confidence > handConfidenceMin else { return nil }
            return Double(p.location.y)  // Vision coords: y=1 at top
        }

        guard let thumbTip   = y(.thumbTip),
              let indexMCP   = y(.indexMCP),
              let middleMCP  = y(.middleMCP),
              let ringMCP    = y(.ringMCP),
              let littleMCP  = y(.littleMCP) else { return false }

        let avgMCP = (indexMCP + middleMCP + ringMCP + littleMCP) / 4.0

        // Thumb tip must be clearly above the knuckle line
        guard thumbTip > avgMCP + tuThumbAboveMCP else { return false }

        // Other fingertips must be curled (not extended above knuckles)
        let otherTips: [VNHumanHandPoseObservation.JointName] = [
            .indexTip, .middleTip, .ringTip, .littleTip
        ]
        let mcps: [VNHumanHandPoseObservation.JointName] = [
            .indexMCP, .middleMCP, .ringMCP, .littleMCP
        ]
        var curledCount = 0
        for (tip, mcp) in zip(otherTips, mcps) {
            if let ty = y(tip), let my = y(mcp), ty < my + tuCurlTolerance {
                curledCount += 1
            }
        }
        return curledCount >= tuMinCurledFingers
    }

    // MARK: - Head-nod detection

    private func detectHeadNod(pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        try? handler.perform([bodyRequest])

        guard let obs = (bodyRequest.results ?? []).first,
              let points = try? obs.recognizedPoints(.all) else { return }

        func y(_ name: VNHumanBodyPoseObservation.JointName) -> Double? {
            guard let p = points[name], p.confidence > bodyConfidenceMin else { return nil }
            return Double(p.location.y)
        }

        guard let neckY  = y(.neck),
              let lShouY = y(.leftShoulder),
              let rShouY = y(.rightShoulder) else { return }

        let shoulderMidY = (lShouY + rShouY) / 2.0
        let relative = neckY - shoulderMidY   // positive = neck is above shoulders (normal)

        // ── Establish baseline from first nodBaselineCount frames ────────
        if nodBaseline == nil {
            nodBaselineSamples.append(relative)
            if nodBaselineSamples.count >= nodBaselineCount {
                nodBaseline = nodBaselineSamples.reduce(0, +) / Double(nodBaselineSamples.count)
            }
            return
        }

        // Continuously update baseline with a slow exponential filter so
        // the detector adapts if the user shifts their posture mid-set.
        nodBaseline = nodBaseline! * (1 - nodBaselineEMAWeight) + relative * nodBaselineEMAWeight

        let baseline = nodBaseline!
        let drop = baseline - relative   // positive when neck moves DOWN relative to baseline

        let now = CACurrentMediaTime()

        // ── Dip state machine ────────────────────────────────────────────
        if !nodInDip && drop > nodDipThresh {
            // Entering a dip
            nodInDip = true
        } else if nodInDip && drop < nodDipThresh * 0.5 {
            // Exiting the dip — record it
            nodInDip = false
            nodDipTimes.append(now)
            if nodFirstSeenAt == nil { nodFirstSeenAt = now }

            // Remove dips that are outside the detection window
            nodDipTimes = nodDipTimes.filter { now - $0 < nodWindowS }

            if nodDipTimes.count >= nodRequired {
                fire(firstSeenAt: nodFirstSeenAt!)
            }
        }
    }

    // MARK: - Fire

    private func fire(firstSeenAt: Double) {
        guard isActive else { return }
        isActive = false   // prevent double-firing
        let t = firstSeenAt
        DispatchQueue.main.async { [weak self] in
            self?.onConfirmed?(t)
        }
    }
}
