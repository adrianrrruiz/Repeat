# Repeat — instrucciones y contexto para agentes

## Colaboración con el propietario

- Responde en español. Si tienes dudas reales sobre la intención de una solicitud, pregunta para aclararlas antes de implementar la parte dudosa. Continúa con el trabajo independiente que sí esté claro.
- El usuario quiere cambios terminados y comprobados en su aplicación. Para cambios de iOS, compila e instala la actualización en su iPhone cuando esté disponible; no te limites a editar archivos o proponer pasos.
- Explica de forma breve qué cambió, qué comprobaste y cualquier límite real. Distingue compilación, instalación, apertura y prueba de interfaz: una no demuestra las otras.
- Evita pedir de nuevo autorizaciones ya dadas. Una consulta sobre distribución o precios no autoriza comprar membresías, invitar personas ni ampliar el acceso al sitio.

## Producto y prioridades

- Repeat es un planificador de hábitos ilimitados. Nació como alternativa personal a Habit Tracker, referencia de App Store `id1438388363`.
- La aplicación principal actual es **nativa de iOS con Swift y SwiftUI**. Hay también un cliente web para el computador; no sustituyas la app nativa por una web encapsulada.
- El usuario pide que la interfaz y los flujos se sientan como la app original. Inspecciona la referencia antes de inventar su funcionamiento. Reutiliza la estructura observada con código y recursos propios.
- La app original está disponible mediante iPhone Mirroring en este Mac. El usuario dejó de usarla y autorizó crear/eliminar hábitos allí para explorar. Prioriza inspección y pruebas no destructivas cuando sean suficientes; esto **no autoriza borrar o reemplazar sus datos de Repeat**.
- No hace falta recorrer todo el catálogo: ejemplos de cantidades, tiempo, sueño, peso y meditación cubren sus tipos de hábito actuales.
- El usuario quiere que su hermano pueda ser un primer probador sin pagar aún la membresía de Apple. Todavía no hay una instalación ni invitación autorizada para su hermano. Mantén cuentas y datos separados cuando se implemente.

## Decisiones de experiencia que se deben conservar

- No imponer límite de cinco hábitos ni funciones de suscripción para el uso personal.
- Barra inferior solo con iconos; conservar nombres accesibles para VoiceOver.
- No mostrar el registro de ánimo («Cómo me siento hoy» y variantes). Conservar datos antiguos existentes, sin borrarlos para ocultar la interfaz.
- No restaurar el aviso «Hábito guardado» ni las filas «Continuar: <hábito>». Los borradores se recuperan silenciosamente mediante el flujo existente.
- Las tarjetas se rellenan horizontalmente según el porcentaje real de progreso, con contraste legible en ambas zonas. Un 40 % debe ocupar el 40 % del ancho.
- Deslizamiento derecho: completar. Izquierdo: Añadir, Saltar y Ocultar. El usuario ya confirmó el gesto físico en su iPhone. Saltar excluye el día de rachas/informes; ocultar es una preferencia local reversible.
- Filtros de Hoy: cápsula rosa compacta y panel desde arriba, fondo atenuado y esquinas inferiores redondeadas. Estado: Todos/Pendientes/Completados, sin cerrar el panel al cambiar. Horario: Todos/Ahora/Cualquier hora/Mañana/Tarde/Noche; elegir cierra y actualiza el texto del botón. «Ahora» incluye cualquier hora más la franja actual; una franja específica excluye cualquier hora. Conservar selección local, sin modificar hábitos, registros ni sincronización. Grupo aparece como fila adicional solo si hay grupos.
- Eliminar desde la ficha, gestión o menú contextual, con confirmación. Archivar conserva historial.
- Cantidades: círculo central, emoji, valor/meta, −/+, añadir, confirmar, nota y estadísticas.
- Tiempo: reloj central, iniciar/pausar, cuenta atrás o cronómetro, estilo circular o cifras divididas, sonido, teclado sec/min/hr, nota y estadísticas.
- Sueño y peso tienen fichas propias. No inventar fases de sueño, clasificaciones médicas ni IMC sin los datos necesarios.
- El calendario del hábito abre directamente el registro de la fecha seleccionada, usando la meta y unidad de esa fecha.

## Invariantes de datos: críticos

