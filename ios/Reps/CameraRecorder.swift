import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - CameraRecorder

/// Wraps AVCaptureSession + AVCaptureMovieFileOutput. Records to a temp .mov.
/// Also drives a GestureDetector via AVCaptureVideoDataOutput so the user can
/// signal end-of-set with a thumbs-up or double head-nod.
@MainActor
final class CameraRecorder: NSObject, ObservableObject {
    @Published var isAuthorized:  Bool = false
    @Published var isRecording:   Bool = false
    @Published var isFrontCamera: Bool = false
    @Published var lastClipURL:   URL?
    @Published var error:         String?

    /// Increments every time the capture session (re)starts.
    /// Passed to CameraPreview so updateUIView is always called after a restart,
    /// re-applying rotation + mirroring on the freshly established connection.
    @Published var previewRevision: Int = 0

    /// Set once the user's end-of-set gesture is confirmed.
    /// Value is the CACurrentMediaTime() of the first frame the gesture appeared —
    /// used by RecordView.stopAndAnalyze to trim transition frames.
    @Published var gestureFirstSeenAt: Double? = nil

    /// Wall-clock time (CACurrentMediaTime) when the current recording started.
    /// Used to convert gestureFirstSeenAt (wall time) → video PTS for frame trimming.
    private(set) var recordingStartWallTime: Double? = nil

    let session = AVCaptureSession()
    private let movieOutput   = AVCaptureMovieFileOutput()
    private let liveOutput    = AVCaptureVideoDataOutput()
    private let gestureQueue  = DispatchQueue(label: "repspt.gesture", qos: .userInitiated)
    let gestureDetector       = GestureDetector()

    private var videoInput: AVCaptureDeviceInput?
    private var stopContinuation: CheckedContinuation<URL, Error>?

    override init() {
        super.init()
        Task { await requestAccessAndConfigure() }
    }

    // MARK: - Setup

