"""Sentence Transformers adapter for LEALLA's documented BERT pooler output.

Mean pooling would silently discard the sentence representation learned by
LEALLA. The exported ONNX forward path uses this same pooler representation.
"""
from pathlib import Path
import json
import torch
import re
import shutil
from transformers import AutoModel, AutoTokenizer

_LATIN_WORD = re.compile(r'[A-Za-z]+')


def load_banglish_normalizer(path):
    path = Path(path)
    if not path.is_file():
        return None
    source = json.loads(path.read_text(encoding='utf-8'))
    words = {alias: meaning for meaning, aliases in source['groups'] for alias in aliases}
    return words, set(source['strong_markers'])


def normalize_banglish(text, normalizer):
    if normalizer is None or any('\u0980' <= c <= '\u09ff' for c in text):
        return text
    words, markers = normalizer
    tokens = [word.lower() for word in _LATIN_WORD.findall(text)]
    if not any(word in markers for word in tokens) and not (len(tokens) == 1 and tokens[0] in words):
        return text
    return ' '.join(_LATIN_WORD.sub(lambda m: words.get(m[0].lower(), m[0]), text).split())


class BertPooler(torch.nn.Module):
    save_in_root = True

    def __init__(self, model_path, max_seq_length=128):
        super().__init__()
        self.auto_model = AutoModel.from_pretrained(str(model_path), local_files_only=True)
        self.tokenizer = AutoTokenizer.from_pretrained(str(model_path), local_files_only=True)
        self.max_seq_length = max_seq_length
        self.normalizer_path = Path(model_path) / 'banglish_normalization.json'
        if not self.normalizer_path.is_file():
            self.normalizer_path = Path(__file__).parent / 'data/banglish_normalization.json'
        self.normalizer = load_banglish_normalizer(self.normalizer_path)

    def tokenize(self, texts, **kwargs):
        return self.tokenizer([normalize_banglish(text, self.normalizer) for text in texts], padding=True, truncation=True,
                              max_length=self.max_seq_length, return_tensors='pt')

    def train(self, mode=True):
        # A frozen encoder must also keep dropout disabled while its small
        # adapter is trained; otherwise the cached multilingual features drift.
        frozen = not any(parameter.requires_grad for parameter in self.parameters())
        return super().train(False if frozen else mode)

    def forward(self, features):
        inputs = {key: features[key] for key in ('input_ids', 'attention_mask', 'token_type_ids')
                  if key in features}
        features['sentence_embedding'] = self.auto_model(**inputs).pooler_output
        return features

    def get_sentence_embedding_dimension(self):
        return self.auto_model.config.hidden_size

    def save(self, output_path, safe_serialization=True):
        output_path = Path(output_path)
        output_path.mkdir(parents=True, exist_ok=True)
        self.auto_model.save_pretrained(output_path, safe_serialization=safe_serialization)
        self.tokenizer.save_pretrained(output_path)
        for source in (self.normalizer_path, Path(__file__)):
            target = output_path / source.name
            if source.is_file() and source.resolve() != target.resolve():
                shutil.copy2(source, target)
        (output_path / 'pooler_config.json').write_text(
            json.dumps({'max_seq_length': self.max_seq_length}), encoding='utf-8')

    @classmethod
    def load(cls, input_path):
        config = json.loads((Path(input_path) / 'pooler_config.json').read_text(encoding='utf-8'))
        return cls(input_path, **config)
