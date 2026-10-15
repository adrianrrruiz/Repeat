# Repeat · landing pública

Landing estática e independiente de la app nativa y del cliente web privado de Sites. Se despliega en un proyecto propio de Vercel desde este directorio, sin variables de entorno, backend ni datos de hábitos reales.

## Vista local

Desde la raíz del repositorio:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory landing
```

## Diseño

Skills seleccionadas del catálogo [UI Skills](https://www.ui-skills.com/): [frontend-design](https://www.ui-skills.com/skills/anthropics/frontend-design) y [better-ui](https://www.ui-skills.com/skills/jakubkrehel/better-ui). Dirección y tokens en `DESIGN.md`.

La demostración funciona exclusivamente en memoria: cantidades, progreso proporcional, completar y reiniciar. Los ejemplos de tiempo e historial se cambian mediante pestañas accesibles por teclado. FAQ usa disclosures nativos; los diálogos tienen foco y cierre con Escape.

Fuentes Bricolage Grotesque y Manrope servidas localmente, con licencias OFL en `assets/`. No hay analítica, formularios, cookies propias ni solicitudes a una API de hábitos. El diálogo de privacidad distingue el procesamiento técnico del alojamiento en Vercel de los registros privados de la app. La página informa que el lanzamiento público y la activación de iCloud siguen pendientes.

## Publicación

Ejecutar Vercel CLI desde `landing/`, vinculando explícitamente el proyecto antes del despliegue. `vercel.json` usa una salida estática y cabeceras de seguridad. La identidad local de Vercel permanece ignorada por Git.

Producción: https://repeat-landing-murex.vercel.app/

Proyecto de Vercel: `repeat-landing`, equipo Adrian Projects. El despliegue se realiza por CLI; la conexión automática de GitHub no está habilitada.
