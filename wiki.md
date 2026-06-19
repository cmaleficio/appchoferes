# Documentación Oficial de Arquitectura y Alcance del Proyecto
## Sistema Inteligente de Control de Gastos y Telemetría para Choferes (Offline-First)

Este documento constituye la Única Fuente de Verdad (SSOT) del aplicativo. Define el alcance funcional, la arquitectura del software, las reglas de negocio estrictas y la hoja de ruta para su desarrollo continuo.

---

## 1. Resumen Ejecutivo del MVP
El sistema es una plataforma tecnológica diseñada para auditar, controlar y registrar los flujos financieros de los choferes de carga pesada o distribución durante sus rutas asignadas. Su principal propuesta de valor es el funcionamiento **Offline-First**, permitiendo que la operación en carretera no se detenga por falta de cobertura celular. Automatiza la clasificación de gastos mediante Inteligencia Artificial (transcripción de voz a texto y etiquetado inductivo) e implementa un riguroso esquema de telemetría de viaje (GPS + niveles de batería) para prevenir desvíos de ruta o sabotajes de dispositivos.

---

## 2. Arquitectura Tecnológica Elegida

Para garantizar el máximo rendimiento con un stack mantenible y ágil para el MVP, se ha seleccionado la siguiente infraestructura:

| Capa del Sistema | Tecnología Principal | Justificación Técnica |
| :--- | :--- | :--- |
| **Aplicación Móvil** | Flutter (Dart) | Compilación nativa de alto rendimiento, excelente ecosistema para control de hardware (Cámara, GPS, Batería) y animaciones fluidas. |
| **Base de Datos Local** | Isar DB (NoSQL) | Base de datos embebida extremadamente rápida para móviles, soporta esquemas relacionales/enlaces, consultas asíncronas y tipado estricto. |
| **Backend API** | FastAPI (Python) | Arquitectura asíncrona nativa ideal para alta concurrencia en la subida de archivos pesados (imágenes, audios) y fácil integración con ecosistemas de IA. |
| **Base de Datos Central**| MariaDB / PostgreSQL | Motor relacional robusto para asegurar la integridad referencial de los saldos de presupuestos y registros de auditoría. |
| **Panel Administrativo**| Vue.js + Tailwind CSS | Interfaz SPA reactiva, ligera y de rápido desarrollo consumiendo la API de FastAPI a través de servicios REST puros. |
| **Motor de IA (Voz)** | OpenAI Whisper API | Transcripción de audio a texto de alta precisión en entornos ruidosos (cabinas de camiones). |

---

## 3. Alcance Funcional y Módulos del Sistema

### 3.1. Aplicación Móvil (Choferes)
*   **Módulo de Autenticación Offline:** El inicio de sesión requiere conexión inicial para validar el JWT. Una vez obtenido, se almacena de forma encriptada en el hardware del dispositivo (`Flutter Secure Storage`), permitiendo accesos posteriores sin conectividad.
*   **Módulo de Formulario Restringido de Gastos:** Interfaz dedicada a capturar egresos financieros basándose exclusivamente en las siguientes categorías válidas:
    *   *Gasolina:* Registro numérico de costo.
    *   *Hoteles:* Registro numérico de costo de hospedaje.
    *   *Otros:* Categoría abierta para emergencias mecánicas o imprevistos.
    *   *Peajes (Lógica Especial):* Campo selector que obliga a definir si el pago corresponde a un **Único Peaje** o a **Múltiples Peajes en lote**. En caso de ser múltiple, solicita la cantidad exacta de peajes cubiertos con ese monto monetario.
*   **Captura Multimedia Obligatoria:** El formulario bloquea el botón de "Aceptar Gasto" hasta que se ejecute la apertura de la cámara interna y se capture la fotografía nítida del recibo físico.
*   **Descripción Asistida por Audio:** El chofer puede optar por no escribir texto y, en su lugar, mantener presionado un botón para grabar un archivo de audio con la explicación del gasto.
*   **Caja Negra de Telemetría (Background Tracking):** Servicio en segundo plano que se activa al iniciar una ruta asignada. Registra las coordenadas geográficas (Latitud, Longitud) del vehículo y el **porcentaje exacto de batería** del dispositivo cada intervalo regular de tiempo (ej. 5 minutos), guardándolo en la base de datos local Isar sin intervención del usuario.
*   **Bandeja de Historial y Solicitudes de Edición:** Permite al chofer inspeccionar sus gastos anteriores (sincronizados o no). Si detecta un error, puede emitir una "Solicitud de Edición" justificando el motivo textualmente.

### 3.2. Panel Administrativo Web (Personal de Administración)
*   **Sincronización Logística Central:** Consulta la base de datos externa de la empresa para importar las rutas válidas y disponibilizarlas a la aplicación móvil.
*   **Gestión de Choferes y Presupuestos (Ledger Bancario):** CRUD de choferes. Permite asignar un fondo monetario base a un chofer para una ruta. El panel descuenta en tiempo real los gastos aprobados que el chofer va sincronizando, mostrando alertas visuales si el conductor se excede del presupuesto o si le queda menos del 10% del dinero asignado.
*   **Panel de Control de Solicitudes:** Bandeja de entrada donde llegan los pedidos de corrección de gastos de los choferes. Un administrador puede aprobar o rechazar la solicitud. **Regla de oro:** El sistema prohíbe la alteración manual de cualquier gasto a menos que exista una solicitud aprobada vinculada al mismo.
*   **Auditoría y Mapeo de Telemetría:** Permite visualizar cronológicamente el viaje del chofer, reconstruyendo la ruta trazada en base a las coordenadas recolectadas en segundo plano y graficando los niveles de batería para comprobar el correcto uso de la herramienta.

