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

The refactor has **not** retrained, recalibrated, or revalidated this classifier. Core Motion delivery timing is requested rather than guaranteed. A gap over 100 ms clears the input window and active detection state. Short gaps and platform filtering can still affect input distributions.

Training scripts, split definitions, original TensorFlow checkpoints, conversion scripts, and held-out metrics were not present in the recovered folder. The original labeled CSV remains private and is not part of this repository. Its first stationary examples appear close to zero acceleration, so verifying whether training removed gravity is a priority before claiming reliable accuracy. The preprocessing convention is preserved rather than silently guessing a new one.

## pose_landmarker_full.task

The task bundle contains `pose_detector.tflite` and `pose_landmarks_detector.tflite`. Their byte-level SHA-256 digests match the models inside [Google's official full-pose task bundle](https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task):

| File | SHA-256 |
|---|---|
| `pose_detector.tflite` | `04f5a96483f8ce5913f8730ad2aa0c4c999c80a4b75653bc0e4712de18e104b2` |
| `pose_landmarks_detector.tflite` | `82be6d591b9dad7d29fe21dc9fd892bf8b9602c458fb05209283de8282a0c488` |

The ZIP container hash differs from the downloaded bundle, but the two contained model files are identical. The bundled pose weights are therefore documented as Google's standard model, rather than a custom-trained sprint-form model. Sprint-specific geometry, visualization, frame selection, and coaching integration are application code.

MediaPipe is pinned to 0.10.18 while this recovered app is stabilized. A dependency upgrade should be tested separately against the same fixtures and real sprint videos. See [Google's pose model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf) and [third-party notices](../../THIRD_PARTY_NOTICES.md).

## Angle definitions

- Hip: shoulder–hip–knee interior angle on the athlete's right side.
- Knee: hip–knee–ankle interior angle on the right side.
- Torso: angle between the shoulder/hip midpoint line and image vertical.

These are image-plane angles, not 3D biomechanical measurements. The renderer rejects low-visibility/presence joints and degenerate geometry. Camera angle, occlusion, image distortion, motion blur, and clothing still affect the result. A single angle is not intrinsically good or bad; stride phase and context matter.

## Evaluation work still needed

1. Recover the training pipeline and confirm units, gravity removal, placement, and orientation.
2. Separate training and evaluation by athlete/session, not overlapping windows.
3. Compare event boundaries against an independent high-frame-rate video or timing reference.
4. Report detection precision/recall and timing error across distances, devices, and phone placements.
5. Evaluate pose/angle accuracy under controlled camera placement and visible ground-contact events.
6. Version the model, preprocessing, dataset description, and metrics together.
