#!/bin/bash
# Backend E2E local: base aislada, IA apagada (motor de reglas), escenarios por correo.
cd "${E2E_DIR:?define E2E_DIR: carpeta con app/ (jar desempaquetado) y harness/classes}"
export SPRING_APPLICATION_JSON='{}'
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN
exec java -cp "harness/classes:app/BOOT-INF/classes:app/BOOT-INF/lib/*" main.web.services.fitsense.FitsenseApplication \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_e2e \
  --spring.datasource.username=postgres --spring.datasource.password=x \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/fitsense_e2e --spring.flyway.user=postgres --spring.flyway.password=x \
  --authorization.jwt.secret=clave-e2e-local-solo-pruebas-0123456789abcdefghijklmnop \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= \
  --fitsense.cors.allowed-origins=http://localhost:5050 \
  --fitsense.plan-generation.heartbeat-ms=5000 \
  --fitsense.plan-generation.stale-seconds=30 \
  --fitsense.plan-generation.max-processing-seconds=300 \
  --fitsense.plan-generation.initial-delay-ms=1000 \
  --server.port=8080
