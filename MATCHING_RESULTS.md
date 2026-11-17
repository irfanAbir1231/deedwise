# Deed matching results

9 November 2026. The Android app now bundles a real on-device model and returns
the nearest candidate from the exact 50 supplied deeds. Automatic matching is
disabled in this bundle because the evaluated model did not meet its acceptance
gate. Results are suggestions requiring review for points. No claim of perfect
matching or production readiness is made.

## Current behavior

- Enter a completed deed in English, Bengali or Banglish. Short descriptions
  such as `namaz` can reach the matcher.
- Compare with the supplied 50 targets, choosing the single highest cosine
  score. Exact ties retain document order. Manual review criteria do not expand
  this automatic classification set.
- Retain the nearest rule ID separately from a confirmed match and show its
  title and score privately. Source verse citations remain internal.
- A validated bundle would also require a score of at least 0.80 for automatic
  matching. The current bundle explicitly sets `automatic_matching_enabled`
  to `false`, so even a higher score remains a suggestion with zero automatic
  points. A score of 0.80 is not an 80% probability of correctness.
- Private saving and the existing consent-based admin review remain available.
  Long inputs exceeding 128 tokens and unavailable inference are reported
  explicitly rather than receiving fabricated scores.

## Model and data

The UI library and matching targets now share all 50 catalog IDs, titles and
descriptions. Demo history uses deeds 11, 14, 16, 19, 21, 27, 42 and 45; plans use
02, 11 and 14; the daily challenge uses 13, the personal goal uses 21 and the
sample group challenge/event uses 14. Tour examples use 18. Demo records are
approved sample history with no fabricated model score. Donation, meal and
volunteering totals use quantity units instead of the retired generic IDs.

