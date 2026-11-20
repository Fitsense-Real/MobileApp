#!/bin/bash
# Backend 5977d28 (generation) local: base aislada fitsense_int, IA apagada (motor de reglas),
# recuperacion por correo a un buzon SMTP local (127.0.0.1:2525), ciclo manual activo para probar la adaptacion.
cd /tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad/int
export SPRING_APPLICATION_JSON='{}'
unset DB_PASSWORD JWT_SECRET REPLICATE_API_TOKEN FITSENSE_MAIL_API_KEY
exec java -cp "harness/classes:app/BOOT-INF/classes:app/BOOT-INF/lib/*" main.web.services.fitsense.FitsenseApplication \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_int \
  --spring.datasource.username=postgres --spring.datasource.password=<clave-local> \
  --spring.flyway.url=jdbc:postgresql://localhost:5432/fitsense_int --spring.flyway.user=postgres --spring.flyway.password=<clave-local> \
  --authorization.jwt.secret=<secreto-local-solo-pruebas> \
  --fitsense.ai.enabled=false --fitsense.ai.api-token= \
  --fitsense.cors.allowed-origins=http://localhost:5050 \
  --fitsense.password-reset.delivery=email --fitsense.mail.transport=smtp \
  --spring.mail.host=127.0.0.1 --spring.mail.port=2525 --fitsense.mail.from=kora-pruebas@e2e.local \
  --fitsense.cycle.manual-run.enabled=true \
  --fitsense.plan-generation.heartbeat-ms=5000 --fitsense.plan-generation.lease-seconds=15 \
  --fitsense.plan-generation.max-processing-seconds=300 --fitsense.plan-generation.initial-delay-ms=1000 \
  --server.port=8080
