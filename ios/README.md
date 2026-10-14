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

## Sincronizar con el computador

Mi espacio → Conectar con el computador. Inicia sesión con la misma cuenta de ChatGPT que utilizas en la web y pulsa Comprobar. Solo el inicio de sesión utiliza WebKit; las pantallas de la app son SwiftUI.

Las cookies permanecen en el almacén del sistema. Las peticiones a la API únicamente reciben las cookies correspondientes al dominio de Repeat, nunca se imprimen ni se exportan. El cliente evita seguir redirecciones de API hacia otros dominios.

Los cambios sin conexión se conservan en una cola local con identificadores estables y se envían al conectar. Los incrementos usan los recibos del servidor para evitar duplicación por reintentos. Los temporizadores en curso son propios de cada dispositivo.

La sincronización necesita que el propietario complete el inicio de sesión en el teléfono; esa autenticación personal no se hizo durante la instalación. Si el proveedor de identidad rechaza el navegador integrado, la conexión necesita un flujo nativo de autenticación adicional. Los hábitos locales continúan disponibles.

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
xcrun swiftc ios/Repeat/Models.swift ios/Repeat/Metrics.swift ios/Repeat/Persistence.swift ios/tests/main.swift -o ios/build/model-tests
ios/build/model-tests
```

## Regresión de creación, versión 1.2

- En el simulador se forzó un fallo real del destino de escritura: el formulario mostró el error, mantuvo todos los valores y no creó un hábito fantasma.
- Tras reiniciar el proceso, El borrador recuperó nombre, descripción, grupo, meta decimal y unidad. Guardar después de restaurar el destino persistió esos campos y retiró el borrador.
- Un segundo borrador con icono, color, periodo personalizado, ciclo/días, franja, memo y fechas futuras pasó por Crear y se verificó campo por campo en disco.
- Se comprobaron las acciones nativas Añadir, Saltar, Ocultar, Mostrar y el diálogo de eliminación en el simulador. El gesto físico de arrastre del control remoto en Simulator produjo un toque; queda por verificar el deslizamiento real en el iPhone actualizado.

La versión 1.3 elimina la confirmación visual Hábito guardado y las filas Continuar. El botón Actualizar Salud también permite solicitar o revisar el permiso del tipo conectado.