    private func requestAccessAndConfigure() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        switch status {
        case .authorized:    granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default:             granted = false
        }
        isAuthorized = granted
        guard granted else {
            error = "Camera access denied. Enable in Settings → RepsPT."
            return
        }
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Could not open back camera."
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }

        // Movie output (records to file)
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let conn = movieOutput.connection(with: .video),
               conn.isVideoRotationAngleSupported(0) {
                conn.videoRotationAngle = 0
                conn.preferredVideoStabilizationMode = .standard
            }
        }

        // Live video output for gesture detection (low-res, discardLate frames)
        liveOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        liveOutput.alwaysDiscardsLateVideoFrames = true
        liveOutput.setSampleBufferDelegate(gestureDetector, queue: gestureQueue)
        if session.canAddOutput(liveOutput) {
            session.addOutput(liveOutput)
        }

        // Wire the gesture detector callback — fires once on main thread
        gestureDetector.onConfirmed = { [weak self] firstSeenAt in
            Task { @MainActor [weak self] in
                self?.gestureFirstSeenAt = firstSeenAt
            }
        }

        session.commitConfiguration()
        Task.detached { [session] in session.startRunning() }
    }

    // MARK: - Session control

    func stopSession() {
        Task.detached { [session] in session.stopRunning() }
    }

    func startSession() {
        guard isAuthorized else { return }
        previewRevision += 1          // triggers CameraPreview.updateUIView → re-applies rotation/mirroring
        Task.detached { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    /// Toggle between front and back camera. No-op while recording.
    func switchCamera() {
        guard !movieOutput.isRecording else { return }
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if let current = videoInput { session.removeInput(current) }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            videoInput = newInput
        }
        // Never mirror the saved file — pose analysis needs unflipped coords
        if let conn = movieOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(0) { conn.videoRotationAngle = 0 }
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = false
        }
        session.commitConfiguration()
        isFrontCamera = (newPosition == .front)
    }

    // MARK: - Gesture configuration

    /// Call once after the user picks an exercise (or changes it).
    /// Sets the gesture kind and hint; the detector is activated/deactivated
    /// automatically by startRecording / stopRecording.
    func configure(for exercise: Exercise) {
        gestureDetector.gestureKind = exercise.gestureKind
    }

    // MARK: - Recording

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        // Write the correct rotation angle into the video file as preferredTransform
        // so PoseAnalyzer can apply the matching Vision orientation when reading.
        // Without this, a portrait recording gets preferredTransform = identity
        // and Vision processes the raw landscape pixel buffer → person appears sideways
        // → leanDeg() returns ~90° for every rep.
        if let conn = movieOutput.connection(with: .video) {
            let angle = Self.movieRotationAngle(for: UIDevice.current.orientation,
                                                isFrontCamera: isFrontCamera)
            if conn.isVideoRotationAngleSupported(angle) {
                conn.videoRotationAngle = angle
            }
        }

        // Set the Vision orientation the gesture detector should use —
        // matches what PoseAnalyzer derives from preferredTransform.
        gestureDetector.orientation = Self.visionOrientation(
            for: UIDevice.current.orientation, isFrontCamera: isFrontCamera)
        gestureFirstSeenAt = nil
        gestureDetector.reset()
        gestureDetector.isActive = true

        movieOutput.startRecording(to: Self.newClipURL(), recordingDelegate: self)
    }

    /// Derives the CGImagePropertyOrientation that Vision needs for live frames,
    /// matching the same angle written into the movie file by movieRotationAngle().
    private static func visionOrientation(for orientation: UIDeviceOrientation,
                                          isFrontCamera: Bool) -> CGImagePropertyOrientation {
        switch orientation {
        case .portrait:       return .right           // 90°
        case .landscapeLeft:  return isFrontCamera ? .down : .up    // 180° / 0°
        case .landscapeRight: return isFrontCamera ? .up   : .down
        default:              return .right            // default portrait
        }
    }

    /// Rotation angle to embed in the saved video file.
    /// Mirrors previewRotationAngle in RecordView so the stored preferredTransform
    /// matches what the user saw in the preview. PoseAnalyzer reads this to choose
    /// the correct CGImagePropertyOrientation for Vision.
    private static func movieRotationAngle(for orientation: UIDeviceOrientation,
                                           isFrontCamera: Bool) -> Double {
        switch orientation {
        case .portrait:       return 90
        case .landscapeLeft:  return isFrontCamera ? 180 : 0
        case .landscapeRight: return isFrontCamera ? 0   : 180
        default:              return 0
        }
    }

    func stopRecording() async throws -> URL {
        gestureDetector.isActive = false   // stop processing frames immediately
        guard movieOutput.isRecording else {
            if let url = lastClipURL { return url }
            throw NSError(domain: "RepsPT", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no recording in progress"])
        }
        return try await withCheckedThrowingContinuation { cont in
            stopContinuation = cont
            movieOutput.stopRecording()
        }
    }

    /// Returns a unique URL inside Documents/repspt_clips/ for a new recording.
    /// Using Documents (not temp) means clips survive across app launches and are
    /// only removed when the user deletes the history entry (see HistoryStore.delete).
    private static func newClipURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("repspt_clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clip_\(Int(Date().timeIntervalSince1970)).mov")
    }
}

// MARK: - Movie file delegate

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didStartRecordingTo fileURL: URL,
                                from connections: [AVCaptureConnection]) {
        let wallTime = CACurrentMediaTime()
        Task { @MainActor in
            self.isRecording = true
            self.recordingStartWallTime = wallTime
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        let finished = (error as NSError?)
            .flatMap { $0.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool }
            ?? (error == nil)

        Task { @MainActor in
            self.isRecording = false
            if finished {
                self.lastClipURL = outputFileURL
                self.stopContinuation?.resume(returning: outputFileURL)
            } else if let error = error {
                self.error = error.localizedDescription
                self.stopContinuation?.resume(throwing: error)
            }
            self.stopContinuation = nil
        }
    }
}

