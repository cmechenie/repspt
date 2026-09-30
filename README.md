# RepsPT

An iOS app that watches your gym set through the phone camera, counts reps, and grades your form, all on-device.

Record a set, and RepsPT uses Apple's Vision body-pose detection to find each rep and flag common form issues like shallow depth, forward lean, a rushed descent, or the weight drifting low. You get a per-rep scorecard with coaching cues and a shareable summary image.

## Features

- **Rep detection and form grading** for 30 exercises across legs, chest, back, shoulders, arms, and core (3 more are marked "coming soon")
- **Hands-free end of set:** give a thumbs up, or nod twice when both hands are busy (push-ups, pull-ups, heavy goblet squats), and recording stops by itself
- **Per-rep scorecard** covering depth or range of motion, torso lean, and eccentric/concentric tempo, plus coaching cues for the issues it found
- **Framing feedback** when the camera can't see enough of your body
- **Set history** and a shareable scorecard image
- **Private by default:** video is analyzed and stored on the phone and never uploaded

## Requirements

- iOS 17.0 or later
- Xcode 16 or later
- An iPhone for real use. The simulator has no camera, so recording won't work there.

## Building

1. Open `ios/Reps.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, choose your own development team. You may also need to change the bundle identifier.
3. Select your iPhone as the run destination and press Run.

The Xcode project can also be regenerated from `ios/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

`ios/Reps/RepsPT.storekit` is a local StoreKit configuration for testing the Pro subscription in Xcode without App Store Connect.

## Project layout

```
ios/                  iOS app (SwiftUI)
  Reps/
    CameraRecorder    capture session, recording, live frames for gestures
    GestureDetector   thumbs-up / head-nod end-of-set detection
    PoseAnalyzer      runs Vision body pose on the recorded video
    Metrics           rep detection and per-rep grading (RepDetector)
    Exercise*         exercise model and the exercise catalog
    *View             SwiftUI screens
prototype/            desktop tools used to develop the algorithm
  Sources/posetool    macOS CLI: video -> annotated MP4 + joints CSV
  analyzer/           Python: joints CSV -> reps, form scores, charts
```

## Prototype tools

These run on a Mac and are handy for tuning the detection algorithm against recorded videos.

```bash
cd prototype
swift run posetool input.mov out/session1
```

This writes `out/session1_annotated.mp4` and `out/session1_joints.csv`.

```bash
cd prototype/analyzer
uv run analyze.py ../out/session1_joints.csv ../out/session1 --video input.mov
```

The analyzer needs Python 3.12+ and [uv](https://github.com/astral-sh/uv).

## License

[MIT](LICENSE)