The deployed candidate is [LEALLA-small](https://huggingface.co/setu4993/LEALLA-small),
revision `8fadf81fe3979f373ba9922ab616468a4184b266`. Its documented BERT pooler output
is preserved. A 128-dimensional, identity-initialized projection adapter was
trained for three epochs at learning rate 0.0001 while the multilingual encoder
and its dropout were frozen. The checkpoint was selected using multilingual
validation only.

Common Banglish words and spelling variants are normalized using a shared
583-word glossary. It preserves unknown words, English sentences, Bengali text,
negation and future markers. The glossary translates words; it does not select
deed IDs or invent similarity scores. Python and Android use the same asset.

The source catalog contains exactly `quran-01` through `quran-50`. All 50 titles
were checked against the supplied Word document in document order. The document
provides labels and references, not a labelled corpus of real app entries;
religious citations have not been independently verified.

| Split | Positive descriptions | Review-only descriptions | Total |
| --- | ---: | ---: | ---: |
| Train | 150 | 162 | 312 |
| Validation | 100 | 12 | 112 |
| Development test | 100 | 24 | 124 |

Training uses 1,074 pairs, including multilingual positive pairs and distinct
competing-deed negatives. Non-completion, questions and future intentions are
review cases. Known source overlaps 08/50 and 22/48 are allowed in evaluation.
Only the 200 title/training reference phrases enter the runtime reference cache;
validation, test and review-only phrases are excluded.

## Measured results

Top-1 accuracy below means the nearest candidate agreed with an authored target
ID among positive descriptions, regardless of whether it crossed 0.80.

| Candidate | Validation top-1 | Development test top-1 |
| --- | ---: | ---: |
| Trained adapter before mobile quantization | 71% | 56% |
| Bundled mobile model | 68% | 58% |

| Language | Mobile validation top-1 | Mobile development test top-1 |
| --- | ---: | ---: |
| English | 52% (50 positive inputs) | No positive English inputs |
| Bengali | 88% (25 positive inputs) | 47.9% (48 positive inputs) |
| Banglish | 80% (25 positive inputs) | 67.3% (52 positive inputs) |

At the 0.80 cutoff the mobile model accepted only four validation positives and
no test positives; one test review case was incorrectly accepted. Consequently
the fixed automatic gate failed. The gate requires at least 0.95 precision,
0.50 positive recall and zero accepted review cases, with language-specific
precision/recall checks. It was not weakened to make deployment pass.

These are small authored development diagnostics. Several models and preprocessing
choices were investigated during this session; these figures are not an unbiased
production test. Real human-labelled descriptions, ambiguous/multiple-action
examples and independent multilingual evaluation are still needed. The original
DistilUSE candidate and full-encoder fine-tuning performed poorly and are not
included in the APK.

## Android preparation and verification

- The deployed ONNX model is 70,419,360 bytes, using per-channel unsigned 8-bit
  quantization for MatMul and Gather. Numerical parity stayed above the unchanged
  0.98 minimum on the export fixtures.
- Two hundred reference vectors are precomputed to avoid two hundred first-use
  inferences. Their model and normalizer hashes must match the bundle.
- Actual Android normalization and WordPiece source matches Python on 612 unique
  corpus/edge-case inputs on JVM, including Unicode, special tokens and limits.
- Seven Flutter catalog/matching/layout tests and seven Python data/deployment checks pass.
  The full Flutter suite has 20 passes and three existing tour/navigation/sharing
  test failures. Static analysis has only the two existing web-library notices.
- Five common deed smoke examples return their expected candidate. All 391
  shared encoder tensors remained unchanged, while the adapter weights changed.
  These are functional checks, not independent accuracy evidence.
- Android APK and Flutter web compilation succeed. Web remains a preview and
  truthfully reports Android inference as unavailable.
- The ARM64 debug APK is `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
  (150,810,651 bytes). Its model/glossary/reference hashes, 50 target IDs, 200
  reference vectors, ARM64 ONNX libraries and disabled automatic flag are checked
  inside the built archive. Packaging status is recorded separately in
  `.model-cache/lealla-normalized-matcher/deployment-status.json`.
- Physical Android inference, cold-start time, latency and memory have not been
  measured. JVM tokenizer parity and desktop ONNX evaluation do not establish
  device inference correctness.

The app remains a session-based prototype: entries and reviews are in memory,
and the admin role is a demo toggle. Backend authorization, persistence and
authoritative scoring are separate remaining work. No deed text is sent to an
external inference API.

## Reproduce the current preparation

Use the dedicated Python 3.12 environment and the compatible package versions in
`tools/model-requirements.txt`. Current verified source weights are retained in
`.model-cache/lealla-base/` with their upstream download manifest.

```powershell
.model-venv/Scripts/python tools/download_lealla.py
.model-venv/Scripts/python tools/prepare_lealla.py --source .model-cache/lealla-base --output .model-cache/lealla-normalized-encoder
.model-venv/Scripts/python tools/run_matching_pipeline.py --model .model-cache/lealla-normalized-encoder --output .model-cache/lealla-normalized-matcher --freeze-encoder --learning-rate .0001
```

The pipeline intentionally stops if the automatic gate fails. To install its
evaluated output for suggestions without enabling automatic points:

```powershell
.model-venv/Scripts/python tools/install_offline_bundle.py --bundle .model-cache/lealla-normalized-matcher/android-staging --report .model-cache/lealla-normalized-matcher/quantized-evaluation.json --allow-suggestions
```

The installed manifest records the failed automatic gate and suggestion-only
mode. The bundle includes the upstream Apache 2.0 license and model attribution.
Raw training and quantized reports are retained under
`.model-cache/lealla-normalized-matcher/`.

This execution environment needed the following process-local Java socket setting
for Gradle; global Java settings were not changed:

```powershell
$env:JAVA_TOOL_OPTIONS = (($env:JAVA_TOOL_OPTIONS, '-Djdk.net.unixdomain.tmpdir=C:/Windows/Temp') -join ' ').Trim()
flutter build apk --debug --no-pub
```
