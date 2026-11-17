"""Install an evaluated bundle; preserve the automatic gate in suggestion mode."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

from build_deed_catalog import ROOT, load_catalog
from matching_quality import check_pilot_metrics


def install_bundle(bundle, report_path, destination, allow_suggestions=False):
    manifest_path = bundle / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    report = json.loads(report_path.read_text(encoding='utf-8'))
    source, _ = load_catalog()
    if report['catalog_version'] != source['version'] or report['threshold'] != .80:
        raise ValueError('Evaluation does not match the app catalog and cutoff.')
    if report['bundle_manifest_sha256'] != hashlib.sha256(manifest_path.read_bytes()).hexdigest():
        raise ValueError('Evaluation does not belong to this bundle.')
    for name, expected in manifest['files'].items():
        # Manifest file names must remain inside the provided bundle.
        if Path(name).name != name:
            raise ValueError('Invalid bundle file name.')
        path = bundle / name
        if path.stat().st_size != expected['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != expected['sha256']:
            raise ValueError('Bundle file verification failed: ' + name)
    try:
        check_pilot_metrics(report)
        automatic = True
        reason = ''
    except ValueError as error:
        if not allow_suggestions:
            raise
        automatic = False
        reason = str(error)
    manifest.update(automatic_matching_enabled=automatic,
                    catalog_version=source['version'], match_threshold=.80,
                    deployment_mode='automatic_pilot' if automatic else 'suggestions_only',
                    automatic_gate_failure=reason, production_validated=False,
                    evaluated_manifest_sha256=report['bundle_manifest_sha256'])
    destination.mkdir(parents=True, exist_ok=True)
    payload_names = set(manifest['files']) | {
        'tokenizer-parity.json', 'tokenizer_config.json', 'special_tokens_map.json',
        'tokenizer.json', 'LICENSE.txt', 'NOTICE.txt',
    }
    for name in sorted(payload_names):
        path = bundle / name
        if path.is_file():
            temporary = destination / (path.name + '.pending')
            shutil.copy2(path, temporary)
            temporary.replace(destination / path.name)
    # Publish the model's mode only after all inference assets have been copied.
    temporary = destination / 'manifest.json.pending'
    temporary.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    temporary.replace(destination / 'manifest.json')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--destination', type=Path,
                        default=ROOT / 'android/app/src/main/assets/offline_model')
    parser.add_argument('--allow-suggestions', action='store_true')
    args = parser.parse_args()
    result = install_bundle(args.bundle, args.report, args.destination, args.allow_suggestions)
    print(json.dumps({'deployment_mode': result['deployment_mode'],
                      'automatic_matching_enabled': result['automatic_matching_enabled'],
                      'automatic_gate_failure': result['automatic_gate_failure']}))


if __name__ == '__main__':
    main()
