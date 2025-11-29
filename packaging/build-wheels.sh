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
        -v "${ROOT}/packaging/simple-index/psutil:/dist" \
        --env PYTHONHASHSEED=0 \
        --env SOURCE_DATE_EPOCH=315532800 \
            python:${python_version}-alpine sh -c '
        apk add gcc python3-dev musl-dev linux-headers patchelf && \
        python -mvenv .venv && .venv/bin/pip install auditwheel pex && \
        .venv/bin/pex3 wheel -d dist-temp psutil && \
        .venv/bin/auditwheel repair -w /dist dist-temp/*.whl
    ' && \
    sudo chown -R "${USER}:${USER}" "${ROOT}/packaging/simple-index/psutil"
done

cat <<EOF > "${ROOT}/packaging/simple-index/psutil/index.html"
<!DOCTYPE html>
<html>
    <head>
        <title>psutil wheels</title>
    </head>
    <body>
        <h1>psutil wheels</h1>
EOF

for whl_path in ${ROOT}/packaging/simple-index/psutil/*.whl; do
    whl="$(basename "${whl_path}")"
    sha256="$(sha256sum "${whl_path}" | cut -d' ' -f1)"

    unzip -qc "${whl_path}" "$(echo "${whl}" | cut -d- -f1-2).dist-info/METADATA" > \
        "${ROOT}/packaging/simple-index/psutil/${whl}.metadata"
    metadata_sha256="$(sha256sum "${ROOT}/packaging/simple-index/psutil/${whl}.metadata" | cut -d' ' -f1)"

    cat <<EOF >> "${ROOT}/packaging/simple-index/psutil/index.html"
        <a href="${whl}#sha256=${sha256}" data-core-metadata="sha256=${metadata_sha256}">${whl}</a><br>
EOF
done

cat <<EOF >> "${ROOT}/packaging/simple-index/psutil/index.html"
    </body>
</html>
EOF
