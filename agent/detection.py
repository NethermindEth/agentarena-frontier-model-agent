"""
Shared helpers for running detect-only audit scripts.
"""
import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from agent.config import Settings
from agent.services.auditor import Audit, VulnerabilityFinding

logger = logging.getLogger(__name__)

DETECTORS = {"codex", "claude", "gemini", "cursor"}
REPORT_NAME = "audit.md"


def _detector_script(detector: str) -> Path:
    script_name = f"run_{detector}_detect.sh"
    candidates = [
        Path("/opt/agent") / script_name,
        Path(__file__).resolve().parents[1] / "docker" / script_name,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"Could not find detector script {script_name}")


def _detect_instructions_path() -> Path:
    candidates = [
        Path("/opt/agent/detect.md"),
        Path(__file__).resolve().with_name("detect.md"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("Could not find detect.md at /opt/agent/detect.md or agent/detect.md")


def _apply_detector_env(env: dict, detector: str, config: Settings) -> None:
    model_env = {
        "codex": "CODEX_MODEL",
        "claude": "CLAUDE_MODEL",
        "gemini": "GEMINI_MODEL",
        "cursor": "CURSOR_MODEL",
    }[detector]
    env.setdefault(model_env, config.model)

    if not config.api_key:
        return

    if detector == "codex":
        env.setdefault("OPENAI_API_KEY", config.api_key)
        env.setdefault("CODEX_API_KEY", env["OPENAI_API_KEY"])
    elif detector == "claude":
        env.setdefault("ANTHROPIC_API_KEY", config.api_key)
    elif detector == "gemini":
        env.setdefault("GEMINI_API_KEY", config.api_key)
    elif detector == "cursor":
        env.setdefault("CURSOR_API_KEY", config.api_key)


def _extract_json_report(report: str) -> str:
    stripped = report.strip()
    if not stripped.startswith("```"):
        return stripped

    lines = stripped.splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def _audit_from_report(report_path: str) -> Audit:
    with open(report_path, "r", encoding="utf-8") as f:
        report = f.read().strip()

    if not report:
        return Audit(findings=[])

    try:
        payload = json.loads(_extract_json_report(report))
        if isinstance(payload, list):
            payload = {"findings": payload}
        if isinstance(payload, dict) and "findings" in payload:
            return Audit(**payload)
        if isinstance(payload, dict) and "vulnerabilities" in payload:
            return Audit(
                findings=[
                    VulnerabilityFinding(
                        title=vulnerability.get("title", "Untitled vulnerability"),
                        description=json.dumps(vulnerability, indent=2),
                        severity=str(vulnerability.get("severity", "informational")).capitalize(),
                        file_paths=[
                            item["file"]
                            for item in vulnerability.get("description", [])
                            if isinstance(item, dict) and item.get("file")
                        ],
                    )
                    for vulnerability in payload["vulnerabilities"]
                    if isinstance(vulnerability, dict)
                ]
            )
    except json.JSONDecodeError:
        pass
    except Exception as exc:
        logger.warning("Detector report was JSON but did not match Audit schema: %s", exc)

    return Audit(
        findings=[
            VulnerabilityFinding(
                title="Detector audit report",
                description=report,
                severity="Informational",
                file_paths=[],
            )
        ]
    )


def run_detector(repo_dir: str, config: Settings) -> Audit:
    detector = config.detector.lower()
    if detector not in DETECTORS:
        raise ValueError(f"Unsupported detector '{config.detector}'. Expected one of {sorted(DETECTORS)}")

    script_path = _detector_script(detector)
    detect_md = _detect_instructions_path()

    with tempfile.TemporaryDirectory(prefix="agentarena-audit-") as work_dir:
        audit_dir = os.path.join(work_dir, "audit")
        submission_dir = os.path.join(work_dir, "submission")
        logs_dir = os.path.join(work_dir, "logs")
        os.makedirs(submission_dir, exist_ok=True)
        os.makedirs(logs_dir, exist_ok=True)

        shutil.copytree(repo_dir, audit_dir, symlinks=True)

        env = os.environ.copy()
        env.update(
            {
                "AGENT_DIR": work_dir,
                "AUDIT_DIR": audit_dir,
                "SUBMISSION_DIR": submission_dir,
                "LOGS_DIR": logs_dir,
                "EVM_BENCH_DETECT_MD": str(detect_md),
            }
        )
        _apply_detector_env(env, detector, config)

        logger.info("Running %s detector against copied repository %s", detector, audit_dir)
        subprocess.run(["bash", str(script_path), audit_dir], check=True, env=env)

        report_path = os.path.join(submission_dir, REPORT_NAME)
        if not os.path.isfile(report_path):
            raise FileNotFoundError(f"Detector did not create expected report: {report_path}")

        return _audit_from_report(report_path)
