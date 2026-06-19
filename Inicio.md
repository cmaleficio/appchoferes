Actúa como un Arquitecto de Software experto en Python y FastAPI. Vamos a iniciar la Fase 1 del backend adaptado a reglas estrictas de negocio logístico.

Lee el pr_status.md y apartir de el comienza las siguientes tareas: 

Genera el código modular para el backend considerando:
1. Modelos de SQLAlchemy con soporte para:
   - Tabla 'expenses': Campo 'category' (ENUM: 'peaje', 'hotel', 'gasolina', 'otros'). Campos específicos para peajes: 'is_multiple_tolls' (booleano) y 'toll_count' (entero).
   - Tabla 'route_tracks': Para telemetría del viaje (id, user_id, route_id, latitud, longitud, battery_level, registrado_en).
   - Tabla 'expense_requests': Para solicitudes de edición (id, expense_id, user_id, motivo, status [pendiente, aprobado, rechazado], creado_en).
   - Resto de tablas base: 'users', 'routes', 'budgets', 'tags'.
2. Configuración de la API con FastAPI, CORS y autenticación JWT.
3. Endpoints críticos:
   - POST '/api/expenses/request-edit' (Chofer solicita editar un gasto).
   - PUT '/api/expenses/{id}/admin-edit' (Admin edita el gasto, SOLO si existe una solicitud con status 'aprobado').
   - POST '/api/telemetry/track' (Para recibir lotes de ubicación y batería del recorrido).

Entrega el código estructurado por archivos limpios y listos para ejecutar. Al final, genera el bloque markdown de actualización para el archivo 'pr_status.md'.


Actúa como un Desarrollador Full-Stack experto en FastAPI, Vue.js (CDN) y Tailwind CSS. Diseñaremos el Panel Administrativo para la Fase 2 incorporando las herramientas de auditoría.

Genera la interfaz web que incluya de forma interactiva:
1. Dashboard de Choferes y Presupuestos: Tabla clásica con saldos, botón para cargar presupuestos y sincronizar rutas.
2. Módulo de Auditoría de Recorridos: Una vista donde el admin seleccione un chofer y una ruta, mostrando una tabla descriptiva (o simulación) del recorrido extraído de 'route_tracks', detallando las coordenadas y la curva de descarga de la batería del dispositivo.
3. Bandeja de Entrada de Solicitudes de Edición:
   - Lista de solicitudes hechas por los choferes ('expense_requests' con estado 'pendiente').
   - Botón para "Aprobar Solicitud" (cambia el estado a aprobado y desbloquea temporalmente un formulario para que el administrador modifique los montos o etiquetas del gasto original) y botón de "Rechazar".

Proporciona el código limpio y acoplable al backend de la Fase 1. Al final, genera la sección actualizada de 'pr_status.md'.

Actúa como un Desarrollador Mobile experto en Flutter e Isar DB. Vamos a crear la estructura móvil de la Fase 3 con soporte offline-first estricto.

Genera el código en Flutter para:
1. Modelos de Isar DB:
   - 'LocalExpense' con campos de categorías restrictivas, banderas de peajes múltiples, cantidad de peajes y estado de sincronización.
   - 'LocalTrack' (id, latitud, longitud, batteryLevel, timestamp, synced).
2. Pantalla de formulario de gastos dinámica:
   - Selector/Dropdown con: Peajes, Hoteles, Gasolina, Otros.
   - Si se selecciona "Peajes", debe desplegar un Switch/Checkbox que pregunte "¿Es pago de múltiples peajes?" y un campo numérico para "Cantidad de peajes".
   - Campo obligatorio para el costo del peaje.
3. Lógica para guardar el gasto localmente restando el saldo estimado del chofer en la interfaz de usuario.

Entrega el código organizado por componentes limpios. Al final, genera la sección actualizada de 'pr_status.md'.

Actúa como un Desarrollador Senior de Flutter y Backend Python. Desarrollaremos la Fase 4 enfocado en hardware y telemetría en tiempo real.

Genera el código para:
1. En Flutter: Implementación de un servicio (usando 'geolocator' y 'battery_plus') que capture la ubicación y el nivel de batería cada 5 minutos (o cambio de distancia) y guarde silenciosamente estos datos en la tabla 'LocalTrack' de Isar DB.
2. En el Formulario de Gastos: Forzar la activación de la cámara para tomar la foto del recibo antes de habilitar el botón "Aceptar Gasto".
3. En el Backend (FastAPI): Endpoint unificado para procesar la subida del gasto, transcripción de audio mediante Whisper e inicialización del flujo de validación.

Proporciona el código fuente detallado y robusto ante cortes de energía del dispositivo. Al final, genera el bloque markdown para 'pr_status.md'.

Actúa como un Ingeniero de Software experto en sincronización de datos. Concluiremos el MVP en la Fase 5.

Genera el código para:
1. En Flutter: Motor de sincronización por lotes que corra cuando haya internet. Debe:
   - Subir primero los registros acumulados en 'LocalTrack' (telemetría de recorrido y batería) al backend y luego limpiarlos.
   - Subir los gastos pendientes con sus respectivos archivos binarios (fotos y audios de descripción).
   - Vista integrada para que el chofer pueda ver su historial de gastos local y presionar un botón de "Solicitar Edición" enviando el motivo al backend.
2. En el Panel Admin: Integración de gráficos que crucen el dinero gastado contra los kilómetros recorridos estimados por la telemetría.

Entrega el código de producción y el archivo 'pr_status.md' en su estado final de culminación.