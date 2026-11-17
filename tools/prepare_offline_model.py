"""Prepare a developer-side model bundle. No inference API is called.

Downloads open model weights once during setup, exports the entire sentence
encoder (transformer + mean pooling + dense/tanh), then quantizes MatMul weights.
Run from the app folder in a dedicated Python environment; see OFFLINE_MATCHING.md.
"""
from pathlib import Path
import argparse
import json
import hashlib
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', default=str(Path(__file__).resolve().parents[1] / '.model-cache/lealla-normalized-matcher/model'))
    parser.add_argument('--output', type=Path, default=Path('android/app/src/main/assets/offline_model'))
    args = parser.parse_args()
    import numpy as np
    import torch
    from sentence_transformers import SentenceTransformer
    from onnxruntime.quantization import quantize_dynamic, QuantType
    import onnxruntime as ort
    from build_deed_catalog import load_catalog
    from train_deed_matcher import references
    from pooler_encoder import load_banglish_normalizer, normalize_banglish

    torch.set_num_threads(4)

    model = SentenceTransformer(args.model, device='cpu').eval()
    model_path = Path(args.model)
    provenance = {}
    for path in (model_path / 'download-manifest.json', model_path.parent / 'evaluation.json'):
        if path.is_file():
            provenance = json.loads(path.read_text(encoding='utf-8'))
            break
    source_id = provenance.get('upstream_model', provenance.get('id', args.model))
    source_revision = provenance.get('upstream_revision', provenance.get('sha'))
    tokenizer = model.tokenizer
    normalization_source = Path(args.model) / 'banglish_normalization.json'
    normalizer = load_banglish_normalizer(normalization_source)
    if tokenizer.__class__.__name__ not in ('DistilBertTokenizer', 'DistilBertTokenizerFast', 'BertTokenizer', 'BertTokenizerFast'):
        raise ValueError('Android tokenizer supports cased BERT WordPiece only; do not substitute a SentencePiece model.')
    if getattr(tokenizer, 'do_lower_case', False):
        raise ValueError('This Android implementation expects a cased tokenizer.')
    model.max_seq_length = 128
    args.output.mkdir(parents=True, exist_ok=True)
    data_path = Path(__file__).resolve().parent / 'data'
    notice = {'setu4993/LEALLA-small': 'lealla-NOTICE.txt',
              'sentence-transformers/distiluse-base-multilingual-cased-v2': 'distiluse-NOTICE.txt'}.get(source_id)
    if notice:
        shutil.copy2(data_path / 'distiluse-APACHE-2.0.txt', args.output / 'LICENSE.txt')
        shutil.copy2(data_path / notice, args.output / 'NOTICE.txt')
    tokenizer.save_pretrained(args.output)
    normalization_asset = args.output / 'banglish_normalization.json'
    if normalizer is not None:
        shutil.copy2(normalization_source, normalization_asset)
    if not (args.output / 'vocab.txt').exists():
        raise ValueError('Expected vocab.txt for Android WordPiece.')

    class Encoder(torch.nn.Module):
        def __init__(self, sentence_model):
            super().__init__()
            self.model = sentence_model

        def forward(self, input_ids, attention_mask):
            return self.model({'input_ids': input_ids, 'attention_mask': attention_mask})['sentence_embedding']

    encoder = Encoder(model).eval()
    sample = tokenizer(['I helped a friend solve a problem.'], return_tensors='pt')
    raw = args.output / 'encoder-fp32.onnx'
    with torch.no_grad():
        torch.onnx.export(encoder, (sample['input_ids'], sample['attention_mask']), str(raw),
                          input_names=['input_ids', 'attention_mask'], output_names=['sentence_embedding'],
                          dynamic_axes={'input_ids': {0: 'batch', 1: 'sequence'}, 'attention_mask': {0: 'batch', 1: 'sequence'}, 'sentence_embedding': {0: 'batch'}},
                          opset_version=17, dynamo=False)
    quantized = args.output / 'encoder.onnx'
    quantize_dynamic(str(raw), str(quantized), weight_type=QuantType.QUInt8,
                     per_channel=True, op_types_to_quantize=['MatMul', 'Gather'])
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(quantized), sess_options=options, providers=['CPUExecutionProvider'])
    examples = ['My friend was stuck in a problem and I told him the way to fix the problem.',
                'I did not help my friend.', 'I will help someone tomorrow.', 'I bought a notebook.',
                'আমি বন্ধুকে একটি সমস্যা সমাধান করতে সাহায্য করেছি।',
                'ami amar bondhuke problem solve korte help korechi']
    parity = []
    for text in examples:
        batch = tokenizer(normalize_banglish(text, normalizer), return_tensors='np', truncation=False)
        if batch['input_ids'].shape[1] > 128:
            raise ValueError('Parity example exceeds model limit.')
        output = session.run(None, {key: batch[key].astype(np.int64) for key in ('input_ids','attention_mask')})[0][0]
        reference = model.encode([text], normalize_embeddings=True)[0]
        normalized = output / max(np.linalg.norm(output), 1e-12)
        agreement = float(normalized @ reference)
        if agreement < .98:
            raise ValueError(f'Quantized encoder parity failed: {agreement:.4f}')
        parity.append({'text': text, 'ids': batch['input_ids'][0].tolist(), 'embedding': normalized.tolist(), 'cosine_to_fp32': agreement})
    (args.output / 'tokenizer-parity.json').write_text(json.dumps(parity, ensure_ascii=False, indent=2), encoding='utf-8')
    # Build the 200 fixed reference vectors once, avoiding 200 cold-start
    # inferences on the phone. Changed/admin phrases still encode on device.
    catalog, records = load_catalog()
    encoder_hash = hashlib.sha256(quantized.read_bytes()).hexdigest()
    cached = []
    for rule_id, text in references(records):
        batch = tokenizer(normalize_banglish(text, normalizer), return_tensors='np', truncation=False)
        if batch['input_ids'].shape[1] > 128:
            raise ValueError('A runtime reference exceeds the Android token limit.')
        vector = session.run(None, {key: batch[key].astype(np.int64)
                                   for key in ('input_ids', 'attention_mask')})[0][0]
        norm = np.linalg.norm(vector)
        if not np.isfinite(vector).all() or not np.isfinite(norm) or norm <= 0:
            raise ValueError('Invalid cached reference embedding.')
        cached.append({'id': rule_id, 'text': text, 'embedding': (vector / norm).tolist()})
    cache_path = args.output / 'reference_embeddings.json'
    normalizer_hash = hashlib.sha256(normalization_asset.read_bytes()).hexdigest() if normalizer else ''
    cache_path.write_text(json.dumps({'encoder_sha256': encoder_hash,
                                     'normalizer_sha256': normalizer_hash,
                                     'catalog_version': catalog['version'], 'entries': cached},
                                    ensure_ascii=False), encoding='utf-8')
    manifest = {'model_id': args.model, 'max_tokens': 128,
                'source_model_id': source_id, 'source_revision': source_revision,
                'automatic_matching_enabled': False,
                'quantization': 'per_channel_uint8_matmul_and_gather',
                'output_dimensions': model.get_sentence_embedding_dimension(),
                'threshold_calibrated': False,
                'files': {p.name: {'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}
                          for p in [quantized, args.output / 'vocab.txt', cache_path] +
                          ([normalization_asset] if normalizer else [])}}
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print('Bundle prepared. Device tokenizer parity, latency, memory, and scoring calibration are still required.')


if __name__ == '__main__':
    main()
