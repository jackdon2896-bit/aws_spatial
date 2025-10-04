FROM python:3.10

RUN pip install \
    cellpose \
    scanpy \
    squidpy \
    celltypist \
    tifffile \
    opencv-python-headless \
    imageio \
    matplotlib \
    pandas \
    leidenalg \
    igraph

WORKDIR /app
COPY bin/ /app/bin/