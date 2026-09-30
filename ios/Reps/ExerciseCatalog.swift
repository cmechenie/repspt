import Foundation

// =====================================================================
// Exercise library
// To add an exercise: add a static let, append to `all`.
// =====================================================================
extension Exercise {

    // MARK: - Legs --------------------------------------------------------

    // headNod: both hands cradle a single DB; heavy loads make one-handing unsafe.
    static let gobletSquat = Exercise(
        id: "goblet_squat", name: "Goblet Squat",
        category: .legs, sfSymbol: "figure.strengthtraining.traditional",
        description: "Dumbbell held at chest",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 1.2, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.25,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 50, bendOverLeanDeg: 60, bendOverTravelMax: 0.20,
        checksArms: true, armsLowRatio: 0.55,
        gestureKind: .headNod, gestureBufferS: 0.5,
        gestureHint: "Nod twice when done"
    )

    static let backSquat = Exercise(
        id: "back_squat", name: "Back Squat",
        category: .legs, sfSymbol: "figure.strengthtraining.traditional",
        description: "Barbell on upper back",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 1.2, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.25,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 55, bendOverLeanDeg: 60, bendOverTravelMax: 0.20,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Release one hand, thumbs up when done"
    )

    static let frontSquat = Exercise(
        id: "front_squat", name: "Front Squat",
        category: .legs, sfSymbol: "figure.strengthtraining.traditional",
        description: "Bar in front rack position",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 1.2, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.25,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 40, bendOverLeanDeg: 60, bendOverTravelMax: 0.20,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Release one hand, thumbs up when done"
    )

