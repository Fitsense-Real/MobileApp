#!/bin/bash
# Backend #71+#72 (93549d5) local: base aislada fitsense_e2e72, IA apagada, escenarios por correo.
cd "${E2E_DIR:?define E2E_DIR}"
export SPRING_APPLICATION_JSON='{}'
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN
exec java -cp "harness/classes:app/BOOT-INF/classes:app/BOOT-INF/lib/*" main.web.services.fitsense.FitsenseApplication \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_e2e72 \
  --spring.datasource.username=postgres --spring.datasource.password=x \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/fitsense_e2e72 --spring.flyway.user=postgres --spring.flyway.password=x \
  --authorization.jwt.secret=clave-e2e-local-solo-pruebas-0123456789abcdefghijklmnop \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= \
  --fitsense.cors.allowed-origins=http://localhost:5050 \
  --fitsense.plan-generation.heartbeat-ms=5000 \
  --fitsense.plan-generation.lease-seconds=15 \
  --fitsense.plan-generation.max-processing-seconds=300 \
  --fitsense.plan-generation.initial-delay-ms=1000 \
  --fitsense.plan-generation.max-concurrent=4 \
  --server.port=8080
