FROM registry.fedoraproject.org/fedora:44@sha256:8ade22c0f76f6b2f0892290b1fb39fa1bda1566ba6e276a2ed427f45589c159b

# Match the host's Fedora/DMS baseline, while keeping Qt and Quickshell
# packages together inside the container instead of mixing host binaries.
RUN curl -fsSL https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-44/avengemedia-dms-fedora-44.repo \
        -o /etc/yum.repos.d/dms.repo \
    && dnf install -y git make nodejs npm python3 python3-pip python3-gobject \
        ShellCheck qt6-qtdeclarative-devel qt6-qtsvg qt6-qtimageformats quickshell-0.3.1 \
    && dnf clean all

ARG DMS_REVISION=v1.6.2
ARG DMS_COMMIT=2db7646fe3ab47fddfdb8723f2da07d61a0d47ac
RUN git clone --depth 1 --branch "${DMS_REVISION}" --recurse-submodules \
        https://github.com/AvengeMedia/DankMaterialShell.git /opt/dms \
    && git -C /opt/dms rev-parse HEAD > /opt/dms-revision \
    && test "$(cat /opt/dms-revision)" = "${DMS_COMMIT}"

COPY requirements-dev.txt /tmp/requirements-dev.txt
RUN python3 -m venv /opt/dev-tools \
    && /opt/dev-tools/bin/pip install --no-cache-dir -r /tmp/requirements-dev.txt \
    && useradd --create-home --uid 1000 developer

ENV PATH="/opt/dev-tools/bin:/usr/lib64/qt6/bin:${PATH}"
USER developer
WORKDIR /workspaces/justin-shell
CMD ["sleep", "infinity"]
