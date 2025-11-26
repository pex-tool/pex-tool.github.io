#!/usr/bin/env bash

ROOT="$(git rev-parse --show-toplevel)"

if [[ -z "$1" ]]; then
    echo >&2 "A python version is required; eg: $0 3.14"
    exit 1
fi
python_version="$1"

for arch in amd64 arm64; do
    docker run \
        --rm \
        --platform linux/${arch} \
        -v ${ROOT}/packaging/find-links:/dist \
        --env PYTHONHASHSEED=0 \
        --env SOURCE_DATE_EPOCH=315532800 \
            python:${python_version}-alpine sh -c '
        apk add gcc python3-dev musl-dev linux-headers patchelf && \
        python -mvenv .venv && .venv/bin/pip install auditwheel pex && \
        .venv/bin/pex3 wheel -d dist-temp psutil && \
        .venv/bin/auditwheel repair dist-temp/*.whl && \
        mv dist-temp/*.whl dist/
    ' && \
    sudo chown -R ${USER}:${USER} ${ROOT}/packaging/find-links
done

