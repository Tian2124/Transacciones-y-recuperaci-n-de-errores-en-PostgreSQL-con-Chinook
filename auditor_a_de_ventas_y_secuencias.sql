SELECT
    i.invoice_id,
    i.customer_id,
    i.invoice_date,
    COUNT(il.invoice_line_id) AS total_lineas,
    i.total AS total_factura,
    COALESCE(SUM(il.unit_price * il.quantity), 0.00)::numeric(10,2) AS suma_lineas,
    (i.total - COALESCE(SUM(il.unit_price * il.quantity), 0.00)::numeric(10,2)) AS diferencia_total
FROM invoice i
LEFT JOIN invoice_line il ON i.invoice_id = il.invoice_id
WHERE i.invoice_id > 412
GROUP BY i.invoice_id, i.customer_id, i.invoice_date, i.total
ORDER BY i.invoice_id;

-- ============================================================================
-- Verificación de inexistencia de facturas huérfanas
-- Resultado esperado: 0 filas. Ninguna factura quedó con cabecera incompleta.
-- ============================================================================
SELECT i.invoice_id, i.customer_id, i.total
FROM invoice i
LEFT JOIN invoice_line il ON i.invoice_id = il.invoice_id
WHERE il.invoice_line_id IS NULL;

-- ============================================================================
-- Inspección del estado actual de las secuencias SERIAL
-- Resultado esperado: El last_value de las secuencias refleja los incrementos
-- consumidos tanto por las transacciones confirmadas como por las revertidas.
-- ============================================================================
SELECT 
    pg_get_serial_sequence('invoice', 'invoice_id') AS secuencia_factura,
    last_value AS ultimo_valor_factura,
    is_called
FROM invoice_invoice_id_seq;

SELECT 
    pg_get_serial_sequence('invoice_line', 'invoice_line_id') AS secuencia_detalle,
    last_value AS ultimo_valor_detalle,
    is_called
FROM invoice_line_invoice_line_id_seq;