- **Nunca perder un formulario personalizado al fallar el guardado.** Guardar de forma atómica antes de cerrar; ante un error, conservar campos/borrador, mostrar el problema y permitir reintentar.
- `StateFile` y la cola de operaciones deben persistir juntos. `HabitStore.mutate` revierte el estado en memoria si falla escribir. No convertir fallos en éxitos silenciosos.
- No borrar la app para actualizarla o renovar su firma. Reinstalar con el mismo bundle ID conserva los datos.
- Antes de instalar cambios, hacer una copia local del contenedor Documents del iPhone. Tras instalar, comparar el estado con esa copia. No publicar archivos de datos, notas, cookies, perfiles ni certificados.
- Los datos ficticios van **solo en el simulador**, nunca en el teléfono real. Comprueba el destino y vuelve a resolver su contenedor después de cada reinstalación: su UUID puede cambiar.
- **Editar una meta no debe reinterpretar el pasado.** `Habit.metricHistory` guarda versiones de tipo, meta, unidad, periodo y frecuencia, con `effectiveDate`. El editor permite aplicar desde hoy o una fecha futura.
- Usa `habit.at(date)` al mostrar unidades/metas, completar, iniciar temporizadores, exportar CSV, calcular progreso o construir widgets de una fecha. Conserva valores, notas y cumplimiento anteriores.
- No sumar unidades de versiones distintas en un periodo que cruce un cambio. Los límites de periodo se recortan por versión.
- La sincronización y los JSON deben conservar `metricHistory`. El servidor protege el historial cuando un cliente anterior lo omite. Los temporizadores retienen la unidad con que arrancaron.

## Privacidad y sincronización desde 1.7

- La prioridad es la app móvil y recuperar los hábitos si se pierde el iPhone. Mac, Windows y una posible web de análisis quedan para después.
- Los hábitos no deben pasar por un servidor propio de Repeat, Sites/OpenAI o Cloudflare. Desde 1.7 el cliente nativo eliminó WebKit/cookies/API de Sites de su flujo de conexión; la web anterior continúa separada y no se borraron sus datos.
- iCloud es opcional y usa la cuenta privada de Apple de la persona. La app funciona localmente sin cuenta. No afirmar que los datos nunca salen del teléfono cuando se activa una nube.
- `CloudSync.swift` prepara la base privada CloudKit con campos cifrados y una zona/manifiesto atómicos. `CloudReplica.swift` conserva recibos y combina el primer envío sin duplicar incrementos. El vínculo de cuenta/época/última sincronización está en `SavedState.cloud`, junto con estado y cola.
- **La firma gratuita actual no admite iCloud**, confirmado por Xcode. La build instalada permanece local; no existe una prueba de subida/recuperación real. No contratar membresías sin petición expresa.
- Para una firma compatible: contenedor `iCloud.com.adrianruiz.repeat`, `REPEAT_CLOUD_FLAGS=REPEAT_ICLOUD` y `REPEAT_CLOUD_ENTITLEMENTS=Repeat/RepeatCloud.entitlements`; esquema y pruebas pendientes en `ios/README.md`. No cambiar el bundle ID.
- No reactivar el backend antiguo como alternativa si iCloud falla. Conservar datos/cola y ofrecer exportación manual. Sincronización no equivale a historial de respaldos; no prometer recuperar cambios pendientes.
- La copia de iCloud incluye el snapshot manual y recibos, nunca `HealthConfiguration`, lecturas/correcciones de Salud ni cookies. Borrar la copia requiere confirmación y conserva el estado local.

## Apple Health

- Integración de **solo lectura**. Los permisos los concede el propietario en iOS; no inferir permiso de lectura a partir de ausencia de muestras.
- Los valores y correcciones de Salud permanecen en el iPhone. No enviarlos a Sites ni incluirlos en la cola de sincronización, copias/exportaciones normales o fixtures del repositorio.
- Meditación se conectó a Atención plena (`mindful`), con meta inicial de cinco minutos. El usuario ya autorizó su lectura.
- La edición que pidió el usuario para Meditación era el **tiempo registrado**, no la meta. Se implementó una corrección local del total del día en Repeat, sin modificar muestras de HealthKit.
- Las correcciones sobreviven a Actualizar Salud y se pueden retirar con «Usar tiempo de Apple Health». Preservar notas y lectura original separada.
- Sueño usa `sleep`; peso usa `weight`. Las fases se consultan localmente y se muestran sin datos si no están disponibles.

## Arquitectura y archivos

- `ios/Repeat.xcodeproj`: proyecto Xcode; schemes/targets Repeat y RepeatWidgets.
- `ios/Repeat/Models.swift`: modelos Codable, fechas, versiones de métricas y progreso.
- `ios/Repeat/Store.swift`: estado observable, operaciones, persistencia, sincronización, Salud, temporizador y recordatorios.
- `ios/Repeat/Persistence.swift`: escritura del estado y borradores.
- `ios/Repeat/NativeStorage.swift`: resúmenes de widgets y configuración/correcciones locales de Salud.
- `ios/Repeat/Views.swift`: navegación y lista Hoy; `TodayFilters.swift`: panel de estado/horario y distribución de chips; `HabitDetail.swift`, `MetricPad.swift` y `Analytics.swift`: fichas, teclado y estadísticas.
- `ios/Repeat/HabitEditor.swift`: formulario completo. El guardado debe seguir conservando todos sus campos.
- `ios/Repeat/HealthIntegration.swift`, `SleepSummary.swift`: lecturas de HealthKit y detalle de sueño.
- Estado principal: `Documents/repeat-state-v2.json`. Salud: `Documents/repeat-health-local.json`. Antes se usaba App Group v1; conservar la migración.
- App Group `group.com.adrianruiz.repeat` contiene el resumen de widgets, no el estado principal ni la cola.
- Bundle principal `com.adrianruiz.repeat`; extensión `com.adrianruiz.repeat.widgets`. No cambiar estos identificadores para actualizar al propietario.
- Web: `components/`, modelos/reglas en `lib/habits.ts`, API `app/api/state/route.ts`, tablas D1 declaradas en `db/schema.ts`. Los datos se separan por usuario autenticado.
- Sitio existente: https://repeat-habitos-personal.freevenus7.chatgpt.site. Identidad de Sites en `.openai/hosting.json`. Es privado del propietario; no cambiar audiencia sin petición expresa.
- Si cambias el sitio o su API, usa la skill Sites y conserva su proyecto/audiencia. Si solo cambias Swift o documentación local, no hace falta desplegar la web.

