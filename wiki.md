# Wiki — AppChoferes

## Índice
1. [Descripción General](#1-descripción-general)
2. [Arquitectura](#2-arquitectura)
3. [Estructura del Proyecto](#3-estructura-del-proyecto)
4. [Backend (FastAPI)](#4-backend-fastapi)
5. [Frontend Admin (Vue 3 SPA)](#5-frontend-admin-vue-3-spa)
6. [App Móvil (Flutter)](#6-app-móvil-flutter)
7. [Base de Datos](#7-base-de-datos)
8. [Endpoints de la API](#8-endpoints-de-la-api)
9. [Flujo de Sincronización](#9-flujo-de-sincronización)
10. [Guía para Desarrolladores](#10-guía-para-desarrolladores)
11. [Variables de Entorno](#11-variables-de-entorno)
12. [Docker](#12-docker)
13. [Solución de Problemas Comunes](#13-solución-de-problemas-comunes)

---

## 1. Descripción General

AppChoferes es un sistema de gestión de gastos para choferes con:
- **App Android** (Flutter) offline-first para registrar gastos con foto, audio y GPS
- **Panel Admin Web** (Vue 3 + Tailwind) para gestión de presupuestos, depósitos y supervisión
- **Backend** (FastAPI + MySQL) como capa de sincronización y persistencia central

---

## 2. Arquitectura

```
┌─────────────────────┐     ┌──────────────────┐     ┌──────────────┐
│  App Android        │────▶│  Backend FastAPI  │────▶│  MySQL       │
│  (Flutter + Isar)   │◀────│  (Python 3.12)    │◀────│  (Docker)    │
│  Offline-first      │     │  Puerto 8000      │     │  Puerto 3306 │
└─────────────────────┘     └──────────────────┘     └──────────────┘
                                     │
                                     ▼
                            ┌──────────────────┐
                            │  Admin Panel     │
                            │  (Vue 3 SPA)     │
                            │  /admin          │
                            └──────────────────┘
```

### Principios
- **Offline-first**: la app funciona sin internet. Los gastos se guardan localmente en Isar y se sincronizan cuando hay conexión.
- **Balance = Depósitos − Gastos**: el presupuesto (budget) es solo informativo, no afecta el saldo.
- **Tasa BCV automática**: el chofer no puede elegir la tasa, se obtiene del backend (`GET /api/exchange-rates/current`).
- **GPS obligatorio**: al abrir el formulario de gastos se captura la ubicación automáticamente.

---

## 3. Estructura del Proyecto

```
appchoferes/
├── backend/
│   └── app/
│       ├── main.py                 # Entry point FastAPI (CORS, routers, StaticFiles)
│       ├── core/
│       │   ├── config.py           # Settings (DATABASE_URL, JWT_SECRET)
│       │   ├── database.py         # Async engine, Base, get_db
│       │   ├── security.py         # Password hashing, JWT
│       │   ├── dependencies.py     # get_current_user
│       │   ├── logger.py           # create_log_entry
│       │   └── bcv_scraper.py      # BCV exchange rate scraper
│       ├── models/
│       │   └── __init__.py         # All SQLAlchemy models
│       ├── routers/
│       │   ├── auth.py             # POST /api/auth/login
│       │   ├── expenses.py         # CRUD + requests + edit flow
│       │   ├── telemetry.py        # POST track, GET summary
│       │   ├── users.py            # CRUD users
│       │   ├── budgets.py          # Budget CRUD
│       │   ├── deposits.py         # Deposit CRUD
│       │   ├── routes.py           # Route + tracks
│       │   ├── logs.py             # Activity log
│       │   ├── exchange_rates.py   # BCV + manual rates
│       │   └── uploads.py          # Multipart expense upload + Whisper
│       └── schemas/
│           ├── expenses.py         # ExpenseCreate, ExpenseResponse, etc.
│           ├── telemetry.py        # TrackPoint, TelemetryBatch
│           ├── auth.py
│           ├── budget.py
│           ├── deposits.py
│           ├── exchange_rates.py
│           ├── logs.py
│           ├── routes.py
│           └── users.py
├── frontend/
│   └── index.html                  # SPA Admin Panel (Vue 3 + Tailwind + Leaflet + Chart.js)
├── mobile/
│   └── lib/
│       ├── main.dart               # Entry point, splash, routes, telemetry start
│       ├── models/
│       │   ├── local_expense.dart  # Isar model
│       │   └── local_track.dart    # Isar model
│       ├── screens/
│       │   ├── login_screen.dart   # Login + URL configurable
│       │   ├── home_screen.dart    # Dashboard (saldo, gráfico, últimos gastos)
│       │   ├── expense_form_screen.dart  # Formulario con cámara, audio, GPS
│       │   └── expense_history_screen.dart  # Historial + solicitar edición
│       ├── services/
│       │   ├── database_service.dart   # Isar CRUD
│       │   ├── sync_service.dart       # Sincronización push/pull
│       │   ├── camera_service.dart     # image_picker
│       │   ├── gps_service.dart        # Geolocator wrapper
│       │   ├── audio_service.dart      # Record wrapper
│       │   └── telemetry_service.dart  # Background GPS + battery
│       └── widgets/
│           ├── expense_category_dropdown.dart
│           └── toll_fields.dart
├── Dockerfile
├── docker-compose.yml
├── docker-entrypoint.sh
├── requirements.txt
├── appchoferes.apk                  # APK precompilado
├── setup_mysql.py                   # Seed script (local dev)
├── pr_status.md                     # Estado del proyecto
├── README.md
└── wiki.md                          # Este archivo
```

---

## 4. Backend (FastAPI)

### Dependencias principales
- `fastapi[all]`, `SQLAlchemy>=2.0`, `aiomysql`, `passlib[bcrypt]`, `pyjwt`, `pydantic-settings`, `httpx`, `openai-whisper`

### Configuración (`core/config.py`)
```python
DATABASE_URL: str = "mysql+aiomysql://root:@127.0.0.1:3306/appchoferes"  # default
JWT_SECRET_KEY: str = "change-me-secret"
JWT_ALGORITHM: str = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24h
```
Las variables se pueden sobreescribir con un archivo `.env` o variables de entorno.

### Modelos (`models/__init__.py`)

| Modelo | Tabla | Descripción |
|--------|-------|-------------|
| `User` | `users` | Admin o driver, con email, password hash, role, name |
| `Expense` | `expenses` | Gasto: amount_bs, exchange_rate, amount (USD), category, description, receipt_image_path, audio_path |
| `ExpenseRequest` | `expense_requests` | Solicitud de edición: expense_id, reason, status (pendiente/aprobado/rechazado) |
| `RouteTrack` | `route_tracks` | Punto GPS: lat, lng, battery_level, route_id (nullable) |
| `Route` | `routes` | Ruta: name, start_location, end_location |
| `Budget` | `budgets` | Presupuesto: amount, amount_bs, exchange_rate, period |
| `Deposit` | `deposits` | Depósito: amount, amount_bs, exchange_rate, user_id |
| `ExchangeRate` | `exchange_rates` | Tasa BCV: date (único), rate, source |
| `Tag` | `tags` | Etiquetas para gastos (many-to-many) |
| `Log` | `logs` | Bitácora: user_id, action, resource, details, ip |

### Reglas de negocio críticas
1. **Edición de gastos** requiere una `ExpenseRequest` con status `aprobado` (ver `expenses.py:201`)
2. **Solo admin** puede editar gastos, aprobar/rechazar solicitudes, ver todos los gastos
3. **Balance = sum(Depósitos) − sum(Gastos)**, el presupuesto es solo informativo
4. **Tasa BCV** solo se puede registrar para la fecha actual; `POST /api/exchange-rates` rechaza fechas pasadas/futuras
5. **Enum en SQLAlchemy** usa `.value` para acceder al string (ej. `ExpenseCategory.PEAGE.value` → `"peaje"`)

---

## 5. Frontend Admin (Vue 3 SPA)

### Archivo único: `frontend/index.html`
Sirve todo el admin panel. Usa CDNs:
- Vue 3 (Composition API con `ref`/`computed`)
- Tailwind CSS
- Leaflet (mapas)
- Chart.js (gráficos)

### Tabs disponibles
| Tab | ID | Descripción |
|-----|----|-------------|
| Dashboard | `dashboard` | Resumen choferes, saldos, modales, detalle de gastos |
| Auditoría | `auditoria` | Mapa Leaflet con rutas, gráfico batería |
| Solicitudes | `solicitudes` | Bandeja de edición con aprobar/rechazar |
| Usuarios | `usuarios` | CRUD usuarios con soft-delete |
| Tasas | `tasas` | Tasa BCV, históricos |
| Bitácora | `bitacora` | Logs de actividad |
| Telemetría | `telemetria` | Gráfico Gastos vs KM |

### Cómo agregar un nuevo tab
1. Agregar botón en `<nav>` (línea ~64)
2. Agregar `<div v-if="activeTab==='nuevo'">` con el contenido
3. Agregar función `fetchNuevo()` y ref `nuevosDatos` en el setup de Vue
4. Agregar al return y al `init()`

---

## 6. App Móvil (Flutter)

### Dependencias principales
`isar`, `geolocator`, `battery_plus`, `record`, `image_picker`, `http`, `flutter_secure_storage`, `path_provider`, `intl`, `permission_handler`

### Modelos Isar

#### `LocalExpense`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `Id` (auto) | Clave local |
| `serverId` | `String?` | ID del backend (indexado) |
| `category` | `String` | peaje, hotel, gasolina, otros |
| `amount` | `double` | USD calculado |
| `amountBs` | `double` | Monto en Bs. |
| `exchangeRate` | `double` | Tasa BCV |
| `description` | `String?` | Descripción textual |
| `receiptImagePath` | `String?` | Ruta local de la foto |
| `audioPath` | `String?` | Ruta local del audio |
| `isMultipleTolls` | `bool?` | Peaje múltiple |
| `tollCount` | `int?` | Cantidad de peajes |
| `createdAt` | `DateTime` | Fecha del gasto (indexado) |
| `synced` | `bool` | Sincronizado con backend |
| `syncedAt` | `DateTime?` | Fecha de sincronización |

#### `LocalTrack`
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `Id` (auto) | Clave local |
| `latitude` | `double` | Latitud |
| `longitude` | `double` | Longitud |
| `batteryLevel` | `double` | Nivel de batería |
| `timestamp` | `DateTime` | Fecha del punto (indexado) |
| `synced` | `bool` | Sincronizado |
| `syncedAt` | `DateTime?` | Fecha de sync |

### Servicios

| Servicio | Archivo | Función |
|----------|---------|---------|
| `DatabaseService` | `database_service.dart` | Singleton para Isar CRUD |
| `SyncService` | `sync_service.dart` | Push/pull expenses + tracks |
| `CameraService` | `camera_service.dart` | Tomar foto con image_picker |
| `GpsService` | `gps_service.dart` | Geolocator wrapper |
| `AudioService` | `audio_service.dart` | Grabar/stop audio |
| `TelemetryService` | `telemetry_service.dart` | Background cada 5 min |

### Sincronización
1. `fullSync()`: push expenses → push tracks → download expenses
2. Expenses con foto/audio se suben con `MultipartRequest`
3. Tracks se suben en batch y luego se limpian localmente
4. Expenses se descargan desde `GET /api/expenses/my` (evita duplicados por `serverId`)

### Regenerar código Isar
```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

---

## 7. Base de Datos

### Esquema MySQL
La base de datos se llama `appchoferes`. Las tablas se crean automáticamente con `Base.metadata.create_all`.

### Usuarios semilla
| Email | Password | Rol |
|-------|----------|-----|
| admin@example.com | secret | admin |
| driver1@example.com | secret | driver |
| driver2@example.com | secret | driver |

### Notas sobre columnas
- `route_tracks.route_id` es **nullable** (la app móvil puede enviar tracks sin ruta asignada)
- `expenses.receipt_image_path` y `expenses.audio_path` son rutas de archivo en el servidor
- `category` es ENUM con valores: `PEAGE`, `HOTEL`, `GASOLINA`, `OTROS`

---

## 8. Endpoints de la API

### Auth
| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/auth/login` | Login, devuelve JWT |

### Expenses
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/expenses/` | Lista todos (admin) |
| POST | `/api/expenses/` | Crear gasto (JSON) |
| GET | `/api/expenses/my` | Mis gastos |
| GET | `/api/expenses/my-summary` | Resumen (balance) |
| POST | `/api/expenses/upload` | Crear con multipart (foto + audio + Whisper) |
| POST | `/api/expenses/request-edit` | Solicitar edición |
| GET | `/api/expenses/requests` | Lista solicitudes (admin) |
| PUT | `/api/expenses/requests/{id}/approve` | Aprobar solicitud |
| PUT | `/api/expenses/requests/{id}/reject` | Rechazar solicitud |
| PUT | `/api/expenses/{id}` | Editar gasto (admin, requiere solicitud aprobada) |

### Telemetry
| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/telemetry/track` | Subir batch de puntos GPS |
| GET | `/api/telemetry/summary` | Resumen por chofer (admin) |
| GET | `/api/telemetry/expense-vs-distance` | Gastos vs KM (admin) |

### Exchange Rates
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/exchange-rates/current` | Tasa del día |
| GET | `/api/exchange-rates/rate?date=` | Tasa por fecha |
| GET | `/api/exchange-rates/` | Histórico (admin) |
| POST | `/api/exchange-rates/` | Crear tasa manual |
| POST | `/api/exchange-rates/bcv` | Scrape BCV |

### Otros
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/users/me` | Perfil actual |
| GET/POST | `/api/users` | CRUD usuarios (admin) |
| DELETE | `/api/users/{id}` | Soft-delete |
| GET/POST | `/api/budgets` | Presupuestos |
| GET/POST | `/api/deposits` | Depósitos |
| GET | `/api/deposits/my` | Mis depósitos (driver) |
| GET | `/api/routes/` | Rutas |
| GET | `/api/routes/{id}/tracks?user_id=` | Puntos de una ruta |
| GET | `/api/logs` | Bitácora (admin) |
| GET | `/health` | Health check |

---

## 9. Flujo de Sincronización

```
App sin conexión:
  1. Usuario registra gasto → se guarda en Isar (synced=false)
  2. TelemetryService captura GPS cada 5 min → LocalTrack (synced=false)
  3. Datos visibles localmente siempre

App con conexión (usuario toca Sync o abre app):
  1. SyncService.fullSync():
     a. syncExpenses(): sube expenses no sync (JSON o multipart)
     b. syncTracks(): sube tracks en batch, luego los limpia
     c. downloadExpenses(): baja gastos del servidor
  2. Dashboard se actualiza con datos frescos
```

---

## 10. Guía para Desarrolladores

### Dónde hacer cambios comunes

| Qué querés cambiar | Dónde |
|--------------------|-------|
| Agregar campo a gasto | `models/__init__.py` (SQLAlchemy) + `schemas/expenses.py` (Pydantic) + `local_expense.dart` (Isar) + regenerar .g.dart |
| Nuevo endpoint | Crear en `routers/` + registrar en `main.py` + schema en `schemas/` |
| Modificar regla de balance | `routers/expenses.py:77` (my-summary) y `frontend/index.html` (drivers computed) |
| Cambiar periodicidad GPS | `services/telemetry_service.dart` — constantes `_interval` y `_minDistanceMeters` |
| Agregar campo al formulario | `expense_form_screen.dart` — agregar widget en el ListView |
| Modificar colores del admin | `frontend/index.html` — clases Tailwind |
| Cambiar URL default de backend | `login_screen.dart:17` — `_baseUrlCtrl` initial value |
| Traducciones | Hardcodeadas en español en cada archivo |

### Flujo de trabajo recomendado
1. Hacé cambios en el backend primero (endpoint + schema)
2. Actualizá el modelo Isar si es necesario
3. Ejecutá `dart run build_runner build` si el modelo cambió
4. Construí APK con `flutter build apk --debug`
5. Instalá con `adb install -r ...`

### Tests
No hay tests automatizados aún. Se recomienda probar manualmente:
- Admin: navegar todas las pestañas
- App: login → crear gasto con foto → sync → verificar en admin

---

## 11. Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `DATABASE_URL` | `mysql+aiomysql://root:@127.0.0.1:3306/appchoferes` | Conexión a MySQL |
| `JWT_SECRET_KEY` | `change-me-secret` | Secreto JWT |
| `JWT_ALGORITHM` | `HS256` | Algoritmo JWT |

Se cargan desde un archivo `.env` en la raíz del proyecto (ver `core/config.py:Config`).

---

## 12. Docker

### Comandos

```bash
# Construir y levantar
docker compose up --build

# Solo backend (para desarrollo sin reconstruir)
docker compose up backend

# Ver logs
docker compose logs -f backend

# Detener
docker compose down

# Borrar volúmenes (pierde datos)
docker compose down -v
```

### Servicios
- **backend**: FastAPI en `http://localhost:8000`
- **db**: MySQL 8.0 en `localhost:3307` (mapeado para evitar conflicto con MySQL local)
- **phpmyadmin**: `http://localhost:8080` (user: root, pass: root)

### Notas
- Las carpetas `frontend/` y `backend/app/` se montan como volúmenes para desarrollo en caliente
- Los uploads se persisten en el volumen `uploads_data`
- En primera ejecución, el entrypoint crea tablas y seedea usuarios automáticamente
- Para usar Whisper en Docker, la imagen incluye `ffmpeg` (necesario para whisper)

---

## 13. Solución de Problemas Comunes

### Error 500 en `/api/expenses/`
**Causa**: La tabla `expenses` no tiene las columnas `receipt_image_path` y `audio_path`.
**Solución local**: Ejecutá en MySQL:
```sql
ALTER TABLE expenses ADD COLUMN receipt_image_path VARCHAR(500) DEFAULT NULL;
ALTER TABLE expenses ADD COLUMN audio_path VARCHAR(500) DEFAULT NULL;
```
**Solución Docker**: Bajá los volúmenes con `docker compose down -v` y reconstruí.

### "GPS no disponible" en el formulario
**Causa**: El emulador no tiene GPS configurado o la app no tiene permiso.
**Solución**: En el emulador, Settings → Location → On. O instalar en dispositivo físico.

### Error de conexión
**Causa**: La URL del backend está mal configurada.
**Solución**: En la pantalla de login, cambiá la URL:
- Emulador: `http://10.0.2.2:8000`
- Misma WiFi: `http://192.168.X.X:8000`
- ngrok: `https://XXXX.ngrok.io`

### APK no se instala
**Causa**: La app ya está instalada con otra firma.
**Solución**: Desinstalá la versión anterior: `adb uninstall com.example.appchoferes_mobile`

### build_runner falla
**Causa**: Versiones incompatibles de paquetes.
**Solución**: Actualizá paquetes y limpiá:
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Whisper no transcribe
**Causa**: `ffmpeg` no está instalado o el modelo no se descargó.
**Solución**: Instalá ffmpeg. En Docker ya está incluido. En local:
```bash
pip install openai-whisper
whisper --help  # descarga el modelo automáticamente
```
