-- =====================================================
-- ROLES DE POSTGRESQL PARA CONTROL DE PERMISOS A NIVEL DE BD
-- =====================================================

-- Crear roles del sistema
CREATE ROLE administrador LOGIN PASSWORD 'admin123';
CREATE ROLE medico LOGIN PASSWORD 'medico123';
CREATE ROLE recepcionista LOGIN PASSWORD 'recepcion123';

-- Asignar permisos base a cada rol
-- Permisos para administrador (acceso total)
GRANT ALL PRIVILEGES ON SCHEMA public TO administrador;

-- Para futuras tablas
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO administrador;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO administrador;

-- Permisos para medico
-- Acceso a datos clínicos, no facturación
GRANT SELECT, INSERT, UPDATE ON pacientes TO medico;
GRANT SELECT, INSERT, UPDATE ON citas TO medico;
GRANT SELECT, INSERT, UPDATE ON consultas_medicas TO medico;
GRANT SELECT, INSERT ON diagnosticos_secundarios TO medico;
GRANT SELECT, INSERT ON medicamento_recetado TO medico;
GRANT SELECT ON medicamentos TO medico;

-- Permisos para recepcionista
-- Manejo básico de citas y pacientes
GRANT SELECT, INSERT, UPDATE ON pacientes TO recepcionista;
GRANT SELECT, INSERT, UPDATE ON citas TO recepcionista;
GRANT SELECT ON personal_medico TO recepcionista;

-- Permisos para funciones específicas
GRANT EXECUTE ON FUNCTION 
    fn_total_facturado(DATE, DATE),
    fn_facturado_por_tipo(TEXT),
    fn_total_por_paciente(INT),
    fn_servicios_mas_usados(),
    fn_contar_facturas_estado_mh(TEXT),
    fn_preparar_dte(INT)
TO administrador;

GRANT EXECUTE ON FUNCTION 
    fn_promedio_dias_entre_visitas(INT),
    fn_citas_por_medico(INT),
    fn_alerta_medicamento_stock_bajo()
TO medico, administrador;

-- Dar permiso de ejecución a funciones de triggers relevantes
GRANT EXECUTE ON FUNCTION 
    fn_log_bitacora_detallada(),
    fn_marcar_factura_anulada(),
    fn_validar_cita_unica(),
    fn_verificar_stock_medicamento(),
    fn_actualizar_stock_inventario(),
    fn_prevenir_eliminacion_cita_facturada(),
    fn_calcular_iva_factura(),
    fn_estado_mh_por_defecto(),
    fn_validar_diagnostico_unico(),
    fn_prevenir_eliminacion_admin()
TO administrador;

-- Crear vistas para facilitar el acceso a datos relevantes

GRANT SELECT ON 
    vista_citas_del_dia,
    vista_agenda_medico,
    vista_historial_paciente,
    vista_pacientes_inactivos,
    vista_examenes_urgentes
TO medico;

GRANT SELECT ON 
    vista_citas_del_dia,
    vista_agenda_medico,
    vista_pacientes_inactivos
TO recepcionista;

GRANT SELECT ON 
    vista_citas_del_dia,
    vista_agenda_medico,
    vista_historial_paciente,
    vista_pacientes_inactivos,
    vista_facturas_pendientes_mh,
    vista_total_facturado_mes,
    vista_ingresos_por_especialidad,
    vista_uso_servicios,
    vista_examenes_urgentes,
    vista_detalle_facturas_emitidas
TO administrador;