## Validación e instalación

- Comandos de compilación, dispositivo y firma en `ios/README.md`. Descubre el dispositivo actual si no está conectado; no supongas que los identificadores o la firma siguen vigentes.
- Incrementa versión/build para actualizaciones instaladas. Última actualización: Repeat 1.7, build 8 (privacidad e integración iCloud preparada; firma gratuita en modo local), el 14 de octubre de 2026.
- Pruebas nativas del modelo y persistencia:

  ```sh
  swiftc ios/Repeat/Models.swift ios/Repeat/Metrics.swift ios/Repeat/Persistence.swift ios/Repeat/NativeStorage.swift ios/Repeat/CloudReplica.swift ios/Tests/main.swift -o /tmp/repeat-native-tests
  /tmp/repeat-native-tests
  ```

- Web: `node --test tests/habits.test.ts` y `npx tsc --noEmit`. `tests/history-api.test.mjs` usa el servidor local de Sites en 5173 y solo admite localhost; nunca ejecutarlo contra producción.
- `tests/api.test.mjs` usa cabeceras de identidad para un entorno de pruebas distinto. El preview portable de Sites las elimina y usa su inicio de sesión local; un 401 allí no demuestra que la API de la app esté rota. No debilitar autenticación para hacer pasar un test.
- En 1.6 pasaron 63 comprobaciones nativas. En la base 1.5 pasaron además 14 del modelo web y la prueba de API del historial; no se modificó la web en 1.6. Volver a leer los tests: los números pueden crecer.
- QA visual y datos de prueba anteriores en `outputs/` (ignorado por Git). No añadir capturas de datos reales de Salud al repositorio.
- Referencia observada: `docs/reference-audit.md`. Historial de implementación/verificación: `ios/README.md` y `docs/verification.md`.

## Control del iPhone y simulador

- Usar Computer Use/CUA para interacciones visuales. App de mirroring: `com.apple.ScreenContinuity`; simulador: `com.apple.iphonesimulator`.
- iPhone Mirroring expone pocos elementos accesibles; normalmente requiere captura y coordenadas. ⌘1: inicio; ⌘2: selector de apps; ⌘3: Spotlight. Tras abrir Spotlight, observar antes de escribir.
- Usar `scroll`, no `drag`, para desplazamiento vertical. Un gesto remoto puede convertirse en toque: no rehacer un gesto nativo correcto basándose solo en esa limitación.
- A veces las capturas salen pequeñas, inclinadas, desactualizadas o fallan con ScreenCaptureKit. Recuperar la app/estado y realizar una observación fresca; no repetir indefinidamente ni afirmar haber visto una pantalla que no se pudo leer.
- Simulator permite acciones por índices de accesibilidad. Tras cerrar una hoja, puede ser necesario volver a obtener la app para actualizar el árbol. El teclado propio admite dígitos y Return con teclado externo; Escape cierra vistas compatibles.
- Los `ForEach` del calendario deben tener identificadores distintos para cabeceras y fechas. En cuadrículas de 52 columnas usar `.flexible(minimum: 0)` para no ensanchar ni recortar la pantalla.

## Distribución: contexto, no autorización para pagar

- La instalación actual es de desarrollo mediante Xcode, no App Store ni TestFlight. La firma gratuita requiere renovación periódica; comprobar la expiración real y actualizar conservando datos.
- Se explicó al usuario que TestFlight no tiene tarifa adicional para probar; subir builds con una cuenta propia requiere Apple Developer Program. La membresía estándar consultada el 14 de octubre de 2026 costaba US$99/año; verificar condiciones actuales antes de aconsejar o contratar.
- Alternativas comentadas para su hermano: compilar con su cuenta gratuita mediante Xcode, estudiar AltStore Classic, o habilitar su propio acceso web. Ninguna se ha ejecutado. No compartir cuentas, hábitos ni permisos del propietario como atajo.
