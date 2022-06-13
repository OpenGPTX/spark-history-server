FROM public.ecr.aws/atcommons/spark/python:14469

ARG spark_uid=185

USER root

RUN groupadd -g 185 spark && \
    useradd -u 185 -g 185 spark

USER "${spark_uid}"