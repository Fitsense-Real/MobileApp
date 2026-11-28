# Kora · QA Android · 3) Evidencia de una fila de la matriz (OK o FALLA).
# Uso: .\3_evidencia.ps1 -Telefono <id> -Fila D8 [-Video 30]
param([Parameter(Mandatory = $true)][string]$Telefono, [Parameter(Mandatory = $true)][string]$Fila, [int]$Video = 0)
$ErrorActionPreference = "Stop"
$dir = "evidencia_qa\$Fila-$Telefono-$(Get-Date -Format yyyyMMdd-HHmmss)"; New-Item -ItemType Directory -Force $dir | Out-Null
"modelo: $(adb -s $Telefono shell getprop ro.product.model)" | Out-File "$dir\telefono.txt"
"android: $(adb -s $Telefono shell getprop ro.build.version.release) (API $(adb -s $Telefono shell getprop ro.build.version.sdk))" | Add-Content "$dir\telefono.txt"
"kora: $(git log --oneline -1)" | Add-Content "$dir\telefono.txt"
adb -s $Telefono exec-out screencap -p > "$dir\pantalla.png"
adb -s $Telefono logcat -d -t 2000 > "$dir\logcat.txt"
if ($Video -gt 0) { adb -s $Telefono shell screenrecord --time-limit $Video /sdcard/kora_qa.mp4; adb -s $Telefono pull /sdcard/kora_qa.mp4 "$dir\video.mp4"; adb -s $Telefono shell rm /sdcard/kora_qa.mp4 }
Write-Host "Evidencia en $dir. Revisa que el logcat no contenga datos personales antes de compartirlo."
