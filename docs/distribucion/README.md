# Cierre del Mobile de Kora

**Base:** `generation` `fb01dd5`, con las PR #1–#11 integradas. Cada trabajo de cierre va en su propia PR, todas sin
fusionar hasta tu autorización.

| PR | Alcance | Fusión |
|---|---|---|
| #12 | Lista de la prueba en Android físico y emulador, en Windows (solo documentación) | Cuando quieras |
| #13 | `flutter_local_notifications` 23 y `flutter_secure_storage` 10 (migración de la sesión) | **Después** de la prueba de actualización en Android (`ACTUALIZACION_NOTIFICACIONES_ALMACENAMIENTO.md`) |
| #14 | **Recordatorios en release** (ícono que sobreviva al *shrinker*), ícono adaptativo, evidencia de 16 KB, AAB firmado y bloqueos de release | Cuando quieras. Conflicto de una línea con la #13 (`reminder_scheduler.dart`) |
| #15 | **El recorrido no se pierde** al cerrar la app durante los 30 s, más la auditoría funcional 32/32 | Cuando quieras |
| #16 (esta) | Distribución beta, inventario de Play Console y conexión al backend de producción (documentación y script) | Cuando quieras |

**Orden sugerido para fusionar:**
1. #15;
2. #14;
3. #12;
4. #16;
5. #13, tras la prueba en Android. Al fusionar la #13 después de la #14, conservar `settings:` y `'ic_stat_kora'` en
   `reminder_scheduler.dart`.

## Documentos

| Documento | Para qué |
|---|---|
| `DISTRIBUCION_BETA.md` | Firebase App Distribution: requisitos, compilar y distribuir, instalación de los evaluadores y actualizaciones |
| `../../tool/beta/distribuir_beta.sh` | Compila la beta firmada y la distribuye. Se niega si falta la clave, la URL https, el identificador o las páginas |
| `INVENTARIO_PLAY_CONSOLE.md` | Qué está cumplido y qué falta: políticas, seguridad de los datos (borrador), declaración de salud, ficha (borradores de descripción y capturas 1080 × 1920) y credenciales del revisor |
| `CONEXION_BACKEND_PRODUCCION.md` | Requisitos del backend desplegado, cómo compilar contra él, entornos y prueba de humo |
| `capturas_ficha/` | 6 borradores de capturas para Play (datos sintéticos) y su generador. Usa los helpers del arnés E2E (`kora.js`, `register.js`, `profile.js`, `aud-lib.js`) |

## Qué depende de terceros o de ti

Sin estos puntos no se puede distribuir fuera de una PC de desarrollo:
1. **Backend HTTPS desplegado**, de pruebas y de producción, con S-1 y B-6 resueltos antes de tener participantes
   reales.
2. **`applicationId` aprobado y clave de subida** creada en tu computadora.
3. **Política de privacidad y página de eliminación** publicadas, aprobadas por el comité de ética.
4. **Prueba en Android real** (PR #12), en Windows.
5. En Play Console:
   - seguridad de los datos;
   - declaración de salud;
   - clasificación de contenido;
   - ficha y gráfico destacado;
   - cuenta del revisor;
   - verificación del desarrollador;
   - prueba cerrada de 12 evaluadores durante 14 días.
