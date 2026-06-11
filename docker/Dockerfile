ARG BASE_IMAGE=agentarena-frontier-model-agent/base:latest
FROM ${BASE_IMAGE}

RUN python3 -m pip install --no-cache-dir httpx uvloop loguru
COPY docker/launch.py /tmp/launch.py
COPY docker/run_*_detect.sh /opt/agent/
RUN chmod +x /opt/agent/run_codex_detect.sh
RUN chmod +x /opt/agent/run_claude_detect.sh
RUN chmod +x /opt/agent/run_gemini_detect.sh
RUN chmod +x /opt/agent/run_cursor_detect.sh

CMD ["python3", "/tmp/launch.py"]