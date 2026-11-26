#!/bin/bash
# Backend generation 98276a9 (O20 + V65 + G5M) local. Uso: run.sh <base> <puerto> [faketime]
# IA apagada (motor de reglas), sin push ni Replicate, sin salida a Internet. Solo datos sintéticos.
DB=$1; PORT=$2; FT=$3
cd "$(dirname "$0")"
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN FITSENSE_MAIL_API_KEY OPENAI_API_KEY HTTPS_PROXY HTTP_PROXY https_proxy http_proxy
PRE=()
if [ -n "$FT" ]; then export FAKETIME_DONT_FAKE_MONOTONIC=1; PRE=(faketime -f "$FT"); fi
exec "${PRE[@]}" java -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttp.nonProxyHosts=localhost \
  -jar ${BACKEND_JAR_DIR:-../be-gen/target}/fitsense-backend-0.0.1-SNAPSHOT.jar \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/$DB \
  --spring.datasource.username=postgres --spring.datasource.password=x \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/$DB --spring.flyway.user=postgres --spring.flyway.password=x \
  --authorization.jwt.secret=clave-e2e-local-solo-pruebas-0123456789abcdefghijklmnop \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= --fitsense.password-reset.delivery=log \
  --fitsense.plan-generation.initial-delay-ms=1000 --server.port=$PORT
