# Transacciones-y-recuperaci-n-de-errores-en-PostgreSQL-con-Chinook
1. Objetivo
Demostrar, con scripts ejecutables y resultados observables, cómo PostgreSQL:
•	confirma una operación completa cuando todas sus partes son válidas;
•	deshace todo el trabajo cuando una parte falla;
•	deshace solo una parte del trabajo cuando se usa un punto de guardado;
•	oculta los cambios no confirmados a otras sesiones y los expone después del COMMIT.
________________________________________
2. Entorno
Elemento	              Valor
Motor	                  PostgreSQL 18 
Variante de Chinook    	Chinook_PostgreSql_SerialPKs.sql
Cliente SQL	            [psql / DataGrip / pgAdmin]
Tablas del esquema original que usa esta práctica: customer, invoice, invoice_line y track. No se crean tablas de inventario, saldos ni otras estructuras ajenas al esquema de Chinook.
________________________________________
3. Importación de la base
3.1 Revisión previa del script
Antes de ejecutar el archivo, revisar que contenga:
•	sentencias DROP DATABASE y CREATE DATABASE (eliminan la base completa si ya existe);
•	una metaorden de conexión de psql (\c ...), que solo funciona en psql y no en todos los clientes gráficos.
Advertencia: la importación borra la base indicada. Ejecutarla únicamente sobre una instancia local de práctica y nunca sobre datos que deban conservarse.
3.2 Pasos de importación
1.	Descargar Chinook_PostgreSql_SerialPKs.sql desde la fuente indicada en la sección 2.
2.	Ubicarse en la carpeta donde está el archivo.
3.	Ejecutar la importación con psql desde una conexión que tenga permisos para crear bases de datos:
bash
psql -h localhost -p 5432 -U usuario_admin -d postgres -f Chinook_PostgreSql_SerialPKs.sql
4.	Verificar la carga con conteos básicos (los valores deben coincidir con los del script oficial):
sql
-- Conteo de tablas principales para confirmar la importación
SELECT 'customer' AS tabla, COUNT(*) FROM customer
UNION ALL SELECT 'invoice', COUNT(*) FROM invoice
UNION ALL SELECT 'invoice_line', COUNT(*) FROM invoice_line
UNION ALL SELECT 'track', COUNT(*) FROM track;
3.3 Ruta de la base para los scripts
Si la base no se llama chinook_s17, cambiar el nombre en el comando de conexión de cada ejecución. No modificar los scripts para ajustarlos a otro nombre.

________________________________________
4. Sesiones A y B
La práctica requiere dos conexiones independientes a la misma base:
Sesión	        Función	Qué ejecuta
A	              Escritura	Todas las operaciones de venta, BEGIN, COMMIT, ROLLBACK y SAVEPOINT
B	              Observación	Solo consultas SELECT para verificar visibilidad
En cada sesión, al inicio, ejecutar:
sql
-- Identifica el proceso de backend de la sesión (útil para evidencias)
SELECT pg_backend_pid();

