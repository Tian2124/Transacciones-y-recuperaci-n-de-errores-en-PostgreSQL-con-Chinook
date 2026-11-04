SELECT
    pg_backend_pid() AS pid_conexion_a,
    current_setting('transaction_isolation') AS nivel_aislamiento,
    current_timestamp AS fecha_hora_inicio;

-- Verificar que el cliente y las canciones existen en el catálogo original
SELECT customer_id, first_name, last_name, address, city, state, country, postal_code
FROM customer
WHERE customer_id = 1;

SELECT track_id, name, unit_price
FROM track
WHERE track_id IN (1, 2, 3)
ORDER BY track_id;

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Insertar cabecera tomando los datos de facturación reales del cliente 1.
-- Se inicializa total en 0.00 temporalmente para calcularlo luego a partir de los detalles.
INSERT INTO invoice (
    customer_id,
    invoice_date,
    billing_address,
    billing_city,
    billing_state,
    billing_country,
    billing_postal_code,
    total
)
SELECT 
    customer_id,
    CURRENT_TIMESTAMP,
    address,
    city,
    state,
    country,
    postal_code,
    0.00::numeric(10,2)
FROM customer
WHERE customer_id = 1
RETURNING invoice_id \gset v_

\echo '--- [CONEXION A] Factura creada en transaccion abierta con ID: ' :v_invoice_id

INSERT INTO invoice_line (invoice_id, track_id, unit_price, quantity)
SELECT 
    :v_invoice_id,
    t.track_id,
    t.unit_price,
    v.cantidad
FROM track t
JOIN (
    VALUES 
        (1, 1),
        (2, 2),
        (3, 1)
) AS v(track_id, cantidad) ON t.track_id = v.track_id;

UPDATE invoice i
SET total = (
    SELECT COALESCE(SUM(il.unit_price * il.quantity), 0.00)::numeric(10,2)
    FROM invoice_line il
    WHERE il.invoice_id = i.invoice_id
)
WHERE i.invoice_id = :v_invoice_id;

SELECT
    i.invoice_id,
    COUNT(il.invoice_line_id) AS cantidad_detalles,
    i.total AS total_cabecera,
    SUM(il.unit_price * il.quantity)::numeric(10,2) AS suma_detalles,
    (i.total = SUM(il.unit_price * il.quantity)::numeric(10,2)) AS coincidencia_exacta
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
WHERE i.invoice_id = :v_invoice_id
GROUP BY i.invoice_id, i.total;

COMMIT;

