# Spark History Server

## Architecture

...

## Magic

## Dockerimage

- We can reuse the spark base image from https://github.com/OpenGPTX/docker-images/tree/main/spark/base
- `public.ecr.aws/atcommons/spark/python:14469` is a spark version 3.2.1
- Adjust Dockerfile
- Build Dockerimage:
```
docker build -t public.ecr.aws/atcommons/sparkhistoryserver:14469 .
```
- Push Dockerimage:
```
docker push public.ecr.aws/atcommons/sparkhistoryserver:14469
```

## Important values

## Deploy Helmchart

```
helm upgrade --install history --namespace tim-krause ./
```

## Uninstall Helmchart

```
helm uninstall history -n tim-krause
```