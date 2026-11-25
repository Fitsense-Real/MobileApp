# Guía breve: probar O20 en tu teléfono Android

**No lo probé en un teléfono físico:** no tengo ninguno disponible. Esta guía es para que lo pruebes tú con tu celular, contra el **Backend de pruebas** (nunca contra producción).

## 1. Preparar

1. **Backend de pruebas** (`generation` con #83 y #84; migración V65) en tu PC, con IA apagada para no gastar créditos:
   - `--fitsense.ai.enabled=false`;
   - sin `REPLICATE_API_TOKEN` ni `OPENAI_API_KEY`.
   - Ejemplo de arranque: `docs/o20/evidencia/backend-local.sh`.
2. **Mismo Wi-Fi:** el teléfono y el PC en la misma red. Averigua la IP del PC (`ipconfig` en Windows).
3. **Instalar Kora en modo debug,** apuntando a ese Backend:

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://IP_DEL_PC:8080/api/v1
   ```

   El modo debug permite HTTP local. Para las notificaciones push hacen falta los archivos locales de Firebase (`docs/push/`).
4. **Dos cuentas:**
   - **Demo Kora,** solo para mirar: cargada con `dataset_demo_kora` 01–05, según su README, en la base de pruebas. **No generes planes ni omitas sesiones con ella.**
   - **Una cuenta sintética nueva para las acciones:** regístrala desde la app con el consentimiento marcado, completa el perfil y genera el primer plan. Sin IA lo genera el motor de reglas.

## 2. Qué comprobar

Marca cada punto y, si algo falla, haz una captura.

| N.º | Qué hacer | Qué debes ver |
|---|---|---|
| 1 | Inicia sesión con Demo Kora | Entra a Inicio sin errores |
| 2 | Mira la rutina vigente (Demo Kora) | La semana con 5 entrenamientos; ninguno marcado «No disponible por ahora» |
| 3 | Perfil → Ejercicios excluidos por dolor (Demo Kora) | «Te dolieron: Aperturas de pecho sentado con palanca. Lo marcaste con dolor · 05/11/2026», con «Ya no me duele». **No lo pulses** con la demo |
| 4 | Con la cuenta sintética, abre un entrenamiento y pulsa «Omitir entrenamiento» → «Dolor o molestias» | Aparece «Gracias por avisar» con «Más tarde» / «Indicar ahora» |
| 5 | Pulsa «Más tarde». Abre otro entrenamiento de la semana | Si repite algún ejercicio de la sesión omitida: «No disponible por ahora», con una explicación sin códigos («Estaba en una sesión en la que reportaste dolor sin indicar qué ejercicio fue.») |
| 6 | En ese ejercicio pulsa «Registrar ejercicio» | Solo se ofrece «No lo hice», con motivo. No aparecen «Lo completé» ni «Lo hice parcialmente» |
| 7 | Comienza la sesión: registra el bloqueado como no realizado y los demás como completados. Finaliza | La sesión se guarda (parcial o completa) con los permitidos |
| 8 | Perfil → Ejercicios excluidos por dolor → la sesión con dolor → «Responder» | Elige el que dolió; marca 1 o 2 como «no tuvieron nada que ver». El que dolió no se puede marcar también. «Enviar» muestra qué vuelve a proponerse y qué sigue excluido |
| 9 | Vuelve a la rutina | Los que marcaste como no relacionados ya no están bloqueados; los no nombrados siguen bloqueados |
| 10 | Cierra la app del todo (deslízala fuera de recientes) y vuelve a abrirla. Repite cerrando sesión y entrando otra vez | Las mismas exclusiones y el mismo bloqueo. La sesión del punto 7 sigue registrada |
| 11 | Con la rutina abierta, manda la app a segundo plano, omite por dolor en otro dispositivo o desde la API, y vuelve a la app | Al volver, la rutina se actualiza sola y muestra el bloqueo |
| 12 | Sin Wi-Fi, intenta registrar trabajo en un ejercicio que quedó bloqueado | Al recuperar la red, el Backend lo rechaza y la app lo explica: «Este ejercicio ya no puede registrarse con trabajo realizado…» |

## 3. Qué enviarme

- La tabla con OK o FALLA en cada punto.
- Las capturas de lo que falle.
- El modelo del teléfono y la versión de Android.
