--==========================================================
--  				funciones financieras
--==========================================================
--==========================================================
--  fn_total_facturado(fecha_inicio, fecha_fin)
--==========================================================
CREATE OR REPLACE FUNCTION fn_total_facturado(fecha_inicio DATE, fecha_fin DATE)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (
        SELECT COALESCE(SUM(total), 0)
        FROM facturas
        WHERE fecha_emision BETWEEN fecha_inicio AND fecha_fin
    );
END;
$$ LANGUAGE plpgsql;

SELECT fn_total_facturado(DATE '2024-01-01', DATE '2024-12-31');

--==========================================================
--  fn_facturado_por_tipo(tipo TEXT)
--==========================================================
CREATE OR REPLACE FUNCTION fn_facturado_por_tipo(tipo TEXT)
RETURNS TABLE (
    cantidad BIGINT,
    total_subtotal NUMERIC,
    total_iva NUMERIC,
    total_total NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS cantidad,
        SUM(subtotal) AS total_subtotal,
        SUM(iva) AS total_iva,
        SUM(total) AS total_total
    FROM facturas
    WHERE tipo_documento = tipo;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM fn_facturado_por_tipo('FCF');

--==========================================================
--  fn_total_por_paciente(paciente_id INT)
--==========================================================
CREATE OR REPLACE FUNCTION fn_total_por_paciente(fn_paciente_id INT)
RETURNS TABLE (
    nombre_paciente TEXT,
    total_citas BIGINT,
    total_facturado NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.nombres || ' ' || p.apellidos,
        COUNT(DISTINCT c.id_cita),
        COALESCE(SUM(f.total), 0)
    FROM pacientes p
    LEFT JOIN citas c ON p.id_paciente = c.paciente_id
    LEFT JOIN facturas f ON p.id_paciente = f.paciente_id
    WHERE p.id_paciente = fn_paciente_id
    GROUP BY p.nombres, p.apellidos;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM fn_total_por_paciente(1);

--==========================================================
--  				Funciones Clínicas
--==========================================================
--==========================================================
--  fn_promedio_dias_entre_visitas(paciente_id INT)
--==========================================================
CREATE OR REPLACE FUNCTION fn_promedio_dias_entre_visitas(fn_paciente_id INT)
RETURNS NUMERIC AS $$
DECLARE
    promedio NUMERIC;
BEGIN
    SELECT AVG(dias_entre)
    INTO promedio
    FROM (
        SELECT 
            fecha_hora - LAG(fecha_hora) OVER (ORDER BY fecha_hora) AS dias_entre
        FROM citas
        WHERE paciente_id = fn_paciente_id
    ) sub
    WHERE dias_entre IS NOT NULL;

    RETURN COALESCE(promedio, 0);
END;
$$ LANGUAGE plpgsql;


SELECT fn_promedio_dias_entre_visitas(1);


--==========================================================
--  fn_citas_por_medico(medico_id INT)
--==========================================================
CREATE OR REPLACE FUNCTION fn_citas_por_medico(medico_id INT)
RETURNS INTEGER AS $$
DECLARE
    total_citas INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO total_citas
    FROM citas
    WHERE medico_id = fn_citas_por_medico.medico_id
      AND estado_cita = 'completada';

    RETURN total_citas;
END;
$$ LANGUAGE plpgsql;
SELECT fn_citas_por_medico(1);
--==========================================================
--  				Función Gerencial
--==========================================================
--==========================================================
--  fn_servicios_mas_usados()
--==========================================================
CREATE OR REPLACE FUNCTION fn_servicios_mas_usados()
RETURNS TABLE (
    nombre_servicio TEXT,
    veces_facturado INT,
    total_ingresos NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sm.nombre_servicio::TEXT,
        COUNT(df.id_detalle)::INT,        -- Casteo a INT aquí
        SUM(df.subtotal)
    FROM detalle_facturas df
    JOIN servicios_medicos sm ON df.servicio_id = sm.id_servicio
    GROUP BY sm.nombre_servicio
    ORDER BY COUNT(df.id_detalle) DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM fn_servicios_mas_usados();
--==========================================================
--  				Funciones Tributarias
--==========================================================
--==========================================================
--  fn_preparar_dte(factura_id INT) (estructura JSON)
--==========================================================
CREATE OR REPLACE FUNCTION fn_preparar_dte(factura_id INT)
RETURNS JSON AS $$
DECLARE
    resultado JSON;
BEGIN
    SELECT json_build_object(
        'numero_factura', f.numero_factura,
        'fecha_emision', f.fecha_emision,
        'tipo_documento', f.tipo_documento,
        'total', f.total,
        'subtotal', f.subtotal,
        'iva', f.iva,
        'paciente', p.nombres || ' ' || p.apellidos,
        'detalle', (
            SELECT json_agg(json_build_object(
                'servicio', df.descripcion_servicio,
                'cantidad', df.cantidad,
                'precio_unitario', df.precio_unitario,
                'subtotal', df.subtotal
            ))
            FROM detalle_facturas df
            WHERE df.factura_id = f.id_factura
        )
    )
    INTO resultado
    FROM facturas f
    JOIN pacientes p ON f.paciente_id = p.id_paciente
    WHERE f.id_factura = factura_id;

    RETURN resultado;
END;
$$ LANGUAGE plpgsql;

SELECT fn_preparar_dte(1);
--==========================================================
--  fn_contar_facturas_estado_mh(estado TEXT)
--==========================================================
CREATE OR REPLACE FUNCTION fn_contar_facturas_estado_mh(estado TEXT)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COUNT(*) INTO total
    FROM facturas
    WHERE estado_mh = estado;

    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT fn_contar_facturas_estado_mh('pendiente');
--==========================================================
--  				Función de Inventario
--==========================================================
--==========================================================
--  fn_alerta_medicamento_stock_bajo()
--==========================================================
CREATE OR REPLACE FUNCTION fn_alerta_medicamento_stock_bajo()
RETURNS TABLE (
    nombre_medicamento TEXT,
    stock_actual INTEGER,
    stock_minimo INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.nombre_comercial::TEXT,
        m.stock_actual,
        m.stock_minimo
    FROM medicamentos m
    WHERE m.stock_actual < m.stock_minimo;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM fn_alerta_medicamento_stock_bajo();

SELECT * FROM vista_citas_del_dia;
SELECT * FROM vista_agenda_medico;
SELECT * FROM vista_historial_paciente;
SELECT * FROM vista_pacientes_inactivos;
SELECT * FROM vista_facturas_pendientes_mh;
SELECT * FROM vista_total_facturado_mes;
SELECT * FROM vista_ingresos_por_especialidad;
SELECT * FROM vista_uso_servicios;
SELECT * FROM vista_examenes_urgentes;
SELECT * FROM vista_detalle_facturas_emitidas;