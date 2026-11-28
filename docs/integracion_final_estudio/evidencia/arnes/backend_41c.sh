#!/bin/bash
# Backend 41c498a LOCAL para la integracion final: base aislada, IA y push apagados, correo dev-log,
# exigencia de consentimientos FORZADA (solo aqui) y documentos SINTETICOS (approval-reference dice que no es real).
# Uso: backend_41c.sh [version_terminos] [documentos: si|no] [registros_por_ip]
T=${1:-T-QA-1}; DOCS=${2:-si}; REG=${3:-300}
cd "${BACKEND_DIR:?ruta del clon del Backend en 41c498a}"
unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy JAVA_TOOL_OPTIONS REPLICATE_API_TOKEN FITSENSE_AI_ENABLED _JAVA_OPTIONS
D=()
if [ "$DOCS" = si ]; then
 i=0
 for spec in "TERMS_OF_SERVICE|$T|[SINTETICO] Condiciones de uso|https://localhost:8443/terminos-$T.txt" \
             "PRIVACY_POLICY|P-QA-1|[SINTETICO] Politica de privacidad|https://localhost:8443/privacidad-P-QA-1.txt" \
             "STUDY_PARTICIPATION|C-QA-1|[SINTETICO] Consentimiento informado|https://localhost:8443/consentimiento-C-QA-1.txt"; do
  IFS='|' read ty ve ti ur <<< "$spec"
  D+=("--fitsense.legal-documents.items[$i].type=$ty" "--fitsense.legal-documents.items[$i].version=$ve" "--fitsense.legal-documents.items[$i].title=$ti"
      "--fitsense.legal-documents.items[$i].url=$ur" "--fitsense.legal-documents.items[$i].status=PUBLISHED" "--fitsense.legal-documents.items[$i].effective-from=2026-11-01"
      "--fitsense.legal-documents.items[$i].approval-reference=PRUEBA-LOCAL-SINTETICA (no es una aprobacion real)")
  i=$((i+1))
 done
 D+=("--fitsense.consent.enforce-on-signup=true")
fi
exec java -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttp.nonProxyHosts=localhost \
 -jar target/fitsense-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=local-dev \
 --spring.datasource.url=jdbc:postgresql://localhost:5432/kora_integracion_final --spring.datasource.username=postgres --spring.datasource.password=x \
 --spring.flyway.url=jdbc:postgresql://localhost:5432/kora_integracion_final --spring.flyway.user=postgres --spring.flyway.password=x \
 --authorization.jwt.secret=${JWT_SECRET_LOCAL:?define una clave local de pruebas} \
 --fitsense.ai.enabled=false --fitsense.ai.api-token= --fitsense.cycle.manual-run.enabled=false --fitsense.push.enabled=false \
 --fitsense.password-reset.delivery=dev-log --fitsense.cors.allowed-origins=http://localhost:5050 \
 --fitsense.plan-generation.initial-delay-ms=1000 --fitsense.auth-rate-limit.register-per-ip=$REG --fitsense.auth-rate-limit.login-per-ip=600 \
 --server.port=8080 "${D[@]}"
