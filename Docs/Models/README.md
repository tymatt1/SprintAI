# Models and measurement limitations

## SprintDetectionModel.mlpackage

This is the project's custom exported sprint classifier. Its embedded conversion metadata identifies TensorFlow 2.13.0 and Core ML Tools; the graph contains LSTM operations.

- Input name: `lstm_input`; shape `[1, 50, 6]`.
- Feature order: acceleration X/Y/Z, angular velocity X/Y/Z.
- Requested sample frequency: 50 Hz; one input window spans approximately one second.
- Acceleration is gravity-inclusive in g; rotation is in radians per second, matching the prior app convention.
- Normalization constants are retained in `MotionClassifier`.
- Output: first value of `Identity`; positive threshold `> 0.9`.
- The previous mean acceleration-magnitude gate `> 2` is retained.
- Confirmation: five positive decisions to start, three negatives to finish.

The refactor has **not** retrained, recalibrated, or revalidated this classifier. Core Motion delivery timing is requested rather than guaranteed. Timestamp-based linear interpolation places samples on a 50 Hz grid. A gap over 100 ms or invalid feature values clears the input window and active detection state; interpolation never bridges that gap. This preprocessing change needs athlete/device evaluation against the original training distribution.

Confirmation still requires five positive / three negative decisions. The app now retains the continuous model score and mean acceleration, and linearly interpolates each threshold crossing between adjacent decisions. Starting requires both gates, so the later crossing wins; stopping requires either gate, so the earlier crossing wins. The confirmed event uses that first crossing rather than the later confirmation time. Without a preceding valid decision, or across a gap over 100 ms, it uses the current decision timestamp. This refines the position within a normal 20 ms interval; it does **not** establish millisecond physical accuracy or compensate for the approximately one-second model window. Scores are used as model outputs, not claimed to be calibrated probabilities.

The display can continue briefly while a stop is confirmed, then settle back to the saved sensor-time duration. Queued display ticks are guarded by recording session and sprint boundary so they cannot overwrite a finished result or another sprint. Reusing the model input buffer reduces per-inference allocation without changing its features or normalization. Invalid model outputs stop monitoring instead of being treated as a physical stop.

Actual timing improvements require a reference: record start/stop motion alongside high-frame-rate video or an independent timing system, use a fixed phone placement, and compare signed start error, signed stop error, and total-duration error across held-out runs. Do not subtract the observed 0.1-second visual correction as a fixed calibration; it includes confirmation and scheduling delay, which vary. GPS speed or a stationary-motion heuristic alone cannot establish a finish-line crossing when an athlete runs through the line. Apple documents [boot-relative motion timestamps](https://developer.apple.com/documentation/coremotion/cmlogitem/timestamp) and recommends checking [delivered timestamps rather than assuming the requested sample interval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval).

Training scripts, split definitions, original TensorFlow checkpoints, conversion scripts, and held-out metrics were not present in the recovered folder. The original labeled CSV remains private and is not part of this repository. Its first stationary examples appear close to zero acceleration, so verifying whether training removed gravity is a priority before claiming reliable accuracy. The preprocessing convention is preserved rather than silently guessing a new one.

## pose_landmarker_full.task

The task bundle contains `pose_detector.tflite` and `pose_landmarks_detector.tflite`. Their byte-level SHA-256 digests match the models inside [Google's official full-pose task bundle](https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task):

| File | SHA-256 |
|---|---|
| `pose_detector.tflite` | `04f5a96483f8ce5913f8730ad2aa0c4c999c80a4b75653bc0e4712de18e104b2` |
| `pose_landmarks_detector.tflite` | `82be6d591b9dad7d29fe21dc9fd892bf8b9602c458fb05209283de8282a0c488` |

The ZIP container hash differs from the downloaded bundle, but the two contained model files are identical. The bundled pose weights are therefore documented as Google's standard model, rather than a custom-trained sprint-form model. Sprint-specific geometry, visualization, frame selection, and coaching integration are application code.

The official pose guide still lists the same version-1 full-pose weights used by this app (checked October 28, 2026). Replacing those identical weights would not modernize pose estimation. The iOS SDK is now pinned to MediaPipeTasksVision 1.0.0, the latest version listed in the CocoaPods registry at this check. It replaces 0.10.18 and passes the hosted inference, annotation, export, and cancellation fixtures on iOS 27. Model weights and SDK versions are tracked separately; this upgrade does not claim measured pose-accuracy gains. See the [official 1.0.0 release](https://github.com/google-ai-edge/mediapipe/releases/tag/v1.0.0). See [Google's pose model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf) and [third-party notices](../../THIRD_PARTY_NOTICES.md).

## Angle definitions

- Hip: shoulder–hip–knee interior angle on the camera-facing side selected before import.
- Knee: hip–knee–ankle interior angle on the same selected side.
- Torso: angle between the selected shoulder–hip line and image vertical. This no longer requires the far-side shoulder and hip to be visible.

These are image-plane angles, not 3D biomechanical measurements. The renderer rejects out-of-frame and low-visibility/presence joints and degenerate geometry. Camera angle, occlusion, image distortion, motion blur, and clothing still affect the result. A single angle is not intrinsically good or bad; stride phase and context matter.

## Evaluation work still needed

1. Recover the training pipeline and confirm units, gravity removal, placement, and orientation.
2. Separate training and evaluation by athlete/session, not overlapping windows.
3. Compare event boundaries against an independent high-frame-rate video or timing reference.
4. Report detection precision/recall and timing error across distances, devices, and phone placements.
5. Evaluate pose/angle accuracy under controlled camera placement and visible ground-contact events.
6. Version the model, preprocessing, dataset description, and metrics together.
