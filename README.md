# Repeat

Aplicación personal de hábitos para iPhone y computador, inspirada en la experiencia de Habit Tracker. Interfaz en español, tarjetas de colores, hábitos ilimitados y sincronización privada.

La app principal actual es [Repeat nativa para iOS](ios/README.md). Desde la versión 1.7 guarda en el iPhone y retira la sincronización con la web. La integración privada de iCloud está preparada, pero la firma gratuita actual impide activarla. Las secciones de cliente web que siguen describen la versión anterior, que continúa separada.

## Funciones

- Crear y editar hábitos: icono, nombre, descripción, color, grupo, construir/dejar, meta y unidad.
- Metas diarias, semanales, mensuales o por ciclos; días específicos y cuotas de días por periodo.
- Registro de cantidades, corrección de valores, confirmación de límites y restablecimiento del progreso conservando las notas.
- Temporizador y cronómetro; el tiempo en curso se recupera en el mismo navegador tras una recarga. Los reintentos de guardado de tiempo no duplican el registro.
- Calendario, rachas, cuadrícula anual e informes semanales/mensuales/anuales con datos reales.
- Notas, estado de ánimo, grupos personales, archivo reversible y tema oscuro.
- Exportación JSON de todos los datos y CSV de registros; los archivos se generan en el navegador.

## Uso en ambos dispositivos

Abre el enlace publicado en ambos dispositivos e inicia sesión con la misma cuenta de ChatGPT. Sites mantiene el acceso privado. Los registros viven en D1; se actualizan al volver a la app y cada 15 segundos mientras está visible. Los cambios de apariencia y los temporizadores en curso son propios de cada navegador.

En iPhone abre el enlace en Safari y usa Compartir → Añadir a pantalla de inicio. Se necesita conexión para cargar y guardar registros; esta versión no incluye una cola de cambios sin conexión.

## Límites de esta versión

No incluye integración automática con Apple Health, widgets de iOS, Dynamic Island, funciones sociales ni notificaciones con la app cerrada. Los recordatorios son avisos dentro de la app cuando está abierta. La copia JSON es de exportación; la restauración mediante importación aún no está implementada.

## Arquitectura

Diagrama de alto nivel: [arquitectura de Repeat](docs/architecture/README.md), con vista previa, HTML interactivo y fuente editable.

- React con App Router mediante el starter Vinext de Sites.
- `components/repeat.tsx`: navegación, registros, sincronización y temporizadores.
- `components/editor.tsx`: formulario con selectores al estilo de la referencia.
- `components/analytics.tsx`: calendario, estadísticas e informes.
- `lib/habits.ts`: esquema validado, programación, metas y rachas.
- `app/api/state/route.ts`: API con identidad de Sites, comprobación de origen, validación y scoping por usuario en todas las consultas.
- `db/schema.ts` y `drizzle/`: tablas y migraciones D1. Los incrementos usan transacciones y recibos para evitar duplicación por reintentos.
- `.openai/hosting.json`: identidad y binding de publicación. No contiene secretos.

## Desarrollo local

Node.js >=22.13 y dependencias del starter. Para instalar y compilar con Sites sigue su skill y sus helpers. `npm run dev` inicia la vista local con autenticación simulada de desarrollo; no se incluye en el build de producción. La base local está aislada de producción.

Generar una migración: `npm run db:generate`.

Después de compilar, aplicar cada migración pendiente en orden:

```sh
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_curly_tusk.sql
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0001_great_lizard.sql
```

No volver a ejecutar migraciones ya aplicadas. Sites aplica las de producción durante la publicación.

## Verificación

```sh
npx tsc --noEmit
node --experimental-strip-types --test tests/habits.test.ts
npm start -- --port 8787
# En otra terminal, contra ese build local:
node --experimental-strip-types --test tests/api.test.mjs
```

La prueba API crea datos sintéticos en usuarios QA locales. No se debe ejecutar contra producción. La inspección de la referencia y los límites de observación están documentados en `docs/reference-audit.md`.
