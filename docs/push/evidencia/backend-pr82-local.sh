#!/bin/bash
# Backend PR #82 (cc703fb) local: base aislada fitsense_push, IA apagada, push encendido con
# Solo para esta prueba: extra/google-http-client-jackson2 (falta en el jar de la PR #82, hallazgo A).
# credenciales SINTETICAS y sin salida a Internet (proxy a un puerto cerrado): nada llega a Google.
cd /tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad/push82
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN FITSENSE_MAIL_API_KEY HTTPS_PROXY HTTP_PROXY https_proxy http_proxy
export FITSENSE_PUSH_ENABLED=true FITSENSE_FIREBASE_CREDENTIALS_BASE64=$(cat cred.b64) FITSENSE_PUSH_MAX_ATTEMPTS=2
exec java -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttp.nonProxyHosts=localhost \
  -cp "app/BOOT-INF/classes:app/BOOT-INF/lib/*:extra/*" main.web.services.fitsense.FitsenseApplication \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_push \
  --spring.datasource.username=postgres --spring.datasource.password=x \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/fitsense_push --spring.flyway.user=postgres --spring.flyway.password=x \
  --authorization.jwt.secret=clave-e2e-local-solo-pruebas-0123456789abcdefghijklmnop \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= \
  --fitsense.password-reset.delivery=log \
  --fitsense.plan-generation.heartbeat-ms=5000 --fitsense.plan-generation.lease-seconds=15 \
  --fitsense.plan-generation.initial-delay-ms=1000 \
  --server.port=8080
