# Repeat para iOS

App nativa en Swift y SwiftUI, instalada directamente en el iPhone del propietario el 13 de octubre de 2026. Bundle ID: `com.adrianruiz.repeat`.

## Abrir el proyecto

Abre `Repeat.xcodeproj` en Xcode y selecciona el scheme Repeat. El proyecto utiliza la firma automática con el equipo de desarrollo ya configurado en este Mac. No se incluyen credenciales ni certificados privados en el código.

## Qué incluye

- Hábitos ilimitados y formulario nativo: icono, color, grupo, construir/dejar, cantidades, unidades, periodos, frecuencia, horarios y fechas.
- Lista diaria con anillos semanales y tarjetas de progreso.
- Guardado local protegido en Documents; migra el guardado anterior de App Group. Los widgets usan únicamente un resumen en App Group, notas, estado de ánimo y archivo reversible.
- Temporizador persistente y cronómetro.
- Calendario, informes semanales/mensuales/anuales y cuadrícula anual.
- Recordatorios nativos, con permiso solicitado al guardar avisos. Programa los siguientes avisos y renueva la programación al abrir la app; iOS limita la cantidad de avisos pendientes.
- Catálogo por categorías y creación personalizada, siguiendo el flujo observado.
- La creación solo cierra después de una escritura correcta. Si falla, muestra el error y conserva el formulario. Cada borrador se guarda por identificador. Al volver a Hábito personalizado se recupera el último pendiente sin avisos adicionales.
- Derecha: completar; izquierda: añadir, saltar y ocultar. Saltar excluye el día de las rachas/informes; ocultar solo cambia la vista en este iPhone. Ambos se revierten desde «Saltados y ocultos».
- Eliminar desde ⋯ en la ficha del hábito o el menú al mantener pulsada la tarjeta, con confirmación antes de quitar el hábito y sus registros.
- Rachas actuales y mejores, gestión, ordenación, duplicación y eliminación de hábitos; cambio de nombre de grupos.
- Restauración JSON con validación, exportación JSON/CSV e informes compartibles.
- Lectura de Apple Health por fuente elegida, con historial exclusivamente local; permiso solicitado por el usuario al guardar.
- Widgets de inicio y pantalla bloqueada, registro desde widgets y temporizador con Actividad en Vivo/Dynamic Island.
- Bloqueo Face ID/código, temas claro/oscuro/sistema, frases y vista semanal configurable.

## Privacidad e iCloud (1.7, build 8)

La app nativa guarda primero en el iPhone y ya no realiza peticiones a Sites, OpenAI ni a la API de la web. El cliente web anterior continúa separado: esta actualización no borra sus datos ni cambia su acceso.

Mi espacio → Privacidad e iCloud explica el estado real de la instalación. La configuración de desarrollo gratuita instala la app en modo local: **iCloud no está activo y todavía no existe una copia confirmada por esta integración**. La interfaz ofrece exportación JSON y restauración manual.

La integración preparada usa CloudKit exclusivamente en la base privada de la cuenta de Apple de la persona, con campos cifrados para el snapshot y los recibos. La primera activación pide combinar los hábitos, conservando valores locales en coincidencias; después utiliza operaciones con recibos y guardado atómico. Las metas por fecha, notas y saltos permanecen en el snapshot. Las lecturas/correcciones de Salud, cookies, borradores y sesiones de temporizador no entran al payload.

El estado, la cola, la cuenta vinculada y la última sincronización confirmada se persisten juntos. Los cambios hechos durante una petición se conservan. Un cambio de cuenta o una copia remota eliminada/reemplazada detiene el envío para evitar mezclas o resucitar la copia. La primera combinación deliberada puede restaurar datos locales: la interfaz lo explica antes de activar.

La copia cifrada se divide en registros y se publica con un manifiesto, comparación de versión y escritura atómica en una zona privada. Cada publicación retira los fragmentos de la generación anterior. Eliminar la copia borra esa zona y desactiva la sincronización, conservando los hábitos locales. No se promete un historial de respaldos ni recuperación de cambios todavía pendientes. La validación de snapshots conserva el límite actual de 10 MB de la importación; errores de cuota/tamaño/red no vacían la cola. Con varios dispositivos se reintenta un conflicto; algunas operaciones sobre hábitos borrados requieren revisión si la validación no permite aplicarlas.

### Habilitación pendiente de Apple

