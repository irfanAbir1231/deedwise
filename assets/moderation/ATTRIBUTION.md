# Moderation list sources

Retrieved 16 November 2026. Original downloaded source files are retained beside
the curated `blocked.txt`. Only `blocked.txt` is loaded for filtering.

- English: Shutterstock, Inc. / LDNOOBW, *List of Dirty, Naughty, Obscene, and
  Otherwise Bad Words*, https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
  (`en`, master). Copyright 2012–2020 Shutterstock, Inc. Licensed CC BY 4.0:
  https://creativecommons.org/licenses/by/4.0/ . Full text in `LICENSE`.
  Adaptation: retained explicit profanity/slurs; omitted anatomy, identity terms,
  ambiguous phrases and harm-related words that require sentence context.
- Bengali: Josue [4tro] A / 4troDev, https://github.com/4troDev/profanity.csv
  (`Bengali.csv`, main). Copyright 2024 Josue [4tro] A. MIT license in `LICENSE-bn`.
  Adaptation: retained seven explicit terms/phrases; omitted innocent or ambiguous
  words including Bangladesh, child, goat and religious honorifics.
- Small additional Bengali/Banglish spellings and English inflections are
  maintained directly in `lib/src/moderation.dart`.

This is a deliberately narrow lexicon, not a comprehensive abuse classifier.
Words inside innocent longer words do not match. Sentence meaning is checked
separately by the Groq classifier when configured. Offline high-risk descriptions
are held for context review; the bundled offline model remains suggestion-only.
