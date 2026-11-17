"""Fine-tune and evaluate the Android-compatible sentence encoder locally.

The supplied document defines labels, not a labelled training dataset. The small
authored dataset is a reproducible starting point, not production validation.
No inference API or user entries are used. Downloads require network access.
"""
from pathlib import Path
import argparse
import hashlib
import json
import random
from importlib.metadata import version

from build_deed_catalog import CATALOG, ROOT, load_catalog


def load_split(name):
    path = ROOT / f'tools/data/{name}.jsonl'
    return [json.loads(line) for line in path.read_text(encoding='utf-8').splitlines() if line.strip()]


def validate_data(records, splits):
    known = {r['id'] for r in records}
    seen = set()
    for name, rows in splits.items():
        if not rows:
            raise ValueError('Empty split: ' + name)
        for row in rows:
            key = row['text'].strip().casefold()
            if not key or key in seen:
                raise ValueError('Empty or repeated text across splits: ' + key)
            seen.add(key)
            if not set(row['rule_ids']) <= known:
                raise ValueError('Unknown rule ID.')
        if {i for row in rows for i in row['rule_ids']} != known:
            raise ValueError('Every split must cover all 50 deeds.')
        if not any(not row['rule_ids'] for row in rows):
            raise ValueError('Every split needs explicit review cases.')


def references(records):
    # Must mirror DeviceDeedMatcher: label plus the three training examples.
    return [(r['id'], text) for r in records for text in
            [r['label'], r['english_example'], r['bengali_example'], r['banglish_example']]]


def training_pairs(records, rows, ranked_reference_indices):
    """Use only training rows; keep known equivalent deeds out of negatives.

    Positive-only fitting pulls every deed together. Mine distinct competing
    deeds as negatives as well as non-completion examples, and explicitly align
    each deed's three languages. Never mine held-out inputs.
    """
    refs = references(records)
    by_id = {r['id']: r for r in records}
    equivalents = {'quran-08': {'quran-08', 'quran-50'},
                   'quran-50': {'quran-08', 'quran-50'},
                   'quran-22': {'quran-22', 'quran-48'},
                   'quran-48': {'quran-22', 'quran-48'}}
    pairs = []
    for row, ranking in zip(rows, ranked_reference_indices, strict=True):
        allowed = set(row['rule_ids'])
        for rule_id in row['rule_ids']:
            allowed.update(equivalents.get(rule_id, ()))
            record = by_id[rule_id]
            pairs.extend((row['text'], record[field], 1.0)
                         for field in ('label', 'description'))
        used = set()
        for index in ranking:
            rule_id, phrase = refs[int(index)]
            if rule_id in allowed or rule_id in used:
                continue
            pairs.append((row['text'], phrase, 0.0))
            used.add(rule_id)
            if len(used) == 2:
                break
    # Teach multilingual equivalence without using validation/test paraphrases.
    for record in records:
        en, bn, banglish = (record[field] for field in
                           ('english_example', 'bengali_example', 'banglish_example'))
        pairs.extend(((en, bn, 1.0), (en, banglish, 1.0), (bn, banglish, 1.0)))
    return pairs


def score_rows(model, records, rows):
    refs = references(records)
    embeddings = model.encode([text for _, text in refs], normalize_embeddings=True,
                              batch_size=16, show_progress_bar=False)
    queries = model.encode([row['text'] for row in rows], normalize_embeddings=True,
                           batch_size=16, show_progress_bar=False)
    ranked = queries @ embeddings.T
    output = []
    for row, scores in zip(rows, ranked):
        # numpy argmax, like Kotlin's strict > comparison, keeps the first tie.
        best = int(scores.argmax())
        output.append({**row, 'predicted_id': refs[best][0], 'score': float(scores[best])})
    return output


def metrics(rows, threshold):
    accepted = [row for row in rows if row['score'] >= threshold]
    correct = sum(row['predicted_id'] in row['rule_ids'] for row in accepted)
    positives = sum(bool(row['rule_ids']) for row in rows)
    negative_count = len(rows) - positives
    false_accepts = sum(not row['rule_ids'] for row in accepted)
    wrong_deed = sum(bool(row['rule_ids']) and row['predicted_id'] not in row['rule_ids'] for row in accepted)
    return {'examples': len(rows), 'threshold': threshold, 'accepted': len(accepted),
            'correct_accepts': correct, 'wrong_deed_accepts': wrong_deed,
            'review_cases_incorrectly_accepted': false_accepts,
            'precision': correct / len(accepted) if accepted else None,
            'positive_recall': correct / positives if positives else None,
            'review_case_false_accept_rate': false_accepts / negative_count if negative_count else None,
            'positive_top1_accuracy': sum(bool(r['rule_ids']) and r['predicted_id'] in r['rule_ids'] for r in rows) / positives if positives else None}