Xcode confirmó que el equipo personal gratuito actual no admite iCloud. Para habilitarlo se necesita una firma compatible, registrar `iCloud.com.adrianruiz.repeat` para el bundle existente y configurar en CloudKit los tipos `RepeatManifest` (campo `chunks`, lista de cadenas) y `RepeatEncryptedChunk` (campo cifrado `payload`, Bytes). El esquema debe desplegarse al entorno correspondiente antes de distribución. No se contrató ninguna membresía ni se creó el contenedor.

Los ajustes `REPEAT_CLOUD_FLAGS=REPEAT_ICLOUD` y `REPEAT_CLOUD_ENTITLEMENTS=Repeat/RepeatCloud.entitlements` activan la variante iCloud solo en el target principal; no deben usarse con la firma gratuita. La configuración predeterminada conserva `Repeat.entitlements` y no intenta acceder a CloudKit. Compilar la variante con el simulador no prueba la conexión a una cuenta ni su recuperación.

Pendiente, tras disponer de firma/contenedor: probar subida real, descifrado en otro iPhone de la misma cuenta, pérdida de red, cuota, conflictos entre dispositivos y borrado. No marcar la protección con iCloud como operativa antes de completar esas pruebas.

## Compilar e instalar

```sh
xcodebuild -project ios/Repeat.xcodeproj -scheme Repeat -configuration Debug -destination 'id=00008120-001C14223E63C01E' -derivedDataPath ios/build -allowProvisioningUpdates build
xcrun devicectl device install app --device 81498727-3564-539A-A0AE-7C73C955DF16 ios/build/Build/Products/Debug-iphoneos/Repeat.app
xcrun devicectl device process launch --device 81498727-3564-539A-A0AE-7C73C955DF16 com.adrianruiz.repeat
```

El perfil de desarrollo instalado vence el 20 de octubre de 2026 a las 19:22, hora de Bogotá. Antes o después de esa fecha, vuelve a compilar e instalar con el mismo bundle ID para renovar la firma conservando los datos. No desinstales la app para renovarla.

No es una distribución de App Store o TestFlight. La lectura real de Salud requiere que el propietario conceda permisos. La ejecución interactiva de widgets y Actividades en Vivo no se ha comprobado con hábitos reales. La alerta reforzada tiene intervalos propios de 5, 10 y 15 minutos. El medidor propietario de estrés y las funciones sociales no están incluidos.

## Verificación realizada

- Build para arm64 físico: `BUILD SUCCEEDED`.
- Firma automática y perfil de desarrollo generados por Xcode.
- Instalación confirmada por devicectl y proceso iniciado en el iPhone 14 Pro conectado.
- Pantalla inicial y formulario comprobados mediante iPhone Mirroring, sin crear hábitos de prueba en el teléfono.
- Veintinueve comprobaciones de fechas, frecuencia, metas, límites y codificación/persistencia:

```sh
xcrun swiftc ios/Repeat/Models.swift ios/Repeat/Metrics.swift ios/Repeat/Persistence.swift ios/Tests/main.swift -o ios/build/model-tests
ios/build/model-tests
```

## Regresión de creación, versión 1.2

- En el simulador se forzó un fallo real del destino de escritura: el formulario mostró el error, mantuvo todos los valores y no creó un hábito fantasma.
- Tras reiniciar el proceso, El borrador recuperó nombre, descripción, grupo, meta decimal y unidad. Guardar después de restaurar el destino persistió esos campos y retiró el borrador.
- Un segundo borrador con icono, color, periodo personalizado, ciclo/días, franja, memo y fechas futuras pasó por Crear y se verificó campo por campo en disco.
- Se comprobaron las acciones nativas Añadir, Saltar, Ocultar, Mostrar y el diálogo de eliminación en el simulador. El gesto físico de arrastre del control remoto en Simulator produjo un toque; queda por verificar el deslizamiento real en el iPhone actualizado.

La versión 1.3 elimina la confirmación visual Hábito guardado y las filas Continuar. El botón Actualizar Salud también permite solicitar o revisar el permiso del tipo conectado.

## Versión 1.4

- La navegación inferior muestra solo iconos. El registro de ánimo se retira de Hoy, Mi espacio y notas, conservando los datos antiguos.
- Cada tarjeta se rellena horizontalmente según su porcentaje real. El texto mantiene contraste sobre ambas zonas.
- Meditación conectada a Salud permite corregir el tiempo registrado del día en Repeat. La corrección se guarda localmente, sobrevive a refrescar Salud y puede retirarse con Usar tiempo de Apple Health. No modifica muestras de HealthKit.
- Verificado desde la interfaz del simulador: cambiar 2,5 a 4 minutos, persistencia de la corrección y lectura original intacta. Inspección de tarjetas al 0, 40, 60 y 100 %, navbar sin textos y ausencia del registro de ánimo.
- Siete comprobaciones adicionales cubren correcciones, notas, refresco, restauración del valor original y compatibilidad de configuración.

