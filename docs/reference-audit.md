# Referencia de Habit Tracker

Inspección mediante Computer / iPhone Mirroring el 13 de octubre de 2026. No se guardaron cambios ni se compró una suscripción.

- Hoy (primera inspección, corregida abajo): filtro superior, anillos de progreso semanales, tarjetas pastel antes de completar y color sólido después. Icono, nombre, descripción opcional, valor/meta, racha. Barra inferior flotante.
- Registrar: círculo central con icono, valor/meta, incremento, confirmar, memo y estadísticas. Unidades temporales habilitan temporizador.
- Formulario observado en Editar: icono, nombre, descripción, color, grupo, construir/dejar, Apple Health, periodo diario/semanal/mensual/personalizado, valor/unidad, frecuencia, franja horaria, recordatorios y memo tras completar.
- Unidades: cantidad (sin unidad, count, steps, m, km, mile, ml, oz, Cal, g, mg, drink, personalizada); tiempo (sec, min, hr).
- Frecuencia: todos los días; días de semana; cantidad de días por semana; días del mes; cantidad de días por mes; días de cada ciclo; cantidad por ciclo.
- Estadísticas: calendario mensual, cuadrícula anual, éxitos del mes/totales, racha actual/mejor. General: filtro por hábito y tasa mensual.
- Informes: semanal/mensual/anual; tabla coloreada. La cuenta original muestra un informe de ejemplo de pago.
- Diario: nota y cinco estados de ánimo.
- Social: compartir hábitos requiere iCloud y notificaciones. Fuera del alcance personal.
- Ajustes: gestor de hábitos/grupos, tema, backup, exportación, idioma, opciones semanales. Perfil muestra estado de ánimo y citas.

## Creación observada después de liberar un hábito

El catálogo muestra categorías Popular, Health y Sports, filas con emoji, nombre, distintivo de Apple Health y botón +, además del botón flotante Custom Habit. Se observaron Walk, Sleep, Drink water, Meditation, Run, Stand, Cycling, Workout y calorías. El corazón indica Salud, no favoritos.

Custom Habit abre nombre vacío, descripción, emoji, color menta, grupo, construir/dejar, Health apagado, periodo diario, 1 count/día, todos los días, franja Anytime, recordatorios apagados y memo tras completar encendido. Walk abre nombre e icono predefinidos, azul, Health encendido y 10000 pasos diarios. No se guardó ninguno. El desplazamiento remoto no permitió leer con fiabilidad toda la parte inferior.

Repeat 1.1 reproduce ese catálogo y formulario con identidad y código propios. Integra Salud de solo lectura, widgets, Actividad en Vivo, bloqueo, rachas, gestión, restauración JSON y exportación CSV. El historial de Salud permanece en el teléfono y no se envía a Sites. Compartir, competir y grupos sociales quedan fuera del uso personal. La alerta reforzada repite avisos a los 5, 10 y 15 minutos; no se pudo observar el intervalo exacto de Super Alert. El medidor propietario de estrés no se ha reproducido.

## Fichas interiores, 14 de octubre de 2026

Inspección en vivo con iPhone Mirroring de lectura, Agradecer, sueño y peso. El propietario autorizó utilizar la aplicación anterior para pruebas. Se probó un incremento en lectura y Agradecer; no se eliminaron hábitos ni se cambiaron permisos.

- Cantidades: fondo suave del color del hábito, círculo central con emoji, cantidad y meta; controles −/+; fila inferior de restablecer, Añadir y confirmar. Nota y estadísticas abajo; ⋯ para editar, archivar y eliminar.
- Tiempo: círculo grande con tiempo restante, iniciar/pausar, restablecer y +; teclado propio de cuatro columnas con dígitos, borrar, decimal, confirmar y selector sec/min/hr. Estilo alternativo de cifras divididas y cambio entre cuenta atrás y cronómetro. Nota y estadísticas.
- Estadísticas del hábito: calendario mensual, estado anual y cuatro tarjetas de éxitos/rachas. Tocar un día abre el registro numérico con su fecha, valor/meta y acciones de saltar/completar.
- Sueño: anillo con duración/meta, resumen, gráfica temporal y fases disponibles; nota y estadísticas.
- Peso: cifra grande, gráfica histórica, variación desde el registro previo, distancia a la meta y promedio reciente. Repeat utiliza los datos de peso ya autorizados; no solicita altura para calcular IMC.

Repeat 1.5 reproduce esas distribuciones y flujos en SwiftUI. El sonido ambiente se genera localmente y las cifras divididas usan vistas propias. Las fases de sueño se leen exclusivamente en el iPhone y aparecen sin datos cuando la fuente no las registra.


## Filtros superiores, 14 de octubre de 2026

Inspección directa del panel de Habit mediante iPhone Mirroring, sin crear ni borrar hábitos. Corrige la interpretación inicial de que el botón superior solo filtraba grupos.

- Cápsula rosa compacta All con chevron; sin cápsula exterior blanca. Panel desde arriba, fondo muy claro, esquinas inferiores redondeadas y resto de la pantalla atenuado, incluida la barra inferior.
- Status: All, Unmet, Met en un control segmentado. Cambiar estado deja abierto el panel y filtra inmediatamente. El botón superior no adopta el nombre del estado.
- Time: All, Now, Anytime, Morning, Afternoon, Evening en chips que saltan de línea. Elegir horario cierra el panel y cambia el título del botón superior. Tocar fuera cierra también.
- Now observado por la tarde incluye hábitos Anytime y de esa franja; excluye los de Evening. Morning no incluye los hábitos Anytime.
- En ambas aplicaciones no había grupos activos; el original mostró solo esas dos filas. Repeat conserva los grupos existentes mediante una fila adicional cuando los haya.

Repeat 1.6 implementa estas opciones en español. «Ahora» usa hora local: mañana de 06:00 a 11:59, tarde de 12:00 a 17:59 y noche el resto; esos límites exactos no se pudieron observar en la referencia. El estado se obtiene del progreso de la fecha seleccionada y sus metas históricas. Los filtros son preferencias locales; no escriben en el historial ni en la cola de sincronización.
