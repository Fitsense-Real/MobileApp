#!/bin/bash
# Backend generation (98276a9, con PR #84 (O20) y #83) local: base aislada fitsense_o20, IA apagada (motor de reglas),
# push apagado, sin Replicate, sin salida a Internet. Solo para las pruebas O20 con datos sintéticos.
cd "$(dirname "$0")"
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN FITSENSE_MAIL_API_KEY HTTPS_PROXY HTTP_PROXY https_proxy http_proxy
exec java -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttp.nonProxyHosts=localhost \
  -jar ${BACKEND_JAR_DIR:-../be-gen/target}/fitsense-backend-0.0.1-SNAPSHOT.jar \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_o20 \
  --spring.datasource.username=postgres --spring.datasource.password=x \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/fitsense_o20 --spring.flyway.user=postgres --spring.flyway.password=x \
  --authorization.jwt.secret=clave-e2e-local-solo-pruebas-0123456789abcdefghijklmnop \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= --fitsense.password-reset.delivery=log \
  --fitsense.plan-generation.initial-delay-ms=1000 --server.port=8080
