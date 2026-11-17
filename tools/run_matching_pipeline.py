"""Run local preparation through Android bundle installation, recording each step.

Never substitutes keyword matching or invented scores for missing model weights.
All commands run as subprocesses without a shell. Any failure stops the pipeline.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timezone

from build_deed_catalog import ROOT
from matching_quality import check_pilot_metrics
from install_offline_bundle import install_bundle


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true', help='Install required packages before training.')
    parser.add_argument('--checks-only', action='store_true', help='Run offline data checks without training.')
    parser.add_argument('--epochs', type=int, default=3)
    parser.add_argument('--freeze-encoder', action='store_true', default=True)
    parser.add_argument('--train-encoder', dest='freeze_encoder', action='store_false')
    parser.add_argument('--learning-rate', type=float, default=1e-4)
    parser.add_argument('--output', type=Path, default=ROOT / '.model-cache/lealla-normalized-matcher')
    parser.add_argument('--model', default=str(ROOT / '.model-cache/lealla-normalized-encoder'),
                        help='Model ID or a previously downloaded local encoder directory.')
    args = parser.parse_args()
    if args.epochs < 1:
        parser.error('Epochs must be positive.')
    working = args.output
    working.mkdir(parents=True, exist_ok=True)
    status_file = working / 'pipeline-status.json'
    status = {'started_utc': datetime.now(timezone.utc).isoformat(), 'steps': [],
              'training_completed': False, 'android_bundle_installed': False,
              'production_validated': False, 'status': 'running'}

    def save_status():
        status_file.write_text(json.dumps(status, indent=2), encoding='utf-8')

    def run(name, arguments):
        step = {'name': name, 'status': 'running'}
        status['steps'].append(step)
        save_status()
        print(name, flush=True)
        result = subprocess.run([sys.executable, *arguments], cwd=ROOT, check=False)
        step.update(status='passed' if result.returncode == 0 else 'failed', exit_code=result.returncode)
        save_status()
        if result.returncode:
            raise RuntimeError(f'{name} failed (exit {result.returncode}).')

    try:
        run('Catalog consistency', ['tools/build_deed_catalog.py', '--check'])
        run('Data validation', ['tools/train_deed_matcher.py', '--validate-only'])
        run('Dataset and metric tests', ['-m', 'unittest', 'discover', '-s', 'tools', '-p', 'test_training_data.py'])
        if args.checks_only:
            status['status'] = 'checks_passed_training_not_run'
            return
        if args.install:
            run('Dependency installation', ['-m', 'pip', 'install', '-r', 'tools/model-requirements.txt',
                                             '--retries', '0', '--timeout', '15'])
        missing = [name for name in ('torch', 'sentence_transformers', 'onnx', 'onnxruntime', 'numpy', 'datasets', 'accelerate')
                   if importlib.util.find_spec(name) is None]
        if missing:
            raise RuntimeError('Required local packages unavailable: ' + ', '.join(missing))
        train_arguments = ['tools/train_deed_matcher.py', '--output', str(working),
                           '--epochs', str(args.epochs), '--model', args.model,
                           '--learning-rate', str(args.learning_rate)]
        if args.freeze_encoder:
            train_arguments.append('--freeze-encoder')
        else:
            train_arguments.append('--train-encoder')
        run('Model training and held-out evaluation', train_arguments)
        status['training_completed'] = True
        save_status()
        # Export to staging. Existing Android assets remain untouched if any
        # later evaluation fails. The runtime cutoff remains 0.80.
        bundle = working / 'android-staging'
        run('ONNX export and numerical parity', ['tools/prepare_offline_model.py', '--model', str(working / 'model'),
                                                 '--output', str(bundle)])
        quantized_report = working / 'quantized-evaluation.json'
        run('Quantized bundle evaluation', ['tools/evaluate_offline_bundle.py', '--bundle', str(bundle),
                                            '--output', str(quantized_report), '--threshold', '.80'])
        gate = {'name': 'Quantized pilot acceptance gate', 'status': 'running'}
        status['steps'].append(gate)
        save_status()
        try:
            check_pilot_metrics(json.loads(quantized_report.read_text(encoding='utf-8')))
        except ValueError:
            gate['status'] = 'failed'
            raise
        gate['status'] = 'passed'
        destination = ROOT / 'android/app/src/main/assets/offline_model'
        destination.mkdir(parents=True, exist_ok=True)
        # Only deploy the inference assets, not the full precision export.
        install_bundle(bundle, quantized_report, destination)
        status['android_bundle_installed'] = True
        status['status'] = 'pilot_bundle_prepared_device_checks_pending'
    except (OSError, RuntimeError, ValueError) as error:
        status.update(status='blocked_or_failed', error=str(error))
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
    finally:
        save_status()
        print(f"Pipeline status: {status['status']}", flush=True)


if __name__ == '__main__':
    main()