-- Muestra el nivel de aislamiento activo; debe ser read committed
SHOW transaction_isolation;
Registrar el PID obtenido en la sección de evidencias del PDF. No registrar credenciales.
4.1 Modo de autocommit
Cliente	Cómo verificar o cambiar
psql	\echo :AUTOCOMMIT muestra el valor. Para desactivarlo: \set AUTOCOMMIT off
DataGrip	Indicador de transacción en la barra de estado (Tx: Auto o modo manual)
Los scripts de esta práctica abren cada venta con BEGIN explícito, por lo que el estado de autocommit no altera el resultado de los bloques transaccionales. Sí altera las sentencias que se ejecutan fuera de un bloque; por eso el README pide documentar el modo usado en cada captura.
________________________________________
5. Convenciones sobre los datos
•	No modificar ni borrar facturas originales. Las ventas de práctica son filas nuevas.
•	Marcar las ventas de práctica en el campo billing_address de invoice con un texto fijo, por ejemplo PRACTICA-S17-ESC1, PRACTICA-S17-ESC2 y PRACTICA-S17-ESC3. Así es posible localizarlas sin adivinar identificadores.
•	Usar clientes y canciones existentes. Obtener el customer_id y los track_id con consultas de lectura antes de insertar.
•	Referencia inválida controlada: elegir un track_id y confirmar que no existe antes de usarlo:
sql
-- Comprueba que el identificador de prueba no existe en track
SELECT NOT EXISTS (SELECT 1 FROM track WHERE track_id = 999999) AS no_existe;
•	Generación de identificadores: nunca usar MAX(id) + 1. Las claves se generan con las secuencias de la base y se recuperan con RETURNING (en la cabecera) o con consultas por el marcador de la sección anterior.
________________________________________
6. Archivos y orden de ejecución
Orden	Archivo	Escenario	Qué demuestra
0	Verificación	Sesión, PID y nivel de aislamiento 
1	01_venta_exitosa.sql	Venta confirmada	Factura con RETURNING, tres detalles, total calculado con SUM y COMMIT; comprobación desde la sesión B
2	02_rollback_total.sql	Error de clave foránea	Violación real de FK, estado abortado y ROLLBACK con verificación posterior
3	03_savepoint.sql	Recuperación parcial	SAVEPOINT, error controlado, ROLLBACK TO SAVEPOINT, detalle corregido y COMMIT
4	04_validaciones.sql	Consultas de control	Coincidencia exacta entre total y suma de detalles, ausencia de referencias huérfanas y conteos
Cada archivo es independiente: puede ejecutarse por separado sobre la base preparada, siempre que no dependa de una venta creada en otro archivo. Los identificadores generados se leen de la salida de cada script, no se escriben a mano.
6.1 Cómo ejecutar un escenario
bash
psql -h localhost -p 5432 -U usuario_practica -d chinook_s17 -f sql/01_venta_exitosa.sql
Para ejecutar los bloques de forma interactiva en DataGrip, copiar cada bloque en la sesión correspondiente (A o B) y respetar el orden indicado en los comentarios del archivo.
________________________________________
7. Manejo de errores durante la ejecución
Los escenarios 2 y 3 contienen un error intencional. Esto tiene dos consecuencias:
1.	Con psql y ON_ERROR_STOP activo (valor por defecto en algunos entornos), el script se detiene en el primer error. En ese caso el bloque de recuperación (ROLLBACK o ROLLBACK TO SAVEPOINT) debe ejecutarse a mano en la misma sesión, porque la transacción queda abortada.
2.	Con psql y \set ON_ERROR_STOP off, el script continúa, pero las sentencias que siguen al error se rechazan con el mensaje de transacción abortada hasta que se ejecute el bloque de recuperación.
El archivo de cada escenario indica en comentarios qué bloque de recuperación corresponde a cada punto de falla.
________________________________________
8. Repetir las pruebas
Las ventas de práctica se pueden repetir sin borrar datos originales:
1.	Consultar las ventas de práctica con el marcador de la sección 5 y decidir si se conservan como evidencia.
2.	Ejecutar de nuevo el archivo deseado. Cada ejecución crea una factura nueva con un identificador distinto.
3.	Para empezar desde cero, volver a importar la base con la sección 3. Esto elimina todos los cambios de práctica.
Nota sobre secuencias: las secuencias de invoice e invoice_line no retroceden tras un ROLLBACK. Un salto en los identificadores después de una reversión es comportamiento esperado y no es un error.
________________________________________
9. Validaciones (04_validaciones.sql)
El archivo de validaciones comprueba, para cada venta de práctica:
•	que el total de la cabecera coincide exactamente con SUM(unit_price * quantity) de sus líneas, usando NUMERIC(10,2) en el cálculo;
•	que el número de líneas es el esperado para cada escenario;
•	que no existen líneas sin factura ni referencias a track_id inexistentes;
•	que las facturas originales no fueron alteradas (conteo previo y posterior).
Cada consulta incluye comentarios con su propósito y el resultado esperado.
________________________________________
10. Seguridad
•	El repositorio no contiene contraseñas, cadenas de conexión reales, archivos .env ni .pgpass.
•	Los datos son los de Chinook. 
Entrada de ejemplo para .gitignore:
.env
.pgpass
*.dump
________________________________________
11. Alcance y límites
Esta práctica demuestra:
•	atomicidad lógica frente a errores de clave foránea;
•	aplicación de reversiones parciales con puntos de guardado;
•	visibilidad entre dos sesiones antes y después del COMMIT.
No demuestra:
•	recuperación ante caídas físicas del proceso o del servidor;
•	comportamiento bajo concurrencia intensa o con otros niveles de aislamiento.
Para analizar durabilidad ante fallos físicos sería necesario un experimento específico con reinicio controlado del servidor, fuera del alcance de estos scripts.

