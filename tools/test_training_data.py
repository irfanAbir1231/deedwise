"""Dataset and decision-metric checks; these do not measure model accuracy."""
import unittest
import tempfile
import json
import hashlib
from pathlib import Path
from install_offline_bundle import install_bundle
from build_deed_catalog import load_catalog
from train_deed_matcher import load_split, validate_data, metrics, references, training_pairs
from run_matching_pipeline import check_pilot_metrics


class DatasetTests(unittest.TestCase):
    def test_glossary_preserves_negation_and_has_unambiguous_word_keys(self):
        path = Path(__file__).parent / 'data/banglish_normalization.json'
        source = json.loads(path.read_text(encoding='utf-8'))
        words = {}
        for meaning, aliases in source['groups']:
            self.assertTrue(meaning.strip())
            for alias in aliases:
                self.assertRegex(alias, r'^[a-z]+$')
                self.assertNotIn(alias, words)
                words[alias] = meaning
        self.assertIn('not', words['porini'])
        self.assertIn('not', words['korini'])
        self.assertIn('will', words['korbo'])
        self.assertEqual(words['obichar'], 'injustice')

    def test_suggestion_install_cannot_enable_a_failed_automatic_gate(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / 'bundle'
            bundle.mkdir()
            files = {}
            for name, data in (('encoder.onnx', b'test fixture'), ('vocab.txt', b'[UNK]')):
                (bundle / name).write_bytes(data)
                files[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            manifest = bundle / 'manifest.json'
            (bundle / 'diagnostic-model.onnx').write_bytes(b'not a runtime asset')
            manifest.write_text(json.dumps({'files': files, 'automatic_matching_enabled': False}))
            report = root / 'evaluation.json'
            source, _ = load_catalog()
            report.write_text(json.dumps({
                'catalog_version': source['version'], 'threshold': .8,
                'bundle_manifest_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
                **{name: {'overall': {'precision': .5, 'positive_recall': .5,
                                     'review_cases_incorrectly_accepted': 1}}
                   for name in ('validation', 'test')},
            }))
            destination = root / 'installed'
            with self.assertRaises(ValueError):
                install_bundle(bundle, report, destination)
            self.assertFalse(destination.exists())
            installed = install_bundle(bundle, report, destination, allow_suggestions=True)
            self.assertFalse(installed['automatic_matching_enabled'])
            self.assertEqual(installed['deployment_mode'], 'suggestions_only')
            self.assertFalse((destination / 'diagnostic-model.onnx').exists())
            # A corrupted file must be rejected even for suggestion use.
            (bundle / 'encoder.onnx').write_bytes(b'corrupted')
            with self.assertRaises(ValueError):
                install_bundle(bundle, report, root / 'tampered', allow_suggestions=True)
            self.assertFalse((root / 'tampered').exists())

    def test_training_distinguishes_deeds_without_penalising_equivalents(self):
        _, records = load_catalog()
        refs = references(records)
        # Rank the equivalent rule first, then another deed, then the target.
        indices = [next(i for i, (rule_id, _) in enumerate(refs) if rule_id == rid)
                   for rid in ('quran-48', 'quran-19', 'quran-22', 'quran-14')]
        text = records[21]['english_example']
        pairs = training_pairs(records, [{'text': text, 'rule_ids': ['quran-22']}], [indices])
        negatives = [b for a, b, label in pairs if a == text and label == 0.0]
        self.assertEqual(negatives, [records[18]['label'], records[13]['label']])
        self.assertIn((records[21]['bengali_example'], records[21]['banglish_example'], 1.0), pairs)
        held_out = {r['text'] for split in ('validation', 'test') for r in load_split(split)}
        self.assertFalse(any(a in held_out or b in held_out for a, b, _ in pairs))

    def test_seed_splits_are_disjoint_and_cover_catalog(self):
        _, records = load_catalog()
        splits = {name: load_split(name) for name in ('train', 'validation', 'test')}
        validate_data(records, splits)
        self.assertEqual([len(splits[n]) for n in splits], [312, 112, 124])
        self.assertEqual(len({i for row in splits['test'] if row['language'] == 'banglish'
                              for i in row['rule_ids']}), 50)
        self.assertEqual(len(references(records)), 200)
        runtime_texts = {text for _, text in references(records)}
        self.assertTrue(all(row['text'] not in runtime_texts
                            for row in splits['train'] if not row['rule_ids']))
        self.assertTrue(all(row['text'] not in [t for _, t in references(records)]
                            for name in ('validation', 'test') for row in splits[name]))

    def test_metrics_count_wrong_deeds_and_false_acceptances(self):
        rows = [
            {'score': .9, 'predicted_id': 'quran-14', 'rule_ids': ['quran-14']},
            {'score': .8, 'predicted_id': 'quran-11', 'rule_ids': ['quran-14']},
            {'score': .85, 'predicted_id': 'quran-19', 'rule_ids': []},
            {'score': .6, 'predicted_id': 'quran-19', 'rule_ids': []},
        ]
        result = metrics(rows, .8)
        self.assertEqual(result['accepted'], 3)
        self.assertEqual(result['wrong_deed_accepts'], 1)
        self.assertEqual(result['review_cases_incorrectly_accepted'], 1)
        self.assertEqual(result['precision'], 1 / 3)
        self.assertEqual(result['positive_recall'], .5)

    def test_no_accepted_examples_does_not_claim_perfect_precision(self):
        result = metrics([{'score': .3, 'predicted_id': 'quran-19', 'rule_ids': []}], .8)
        self.assertIsNone(result['precision'])
        self.assertEqual(result['review_case_false_accept_rate'], 0)

    def test_bundle_gate_rejects_false_acceptances_and_low_coverage(self):
        def report(**updates):
            values = {'precision': 1., 'positive_recall': .8, 'review_cases_incorrectly_accepted': 0}
            values.update(updates)
            return {name: {'overall': dict(values)} for name in ('validation', 'test')}
        check_pilot_metrics(report())
        for updates in ({'precision': None}, {'precision': .8},
                        {'positive_recall': .1}, {'review_cases_incorrectly_accepted': 1}):
            with self.subTest(updates=updates):
                with self.assertRaises(ValueError):
                    check_pilot_metrics(report(**updates))
        uneven = report()
        uneven['validation']['by_language'] = {'banglish': {'precision': .6, 'positive_recall': .7}}
        with self.assertRaises(ValueError):
            check_pilot_metrics(uneven)


if __name__ == '__main__':
    unittest.main()