## Versión 1.5

- Fichas a pantalla completa con fondo del hábito y controles inferiores. Cantidades: anillo, incrementos −/+, teclado y confirmación. Tiempo: reloj grande, cuenta atrás/cronómetro, estilo circular o cifras divididas y sonidos ambiente locales.
- El teclado de registro convierte sec/min/hr a la unidad correspondiente a esa fecha, acepta decimales y guarda antes de cerrar. También acepta teclado externo.
- Calendario del hábito, cuadrícula anual compacta y cuatro tarjetas de estadísticas. Tocar un día abre directamente su registro. Los identificadores del calendario son únicos para mostrar también la primera semana.
- Sueño tiene ficha propia con duración, meta, gráfica y fases disponibles de HealthKit. Peso muestra gráfica, cambio desde el registro anterior, distancia a la meta y promedio de 30 días. No se calculan clasificaciones médicas ni IMC sin altura.
- Las metas, unidades, tipo, periodo y frecuencia tienen versiones por fecha. Editar permite elegir Aplicar cambios de meta desde (hoy o una fecha futura); los registros, porcentajes e informes anteriores usan su configuración original. Una unidad nueva nunca se suma con la anterior dentro de un periodo que cruce el cambio.
- Historial incluido en JSON, sincronización y widgets; CSV usa la unidad de cada fecha. Los temporizadores conservan la unidad con la que iniciaron y mantienen la sesión si falla guardar.
- API conserva el historial al renombrar desde un cliente anterior y rechaza cambiar su métrica si ese cliente omite el historial.
- 51 comprobaciones nativas y 14 pruebas del modelo web. Prueba de API local con sesión de desarrollo: guardar/releer historial, conservar un registro cumplido y compatibilidad con clientes anteriores (`node --test tests/history-api.test.mjs`, servidor local 5173).
- QA de interfaz: añadir 3 minutos (10→13), incremento de cantidad, día anterior con 20/20 frente a meta actual 30, corregir meditación 2,5→4 y restaurar lectura original. Datos de prueba separados del iPhone del propietario.


## Filtros de Hoy, versión 1.6 (build 7)

El botón superior abre un panel como el observado en Habit: Estado (Todos, Pendientes, Completados) y Horario (Todos, Ahora, Cualquier hora, Mañana, Tarde, Noche). Cambiar estado mantiene el panel abierto; elegir horario lo cierra y actualiza la cápsula del encabezado. Los grupos siguen disponibles si existen. La selección se conserva localmente.

- Build de Simulator y del iPhone: `BUILD SUCCEEDED`.
- Pasaron las 63 comprobaciones nativas, con nuevas combinaciones de estado/horario, días programados y cumplimiento según metas históricas.
- QA visual en Simulator: panel, cambio de estado sin cierre, resultados pendientes/completados, Mañana, Ahora, título del botón y cierre con Escape. El estado persistido y la cola permanecieron iguales tras filtrar.
- Evidencia local: `outputs/repeat-filters-1-6.png` (datos ficticios, ignorada por Git).
- Contexto, preferencias y reglas para siguientes agentes en `../AGENTS.md`.

La versión 1.6 se instaló sobre la anterior sin desinstalar. La copia del estado y la cola tras instalar fue idéntica a la copia previa; se conservaron los nueve hábitos activos presentes en esa copia.
La app actualizada se abrió y el panel de filtros se comprobó también mediante iPhone Mirroring en el dispositivo físico.

## Verificación 1.7

- 79 comprobaciones nativas: las 63 anteriores y 16 de copia privada/reconciliación, recibos, migración, borrado y aislamiento del formato portable. Son pruebas locales, no una subida a iCloud.
- Compilación de simulador con la variante iCloud y con el modo local: correcta.
- Compilación de dispositivo con la firma gratuita y modo local: correcta. Xcode rechaza expresamente habilitar iCloud con ese equipo.
- Interfaz de simulador: Mi espacio → Privacidad e iCloud muestra la limitación real; la alternativa de exportación abre Copia y exportación.
- Instalada en el iPhone del propietario conservando el bundle ID. Documents coincidió byte por byte con la copia local previa. La apertura física quedó bloqueada por el bloqueo del teléfono; Mirroring solicita desbloquearlo. La interfaz del teléfono para esta versión aún no está comprobada.