def evaluation(rows, threshold):
    return {'overall': metrics(rows, threshold),
            'by_language': {lang: metrics([r for r in rows if r['language'] == lang], threshold)
                            for lang in sorted({r['language'] for r in rows})},
            'predictions': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', default=str(ROOT / '.model-cache/lealla-normalized-encoder'))
    parser.add_argument('--output', type=Path, default=ROOT / '.model-cache/lealla-normalized-matcher')
    parser.add_argument('--epochs', type=int, default=3)
    parser.add_argument('--batch-size', type=int, default=8)
    parser.add_argument('--threads', type=int, default=4)
    parser.add_argument('--threshold', type=float, default=.80)
    parser.add_argument('--min-precision', type=float, default=.95)
    parser.add_argument('--freeze-encoder', action='store_true', default=True,
                        help='Train only the projection adapter, preserving pretrained multilingual features.')
    parser.add_argument('--train-encoder', dest='freeze_encoder', action='store_false')
    parser.add_argument('--learning-rate', type=float, default=1e-4)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    if not 0 < args.threshold <= 1 or not 0 < args.min_precision <= 1:
        parser.error('Threshold and minimum precision must be in (0, 1].')
    if min(args.epochs, args.batch_size, args.threads) < 1:
        parser.error('Epochs, batch size, and threads must be positive.')
    source, records = load_catalog()
    download_manifest = Path(args.model) / 'download-manifest.json'
    upstream = json.loads(download_manifest.read_text(encoding='utf-8')) if download_manifest.is_file() else {}
    splits = {name: load_split(name) for name in ('train', 'validation', 'test')}
    validate_data(records, splits)
    if args.validate_only:
        print('Dataset valid: 50 deed IDs, disjoint splits, review examples. No model trained.')
        return

    import torch
    from torch.utils.data import DataLoader
    from sentence_transformers import SentenceTransformer, InputExample, losses
    from sentence_transformers.evaluation import SentenceEvaluator

    random.seed(20261109)
    torch.manual_seed(20261109)
    torch.set_num_threads(args.threads)
    model = SentenceTransformer(args.model, device='cpu')
    if args.freeze_encoder:
        for parameter in model[0].parameters():
            parameter.requires_grad = False
        if not any(p.requires_grad for p in model.parameters()):
            raise ValueError('Freezing the encoder leaves no trainable adapter.')
    if model.tokenizer.__class__.__name__ not in ('DistilBertTokenizer', 'DistilBertTokenizerFast', 'BertTokenizer', 'BertTokenizerFast') or getattr(model.tokenizer, 'do_lower_case', False):
        raise ValueError('Use the cased WordPiece model supported by the Android tokenizer.')
    model.max_seq_length = 128
    refs = references(records)
    # Prevent Android from later failing on any bundled reference.
    for _, text in refs:
        if len(model.tokenizer.encode(text, truncation=False)) > 128:
            raise ValueError('A bundled reference exceeds the Android token limit.')
    args.output.mkdir(parents=True, exist_ok=True)
    baseline_validation = score_rows(model, records, splits['validation'])
    (args.output / 'baseline-validation.json').write_text(
        json.dumps(evaluation(baseline_validation, args.threshold), ensure_ascii=False, indent=2),
        encoding='utf-8')
    print('Baseline validation: ' + json.dumps(metrics(baseline_validation, args.threshold)), flush=True)
    if not args.baseline_only:
        checkpoint_metrics = []

        class ValidationEvaluator(SentenceEvaluator):
            def __init__(self):
                super().__init__()
                self.primary_metric = 'selection'
                self.greater_is_better = True

            def __call__(self, model, output_path=None, epoch=-1, steps=-1):
                assessed = evaluation(score_rows(model, records, splits['validation']), args.threshold)
                measured = assessed['overall']
                languages = [m for m in assessed['by_language'].values()
                             if m['positive_top1_accuracy'] is not None]
                macro_accuracy = sum(m['positive_top1_accuracy'] for m in languages) / len(languages)
                # Select by validation only. Reward usable coverage after the
                # precision/review gate, otherwise penalise incorrect accepts.
                qualified = (measured['precision'] is not None and
                             measured['precision'] >= args.min_precision and
                             measured['review_cases_incorrectly_accepted'] == 0 and
                             all(m['precision'] is not None and m['precision'] >= args.min_precision
                                 and m['positive_recall'] >= .5 for m in languages))
                selection = (10000 if qualified else 0) + 100 * macro_accuracy - (
                    measured['wrong_deed_accepts'] +
                    2 * measured['review_cases_incorrectly_accepted'])
                checkpoint_metrics.append({'epoch': epoch, 'steps': steps,
                                           'macro_positive_top1_accuracy': macro_accuracy,
                                           'selection': selection, **measured})
                (args.output / 'validation-checkpoints.json').write_text(
                    json.dumps(checkpoint_metrics, indent=2), encoding='utf-8')
                print('Checkpoint validation: ' + json.dumps(checkpoint_metrics[-1]), flush=True)
                return {'selection': float(selection)}

        vectors = model.encode([text for _, text in refs], normalize_embeddings=True,
                               show_progress_bar=False, batch_size=16)
        queries = model.encode([row['text'] for row in splits['train']],
                               normalize_embeddings=True, show_progress_bar=False, batch_size=16)
        rankings = (queries @ vectors.T).argsort(axis=1)[:, ::-1]
        pairs = training_pairs(records, splits['train'], rankings)
        examples = [InputExample(texts=[a, b], label=label) for a, b, label in pairs]
        print(f'Training on {len(pairs)} train-only pairs, including competing deeds and multilingual pairs.', flush=True)
        model.fit(train_objectives=[(DataLoader(examples, shuffle=True, batch_size=args.batch_size),
                                     losses.CosineSimilarityLoss(model))],
                  epochs=args.epochs, warmup_steps=max(1, len(examples) // args.batch_size // 10),
                  optimizer_params={'lr': args.learning_rate}, show_progress_bar=True,
                  evaluator=ValidationEvaluator(), output_path=str(args.output / 'model'),
                  save_best_model=True)
        # fit() keeps the final epoch in memory; load the validation-selected
        # checkpoint before running the test split exactly once.
        model = SentenceTransformer(str(args.output / 'model'), device='cpu')
        model.max_seq_length = 128

    # Use validation only for a diagnostic threshold recommendation. Do not
    # overwrite the app's pilot cutoff or tune against the test set.
    validation = score_rows(model, records, splits['validation'])
    candidates = [metrics(validation, i / 100) for i in range(50, 100)]
    viable = [m for m in candidates if m['accepted'] and m['precision'] >= args.min_precision
              and m['review_cases_incorrectly_accepted'] == 0]
    recommended = max(viable, key=lambda m: (m['correct_accepts'], m['threshold']))['threshold'] if viable else None
    test = score_rows(model, records, splits['test'])
    report = {'catalog_version': source['version'], 'model': args.model,
              'upstream_model': upstream.get('id', args.model),
              'upstream_revision': upstream.get('sha'),
              'package_versions': {name: version(name) for name in
                                   ('sentence-transformers', 'transformers', 'torch', 'numpy')},
              'training_executed': not args.baseline_only,
              'encoder_frozen': args.freeze_encoder, 'learning_rate': args.learning_rate,
              'data_status': 'synthetic_unreviewed_seed_only',
              'production_validated': False,
              'limitations': ['Small authored seed data; needs independent human-labelled examples.',
                              'Authored multilingual validation and test cases are development diagnostics; independent human-labelled multilingual data is still needed.',
                              'Overlapping IDs 08/50 and 22/48 accept either ID in evaluation.',
                              'Device tokenizer parity, quantization and latency need separate checks.'],
              'data_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                              [CATALOG] + [ROOT / f'tools/data/{n}.jsonl' for n in splits]},
              'baseline_validation_at_pilot': evaluation(baseline_validation, args.threshold),
              'validation_at_pilot': evaluation(validation, args.threshold),
              'test_at_pilot': evaluation(test, args.threshold),
              'validation_recommended_threshold': recommended,
              'test_at_recommended': evaluation(test, recommended) if recommended is not None else None}
    (args.output / 'evaluation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'training_executed': report['training_executed'],
                      'validation_at_pilot': metrics(validation, args.threshold),
                      'test_at_pilot': metrics(test, args.threshold),
                      'recommended_threshold': recommended, 'production_validated': False}, indent=2))


if __name__ == '__main__':
    main()
