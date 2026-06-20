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

## Fase 1 — Backend (Completada ✅)
- FastAPI scaffold con routers, auth JWT, hashing argon2.
- Modelos: User, Expense, Route, RouteTrack, Budget, Tag, ExpenseRequest.
- MySQL via XAMPP, async SQLAlchemy, Pydantic v2.

## Fase 2 — Admin Panel (Completada ✅)
- Routers: users (GET/POST/DELETE soft), budgets (GET/POST con exchange rate), expenses (GET/PUT/requests), routes, telemetry, logs, exchange_rates (GET/POST/BCV scrape), deposits (GET/POST).
- Frontend SPA (Vue 3 + Tailwind CDN):
  - Dashboard: cards resumen, tabla choferes, modal presupuesto + Bs./tasa BCV, modal depósitos, botón sincronizar rutas.
  - Auditoría: filtros chofer/ruta, mapa Leaflet con polyline, curva SVG batería, tabla de puntos.
  - Solicitudes: bandeja con aprobar/rechazar + edición inline.
  - Usuarios: tabla activos/inactivos, crear, desactivar (soft-delete).
  - Tasas: tarjeta última tasa + botón "Obtener del BCV", tabla histórica.
  - Bitácora: tabla de logs con usuario, acción, recurso, detalle, IP.
- Modelos: Log, ExchangeRate (date unique), Deposit.
- BCV scraper (Python/httpx): extrae tasa del BCV y la guarda en BD.

## Fase 3 — Mobile Base (En progreso 🚧)

### Estructura del proyecto Flutter (`mobile/`)
```
mobile/
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml  # Permisos: cámara, GPS, internet, storage
├── lib/
│   ├── main.dart                              # Splash con auto-login, HomeScreen, rutas
│   ├── models/
│   │   ├── local_expense.dart                 # Isar model: LocalExpense
│   │   └── local_track.dart                   # Isar model: LocalTrack
│   ├── screens/
│   │   ├── login_screen.dart                  # Login con JWT + URL configurable
│   │   ├── expense_form_screen.dart           # Formulario dinámico + cámara + GPS + balance
│   │   └── expense_history_screen.dart        # Historial con filtros por categoría
│   ├── services/
│   │   ├── database_service.dart              # Isar init, CRUD, markSynced
│   │   ├── camera_service.dart                # image_picker para foto comprobante
│   │   ├── gps_service.dart                   # Captura de ubicación (scaffold)
│   │   └── sync_service.dart                  # HTTP sync con backend
│   └── widgets/
│       ├── expense_category_dropdown.dart      # Dropdown categorías
│       └── toll_fields.dart                   # Switch peajes múltiples + cantidad
```

### Modelos Isar DB
- **LocalExpense**: id, serverId, category (enum: peaje|hotel|gasolina|otros), amount, amountBs, exchangeRate, description, receiptImagePath, isMultipleTolls, tollCount, createdAt, synced, syncedAt.
- **LocalTrack**: id, latitude, longitude, batteryLevel, timestamp, synced, syncedAt.

### Funcionalidades implementadas
- ✅ Guardado offline en Isar DB (sin conexión a internet).
- ✅ Formulario dinámico: dropdown categorías → si "peaje" → switch + campo cantidad.
- ✅ Cámara: botón para tomar foto del comprobante (image_picker), previsualización.
- ✅ Balance diario estimado: resta gastos del día del presupuesto diario ($167/día aprox).
- ✅ Sincronización diferida: SyncService sube expenses/tracks no sincronizados al backend.
- ✅ Login screen con JWT persistente (flutter_secure_storage), splash con auto-login.
- ✅ Pantalla de historial de gastos con filtros por categoría y total.
- ✅ Captura automática de GPS al abrir formulario, guarda como track point local.
- ✅ AndroidManifest.xml con permisos: cámara, GPS (fine/coarse/background), internet, storage.

### Pendiente (próximos commits)
- ⬜ Grabación de audio (Phase 4).
- ⬜ Generar archivos .g.dart con build_runner (`dart run build_runner build`).
- ⬜ Agregar dependencias geolocator/location en pubspec.yaml y activar GPS real.
- ⬜ Subir foto del comprobante al backend (multipart upload).
- ⬜ Sincronización automática en segundo plano (workmanager / background fetch).
