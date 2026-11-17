# Revised product flow: free text and on-device matching

**Current result:** [MATCHING_RESULTS.md](MATCHING_RESULTS.md) supersedes the
execution status, model choice, counts and verification claims below. A real
LEALLA-based model is now bundled for suggestions only; its automatic accuracy
gate failed. The following notes retain the earlier implementation history.

## Latest follow-up on 9 November 2026

The editor now retains the highest-scoring candidate separately from a qualifying
match. Private result cards show the exact deed title and its cosine similarity.
A score below 0.80 is labelled **Closest suggestion** and awards zero automatic
points; qualifying scores are labelled **Matched activity**. Saving without a
check or a failed/unavailable engine does not invent a candidate. Short input
such as `namaz` can now reach the matcher instead of failing the old eight-character
form minimum. A similarity score is not a probability of correctness.

Training now uses 1074 train-only pairs: positive descriptions, cross-language
alignment, competing deed negatives and review-only negatives. Known equivalents
08/50 and 22/48 are excluded from competing-deed negatives. The best epoch is
selected using validation only; test inputs are evaluated after that selection.
`baseline-validation.json` and `validation-checkpoints.json` record the comparison.
The extra 50 Banglish positives and 12 Banglish review cases in
`tools/data/banglish_test.json` are held out from training and runtime references.
The current split sizes are 312 train, 62 validation and 124 test examples. Training
also includes 150 source-label contrasts for non-completion, future intention and
questions, covering all 50 deeds.
These remain authored synthetic examples, not independent production evidence.

Five matching workflow tests and five Python data/metric tests pass. The Flutter
web build succeeds. The complete Flutter suite also exposed three existing
tour/navigation/sharing test failures; they are outside the matching change.
Static analysis reports only the two existing `share_web.dart` informational
notices. Actual Android tokenizer source matches the reference tokenizer on 409
inputs on JVM, including all dataset text, Bengali/Banglish, special tokens and
length limits. This corrected special-token handling in the Android tokenizer.
JVM parity does not establish device inference accuracy or latency.

Android Kotlin compilation succeeds with this process-local workaround for
the Java NIO temporary socket failure in this execution environment:

```powershell
$env:JAVA_TOOL_OPTIONS = (($env:JAVA_TOOL_OPTIONS, '-Djdk.net.unixdomain.tmpdir=C:/Windows/Temp') -join ' ').Trim()
flutter build apk --debug --no-pub
```

The property is documented in the [Java networking properties](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/net/doc-files/net-properties.html).
It is a build-environment setting, not an app runtime requirement. No global Java
configuration was changed. `tools/check_android_tokenizer.py` can rerun the native
source comparison using an installed JDK and the cached Kotlin compiler.

The older execution-blocker notes below describe earlier attempts. The current
rerun has downloaded and hash-verified the base encoder at upstream revision
`bfe45d0732ca50787611c0fe107ba278c7f3f889`, installed a compatible pinned training
stack, and started real fine-tuning. The pipeline status and evaluation reports
under `.model-cache/deed-matcher/` record the actual training/export outcome.

## 9 November 2026: supplied 50-deed catalog

The initial matching rules now use all 50 entries, in document order, from
`50 Good Deeds Directed in the Holy Quran.doc`. Stable IDs are `quran-01` through
`quran-50`. Titles, descriptions and verse references are transcribed from that
user-supplied compilation; references have not been independently verified.
The old seven UI activity templates remain presentation categories, while the
50 rules are the matching targets. Existing category participation points are
retained; the document assigns no numerical points to deeds.

`tools/data/deed_catalog.json` is the source of truth. Run
`py -3.12 tools/build_deed_catalog.py` after editing it to regenerate
`lib/src/deed_catalog.g.dart` and the ML seed splits. `--check` verifies them
without overwriting anything. Admin-approved criteria can still be added by the
existing review workflow; they do not change the original 50 IDs.

Each deed has one authored English, Bengali and Banglish training example.
Runtime matching compares the input with each rule's title and three examples,
and selects the single highest cosine score. The provisional cutoff is now
**0.80** (inclusive). Lower scores offer **Request a review** and award zero
automatic points. Sending the request still requires explicit consent; merely
seeing a low score does not share the entry. A score is not a correctness
probability. Exact ties use the first rule in catalog order.

### Training and evaluation

`tools/run_matching_pipeline.py --install` orchestrates data checks, dependency
installation, training, export, quantized evaluation and Android asset copying.
Run it with the model virtual environment's Python. It stops at the first failed
step and records `.model-cache/deed-matcher/pipeline-status.json`. It does not
report unexecuted training as successful. `--checks-only` runs the offline data
checks. Android inference assets are installed only if the quantized model at
the app's 0.80 cutoff reaches at least 0.95 accepted-match precision, 0.50 positive
recall and zero accepted review cases in each authored held-out split. This is a
small synthetic-data pilot gate, not production validation. These fixed gates
must not be weakened simply to make a run pass. Device tests and independent
human-reviewed evaluation remain necessary after a bundle is prepared.

