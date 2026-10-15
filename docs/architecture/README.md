# Arquitectura de Repeat

Vista de alto nivel centrada en la persona que usa Repeat en iPhone. Los doce componentes muestran la app nativa, el guardado local, la sincronización opcional, los servicios alojados y las ramas de Salud, widgets y cliente web.

![Diagrama de arquitectura de Repeat](repeat-preview.png)

- [Diagrama interactivo](repeat.html): descarga el archivo y ábrelo en un navegador. GitHub muestra el código del HTML.
- [Fuente editable de Archify](repeat.architecture.json).
- [Código usado como referencia](https://github.com/adrianrrruiz/Repeat/tree/4d692ecf58fc1c8611baeb94a31d04c0501b3452).

El camino principal comienza en la app, actualiza el motor y guarda el estado junto con las operaciones pendientes en el iPhone. Tras guardar, una cuenta conectada permite sincronizar mediante la API con D1. Motor y sincronización son responsabilidades de `HabitStore`, no servicios separados.

Las lecturas y correcciones de Apple Health permanecen en el iPhone. Los widgets usan un resumen local del App Group. La API exige identidad y separa los datos por usuario. El público objetivo es cualquier persona con iPhone; el acceso actual al sitio continúa siendo privado.

No se verificaron la sesión o disponibilidad actuales de producción, la región de D1 ni las políticas operativas de respaldo. El diagrama describe el código revisado, sin afirmar un despliegue público.

Generado con Archify. Las referencias de archivo y línea de cada componente se conservan en el JSON y en el visor. La entrega pasa validación del artefacto y comprobaciones automáticas en navegador; la vista previa procede de la misma entrega.
