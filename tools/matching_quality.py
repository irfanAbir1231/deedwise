"""Fixed pilot gate for automatic matches; suggestions never imply approval."""


def check_pilot_metrics(report, minimum_precision=.95, minimum_recall=.50):
    for split in ('validation', 'test'):
        data = report[split]['overall']
        if data['precision'] is None or data['precision'] < minimum_precision:
            raise ValueError(f'{split}: accepted-match precision is below {minimum_precision}.')
        if data['positive_recall'] is None or data['positive_recall'] < minimum_recall:
            raise ValueError(f'{split}: positive recall is below {minimum_recall}.')
        if data['review_cases_incorrectly_accepted']:
            raise ValueError(f'{split}: a review-only example received an automatic match.')
        for language, measured in report[split].get('by_language', {}).items():
            if measured['positive_recall'] is not None and (
                    measured['precision'] is None or measured['precision'] < minimum_precision or
                    measured['positive_recall'] < minimum_recall):
                raise ValueError(f'{split}/{language}: automatic precision or recall gate failed.')
