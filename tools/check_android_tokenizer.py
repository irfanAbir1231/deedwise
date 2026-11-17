"""Compare the actual Android WordPiece source with the model tokenizer on JVM.

Uses a cached Kotlin compiler and a JDK; does not replace physical device tests.
No test tokenizer reimplementation is used: the class is read from app source.
"""
from pathlib import Path
import argparse
import base64
import json
import os
import subprocess

from build_deed_catalog import ROOT, load_catalog
from train_deed_matcher import load_split, references


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--java', type=Path, required=True)
    parser.add_argument('--cache', type=Path,
                        default=Path.home() / '.gradle/caches/modules-2/files-2.1')
    args = parser.parse_args()
    from transformers import AutoTokenizer
    from pooler_encoder import load_banglish_normalizer, normalize_banglish

    work = ROOT / '.model-cache/tokenizer-check'
    work.mkdir(parents=True, exist_ok=True)
    packages = {
        'org.jetbrains.kotlin': ['kotlin-compiler-embeddable', 'kotlin-stdlib',
                                 'kotlin-script-runtime', 'kotlin-reflect', 'kotlin-daemon-embeddable'],
        'org.jetbrains.intellij.deps': ['trove4j'],
        'org.jetbrains': ['annotations'],
        'org.jetbrains.kotlinx': ['kotlinx-coroutines-core-jvm'],
    }
    jars = []
    for group, names in packages.items():
        for name in names:
            found = list((args.cache / group / name).glob('*/*/*.jar'))
            preferred = [p for p in found if '2.1.0' in p.parts]
            if not found:
                raise FileNotFoundError('Missing cached compiler dependency: ' + name)
            jars.append(sorted(preferred or found)[-1])
    classpath = os.pathsep.join(str(p) for p in jars)
    source = (ROOT / 'android/app/src/main/kotlin/com/example/deedwise/OfflineMatcher.kt').read_text(encoding='utf-8')
    source = source[source.index('class BanglishNormalizer'):]
    normalizer = load_banglish_normalizer(args.model / 'banglish_normalization.json')
    extra_args = []
    if normalizer:
        words, markers = normalizer
        word_path, marker_path = work / 'words.tsv', work / 'markers.txt'
        word_path.write_text('\n'.join(k + '\t' + base64.b64encode(v.encode()).decode()
                                       for k, v in words.items()), encoding='utf-8')
        marker_path.write_text('\n'.join(markers), encoding='utf-8')
        extra_args = [str(word_path), str(marker_path)]
    harness = work / 'TokenizerCheck.kt'
    harness.write_text('import java.io.File\nimport java.util.Base64\n' + source + '''
fun main(args: Array<String>) {
    val tokenizer = CasedWordPiece(File(args[0]).readLines())
    val normalizer = if (args.size > 1) {
        val words = File(args[1]).readLines().associate { line ->
            val parts = line.split('\\t')
            parts[0] to String(Base64.getDecoder().decode(parts[1]), Charsets.UTF_8)
        }
        BanglishNormalizer(words, File(args[2]).readLines().toSet())
    } else null
    generateSequence(::readLine).forEach { line ->
        val text = String(Base64.getDecoder().decode(line), Charsets.UTF_8)
        val normalized = normalizer?.normalize(text) ?: text
        val prefix = Base64.getEncoder().encodeToString(normalized.toByteArray(Charsets.UTF_8)) + "\\t"
        try { println(prefix + tokenizer.encode(normalized).joinToString(",")) }
        catch (e: TextTooLongException) { println(prefix + "TOO_LONG") }
    }
}
''', encoding='utf-8')
    jar = work / 'tokenizer.jar'
    subprocess.run([str(args.java), '-cp', classpath,
                    'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect',
                    '-classpath', classpath, '-jvm-target', '11', '-d', str(jar), str(harness)], check=True)
    _, records = load_catalog()
    texts = list(dict.fromkeys([t for _, t in references(records)] +
                              [r['text'] for split in ('train', 'validation', 'test') for r in load_split(split)] +
                              ['namaz', 'রোজা', 'I helped.\nআমিও সাহায্য করেছি।',
                               'Kindness 😀 costs nothing!', 'word\u200dword',
                               'I said [MASK] and [CLS].', 'word ' * 200,
                               'a[MASK]b', '[PAD][UNK][SEP][CLS][MASK]',
                               '\x00help\x07 \ufffd', 'x' * 101,
                               'ami aj namaz porini', 'ami kal taka dibo',
                               'ami\u00a0aj namaz porechi', 'আমি Dan-কে সাহায্য করেছি।']))
    tokenizer = AutoTokenizer.from_pretrained(str(args.model), local_files_only=True)
    payload = '\n'.join(base64.b64encode(t.encode()).decode() for t in texts) + '\n'
    result = subprocess.run([str(args.java), '-cp', str(jar) + os.pathsep + classpath,
                             'TokenizerCheckKt', str(args.model / 'vocab.txt'), *extra_args],
                            input=payload, text=True, capture_output=True, check=True)
    lines = result.stdout.splitlines()
    if len(lines) != len(texts):
        raise ValueError('Native harness returned the wrong number of results.')
    failures = []
    for text, line in zip(texts, lines, strict=True):
        normalized, line = line.split('\t', 1)
        normalized = base64.b64decode(normalized).decode()
        expected_text = normalize_banglish(text, normalizer)
        expected = tokenizer.encode(expected_text, truncation=False)
        actual = line if line == 'TOO_LONG' else [int(i) for i in line.split(',')]
        expected = 'TOO_LONG' if len(expected) > 128 else expected
        if expected != actual or normalized != expected_text:
            failures.append({'text': text, 'expected': expected, 'actual': actual,
                             'expected_text': expected_text, 'actual_text': normalized})
    report = {'examples': len(texts), 'mismatches': failures, 'device_verified': False}
    (work / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'examples': len(texts), 'mismatches': len(failures), 'device_verified': False}))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
