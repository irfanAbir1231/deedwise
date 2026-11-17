# Groq matching setup

Paste your Groq key into `GROQ_API_KEY` in `config/groq.local.json`. Do not paste
the key into chat. This file is gitignored; `groq.example.json` is the template.

```json
{
  "GROQ_API_KEY": "paste-your-key-here",
  "GROQ_MODEL": "openai/gpt-oss-120b"
}
```

Build the Android preview after saving the key:

```powershell
./tools/build_groq_android.ps1
```

For a browser preview:

```powershell
flutter run -d chrome --dart-define-from-file=config/groq.local.json
```

Configuration is read at build time, so changing the file requires rebuilding
the installed app. The current phone installation does not gain Groq access
until a new build includes your key.

Groq is primary. The original deed text (English/Bengali/Banglish) and the fixed
50-deed catalog are sent to Groq; journals and history are not sent. A completed
deed with a valid catalog ID and confidence at least the configured cutoff
(initially 0.80) is matched. Model confidence is an estimate, not measured accuracy.
Questions, future intentions, negation, unrelated text and wrongdoing are review
cases. Unknown IDs and invalid responses are rejected.

Missing key, network/timeout errors, authentication errors and rate limits use
the existing Android local model. A valid negative Groq decision does not invoke
the fallback to override that decision. Local fallback retains suggestion-only
behavior because its earlier validation failed. Browser has no local Android
fallback, but can use configured Groq requests.

This direct-key setup is for private development previews. Build-time secrets
can be extracted from APKs and browser bundles; production should keep the key
on an authenticated backend instead. Do not distribute an APK containing your
personal key as a production release.

Integration tests use mocked HTTP responses. On 10 November 2026, live developer-machine
calls using the local key returned HTTP 200 and correctly selected quran-19 for
the synthetic English and Bengali friend-help examples. These smoke checks do
not establish general accuracy or verify inference over the phone's network.
`dart run tools/check_groq.dart` repeats the synthetic check without printing the key.

API references: [Groq OpenAI compatibility](https://console.groq.com/docs/openai),
[JSON object mode](https://console.groq.com/docs/structured-outputs),
[available models](https://console.groq.com/docs/models).


## 17 November 2026 build

At the user's explicit request, the current ARM64 debug APK includes the existing
local Groq configuration. Compiled-key presence was verified without printing the
key. Live smoke checks returned HTTP 200, accepting ordinary help and rejecting
helping someone kill a person. See `LOCAL_FEATURES_REPORT.md` for the current
artifact and validation scope. End users do not need to enter a key or configure
a backend. The build script now uses workspace temporary paths to avoid Java's
Windows socket-path-length failure.
