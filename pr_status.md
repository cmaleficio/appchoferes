# Mokup del proyecto:

Desarrollar una app android con un administrador web para registrar el dinero asignado y gastado por choferes.

 - Cada chofer cumple una ruta (Debe ser grabada en GPS)
 - Al registrar un chófer se crea un usuario para el mismo, permitiéndole registrar gastos, siempre y cuando tome la foto del recibo.Esta foto debe guardarse en la db en cuanto tenga conexión a internet.
 - Alguien desde el panel administrativo asigne montos de dinero al chófer y este de allí vaya descontando con cada gasto del chófer.
 - El chófer puede grabar un audio como descripción.
 - Se pueden crear etiquetas en las descripciones para que un gasto tenga más de una etiqueta.
 - Al registrar el gasto se captura la ubicación GPS del equipo.

# AGENTES
    Agents.md contiene toda la informacion del proyecto.

# Hoja de ruta
    
    [Fase 1: Backend & DB] ──> [Fase 2: Admin Panel] ──> [Fase 3: Mobile Base] ──> [Fase 4: Hardware & IA] ──> [Fase 5: Sync & Reportes]

###  Fase 1: Base del Backend y Modelo de Datos
Diseño de la base de datos relacional y los endpoints críticos de autenticación y sincronización inicial de rutas.

Entregables: Migraciones de base de datos, API base con FastAPI, hashing de contraseñas y seeders para las rutas actuales.

### Fase 2: Panel Administrativo (Gestión y Asignación)
Construcción de la interfaz web para el control de dinero y visualización de choferes.

Entregables: CRUD de choferes, vista de asignación de presupuesto (tabla de saldos), interfaz para jalar/sincronizar rutas externas.

### Fase 3: Aplicación Móvil (Estructura Local y Login)
Configuración del entorno offline-first en la app móvil.

Entregables: Interfaz de login (con sesión persistente local), almacenamiento local con Isar de las rutas descargadas y formulario base de registro de gastos en modo desconectado.

### Fase 4: Captura de Hardware e Integración de IA
Implementación de los módulos de captura física y el procesamiento inteligente de la descripción del gasto.

Entregables: Captura de coordenadas GPS automáticas al abrir el formulario, apertura de cámara para adjuntar foto, grabación de audio (.mp4/.m4a) y endpoint en el backend que reciba el audio, invoque a Whisper para la transcripción y aplique lógica de etiquetado automático.

### Fase 5: Motor de Sincronización y Reportes Administrativos
Cierre del ciclo de datos: subida en segundo plano y analítica para la toma de decisiones.

Entregables: Lógica de sincronización diferida en la app móvil, vista en el panel administrativo con gráficos de barras/pasteles de los gastos más fuertes por etiqueta y alertas visuales de choferes excedidos o con saldo bajo.

# CODDING
- Backend scaffold (models, routers, auth, FastAPI) completed for Phase 1
- Phase 2: Admin Panel completed.
  - New routers: `users.py` (`GET /api/users`, `GET /api/users/me`), `budgets.py` (`GET /api/budgets`, `POST /api/budgets`), `routes.py` (`GET /api/routes`, `GET /api/routes/{id}/tracks`).
  - Updated `expenses.py`: added `GET /api/expenses/`, `GET /api/expenses/requests`, `PUT /api/expenses/requests/{id}/approve`, `PUT /api/expenses/requests/{id}/reject`.
  - Fixed missing `CORSMiddleware` import in `main.py` and registered new routers. Version bumped to `0.2.0`.
  - Admin UI at `frontend/index.html` (Vue 3 + Tailwind CDN, SPA):
    - Dashboard: tabla de choferes con saldos, modal para cargar presupuesto, botón de sincronizar rutas.
    - Auditoría: selector chofer/ruta, tabla de `route_tracks`, gráfico SVG de curva de descarga de batería, resumen de inicio/fin/descarga.
    - Solicitudes: listado de `expense_requests` pendientes, botones Aprobar/Rechazar, formulario inline de edición del gasto al aprobar (flujo: approve → PUT expense).
    