The source document is a label catalog, not a real labelled training corpus.
The generated examples are **synthetic, unreviewed seed data**:

- Train: 150 positive descriptions plus 162 explicit review cases.
- Validation: 50 positive descriptions plus 12 review cases.
- Test: 100 positive descriptions plus 24 review cases.

Splits contain distinct text. Only training examples are bundled as references.
Review cases include negation, future intention, questions, third-party actions,
wrongdoing and unrelated text. Validation positives are English and test
positives are Bengali and Banglish; independent balanced multilingual
evaluation data is still needed. Do not infer production accuracy from these
small authored splits. The overlap between deeds 08/50 and 22/48 is explicitly
allowed in evaluation; the app still selects one rule.

With Python 3.12 and network access available:

```powershell
py -3.12 -m venv .model-venv
.model-venv/Scripts/python -m pip install -r tools/model-requirements.txt
.model-venv/Scripts/python tools/train_deed_matcher.py --validate-only
.model-venv/Scripts/python tools/train_deed_matcher.py
.model-venv/Scripts/python tools/prepare_offline_model.py --model .model-cache/deed-matcher/model
flutter build apk --debug
```

The training script fine-tunes using explicit positive cosine pairs and hard
negatives mined only from training review cases. It writes a saved sentence
encoder and `evaluation.json` under `.model-cache/deed-matcher/`. Reports include
baseline validation, post-training validation/test scores, per-language metrics,
wrong-deed acceptances, false acceptances of review cases, input hashes, and a
diagnostic cutoff selected using validation only. It never overwrites the app's
cutoff or claims production readiness. `--baseline-only` evaluates without
training. Compare a trained model to that baseline before choosing it.

**Training was attempted but could not start in this session:** dependency
installation failed with DNS resolution errors (`getaddrinfo failed`) reaching
the Python package index. No new model weights, embedding accuracy measurements
or Android inference results are claimed. Dataset validation and app-flow tests
are separate from model evaluation. Replacing the catalog does not make matching
operational until a real model bundle is prepared and tested.

Verification for this update: the catalog generation consistency check, dataset
validation, three Python dataset/metric tests and Python syntax compilation
passed. Flutter test execution was blocked because the installed SDK's cache
lockfile is outside writable directories. Direct Dart analysis found no code
errors; existing `share_web.dart` deprecation/platform-lint notices remain, and
the analyzer's telemetry write was blocked by filesystem permissions. The new
Flutter tests have been added but are not claimed as executed successfully.

Retry on 9 November: a writable local Flutter SDK cache was assembled from the
installed SDK under `.build-tmp/flutter-sdk`, including existing fonts, engine
and Gradle wrapper assets. This resolved the SDK lockfile problem without
changing the installed SDK. The test sources compiled and the Flutter tester
started, but both suites failed to load because this execution environment
blocked its connection to `127.0.0.1` (socket error 10057). No Flutter tests are
claimed as passing. Offline package caches and installed Python environments
also lacked PyTorch/Sentence Transformers, so they could not replace the
DNS-blocked dependency download. The three Python tests and data checks still
pass. These remaining blockers require execution-environment access changes,
not a change to the app's matching rules.

The earlier implementation notes below remain useful background; their 0.82
cutoff and one sample rule have been superseded by this update.

26 October 2026. This replaces the earlier template-first logging and fixed-template point assumption in the original UI plan.

## User journey

1. Open Add deed and write one completed action in ordinary language.
2. Choose the day. Do not require choosing a fixed activity or religious reference.
3. Save and run an offline check on Android, or save without a check.
4. A qualifying model match makes the entry eligible for fixed points, subject to the daily cap. A similarity value is not a probability, proof of action, or moral verdict.
5. A non-match, unavailable model, or unchecked entry stays private with zero points.
6. User may explicitly share that entry and an explanation with the admin review team.
7. Acceptance adds a reusable criterion and makes that version of the entry eligible for points. Rejection leaves it at zero. Duplicate requests/decisions must not award twice.
8. Editing the text starts a new check and invalidates pending requests for older versions.

Ordinary user screens use neutral wording such as activity review, accepted activity, and participation points. Internal source text and religious provenance are not rendered in those screens. This is a presentation choice, not an encryption boundary: anything bundled on a phone can be inspected by a determined device owner.

## Selected deployment

The user explicitly selected **Android on-device inference**, rather than a self-hosted inference server. No OpenAI, Groq, or other hosted inference service is used. Matching performs no network request.

