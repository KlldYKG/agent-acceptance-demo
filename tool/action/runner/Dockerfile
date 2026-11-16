FROM python:3.12-slim

# Pinned toolchain inside the sandbox. mutmut 2.5.x: setup.cfg-driven CLI.
RUN pip install --no-cache-dir "pytest==8.3.*" "mutmut==2.5.1"

# Non-root execution inside hardened containers.
RUN useradd --create-home --uid 1000 runner
USER runner

WORKDIR /work
# No ENTRYPOINT: the orchestrator chooses pytest / mutmut per phase.
CMD ["bash"]
