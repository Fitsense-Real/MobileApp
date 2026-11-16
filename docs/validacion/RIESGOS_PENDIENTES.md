# Riesgos y pendientes (cierre del primer bloque del Mobile)

| # | Riesgo o pendiente | Impacto | Qué hacer |
|---|---|---|---|
| 1 | **Android real sin probar** | Medio: el código es el mismo que en web, pero no se vieron en un teléfono los plugins nativos, el almacenamiento seguro, las notificaciones ni el rendimiento | Seguir `GUIA_INSTALACION_APK.md` en un teléfono |
| 2 | iOS sin compilar ni probar | Medio para una futura publicación en iPhone | Mac con Xcode |
| 3 | TalkBack/VoiceOver reales | Bajo: el árbol de semántica está verificado | Prueba manual en el teléfono |
| 4 | Backend #72 en borrador | La app no depende de él (contrato idéntico), pero se probó contra su head; si cambia el contrato antes del merge, hay que repetir | Revisar `interfaces/rest` antes de fusionar |
| 5 | Zona del teléfono distinta de la del perfil | Durante unas horas alrededor de medianoche, la etiqueta de días puede ir un día por delante o por detrás de la semana del backend | Aceptable para el estudio (America/Lima); si importa, usar la zona del perfil en la app |
| 6 | V55 sin interruptor en la app | Ninguno hoy: la API no lo expone y el permiso está apagado | Al activarlo en el backend, añadir el campo al recurso REST y un interruptor en el paso 5 |
| 7 | Progreso del tour solo en el teléfono | Si se reinstala la app, el tour empieza de nuevo; el plan no se pierde | Campo en el backend si se quiere conservar entre dispositivos |
| 8 | APK release firmado con la clave debug y sin HTTP | No sirve para Play ni para el backend local | Clave de firma propia y backend HTTPS antes de publicar |
| 9 | `applicationId` `com.example.fitsense_mobile` | Play no acepta `com.example` | Definir el identificador definitivo antes de publicar |
| 10 | CI del Mobile aún no ejecutado en GitHub | Se activa al integrarse en `generation` | Revisar el primer run |
| 11 | Concurrencia del backend (`max-concurrent=2`) | Con muchas altas a la vez, algunas esperan en cola; la app lo muestra como espera | Dimensionarlo en el backend |
| 12 | `CurrentPlanCard` sin usar | Ninguno | Eliminar en una limpieza futura |

## Comprobado y sin riesgo abierto

- Rutinas duplicadas: 0 en las dos rondas E2E.
- Operaciones perdidas tras cerrar la app o reiniciar el backend: 0.
- Accesos cruzados entre usuarios: 0.
- Cargas infinitas: el backend cierra toda operación en 30 min como máximo.
- Mensajes falsos: el repaso del tour es neutro y la etiqueta de días es correcta.
