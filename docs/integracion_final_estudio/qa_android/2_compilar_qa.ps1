# Kora · QA Android · 2) Compilacion de PRUEBAS (debug). Nunca una APK de produccion ni de Google Play.
# Instala en el telefono conectado por USB y apunta al Backend de pruebas del PC mediante adb reverse.
# Uso (en la carpeta de MobileApp, en la rama o commit que se valida):  .\2_compilar_qa.ps1 -Telefono <id de adb devices>
param([Parameter(Mandatory = $true)][string]$Telefono, [switch]$SinRecuperacion)
$ErrorActionPreference = "Stop"
adb -s $Telefono reverse tcp:8080 tcp:8080
adb -s $Telefono reverse --list
git log --oneline -1   # anota este commit como «Versión de Kora» en la matriz
$defines = @("--dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1", "--dart-define=ALLOW_INSECURE_API=true")
# Recuperacion: SOLO en esta compilacion de QA (el codigo sale en la consola del Backend de pruebas).
if (-not $SinRecuperacion) { $defines += "--dart-define=PASSWORD_RECOVERY_ENABLED=true" }
flutter run --debug -d $Telefono @defines
