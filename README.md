# Spark History Server

This helmchart is more or less just a workaround. The idea is to make a K8s operator/controller to automate the spark-history-servers via CR's.

## Architecture

The idea is to reuse as much as possible from the plural kubeflow distribution.

- First of all, every user gets his/her own spark-history-server instance with a dedicated url.
- Every user gets automatically though the plural kubeflow distribution the folder `s3://at-plural-sh-at-onplural-sh-kubeflow-pipelines/pipelines/tim-krause/` with according permissions. We just add a folder `/history` at the end, to store and read the spark logs there.
- IRSA permissions are already very well integrated.
- Using the bucket instead of a PVC, the spark apps (pushing logs onto) and the spark-history-server (reading the logs from) are better decoupled. S3-like storage is normally available everywhere.
- Authentication/autorization is handled via Istio. The URL for the different spark-history-servers are seperated via a prefix. `https://kubeflow.at.onplural.sh/sparkhistory/<user-namespace>/` e.g. `https://kubeflow.at.onplural.sh/sparkhistory/tim-krause/`.
- All in all, the specific user can only see his/her own spark logs.
- By default the spark logs are rotated which are older than 30 days.
- The SparkApplication or SparkSession just needs to be configured to upload spark logs like:
```
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "s3a://at-plural-sh-at-onplural-sh-kubeflow-pipelines/pipelines/tim-krause/history"
```

## Magic

In this section, we explain the config of the spark-history-server briefly.

Here is an specific example what the helmchart would generate. Basically it adds the config into the environmental variable `SPARK_HISTORY_OPTS` and finally starts the spark-history-server
```
          export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS \
            -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \ #Use S3
            -Dspark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.WebIdentityTokenCredentialsProvider \ #Use IRSA for S3
            -Dspark.history.fs.logDirectory=s3a://at-plural-sh-at-onplural-sh-kubeflow-pipelines/pipelines/tim-krause/history \ #Use this bucket location to read the spark logs
            -Dspark.ui.proxyBase=/sparkhistory/tim-krause \ #Needed to forward accordingly for Istio
            -Dspark.ui.reverseProxy=true \ #Needed to forward accordingly for Istio
            -Dspark.ui.reverseProxyUrl=https://kubeflow.at.onplural.sh/sparkhistory/tim-krause \ #Needed to forward accordingly for Istio
            -Dspark.history.fs.cleaner.enabled=true \ #Enable logrotation (deleting old spark logs)
            -Dspark.history.fs.cleaner.maxAge=30d"; #In this case delete spark logs which are older than 30 days
          /opt/spark/bin/spark-class
          org.apache.spark.deploy.history.HistoryServer;
```

Another important point is to mention a redirect bug of the spark-history-server. When clicking on a specifc spark app, it tries to redirect without the URL prefix `sparkhistory/<user-namespace>/` which leads to an empty page. We created an EnvoyFilter to delete that redirect via replacing the location-header to an empty string:
```
                response_handle:headers():replace("location", "");
```

## Dockerimage

The reason for building a new Dockerimage is to grant spark accordingly.

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

In general all values in values.yaml are important and are described with comments. However, for a good overview:
- `serviceAccount.Name=default-editor` has according IRSA permissions to get access on the bucket
- `image` we need to use our built image. It makes sense to keep the spark version up to date inside 
- `service.port.name` needs to be `http` otherwise the EnvoyFilter cannot listen on it
- `ingress.enabled=true`deploys the according Istio VirtualService
- `s3.bucket` is the bucket name where the spark logs are stored
- `cleaner.maxAge="30d"` rotates/deletes spark logs that are older than 30 days

## Deploy Helmchart

Be sure `s3://at-plural-sh-at-onplural-sh-kubeflow-pipelines/pipelines/tim-krause/history` (according bucket and according namespace) folder (so the folder `/history`) exists. Otherwise create it beforehand.

- Adjust the according namespace `tim-krause`
- Adjust the according bucket at-plural-sh-at-onplural-sh-kubeflow-pipelines (as of now it is KF6)
```
helm upgrade --install history --namespace tim-krause ./ --set s3.bucket="at-plural-sh-at-onplural-sh-kubeflow-pipelines"
```

## Uninstall Helmchart

```
helm uninstall history -n tim-krause
```