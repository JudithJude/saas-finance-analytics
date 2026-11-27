"""Run extract and load without Airflow, e.g. locally or in CI.

    python -m include.run_extract            # every source
    python -m include.run_extract stripe     # one source
"""

import logging
import sys

from include.extract.load import run
from include.extract.sources import SOURCES

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    for source in sys.argv[1:] or list(SOURCES):
        for table, n in run(source).items():
            print(f"{table}: {n} rows loaded")
