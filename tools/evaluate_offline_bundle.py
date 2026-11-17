"""Evaluate the actual quantized Android bundle against held-out deed inputs."""
from pathlib import Path
import argparse
import json
import hashlib

from build_deed_catalog import ROOT, load_catalog
from train_deed_matcher import load_split, score_rows, evaluation


class QuantizedEncoder:
    def __init__(self, bundle):
        import onnxruntime as ort
        from transformers import AutoTokenizer
        from pooler_encoder import load_banglish_normalizer
        self.tokenizer = AutoTokenizer.from_pretrained(str(bundle), local_files_only=True)
        self.normalizer = load_banglish_normalizer(bundle / 'banglish_normalization.json')
        options = ort.SessionOptions()
        options.intra_op_num_threads = 4
        options.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(bundle / 'encoder.onnx'), sess_options=options,
                                           providers=['CPUExecutionProvider'])
        import numpy as np
        manifest = json.loads((bundle / 'manifest.json').read_text(encoding='utf-8'))
        cache = json.loads((bundle / 'reference_embeddings.json').read_text(encoding='utf-8'))
        if cache['encoder_sha256'] != manifest['files']['encoder.onnx']['sha256']:
            raise ValueError('Reference cache does not belong to this model.')
        normalizer_hash = manifest['files'].get('banglish_normalization.json', {}).get('sha256', '')
        if cache.get('normalizer_sha256', '') != normalizer_hash:
            raise ValueError('Reference cache uses a different text normalizer.')
        self.cached = {row['text']: np.asarray(row['embedding'], dtype=np.float32)
                       for row in cache['entries']}

    def encode(self, texts, **unused):
        import numpy as np
        from pooler_encoder import normalize_banglish
        outputs = []
        # Android runs unpadded individual inputs; match that path here.
        for text in texts:
            if text in self.cached:
                outputs.append(self.cached[text])
                continue
            batch = self.tokenizer(normalize_banglish(text, self.normalizer), return_tensors='np', truncation=False)
            if batch['input_ids'].shape[1] > 128:
                raise ValueError('Held-out input exceeds Android token limit; do not silently truncate.')
            vector = self.session.run(None, {
                key: batch[key].astype(np.int64) for key in ('input_ids', 'attention_mask')
            })[0][0]
            norm = np.linalg.norm(vector)
            if not np.isfinite(vector).all() or not np.isfinite(norm) or norm <= 0:
                raise ValueError('Invalid quantized embedding.')
            outputs.append(vector / norm)
        return np.asarray(outputs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--threshold', type=float, default=.80)
    args = parser.parse_args()
    if not 0 < args.threshold <= 1:
        parser.error('Threshold must be in (0, 1].')
    source, records = load_catalog()
    encoder = QuantizedEncoder(args.bundle)
    report = {'catalog_version': source['version'], 'engine': 'quantized_onnx_cpu',
              'bundle_manifest_sha256': hashlib.sha256((args.bundle / 'manifest.json').read_bytes()).hexdigest(),
              'threshold': args.threshold, 'production_validated': False,
              'device_verified': False, 'data_status': 'synthetic_unreviewed_seed_only'}
    for split in ('validation', 'test'):
        report[split] = evaluation(score_rows(encoder, records, load_split(split)), args.threshold)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({split: report[split]['overall'] for split in ('validation', 'test')}, indent=2))


if __name__ == '__main__':
    main()
