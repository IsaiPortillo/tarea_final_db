--==========================================================
--				    vistas operativas
--==========================================================

--==========================================================
--  vista_citas_del_dia
--==========================================================
CREATE OR REPLACE VIEW vista_citas_del_dia AS
SELECT 
    c.id_cita,
    c.fecha_hora,
    c.estado_cita,
    c.motivo_consulta,
    p.nombres || ' ' || p.apellidos AS paciente,
    m.nombres || ' ' || m.apellidos AS medico,
    e.nombre_especialidad
FROM citas c
JOIN pacientes p ON c.paciente_id = p.id_paciente
JOIN personal_medico m ON c.medico_id = m.id_personal
LEFT JOIN especialidades e ON m.especialidad_id = e.id_especialidad
WHERE DATE(c.fecha_hora) = CURRENT_DATE;

--==========================================================
--  vista_agenda_medico
--==========================================================
CREATE OR REPLACE VIEW vista_agenda_medico AS
SELECT 
    m.id_personal,
    m.nombres || ' ' || m.apellidos AS medico,
    e.nombre_especialidad,
    c.fecha_hora,
    c.estado_cita,
    p.nombres || ' ' || p.apellidos AS paciente
FROM personal_medico m
JOIN especialidades e ON m.especialidad_id = e.id_especialidad
JOIN citas c ON m.id_personal = c.medico_id
JOIN pacientes p ON c.paciente_id = p.id_paciente
WHERE c.fecha_hora > CURRENT_TIMESTAMP
ORDER BY c.fecha_hora;

--==========================================================
--  vista_historial_paciente
--==========================================================
CREATE OR REPLACE VIEW vista_historial_paciente AS
SELECT 
    p.id_paciente,
    p.nombres || ' ' || p.apellidos AS paciente,
    cm.fecha_consulta,
    cm.diagnostico_principal,
    cm.tratamiento_indicado,
    cm.observaciones_generales
FROM pacientes p
JOIN citas c ON p.id_paciente = c.paciente_id
JOIN consultas_medicas cm ON c.id_cita = cm.cita_id
ORDER BY p.id_paciente, cm.fecha_consulta DESC;

--==========================================================
--  vista_pacientes_inactivos
--==========================================================
CREATE OR REPLACE VIEW vista_pacientes_inactivos AS
SELECT 
    p.id_paciente,
    p.nombres || ' ' || p.apellidos AS nombre_paciente,
    MAX(c.fecha_hora) AS ultima_cita
FROM pacientes p
LEFT JOIN citas c ON p.id_paciente = c.paciente_id
GROUP BY p.id_paciente, p.nombres, p.apellidos
HAVING MAX(c.fecha_hora) IS NULL OR MAX(c.fecha_hora) < CURRENT_DATE - INTERVAL '6 months';

--==========================================================
--  vista_facturas_pendientes_mh
--==========================================================
CREATE OR REPLACE VIEW vista_facturas_pendientes_mh AS
SELECT 
    f.id_factura,
    f.numero_factura,
    f.tipo_documento,
    f.fecha_emision,
    f.estado_mh,
    p.nombres || ' ' || p.apellidos AS paciente,
    f.total
FROM facturas f
LEFT JOIN pacientes p ON f.paciente_id = p.id_paciente
WHERE f.estado_mh IN ('pendiente', 'rechazado');

--==========================================================
--  vista_facturas_pendientes_mh
--==========================================================
CREATE OR REPLACE VIEW vista_facturas_pendientes_mh AS
SELECT 
    f.id_factura,
    f.numero_factura,
    f.tipo_documento,
    f.fecha_emision,
    f.estado_mh,
    p.nombres || ' ' || p.apellidos AS paciente,
    f.total
FROM facturas f
LEFT JOIN pacientes p ON f.paciente_id = p.id_paciente
WHERE f.estado_mh IN ('pendiente', 'rechazado');


--==========================================================
--  			vistas gerenciales
--==========================================================
--==========================================================
--  vista_total_facturado_mes
--==========================================================
CREATE OR REPLACE VIEW vista_total_facturado_mes AS
SELECT 
    TO_CHAR(fecha_emision, 'YYYY-MM') AS mes,
    tipo_documento,
    COUNT(*) AS cantidad_facturas,
    SUM(subtotal) AS total_subtotal,
    SUM(iva) AS total_iva,
    SUM(total) AS total_facturado
FROM facturas
GROUP BY mes, tipo_documento
ORDER BY mes DESC;

--==========================================================
--  vista_ingresos_por_especialidad
--==========================================================
CREATE OR REPLACE VIEW vista_ingresos_por_especialidad AS
SELECT 
    e.nombre_especialidad,
    SUM(df.subtotal) AS ingresos
FROM detalle_facturas df
JOIN servicios_medicos sm ON df.servicio_id = sm.id_servicio
LEFT JOIN especialidades e ON sm.especialidad_id = e.id_especialidad
GROUP BY e.nombre_especialidad
ORDER BY ingresos DESC;

--==========================================================
--  vista_uso_servicios
--==========================================================
CREATE OR REPLACE VIEW vista_uso_servicios AS
SELECT 
    sm.nombre_servicio,
    COUNT(df.id_detalle) AS veces_facturado,
    SUM(df.cantidad) AS total_cantidad,
    SUM(df.subtotal) AS total_ingresos
FROM detalle_facturas df
JOIN servicios_medicos sm ON df.servicio_id = sm.id_servicio
GROUP BY sm.nombre_servicio
ORDER BY veces_facturado DESC;

--==========================================================
--  vista_examenes_urgentes
--==========================================================
CREATE OR REPLACE VIEW vista_examenes_urgentes AS
SELECT 
    es.id_examen,
    es.nombre_examen,
    es.tipo_examen,
    p.nombres || ' ' || p.apellidos AS paciente,
    cm.fecha_consulta,
    es.fecha_solicitud,
    es.resultado
FROM examenes_solicitados es
JOIN consultas_medicas cm ON es.consulta_id = cm.id_consulta
JOIN citas c ON cm.cita_id = c.id_cita
JOIN pacientes p ON c.paciente_id = p.id_paciente
WHERE es.urgente = TRUE AND es.resultado IS NULL;

--==========================================================
--  vista_detalle_facturas_emitidas
--==========================================================
CREATE OR REPLACE VIEW vista_detalle_facturas_emitidas AS
SELECT 
    f.numero_factura,
    f.fecha_emision,
    f.tipo_documento,
    f.estado_mh,
    p.nombres || ' ' || p.apellidos AS paciente,
    df.descripcion_servicio,
    df.cantidad,
    df.precio_unitario,
    df.subtotal,
    df.gravado
FROM facturas f
JOIN pacientes p ON f.paciente_id = p.id_paciente
JOIN detalle_facturas df ON f.id_factura = df.factura_id
ORDER BY f.fecha_emision DESC, f.numero_factura;
