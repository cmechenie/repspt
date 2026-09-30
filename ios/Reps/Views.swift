import SwiftUI
import AVFoundation
import AVKit

// =====================================================================
// Camera preview (UIView wrapper around AVCaptureVideoPreviewLayer)
// =====================================================================
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isFrontCamera: Bool
    let rotationAngle: Double        // 0 = landscape-right, 180 = landscape-left
    let revision: Int                // increment to force updateUIView after session restarts

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    /// Called whenever any parameter changes — including revision, which fires
    /// after every session (re)start so rotation is re-applied to the
    /// freshly established connection.
    ///
    /// NOTE: mirroring for the front camera is NOT done here via isVideoMirrored.
    /// AVFoundation applies: mirror → then rotate. So isVideoMirrored=true +
    /// videoRotationAngle=180 produces a vertical flip (upside-down), not a
    /// correct selfie view. Instead, mirroring is handled by a SwiftUI
    /// .scaleEffect(x: -1) on the parent view, which is a pure 2D transform
    /// that composes correctly with any rotation angle.
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        guard let conn = uiView.previewLayer.connection else { return }
        conn.automaticallyAdjustsVideoMirroring = false
        conn.isVideoMirrored = false   // never mirror here — see scaleEffect in RecordView
        if conn.isVideoRotationAngleSupported(rotationAngle) {
            conn.videoRotationAngle = rotationAngle
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// =====================================================================
// Record screen
// =====================================================================
struct RecordView: View {
    @ObservedObject var recorder: CameraRecorder
    @Binding var phase: AppPhase
    @ObservedObject var history: HistoryStore
    @Binding var selectedExercise: Exercise
    @State private var analysisError: String?
    @State private var showingHistory = false
    @State private var showingExercisePicker = true
    @State private var previewAngle: Double = 0
    /// nil = idle; 3/2/1 = counting down before recording starts
    @State private var countdownValue: Int? = nil
    /// Briefly shown after gesture is confirmed before analysis starts.
    @State private var showGestureConfirmed: Bool = false

    var body: some View {
        ZStack {
            if recorder.isAuthorized {
                CameraPreview(session: recorder.session,
                              isFrontCamera: recorder.isFrontCamera,
                              rotationAngle: previewAngle,
                              revision: recorder.previewRevision)
                    // Horizontal flip for selfie-camera mirror effect.
                    // Done here (SwiftUI transform) rather than via
                    // AVCaptureConnection.isVideoMirrored, because AVFoundation
                    // applies mirror-then-rotate internally, which makes
                    // isVideoMirrored=true + 180° rotation produce a vertical
                    // flip instead of a correct selfie view.
                    .scaleEffect(x: recorder.isFrontCamera ? -1 : 1, y: 1)
                    .ignoresSafeArea()
                framingOverlay
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                    Text(recorder.error ?? "Waiting for camera permission...")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(.white)
            }

            // ── Bottom control bar ─────────────────────────────────────────
            // All controls live at the bottom to avoid Dynamic Island / status
            // bar conflicts. Shown in full when idle; collapses to just the
            // stop button while recording.
            VStack(spacing: 0) {
                Spacer()

                // Exercise selector pill — shown when idle (not recording, not counting down)
                if !recorder.isRecording && countdownValue == nil {
                    Button { showingExercisePicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedExercise.sfSymbol)
                            Text(selectedExercise.name)
                            Image(systemName: "chevron.up")
                                .font(.caption)
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 20)
                }

                // Bottom row: history | record | camera-flip
                HStack {
                    // TODO: Move history to a dedicated non-camera screen once
                    // the overall user journey / navigation architecture is defined.
                    Group {
                        if !recorder.isRecording && countdownValue == nil {
                            Button { showingHistory = true } label: {
                                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 56, height: 56)

                    Spacer()
                    recordButton
                    Spacer()

                    Group {
                        if !recorder.isRecording && countdownValue == nil {
                            Button { recorder.switchCamera() } label: {
                                Image(systemName: "camera.rotate")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 56, height: 56)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)   // sits above home-indicator / safe area
            }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            previewAngle = Self.previewRotationAngle(current: previewAngle, isFrontCamera: recorder.isFrontCamera)
            recorder.configure(for: selectedExercise)
            recorder.startSession()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            previewAngle = Self.previewRotationAngle(current: previewAngle, isFrontCamera: recorder.isFrontCamera)
        }
        .onChange(of: recorder.isFrontCamera) { _, isFront in
            // Recalculate angle immediately when camera is switched —
            // front and back need opposite angles for the same orientation.
            previewAngle = Self.previewRotationAngle(current: previewAngle, isFrontCamera: isFront)
        }
        .onChange(of: recorder.isRecording) { _, isRec in
            UIApplication.shared.isIdleTimerDisabled = isRec
            if !isRec { showGestureConfirmed = false }
        }
        .onChange(of: selectedExercise) { _, exercise in
            recorder.configure(for: exercise)
        }
        .onChange(of: recorder.gestureFirstSeenAt) { _, firstSeenAt in
            guard firstSeenAt != nil, recorder.isRecording else { return }
            // Show "✓ Set complete" briefly, then auto-stop and analyze
            withAnimation(.easeInOut(duration: 0.25)) { showGestureConfirmed = true }
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 s
                await stopAndAnalyze(gestureFirstSeenAt: firstSeenAt)
            }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(store: history)
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(selected: $selectedExercise)
        }
        .onChange(of: showingHistory) { _, showing in
            if showing { recorder.stopSession() }
            else       { recorder.startSession() }
        }
        .onChange(of: showingExercisePicker) { _, showing in
            if showing { recorder.stopSession() }
            else       { recorder.startSession() }
        }
        .alert("Analysis failed", isPresented: Binding(
            get: { analysisError != nil },
            set: { if !$0 { analysisError = nil } }
        )) {
            Button("OK") { analysisError = nil }
        } message: {
            Text(analysisError ?? "")
        }
    }

    private var recordButton: some View {
        Button {
            Task { await handleRecordButton() }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                if let n = countdownValue {
                    // Countdown — shows the digit; tap cancels
                    Text("\(n)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .id(n)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.25), value: n)
                } else if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .disabled(!recorder.isAuthorized)
    }

    /// Faint guides so the user frames their body in the middle of the screen.
    private var framingOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let isPortrait = h > w
            ZStack {
                // Vertical center line
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: h)
                    .position(x: w / 2, y: h / 2)

                // Body bounding hint — wider in portrait (person fills more of frame width)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.25), style: .init(lineWidth: 2, dash: [8, 6]))
                    .frame(
                        width:  isPortrait ? w * 0.55 : w * 0.25,
                        height: isPortrait ? h * 0.78 : h * 0.75
                    )
                    .position(x: w / 2, y: h / 2)

                if let n = countdownValue {
                    // Full-screen countdown — large centred digit, subtle scrim
                    Color.black.opacity(0.35).ignoresSafeArea()
                    Text("\(n)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .id(n)
                        .transition(.scale(scale: 1.3).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.25), value: n)
                        .position(x: w / 2, y: h / 2)
                    Text("Get into position")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .position(x: w / 2, y: h / 2 + 80)
                } else if recorder.isRecording {
                    // REC badge — top-left, safely below Dynamic Island / status bar
                    Text("REC")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .position(x: 50, y: 60)

                    // Gesture hint pill — bottom-centre, above the stop button area
                    if showGestureConfirmed {
                        Text("✓ Set complete")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .transition(.scale.combined(with: .opacity))
                            .position(x: w / 2, y: h - 140)
                    } else {
                        Text(selectedExercise.gestureHint)
                            .font(.footnote)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white.opacity(0.9))
                            .clipShape(Capsule())
                            .position(x: w / 2, y: h - 140)
                    }
                } else {
                    // Camera-placement hint — sits just inside the top of the
                    // bounding-hint box, well below the Dynamic Island.
                    Text(selectedExercise.cameraHint)
                        .font(.footnote)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .position(x: w / 2, y: isPortrait ? h * 0.14 : h * 0.15)
                }
            }
        }
    }

    /// Maps UIDeviceOrientation to the AVCaptureConnection videoRotationAngle.
    ///
    /// Portrait:                    90° for both cameras (vertical axis is shared).
    /// Landscape left  (home right): back=0°,   front=180°.
    /// Landscape right (home left):  back=180°, front=0°.
    /// Face-up / face-down / unknown → keep whatever was last set (no jump).
    ///
    /// Front-camera mirror effect is handled via SwiftUI .scaleEffect(x: -1),
    /// NOT via AVCaptureConnection.isVideoMirrored — see CameraPreview for why.
    private static func previewRotationAngle(current: Double, isFrontCamera: Bool) -> Double {
        switch UIDevice.current.orientation {
        case .portrait:       return 90
        case .landscapeLeft:  return isFrontCamera ? 180 : 0
        case .landscapeRight: return isFrontCamera ? 0   : 180
        default:              return current
        }
    }

    private func handleRecordButton() async {
        if recorder.isRecording {
            await stopAndAnalyze(gestureFirstSeenAt: nil)
        } else if countdownValue != nil {
            // Cancel the in-progress countdown
            countdownValue = nil
            UIApplication.shared.isIdleTimerDisabled = false
        } else {
            await startCountdownThenRecord()
        }
    }

    /// 3-2-1 countdown, then starts recording. Tapping the button during the
    /// countdown sets countdownValue = nil which the guard below detects.
    private func startCountdownThenRecord() async {
        UIApplication.shared.isIdleTimerDisabled = true   // keep screen on while waiting
        for i in stride(from: 9, through: 1, by: -1) {
            countdownValue = i
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 s
            guard countdownValue != nil else {
                UIApplication.shared.isIdleTimerDisabled = false
                return   // cancelled by second tap
            }
        }
        countdownValue = nil
        recorder.startRecording()
        // isIdleTimerDisabled stays true; onChange(recorder.isRecording) keeps it set
    }

    /// Removes frames recorded after the user's end-of-set gesture.
    ///
    /// gestureFirstSeenAt is in CACurrentMediaTime(); PoseFrame.timeSeconds is
    /// the CMSampleBuffer PTS (not wall time). Mapping: subtract the wall-clock
    /// time when recording started. The per-exercise buffer additionally trims
    /// the transition movement between the last rep and the gesture.
    private static func trimAfterGesture(_ frames: [PoseFrame],
                                         gestureFirstSeenAt: Double?,
                                         recordingStartWallTime: Double?,
                                         bufferS: Double) -> [PoseFrame] {
        guard let firstSeen = gestureFirstSeenAt,
              let recordingStart = recordingStartWallTime else { return frames }
        let cutPTS = (firstSeen - recordingStart) - bufferS
        guard cutPTS > 0 else { return frames }
        return frames.filter { $0.timeSeconds <= cutPTS }
    }

    private func stopAndAnalyze(gestureFirstSeenAt: Double?) async {
        phase = .analyzing
        do {
            let url = try await recorder.stopRecording()
            recorder.stopSession()          // green dot gone; file is safely on disk
            let allFrames = try await PoseAnalyzer.analyze(videoURL: url)
            let frames = Self.trimAfterGesture(allFrames,
                                               gestureFirstSeenAt: gestureFirstSeenAt,
                                               recordingStartWallTime: recorder.recordingStartWallTime,
                                               bufferS: selectedExercise.gestureBufferS)
            let analysis = RepDetector.process(frames: frames, exercise: selectedExercise)
            let result = SetResult(videoURL: url,
                                   reps: analysis.reps,
                                   durationS: analysis.durationS,
                                   detectedSide: analysis.detectedSide,
                                   cameraNote: analysis.cameraNote,
                                   exercise: selectedExercise)
            await MainActor.run {
                history.append(result)      // persist before showing results
                phase = .results(result)
            }
        } catch {
            print("‼️ RepsPT analysis error: \(error)")
            await MainActor.run {
                analysisError = error.localizedDescription
                phase = .idle
            }
        }
    }
}

// =====================================================================
// Analyzing screen (post-stop, while pose runs)
// =====================================================================
struct AnalyzingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Analyzing your set...")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text("Running pose detection and grading each rep.")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }
        }
    }
}

