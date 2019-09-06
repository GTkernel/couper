FROM python:2.7
# for model slicer
RUN pip install tensorflow

COPY ./ /couper

WORKDIR /couper
