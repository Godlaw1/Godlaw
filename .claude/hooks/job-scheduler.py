#!/usr/bin/env python3
"""
Bepaalt welke jobs klaar zijn om uitgevoerd te worden.
Leest .job-bestanden, vergelijkt schema met laatste uitvoering.
Output: lijst van verschuldigde jobs met hun prompts.
"""
import os
import sys
import json
from datetime import date, datetime
from pathlib import Path

JOBS_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")) / ".claude" / "jobs"
LOGS_DIR = JOBS_DIR / "logs"
STATE_FILE = JOBS_DIR / ".state.json"

DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
TODAY = date.today()
TODAY_STR = TODAY.isoformat()
TODAY_WEEKDAY = DAYS[TODAY.weekday()]


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}


def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=2))


def parse_job(path):
    job = {"name": path.stem, "schedule": None, "description": "", "prompt": ""}
    for line in path.read_text().splitlines():
        if line.startswith("# JOB:"):
            job["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("# SCHEDULE:"):
            job["schedule"] = line.split(":", 1)[1].strip()
        elif line.startswith("# DESCRIPTION:"):
            job["description"] = line.split(":", 1)[1].strip()
        elif line.startswith("# PROMPT:"):
            job["prompt"] = line.split(":", 1)[1].strip()
    return job


def is_due(job, last_run):
    schedule = job["schedule"]
    if not schedule:
        return False

    if schedule == "daily":
        return last_run != TODAY_STR

    if schedule.startswith("weekly:"):
        day = schedule.split(":")[1].lower()
        if TODAY_WEEKDAY != day:
            return False
        # Controleer of niet al uitgevoerd deze week
        if last_run:
            last_date = date.fromisoformat(last_run)
            days_since = (TODAY - last_date).days
            return days_since >= 7
        return True

    if schedule.startswith("monthly:"):
        day_of_month = int(schedule.split(":")[1])
        if TODAY.day != day_of_month:
            return False
        if last_run:
            last_date = date.fromisoformat(last_run)
            return last_date.month != TODAY.month or last_date.year != TODAY.year
        return True

    return False


def main():
    state = load_state()
    due_jobs = []

    for job_file in sorted(JOBS_DIR.glob("*.job")):
        job = parse_job(job_file)
        last_run = state.get(job["name"], {}).get("last_run", "")
        if is_due(job, last_run):
            due_jobs.append(job)

    if not due_jobs:
        print("## GEPLANDE JOBS\nGeen jobs verschuldigd. Alles is up-to-date.")
        return

    print("## GEPLANDE JOBS — ACTIE VEREIST")
    print(f"\n{len(due_jobs)} job(s) staan klaar om uitgevoerd te worden:\n")
    for job in due_jobs:
        print(f"### {job['name']}")
        print(f"Schema    : {job['schedule']}")
        print(f"Omschrijving: {job['description']}")
        prompt = job['prompt'].replace("DATUM", TODAY_STR)
        print(f"Prompt    : {prompt}")
        print()

    print("Voer bovenstaande jobs nu uit. Markeer ze daarna als voltooid via:")
    print(f"  python3 .claude/hooks/job-scheduler.py --mark-done <jobnaam>")


def mark_done(job_name):
    state = load_state()
    if job_name not in state:
        state[job_name] = {}
    state[job_name]["last_run"] = TODAY_STR
    state[job_name]["last_run_human"] = datetime.now().strftime("%Y-%m-%d %H:%M")
    save_state(state)
    print(f"Job '{job_name}' gemarkeerd als voltooid op {TODAY_STR}.")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--mark-done":
        mark_done(sys.argv[2])
    else:
        main()
