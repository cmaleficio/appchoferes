# AppChoferes — Estado Final del MVP

## Resumen del proyecto
App Android con panel web administrativo para gestionar presupuestos, gastos, telemetría GPS y sincronización offline-first para choferes.

## Stack tecnológico
- **Backend**: FastAPI + SQLAlchemy async + MySQL (XAMPP)
- **Frontend Admin**: SPA Vue 3 + Tailwind CSS + Leaflet + Chart.js
- **Mobile**: Flutter 3.44.2 + Isar 3.1.0 (local-first) + geolocator + battery_plus + record

---

## Fase 1 — Backend & DB ✅
- FastAPI scaffold con routers, JWT auth, bcrypt hashing
- Modelos: User, Expense (con amount_bs, exchange_rate, receipt_image_path, audio_path), RouteTrack (route_id nullable), Budget, Tag, ExpenseRequest, ExchangeRate, Deposit, Log
- MySQL via XAMPP `127.0.0.1:3306`, async SQLAlchemy, Pydantic v2 (`from_attributes = True`)
- Seed script `setup_mysql.py`

## Fase 2 — Admin Panel ✅
- **SPA** (`frontend/index.html`): Vue 3 + Tailwind + Leaflet + Chart.js
- **Dashboard**: cards resumen, tabla choferes con saldo (depósitos − gastos), modales: presupuesto (con tasa BCV), depósitos, detalle de gastos por chofer (colapsable), sincronizar rutas
- **Auditoría**: filtros chofer/ruta, mapa Leaflet con polyline y battery chart SVG
- **Solicitudes**: bandeja aprobar/rechazar + edición inline del gasto
- **Usuarios**: CRUD con soft-delete
- **Tasas**: última tasa + botón "Obtener del BCV", tabla histórica
- **Bitácora**: logs con usuario, acción, recurso, IP
- **Telemetría** (nuevo en Fase 5): gráfico Chart.js (barras dobles) Gastos USD vs KM recorridos por chofer, tabla con USD/km
- **Balance corregido**: `balance = total_deposits − total_expenses` (excluye budget)

## Fase 3 — Mobile Base ✅
- Login con JWT persistente (`flutter_secure_storage`), splash con auto-login
- Isar DB local: LocalExpense (category, amount, amountBs, exchangeRate, receiptImagePath, audioPath, etc.) y LocalTrack (lat, lng, batteryLevel)
- Formulario de gastos: categorías, monto Bs, tasa BCV auto-select, USD auto-calculado, GPS automático, foto comprobante, audio descripción
- Captura automática de GPS al abrir el formulario
- SyncService: sube expenses (JSON o multipart con binarios), tracks, descarga expenses del servidor
- **Historial**: filtros por categoría, total, botón "Solicitar Edición" (envía motivo al backend, swipe o icono)
- **Dashboard**: saludo con nombre, saldo en USD, últimos 4 gastos, gráfico de distribución por categoría, FAB nuevo gasto, AppBar con sync/historial/logout

## Fase 4 — Hardware & IA ✅
- **Telemetría background**: `TelemetryService` captura ubicación (geolocator) + batería (battery_plus) cada 5 min o 100m de distancia, guarda en LocalTrack
- **Iniciado en `main.dart`**: `TelemetryService.instance.start()`
- **Cámara obligatoria**: botón "Guardar" deshabilitado hasta tomar foto del comprobante
- **Audio descripción**: botón para grabar/stop audio (record package), se guarda ruta en `LocalExpense.audioPath`
- **Backend**: `POST /api/expenses/upload` — endpoint multipart que:
  - Recibe image + audio + metadatos
  - Ejecuta Whisper (openai-whisper) para transcripción del audio
  - Guarda rutas en `receipt_image_path` y `audio_path`
  - Registra en bitácora

## Fase 5 — Sync & Reportes ✅
- **SyncService actualizado**:
  - Sube expenses con/sin binarios (multipart si tiene foto/audio)
  - Sube tracks y los limpia localmente (`clearSyncedTracks`)
  - Descarga expenses del servidor (evita duplicados por serverId)
  - `requestEdit()`: envía solicitud de edición al backend
- **Expense History**: icono edit_note en gastos sincronizados → modal con motivo → `POST /api/expenses/request-edit`
- **Admin Telemetría**: gráfico Chart.js (doble eje Y) que cruza KM recorridos vs Gastos USD por chofer, tabla con USD/km
- **Backend telemetry summary**: `GET /api/telemetry/expense-vs-distance` con Haversine + suma de gastos por usuario

## Comandos clave
```bash
# Backend
uvicorn backend.app.main:app --reload --port 8000

# Mobile build
cd mobile
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Isar codegen
dart run build_runner build --delete-conflicting-outputs
```

## APK
- AGP 8.11.1, Gradle 9.1.0
- Permisos: cámara, GPS (fine/coarse/background), internet, storage, audio
- Emulator: `flutter_emulator` (Pixel 6, API 36), host `10.0.2.2:8000`
