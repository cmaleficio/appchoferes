# AppChoferes

Sistema de gestión de gastos para choferes con app Android offline-first, panel administrativo web y backend FastAPI.

## Stack
- **Backend**: FastAPI + SQLAlchemy async + MySQL 8.0
- **Frontend Admin**: Vue 3 + Tailwind CSS + Leaflet + Chart.js (SPA single file)
- **App Móvil**: Flutter 3.44 + Isar 3.1 (local DB) + geolocator + image_picker + record
- **Infraestructura**: Docker Compose

---

## Requisitos

### Sin Docker
- Python 3.12+
- MySQL 8.0 (XAMPP o standalone)
- Flutter 3.44+ (para compilar APK)
- JDK 17 (para compilar APK)
- Android SDK (para compilar APK)

### Con Docker
- Docker Engine 24+
- Docker Compose v2

---

## 🔧 Instalación y Ejecución

### Opción 1: Con Docker (recomendado)

```bash
# Clonar el repositorio
git clone <repo-url> && cd appchoferes

# Construir y levantar todo
docker compose up --build

# La primera vez puede tomar varios minutos
# Backend: http://localhost:8000
# Admin:   http://localhost:8000/admin
# phpMyAdmin: http://localhost:8080 (root/root)
```

Usuarios precargados:
| Email | Password | Rol |
|-------|----------|-----|
| admin@example.com | secret | admin |
| driver1@example.com | secret | driver |
| driver2@example.com | secret | driver |

Para instalar la app en un dispositivo Android:
```bash
adb install appchoferes.apk
```
Y configurar la URL del backend al iniciar sesión.

### Opción 2: Manual (sin Docker)

#### 1. Base de datos
```bash
# Con XAMPP, iniciar MySQL en puerto 3306
# Crear la base de datos
python setup_mysql.py
```

#### 2. Backend
```bash
python -m venv venv
source venv/bin/activate   # Linux/Mac
.\venv\Scripts\activate    # Windows

pip install -r requirements.txt
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

#### 3. Panel Admin
Ya está servido por FastAPI en `http://localhost:8000/admin`

#### 4. App Móvil
```bash
cd mobile
flutter pub get
dart run build_runner build   # solo si cambian los modelos Isar
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🚀 Uso rápido

1. Abrir `http://localhost:8000/admin` e iniciar sesión como `admin@example.com` / `secret`
2. En la app Android, iniciar sesión como `driver1@example.com` / `secret`
3. Configurar la URL del backend en la pantalla de login:
   - Emulador: `http://10.0.2.2:8000`
   - Misma WiFi: `http://192.168.X.X:8000`
   - ngrok: `https://XXXX.ngrok.io`
4. Registrar un gasto (requiere foto del comprobante)
5. Sincronizar con el botón 🔄 en el dashboard
6. Ver el gasto en el panel admin

---

## 📱 Funcionalidades principales

### App Android
- ✅ Login con JWT persistente
- ✅ Dashboard con saldo, últimos gastos y gráfico por categoría
- ✅ Registro de gastos con categoría, monto en Bs., tasa BCV automática
- ✅ Foto de comprobante obligatoria (cámara)
- ✅ Grabación de audio como descripción
- ✅ Captura GPS automática
- ✅ Sincronización offline-first (push + pull)
- ✅ Historial con filtros y solicitud de edición
- ✅ Telemetría background (GPS + batería cada 5 min)

### Panel Admin
- ✅ Dashboard con tabla de choferes, saldos, presupuestos y depósitos
- ✅ Detalle de gastos por chofer (colapsable)
- ✅ Mapa Leaflet con rutas y gráfico de batería
- ✅ Bandeja de solicitudes de edición (aprobar/rechazar)
- ✅ CRUD de usuarios con soft-delete
- ✅ Tasas de cambio (BCV automático + manual)
- ✅ Bitácora de actividades
- ✅ Gráfico Gastos USD vs KM recorridos

---

## 📁 Estructura del proyecto

```
appchoferes/
├── backend/app/          # API FastAPI
├── frontend/index.html   # Admin SPA (Vue 3)
├── mobile/lib/           # App Flutter
├── Dockerfile            # Backend container
├── docker-compose.yml    # Infraestructura completa
├── requirements.txt      # Dependencias Python
├── setup_mysql.py        # Seed script (local)
├── appchoferes.apk       # APK precompilado
└── wiki.md               # Documentación detallada
```

Ver `wiki.md` para documentación exhaustiva: modelo de datos, endpoints, guía de desarrollo y solución de problemas.

---

## 🔗 Enlaces útiles
- Admin Panel: `http://localhost:8000/admin`
- API Docs: `http://localhost:8000/docs` (Swagger)
- phpMyAdmin: `http://localhost:8080`
- Estado del proyecto: `pr_status.md`

## 📄 Licencia
Uso interno.
