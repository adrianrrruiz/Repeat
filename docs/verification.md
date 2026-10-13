# Verificación · 13 de octubre de 2026

Historia comprobada: crear más de cinco hábitos desde una interfaz parecida a la referencia → API autenticada → D1 → recuperar el mismo progreso en una segunda sesión.

- TypeScript sin errores y build Vinext de producción correcto.
- Nueve pruebas de lógica: días y fechas, acumulación semanal, hábitos a dejar con límite cero, cuotas semanales, ciclos, rachas y validación.
- Prueba de integración contra el Worker compilado y D1 local: ocho hábitos; persistencia; aislamiento entre dos usuarios simulados; 401 anónimo; 403 origen externo; 400 datos inválidos; 404 hábito de otro usuario; incrementos concurrentes sin pérdidas; reintentos únicos; notas conservadas al restablecer; archivo y recuperación; estado de ánimo.
- Computer / navegador: creación y edición, completar meta, nota y ánimo; cambio de unidad a segundos; cuenta atrás de dos segundos que guarda exactamente dos; calendario refleja la meta.
- Segunda pestaña: ocho hábitos y el cambio del agua aparece al recargar.
- Vistas de 390×844 y escritorio de 1280×900 revisadas; anillos y detalle corregidos; consola del navegador sin errores durante estas pruebas.

Todos los datos de prueba son locales. La publicación empieza vacía para que el propietario cree sus hábitos. La autenticación real y el acceso desde el iPhone físico dependen del inicio de sesión del propietario en el sitio publicado; no se simulan como una prueba completada en hardware.