---

## 4. Estructura de Datos Detallada (Esquema de Base de Datos)

### 4.1. Base de Datos Central (Relacional SQL)

#### Tabla: `users`
*   `id` (UUID, PK)
*   `name` (VARCHAR)
*   `email` (VARCHAR, UNIQUE)
*   `password_hash` (VARCHAR)
*   `role` (ENUM: 'admin', 'driver')
*   `created_at` (TIMESTAMP)

#### Tabla: `routes`
*   `id` (INT, PK)
*   `route_code` (VARCHAR, UNIQUE)
*   `origin` (VARCHAR)
*   `destination` (VARCHAR)

#### Tabla: `budgets`
*   `id` (UUID, PK)
*   `user_id` (UUID, FK -> users.id)
*   `route_id` (INT, FK -> routes.id)
*   `initial_amount` (DECIMAL(10,2))
*   `current_amount` (DECIMAL(10,2))
*   `updated_at` (TIMESTAMP)

#### Tabla: `expenses`
*   `id` (UUID, PK)
*   `user_id` (UUID, FK -> users.id)
*   `budget_id` (UUID, FK -> budgets.id)
*   `category` (ENUM: 'peaje', 'hotel', 'gasolina', 'otros')
*   `is_multiple_tolls` (BOOLEAN, DEFAULT FALSE)
*   `toll_count` (INT, DEFAULT 1)
*   `amount` (DECIMAL(10,2))
*   `latitude` (DECIMAL(10,8))
*   `longitude` (DECIMAL(11,8))
*   `photo_url` (VARCHAR)
*   `audio_url` (VARCHAR, NULLABLE)
*   `transcription` (TEXT, NULLABLE)
*   `created_at` (TIMESTAMP)

#### Tabla: `route_tracks` (Módulo de Telemetría)
*   `id` (BIGINT, PK)
*   `user_id` (UUID, FK -> users.id)
*   `budget_id` (UUID, FK -> budgets.id)
*   `latitude` (DECIMAL(10,8))
*   `longitude` (DECIMAL(11,8))
*   `battery_level` (INT)
*   `recorded_at` (TIMESTAMP)

#### Tabla: `expense_requests` (Módulo de Solicitudes)
*   `id` (UUID, PK)
*   `expense_id` (UUID, FK -> expenses.id)
*   `user_id` (UUID, FK -> users.id)
*   `reason` (TEXT)
*   `status` (ENUM: 'pending', 'approved', 'rejected', DEFAULT 'pending')
*   `processed_by` (UUID, NULLABLE, FK -> users.id)
*   `created_at` (TIMESTAMP)

---

### 4.2. Base de Datos Embebida Móvil (Isar DB NoSQL)

#### Colección: `LocalExpense`
*   `id` (int, autoIncrement de Isar)
*   `remoteId` (String, nullable)
*   `category` (String) -> Restringido por código a ('peaje', 'hotel', 'gasolina', 'otros')
*   `isMultipleTolls` (bool)
*   `tollCount` (int)
*   `amount` (double)
*   `latitude` (double)
*   `longitude` (double)
*   `localPhotoPath` (String)
*   `localAudioPath` (String, nullable)
*   `transcription` (String, nullable)
*   `synced` (bool, indexado)
*   `createdAt` (DateTime)

#### Colección: `LocalTrack`
*   `id` (int, autoIncrement)
*   `latitude` (double)
*   `longitude` (double)
*   `batteryLevel` (int)
*   `timestamp` (DateTime)
*   `synced` (bool, indexado)

---

## 5. Reglas de Negocio Estrictas e Invariables

1.  **Validación de Saldo Local vs Remoto:** Cuando la aplicación móvil registra un gasto offline, resta de forma estimada el dinero de la pantalla del chofer basándose en el último saldo conocido traído del servidor. La API del backend realiza la resta definitiva e inmutable sobre la tabla `budgets` una vez que los datos se sincronizan y la foto es almacenada con éxito.
2.  **Bloqueo de Modificación Administrativa:** Ningún usuario con rol `admin` puede modificar los montos o variables de un gasto reportado por un chofer si no existe un registro en `expense_requests` cuyo estado sea explícitamente `approved`. Al ejecutarse la modificación, el sistema guarda un log histórico del cambio.
3.  **Integridad Preventiva de Telemetría:** El servicio de rastreo en segundo plano (`route_tracks`) debe operar de manera independiente a las acciones del usuario. Si el dispositivo se queda sin batería o el proceso es destruido por el sistema operativo, la app móvil, al volver a encender, debe registrar inmediatamente un log local con un flag de interrupción forzada, guardando el porcentaje de batería inicial.
4.  **Carga Multipart Condicional:** Los archivos de imágenes y audios locales no se transforman en Base64. Deben ser transmitidos a la API mediante peticiones HTTP estructuradas en bloques `multipart/form-data` secuenciales para evitar sobrecargas de memoria RAM en el dispositivo móvil.

---

## 6. Fases del Cronograma de Desarrollo