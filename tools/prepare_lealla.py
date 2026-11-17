"""Wrap a verified local LEALLA model with its pooler and identity adapter."""
from pathlib import Path
import argparse
import shutil
import torch
from sentence_transformers import SentenceTransformer, models
from pooler_encoder import BertPooler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    encoder = BertPooler(args.source)
    if getattr(encoder.tokenizer, 'do_lower_case', False):
        raise ValueError('Android requires the cased WordPiece tokenizer.')
    size = encoder.get_sentence_embedding_dimension()
    adapter = models.Dense(size, size, bias=True, activation_function=torch.nn.Identity())
    with torch.no_grad():
        adapter.linear.weight.copy_(torch.eye(size))
        adapter.linear.bias.zero_()
    model = SentenceTransformer(modules=[encoder, adapter], device='cpu')
    model.save(str(args.output))
    shutil.copy2(args.source / 'download-manifest.json', args.output / 'download-manifest.json')
    print(f'Prepared pooler encoder and identity adapter: {size} dimensions.')


if __name__ == '__main__':
    main()