    static let sumoSquat = Exercise(
        id: "sumo_squat", name: "Sumo Squat",
        category: .legs, sfSymbol: "figure.strengthtraining.traditional",
        description: "Wide stance, toes flared out",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 1.2, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.25,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 50, bendOverLeanDeg: 60, bendOverTravelMax: 0.20,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let bulgarianSplitSquat = Exercise(
        id: "bulgarian_split_squat", name: "Bulgarian Split Squat",
        category: .legs, sfSymbol: "figure.strengthtraining.traditional",
        description: "Rear foot elevated on bench",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 1.2, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 45, bendOverLeanDeg: 55, bendOverTravelMax: 0.20,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.5,
        gestureHint: "👍 Thumbs up before stepping off"
    )

    static let forwardLunge = Exercise(
        id: "forward_lunge", name: "Forward Lunge",
        category: .legs, sfSymbol: "figure.walk",
        description: "Step forward, lower back knee",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 45, bendOverLeanDeg: 65, bendOverTravelMax: 0.25,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let reverseLunge = Exercise(
        id: "reverse_lunge", name: "Reverse Lunge",
        category: .legs, sfSymbol: "figure.walk",
        description: "Step back, lower front knee",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 45, bendOverLeanDeg: 65, bendOverTravelMax: 0.25,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // Coming soon — hip hinge / glute exercises need additional algorithm work
    static let romanianDeadlift = Exercise(
        id: "romanian_deadlift", name: "Romanian Deadlift",
        category: .legs, sfSymbol: "figure.strengthtraining.functional",
        description: "Hip hinge, flat back, soft knees",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: false, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.5, tempoValidMin: 0.4, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 0, depthParallelPx: -50,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let hipThrust = Exercise(
        id: "hip_thrust", name: "Hip Thrust",
        category: .legs, sfSymbol: "figure.strengthtraining.functional",
        description: "Glute bridge on bench",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: false, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.3, tempoValidMax: 3.0,
        minDropFracOfTorso: 0.12,
        depthGoodPx: 0, depthParallelPx: -30,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // MARK: - Chest -------------------------------------------------------

    static let inclineDBPress = Exercise(
        id: "incline_db_press", name: "Incline DB Press",
        category: .chest, sfSymbol: "dumbbell.fill",
        description: "Bench at 30–45°, press to lockout",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 50, depthParallelPx: 25,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up before lowering the weights"
    )

    static let flatDBPress = Exercise(
        id: "flat_db_press", name: "Flat DB Press",
        category: .chest, sfSymbol: "dumbbell.fill",
        description: "Flat bench, full range of motion",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 55, depthParallelPx: 28,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up before lowering the weights"
    )

    static let declineDBPress = Exercise(
        id: "decline_db_press", name: "Decline DB Press",
        category: .chest, sfSymbol: "dumbbell.fill",
        description: "Decline bench, lower chest focus",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 45, depthParallelPx: 22,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up before lowering the weights"
    )

    // headNod: both hands planted — can't lift one during a set without collapsing.
    static let pushUp = Exercise(
        id: "push_up", name: "Push-up",
        category: .chest, sfSymbol: "figure.strengthtraining.traditional",
        description: "Bodyweight chest press",
        cameraHint: "Side view · ~3 ft height · 6–8 ft away",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.25, dropFractionMin: 0.30,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.10,
        depthGoodPx: -50, depthParallelPx: -150,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .headNod, gestureBufferS: 0.5,
        gestureHint: "Nod twice at the top when done"
    )

    // MARK: - Back --------------------------------------------------------

    // headNod: both hands gripping the bar — releasing one while exhausted is risky.
    static let pullUp = Exercise(
        id: "pull_up", name: "Pull-up / Chin-up",
        category: .back, sfSymbol: "figure.strengthtraining.functional",
        description: "Bodyweight vertical pull",
        cameraHint: "Side view · full body visible · ~10 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.30,
        tempoRushS: 0.8, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.35,
        depthGoodPx: -200, depthParallelPx: -400,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .headNod, gestureBufferS: 0.5,
        gestureHint: "Nod twice while still hanging"
    )

    static let latPulldown = Exercise(
        id: "lat_pulldown", name: "Lat Pulldown",
        category: .back, sfSymbol: "figure.strengthtraining.functional",
        description: "Cable bar from overhead to chest",
        cameraHint: "Side view · seat height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.7, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.12,
        depthGoodPx: 65, depthParallelPx: 35,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Release bar, thumbs up when done"
    )

    static let bentOverRow = Exercise(
        id: "bent_over_row", name: "Bent-over Row",
        category: .back, sfSymbol: "figure.strengthtraining.functional",
        description: "Barbell or dumbbell, hinged torso",
        cameraHint: "Side view · hip height · ~8 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.6, tempoValidMin: 0.3, tempoValidMax: 6.0,
        minDropFracOfTorso: 0.12,
        depthGoodPx: 40, depthParallelPx: 20,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.0,
        gestureHint: "👍 Thumbs up before standing"
    )

    static let singleArmDBRow = Exercise(
        id: "single_arm_db_row", name: "Single-arm DB Row",
        category: .back, sfSymbol: "figure.strengthtraining.functional",
        description: "One hand on bench, dumbbell",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.6, tempoValidMin: 0.3, tempoValidMax: 6.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 55, depthParallelPx: 28,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.0,
        gestureHint: "👍 Thumbs up before stepping off"
    )

    // MARK: - Shoulders ---------------------------------------------------

    static let overheadPress = Exercise(
        id: "overhead_press", name: "Overhead Press",
        category: .shoulders, sfSymbol: "figure.arms.open",
        description: "Standing barbell or dumbbell press",
        cameraHint: "Side view · full body visible · ~8 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.6, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 70, depthParallelPx: 40,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.0,
        gestureHint: "👍 Thumbs up when done"
    )

    static let seatedDBPress = Exercise(
        id: "seated_db_press", name: "Seated DB Press",
        category: .shoulders, sfSymbol: "figure.arms.open",
        description: "Seated dumbbell shoulder press",
        cameraHint: "Side view · shoulder height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.6, tempoValidMin: 0.3, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.18,
        depthGoodPx: 65, depthParallelPx: 35,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let lateralRaise = Exercise(
        id: "lateral_raise", name: "Lateral Raise",
        category: .shoulders, sfSymbol: "figure.arms.open",
        description: "Dumbbell side raises",
        cameraHint: "Front view · full body visible · ~8 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.5, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 80, depthParallelPx: 40,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // MARK: - Arms --------------------------------------------------------

    static let ezBarCurl = Exercise(
        id: "ez_bar_curl", name: "EZ Bar Curl",
        category: .arms, sfSymbol: "dumbbell",
        description: "EZ bar, angled grip",
        cameraHint: "Side view · waist height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 50, depthParallelPx: 25,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let bicepCurl = Exercise(
        id: "bicep_curl", name: "Bicep Curl",
        category: .arms, sfSymbol: "dumbbell",
        description: "Straight bar or dumbbell curl",
        cameraHint: "Side view · waist height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 50, depthParallelPx: 25,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let hammerCurl = Exercise(
        id: "hammer_curl", name: "Hammer Curl",
        category: .arms, sfSymbol: "dumbbell",
        description: "Neutral grip, dumbbell",
        cameraHint: "Side view · waist height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 50, depthParallelPx: 25,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let concentrationCurl = Exercise(
        id: "concentration_curl", name: "Concentration Curl",
        category: .arms, sfSymbol: "dumbbell",
        description: "Seated, elbow braced on thigh",
        cameraHint: "Side view · knee height · ~5 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 40, depthParallelPx: 20,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up with free hand when done"
    )

    static let preacherCurl = Exercise(
        id: "preacher_curl", name: "Preacher Curl",
        category: .arms, sfSymbol: "dumbbell",
        description: "Upper arm on pad, barbell or EZ bar",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 35, depthParallelPx: 18,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Release one hand, thumbs up when done"
    )

    static let cablePushdown = Exercise(
        id: "cable_pushdown", name: "Cable Pushdown",
        category: .arms, sfSymbol: "dumbbell",
        description: "Rope or bar, cable machine",
        cameraHint: "Side view · waist height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.20,
        depthGoodPx: 60, depthParallelPx: 30,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // Safety note: must lower bar to chest before signaling — can't release
    // one hand while the bar is directly above the face.
    static let skullCrusher = Exercise(
        id: "skull_crusher", name: "Skull Crusher",
        category: .arms, sfSymbol: "dumbbell",
        description: "Lying, bar toward forehead",
        cameraHint: "Side view · bench height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.5, tempoValidMin: 0.2, tempoValidMax: 6.0,
        minDropFracOfTorso: 0.15,
        depthGoodPx: 45, depthParallelPx: 22,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 2.0,
        gestureHint: "Lower bar to chest first, then 👍"
    )

    static let tricepExtension = Exercise(
        id: "tricep_extension", name: "Overhead Tricep Ext. (DB)",
        category: .arms, sfSymbol: "dumbbell",
        description: "Dumbbell, seated or standing",
        cameraHint: "Side view · full body visible · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.18,
        depthGoodPx: 45, depthParallelPx: 22,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 1.0,
        gestureHint: "👍 Thumbs up when done"
    )

    static let cableOverheadExtension = Exercise(
        id: "cable_overhead_extension", name: "Overhead Tricep Ext. (Cable)",
        category: .arms, sfSymbol: "dumbbell",
        description: "Rope or bar, facing away from stack",
        cameraHint: "Side view · full body visible · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.4, tempoValidMin: 0.2, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.18,
        depthGoodPx: 45, depthParallelPx: 22,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // MARK: - Core --------------------------------------------------------

    // headNod: both hands grip the wheel handles throughout the exercise.
    static let abWheel = Exercise(
        id: "ab_wheel", name: "Ab Wheel Rollout",
        category: .core, sfSymbol: "circle.circle",
        description: "Roll out, maintain plank position",
        cameraHint: "Side view · floor level · ~6 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.25,
        tempoRushS: 0.8, tempoValidMin: 0.5, tempoValidMax: 8.0,
        minDropFracOfTorso: 0.10,
        depthGoodPx: -999, depthParallelPx: -999,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .headNod, gestureBufferS: 1.5,
        gestureHint: "Nod twice when done"
    )

    // headNod: both hands on bar — nod while still hanging.
    static let hangingLegRaise = Exercise(
        id: "hanging_leg_raise", name: "Hanging Leg Raise",
        category: .core, sfSymbol: "circle.circle",
        description: "Hang from bar, raise knees or legs",
        cameraHint: "Side view · full body visible · ~10 ft",
        isAvailable: true, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.25,
        tempoRushS: 0.6, tempoValidMin: 0.3, tempoValidMax: 6.0,
        minDropFracOfTorso: 0.08,
        depthGoodPx: -999, depthParallelPx: -999,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .headNod, gestureBufferS: 0.5,
        gestureHint: "Nod twice while still hanging"
    )

    static let cableCrunch = Exercise(
        id: "cable_crunch", name: "Cable Crunch",
        category: .core, sfSymbol: "circle.circle",
        description: "Kneeling, rope from high cable",
        cameraHint: "Side view · waist height · ~6 ft",
        isAvailable: true, repSignalJoint: .wrist,
        prominenceFraction: 0.25, dropFractionMin: 0.25,
        tempoRushS: 0.5, tempoValidMin: 0.4, tempoValidMax: 5.0,
        minDropFracOfTorso: 0.18,
        depthGoodPx: 80, depthParallelPx: 40,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    static let crunch = Exercise(
        id: "crunch", name: "Crunch / Sit-up",
        category: .core, sfSymbol: "circle.circle",
        description: "Coming soon — needs torso-angle tracking",
        cameraHint: "Side view · floor level · ~6 ft",
        isAvailable: false, repSignalJoint: .hip,
        prominenceFraction: 0.20, dropFractionMin: 0.20,
        tempoRushS: 0.3, tempoValidMin: 0.2, tempoValidMax: 4.0,
        minDropFracOfTorso: 0.0,
        depthGoodPx: 0, depthParallelPx: -20,
        leanBadDeg: 999, bendOverLeanDeg: 999, bendOverTravelMax: 999,
        checksArms: false, armsLowRatio: 999,
        gestureKind: .thumbsUp, gestureBufferS: 0.5,
        gestureHint: "👍 Thumbs up when done"
    )

    // MARK: - Full catalog (order = display order within each category)
    static let all: [Exercise] = [
        // Legs
        gobletSquat, backSquat, frontSquat, sumoSquat, bulgarianSplitSquat,
        forwardLunge, reverseLunge,
        romanianDeadlift, hipThrust,
        // Chest
        inclineDBPress, flatDBPress, declineDBPress, pushUp,
        // Back
        pullUp, latPulldown,
        bentOverRow, singleArmDBRow,
        // Shoulders
        overheadPress, seatedDBPress, lateralRaise,
        // Arms — biceps
        ezBarCurl, bicepCurl, hammerCurl, concentrationCurl, preacherCurl,
        // Arms — triceps
        cablePushdown, skullCrusher, tricepExtension, cableOverheadExtension,
        // Core
        abWheel, hangingLegRaise, cableCrunch, crunch,
    ]
}
