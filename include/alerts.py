"""Send a Slack message when an Airflow task fails.

Set SLACK_WEBHOOK_URL to turn it on. Without it, the alert is only logged.
"""

import logging
import os

import requests

log = logging.getLogger(__name__)


def notify_failure(context) -> None:
    ti = context["task_instance"]
    text = f":red_circle: {ti.dag_id}.{ti.task_id} failed (try {ti.try_number}). Logs: {ti.log_url}"
    url = os.getenv("SLACK_WEBHOOK_URL")
    if not url:
        log.error(text)
        return
    try:
        requests.post(url, json={"text": text}, timeout=10)
    except requests.RequestException:
        log.exception("Could not send the Slack alert")
