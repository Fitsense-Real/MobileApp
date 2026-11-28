# Kora · QA Android · 1) Backend de PRUEBAS (nunca el de participantes ni la base real).
# Base nueva aislada, IA y push apagados, correo dev-log (el codigo de recuperacion sale en esta consola).
# Documentos SINTETICOS (evidencia/documentos_sinteticos): publicalos en una direccion https con certificado valido que
# controle el equipo (los telefonos no aceptan certificados propios). Su referencia de aprobacion dice que NO son reales.
# Uso, en la carpeta del Backend (generation 41c498a o posterior, compilado con mvnw.cmd -DskipTests package):
#   $env:JWT_SECRET_PRUEBAS = "<clave local de pruebas, 64+ caracteres>"
#   $env:DOCS_BASE = "https://<host-de-pruebas>/kora-sintetico"
#   $env:PG_USER = "postgres"; $env:PG_PASSWORD = "<clave de tu PostgreSQL local>"   # base kora_qa_android ya creada y vacia
#   .\1_backend_de_pruebas.ps1                      # documentos sinteticos y exigencia encendida (solo aqui)
#   .\1_backend_de_pruebas.ps1 -VersionTerminos T-QA-2   # para A6 (version cambiada)
#   .\1_backend_de_pruebas.ps1 -SinDocumentos       # para A7 (registro cerrado)
param([switch]$SinDocumentos, [string]$VersionTerminos = "T-QA-1")
$ErrorActionPreference = "Stop"
if (-not $env:JWT_SECRET_PRUEBAS) { throw "Define JWT_SECRET_PRUEBAS (solo para este Backend de pruebas)." }
Remove-Item Env:REPLICATE_API_TOKEN, Env:OPENAI_API_KEY, Env:FITSENSE_FIREBASE_CREDENTIALS_BASE64, Env:FITSENSE_FIREBASE_CREDENTIALS_FILE -ErrorAction SilentlyContinue
$a = @(
  "-jar", "target\fitsense-backend-0.0.1-SNAPSHOT.jar", "--spring.profiles.active=local-dev",
  "--spring.datasource.url=jdbc:postgresql://localhost:5432/kora_qa_android", "--spring.flyway.url=jdbc:postgresql://localhost:5432/kora_qa_android",
  "--spring.datasource.username=$env:PG_USER", "--spring.datasource.password=$env:PG_PASSWORD",
  "--spring.flyway.user=$env:PG_USER", "--spring.flyway.password=$env:PG_PASSWORD",
  "--authorization.jwt.secret=$env:JWT_SECRET_PRUEBAS",
  "--fitsense.ai.enabled=false", "--fitsense.ai.api-token=", "--fitsense.push.enabled=false", "--fitsense.cycle.manual-run.enabled=false",
  "--fitsense.password-reset.delivery=dev-log", "--server.port=8080"
)
if (-not $SinDocumentos) {
  if (-not $env:DOCS_BASE) { throw "Define DOCS_BASE (https con certificado valido) o usa -SinDocumentos." }
  $docs = @(
    @("TERMS_OF_SERVICE", $VersionTerminos, "[SINTETICO] Condiciones de uso", "$env:DOCS_BASE/terminos-$VersionTerminos.txt"),
    @("PRIVACY_POLICY", "P-QA-1", "[SINTETICO] Politica de privacidad", "$env:DOCS_BASE/privacidad-P-QA-1.txt"),
    @("STUDY_PARTICIPATION", "C-QA-1", "[SINTETICO] Consentimiento informado", "$env:DOCS_BASE/consentimiento-C-QA-1.txt"))
  for ($i = 0; $i -lt $docs.Count; $i++) {
    $d = $docs[$i]
    $a += "--fitsense.legal-documents.items[$i].type=$($d[0])", "--fitsense.legal-documents.items[$i].version=$($d[1])",
      "--fitsense.legal-documents.items[$i].title=$($d[2])", "--fitsense.legal-documents.items[$i].url=$($d[3])",
      "--fitsense.legal-documents.items[$i].status=PUBLISHED", "--fitsense.legal-documents.items[$i].effective-from=2026-11-01",
      "--fitsense.legal-documents.items[$i].approval-reference=PRUEBA-QA-SINTETICA (no es una aprobacion real)"
  }
  $a += "--fitsense.consent.enforce-on-signup=true"
}
Write-Host "Backend de PRUEBAS. Comprueba: Invoke-RestMethod http://localhost:8080/api/v1/legal-documents"
& java @a