Admin submission and decision synchronization are separate from inference. A real remote admin requires connectivity. This prototype's requests, decisions, rules, and point updates are in-memory session data, not remotely submitted or durable offline queues.

## What is implemented

- Free-text entry is the main Add deed flow, including completion from a plan/challenge.
- Matched, unmatched, unavailable, unchecked, pending, accepted, and rejected UI states.
- Explicit review consent, user request history, admin queue, accept/decline, rule creation, and capped point recalculation.
- An Android MethodChannel adapter using ONNX Runtime, running inference on a worker thread with no network fallback.
- Cased WordPiece tokenization and a model-preparation script exporting the complete sentence encoder.
- Threshold and response handling tested with platform fixtures, not represented as real model accuracy tests.

## Model candidate and preparation

Candidate: [sentence-transformers/distiluse-base-multilingual-cased-v2](https://huggingface.co/sentence-transformers/distiluse-base-multilingual-cased-v2).

The official architecture is a DistilBERT encoder, mean pooling, and a dense/tanh layer producing 512-dimensional sentence embeddings. The Android tokenizer is specific to this cased WordPiece model. Substituting E5 or multilingual MiniLM with a different tokenizer requires a different tokenizer implementation.

Set up a compatible Python environment (Python 3.11 or 3.12 recommended for the development tools):

```powershell
python -m venv .model-venv
.model-venv/Scripts/python -m pip install -r tools/model-requirements.txt
.model-venv/Scripts/python tools/prepare_offline_model.py
flutter build apk --debug
```

Setup downloads open weights once on the developer machine. It does not send deed text to an inference API. The script generates model/vocabulary assets under `android/app/src/main/assets/offline_model`. A configured build bundles them; therefore no first-launch model download is required. Measure the resulting APK/model size before choosing bundling versus a later checksum-verified asset download flow.

The script includes full-encoder export, MatMul quantization, local ONNX-to-PyTorch embedding parity checks, tokenizer token-ID fixtures, and a file/hash manifest. Device tokenizer parity must still be checked against those fixtures. Include the upstream Apache-2.0 license and notices when distributing model assets.

Reference runtime documentation: [ONNX Runtime for Android](https://onnxruntime.ai/docs/tutorials/mobile/deploy-android.html), [Java inference API](https://onnxruntime.ai/docs/get-started/with-java.html).

## Current verification limits

**Weights have not been downloaded/exported/bundled. Actual Android inference and device latency/memory have not been verified.** The app truthfully shows model-unavailable and awards no automatic points in that state. The browser preview cannot execute the Android MethodChannel.

The previous Android packaging attempt failed with `java.io.IOException: Unable to establish loopback connection` in Gradle. That environment issue remains unresolved. The Kotlin integration is source-level work and is not claimed as a tested APK.

The initial 0.82 cosine cutoff is an illustrative pilot setting, not a validated confidence percentage. Before enabling real automatic rewards:

- Evaluate completed actions versus negations, intentions, hypotheticals, copied reference text, vague claims, unrelated statements, and mixed actions.
- Use held-out positive/negative examples in English, Bengali, and Banglish. Do not assume Banglish quality from multilingual labeling.
- Tune cutoff and ambiguity handling from false-positive/false-negative measurements. Embedding similarity alone can confuse contradiction and implication.
- Compare performance before and after quantization and test low-end Android devices.
- Replace sample criteria with reviewed source-backed rules and neutral behavioral paraphrases linked by stable IDs/versions.
- Persist entries and queued requests; authenticate admin decisions; distribute approved versioned rules. Do not use a client-side demo role toggle as authorization.
- Group competition needs protection against client-tampered point claims and a defined reconciliation rule for offline entries.

## Relevant code

- `lib/src/matching.dart`: entry, result, request/admin UI, platform adapter.
- `lib/src/data.dart`: review eligibility, request deduplication/versioning, point updates.
- `android/app/src/main/kotlin/com/example/deedwise/OfflineMatcher.kt`: tokenization and local embeddings.
- `android/app/src/main/kotlin/com/example/deedwise/MainActivity.kt`: native channel and inference worker.
- `tools/prepare_offline_model.py`: developer-side export and parity checks.

No keyword matcher or fabricated similarity percentage is used as a substitute for the local model.

## Checks completed for this UI revision

- Fourteen passing tests cover approval/rejection, no-match point eligibility, duplicate decisions, consent, edit invalidation, platform response fixtures, private group sharing, navigation, and existing planner/journal behavior.
- Sixteen screen layouts checked at both 360px and 390px widths, with generated previews in `preview/`.
- Flutter static analysis: no issues.
- Model export script parsed successfully; its dependency installation, export, quantization, and native inference have not been executed.
