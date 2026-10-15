# Verificación · 13 de octubre de 2026

Historia comprobada: crear más de cinco hábitos desde una interfaz parecida a la referencia → API autenticada → D1 → recuperar el mismo progreso en una segunda sesión.

- TypeScript sin errores y build Vinext de producción correcto.
- Nueve pruebas de lógica: días y fechas, acumulación semanal, hábitos a dejar con límite cero, cuotas semanales, ciclos, rachas y validación.
- Prueba de integración contra el Worker compilado y D1 local: ocho hábitos; persistencia; aislamiento entre dos usuarios simulados; 401 anónimo; 403 origen externo; 400 datos inválidos; 404 hábito de otro usuario; incrementos concurrentes sin pérdidas; reintentos únicos; notas conservadas al restablecer; archivo y recuperación; estado de ánimo.
- Computer / navegador: creación y edición, completar meta, nota y ánimo; cambio de unidad a segundos; cuenta atrás de dos segundos que guarda exactamente dos; calendario refleja la meta.
- Segunda pestaña: ocho hábitos y el cambio del agua aparece al recargar.
- Vistas de 390×844 y escritorio de 1280×900 revisadas; anillos y detalle corregidos; consola del navegador sin errores durante estas pruebas.

Todos los datos de prueba son locales. La publicación empieza vacía para que el propietario cree sus hábitos. La autenticación real y el acceso desde el iPhone físico dependen del inicio de sesión del propietario en el sitio publicado; no se simulan como una prueba completada en hardware.

## Privacidad e iCloud · Repeat 1.7 (build 8)

- La app nativa retiró las peticiones a la API de Sites y el inicio de sesión WebKit/ChatGPT. La web anterior continúa separada; no se borraron sus datos.
- CloudKit preparado con base privada, payload en campos cifrados, comparación de versión, fragmentos/manifiesto atómicos y recibos para reintentos. El estado manual, la cola y el vínculo iCloud se guardan juntos; Salud permanece fuera del payload. La restauración manual solo informa éxito tras guardar.
- Pasaron 79 comprobaciones del modelo y persistencia (63 previas y 16 de reconciliación privada). No son pruebas de red con iCloud.
- Compilación de simulador con iCloud habilitado y en modo local: correcta. Build firmado para el iPhone en modo local: correcto.
- Xcode rechazó la capacidad iCloud para el equipo personal gratuito. No se compró membresía, no se creó contenedor y no se verificó subida, descifrado, recuperación o eliminación reales en CloudKit. La build instalada lo indica expresamente y ofrece exportación manual.
- UI de simulador comprobada mediante CUA: Mi espacio → Privacidad e iCloud, aviso de firma y entrada a Copia y exportación. No se introdujeron datos ficticios en el iPhone.
- Instalada sobre la app anterior con el mismo bundle ID, sin desinstalar. Todos los archivos de Documents tras instalar coincidieron byte por byte con la copia previa, incluido estado, cola y Salud. Las copias y logs permanecen solo en `outputs/`, ignorado por Git.
- La apertura física mediante devicectl fue rechazada por teléfono bloqueado. Mirroring pide desbloquear el iPhone. Esto no invalida la instalación, pero la interfaz física todavía no está comprobada para esta versión.
