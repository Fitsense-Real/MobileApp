# 08 · Pruebas en Android físico

**Estado: ninguna prueba física realizada.** Este entorno no tiene teléfono ni emulador, y ningún documento del
repositorio registra una ejecución en un dispositivo. Todo lo que sigue está **pendiente de ejecución por el
propietario**; no se presenta ningún resultado de dispositivo.

## 1. Guía base

`docs/o20/validacion/GUIA_ANDROID.md`. La versión de la **PR #25 (fusionada el 27/11/2026, `f8f5e24`)**
corrige lo que la auditoría señaló como desactualizado: compilar el Backend (`mvnw.cmd -DskipTests package`), arrancarlo
con IA y push apagados, y cuándo se registra el teléfono para push. Para no chocar con esa PR, esta guía **no edita**
`GUIA_ANDROID.md`: la complementa con las pruebas del cierre. Ahora que la PR #25 está fusionada, conviene incorporar
este documento a la guía (M-39). Matriz rellenable para dos teléfonos: [`12_MATRIZ_DOS_TELEFONOS.csv`](12_MATRIZ_DOS_TELEFONOS.csv).

Compilación de prueba (nunca de producción), en Android Studio o PowerShell:

```powershell
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1 --dart-define=PASSWORD_RECOVERY_ENABLED=true
```

Para probar documentos, añadir las direcciones y versiones de **documentos de prueba** (nunca presentados como
aprobados) y configurar las mismas versiones en el Backend de pruebas.

## 2. Pruebas por PR (además de §5–§7 de la guía base)

Cuenta: **sintética** salvo que se indique. Usuario 48: solo lectura, como en la guía base.

| N.º | PR | Acción | Resultado esperado | Resultado |
|---|---|---|---|---|
| A1 | M1 | Registro sin marcar participación → «Crear sin participar» | Entra y ve «Por ahora no hay una rutina para ti»; no hay perfil ni «Generando» | PENDIENTE |
| A2 | M1 | «Volver a comprobar» y «Cerrar sesión» en esa pantalla | Relee la cuenta; vuelve al login | PENDIENTE |
| A3 | M1 | Registro marcando participación | Entra directamente al perfil sin volver a escribir la clave | PENDIENTE |
| A4 | M1 | Zona horaria: abrir la lista y elegir otra | Se guarda la elegida; nada se escribe a mano | PENDIENTE |
| A5 | M1 | (Con documentos de prueba configurados) leer, aceptar y registrarse; cambiar la versión del Backend y repetir | Versión enviada; con versión cambiada, «Los documentos cambiaron» y la cuenta no se crea | PENDIENTE |
| B1 | M2 | «¿Olvidaste la clave?» → correo → «Enviar código» | Pantalla del código con «Lo pediste para…» | PENDIENTE |
| B2 | M2 | Cerrar Kora del todo, reabrir → «¿Olvidaste?» → «Ya tengo un código» | Pantalla del código sin pedir otro | PENDIENTE |
| B3 | M2 | Copiar el código (del log local, o del correo cuando exista) y «Pegar código» | Se pega sin espacios; 204; login con el correo escrito | PENDIENTE |
| B4 | M2 | Repetir con el mismo código | «El código no es válido, ya se usó o caducó…» | PENDIENTE |
| B5 | M2 | **Con proveedor de correo real** | El correo llega; la recuperación termina en < 3 min | PENDIENTE (bloqueado por Backend) |
| C1 | M3 | Abrir un ejercicio desde «Ver instrucciones» y tocando la animación | Ficha completa; anterior/siguiente; volver deja la rutina igual | PENDIENTE |
| C2 | M3 | «Pausar animación», «Ampliar» y pellizcar | Se pausa; se amplía con zoom | PENDIENTE |
| C3 | M3 | Activar «Quitar animaciones» del sistema | Los GIF quedan quietos | PENDIENTE |
| C4 | M3 | Modo avión con la rutina abierta por primera vez | Mensaje sin imagen; el resto funciona | PENDIENTE |
| D1 | M4 | Rutina de 8 ejercicios: Comenzar → Marcar varios → Seleccionar todos → Confirmar → Finalizar | ≤ 12 toques; 8 resultados en el Backend; resumen correcto | PENDIENTE |
| D2 | M4 | Parcial serie por serie | Total correcto; mismo resultado en el Backend que con totales | PENDIENTE |
| D3 | M4 | «Tengo dolor o molestias» → «Guardar» | 2 toques; exclusión O20 en Perfil | PENDIENTE |
| D4 | M4 | D3 en modo avión; cerrar Kora; reabrir | Resultado «Pendiente de enviar» (P1), no se envía solo | PENDIENTE |
| E1 | M5 | Texto del sistema al 130 % y al 200 % en Inicio, Rutinas, Progreso, Perfil y la rutina | Nada cortado ni superpuesto | PENDIENTE |
| E2 | M5 | TalkBack en la rutina y el diálogo de resultado | Todo se anuncia; los GIF no | PENDIENTE |
| E3 | M5 | Activar recordatorios en Perfil, cerrar Kora y tocar el aviso del día | Abre Rutinas tras restaurar la sesión | PENDIENTE |
| E4 | M5 | Ayuda y soporte; Progreso sin métricas | Preguntas y contacto; explicación del lunes | PENDIENTE |
| F1 | Push | Con un Backend **de pruebas** con credenciales de Firebase autorizadas: generar el primer plan con la app abierta, en segundo plano y cerrada | Aviso `PLAN_GENERATED` en `kora_planes`; al tocarlo abre el plan | PENDIENTE (requiere credenciales de servidor; **nunca a participantes reales**) |
| F2 | Plataforma | Instalar encima de una versión anterior sin desinstalar | Sesión conservada (migración de almacenamiento seguro) | PENDIENTE |
| F3 | Plataforma | Restaurar una copia de seguridad en otro teléfono (M-22) | La app arranca y pide iniciar sesión sin errores | PENDIENTE |
| F4 | Plataforma | Ahorro de batería de Samsung activado | Recordatorios y push llegan o el retraso se documenta | PENDIENTE |
| F5 | Rendimiento | Sesión de 40 min con pantalla encendida en un gama baja | Fluidez, batería y temperatura anotadas | PENDIENTE |

Teléfonos: al menos **uno de gama baja (Android 11–13) y uno de gama media (Android 15–16)**.

## 3. Evidencia a enviar

Por cada fila: OK/FALLA, modelo y versión de Android, y para cada fallo `adb logcat -d`, `adb exec-out screencap -p` y,
si ayuda, `adb shell screenrecord` (guía base §8).
