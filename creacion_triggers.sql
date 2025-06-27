--==========================================================
--  Funcion para Actualizar registro en bitacora_actividad
--==========================================================
CREATE OR REPLACE FUNCTION fn_log_bitacora_detallada()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO bitacora_actividad (
        usuario_bd,
        accion,
        tabla_afectada,
        id_registro_afectado,
        descripcion,
        datos_anteriores,
        datos_nuevos,
        fecha_hora,
        ip_usuario,
        aplicacion
    )
    VALUES (
        current_user,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id), -- Adaptar si el PK tiene otro nombre
        CASE TG_OP
            WHEN 'INSERT' THEN 'Inserción de registro'
            WHEN 'UPDATE' THEN 'Actualización de registro'
            WHEN 'DELETE' THEN 'Eliminación de registro'
        END,
        to_jsonb(OLD),
        to_jsonb(NEW),
        now(),
        inet_client_addr(), -- IP
        current_setting('application_name', true) -- Nombre de la app si lo seteas en conexión
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- INSERT
CREATE TRIGGER trg_log_insert_citas
AFTER INSERT ON citas
FOR EACH ROW EXECUTE FUNCTION fn_log_bitacora_detallada();

-- UPDATE
CREATE TRIGGER trg_log_update_citas
AFTER UPDATE ON citas
FOR EACH ROW EXECUTE FUNCTION fn_log_bitacora_detallada();

-- DELETE
CREATE TRIGGER trg_log_delete_citas
AFTER DELETE ON citas
FOR EACH ROW EXECUTE FUNCTION fn_log_bitacora_detallada();

--==========================================================
--  Triger para anulaciones
--==========================================================
CREATE OR REPLACE FUNCTION fn_marcar_factura_anulada()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE facturas
    SET estado_mh = 'anulado'
    WHERE id_factura = NEW.id_factura;

    -- Bitácora
    INSERT INTO bitacora_actividad (
        usuario_bd,
        accion,
        tabla_afectada,
        id_registro_afectado,
        descripcion,
        datos_anteriores,
        datos_nuevos,
        fecha_hora,
        ip_usuario,
        aplicacion
    )
    VALUES (
        current_user,
        'ANULACION',
        'facturas',
        NEW.id_factura,
        'Factura anulada por inserción en anulaciones',
        (SELECT to_jsonb(f) FROM facturas f WHERE f.id_factura = NEW.id_factura),
        jsonb_build_object('estado_mh', 'anulado'),
        now(),
        inet_client_addr(),
        current_setting('application_name', true)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_marcar_factura_anulada
AFTER INSERT ON anulaciones
FOR EACH ROW
EXECUTE FUNCTION fn_marcar_factura_anulada();

--==========================================================
--  Triger para evitar citas duplicadas
--==========================================================
CREATE OR REPLACE FUNCTION fn_validar_cita_unica()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM citas
        WHERE fecha_hora = NEW.fecha_hora
        AND medico_id = NEW.medico_id
    ) THEN
        RAISE EXCEPTION 'El médico ya tiene una cita programada en esa fecha y hora.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evitar_citas_duplicadas
BEFORE INSERT ON citas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_cita_unica();

--==========================================================
--  Trigger para verificar stock antes de recetar
--==========================================================
CREATE OR REPLACE FUNCTION fn_verificar_stock_medicamento()
RETURNS TRIGGER AS $$
DECLARE
    stock_actual INT;
BEGIN
    SELECT stock_actual INTO stock_actual
    FROM medicamentos
    WHERE id_medicamento = NEW.medicamento_id;

    IF stock_actual IS NULL THEN
        RAISE EXCEPTION 'Medicamento no encontrado.';
    ELSIF NEW.cantidad > stock_actual THEN
        RAISE EXCEPTION 'Cantidad recetada excede el stock disponible (%).', stock_actual;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verificar_stock_al_recetar
BEFORE INSERT ON medicamento_recetado
FOR EACH ROW
EXECUTE FUNCTION fn_verificar_stock_medicamento();

--==========================================================
--  Trigger para actualizar stock automáticamente
--==========================================================
CREATE OR REPLACE FUNCTION fn_actualizar_stock_inventario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo_movimiento = 'entrada' THEN
        UPDATE medicamentos
        SET stock_actual = stock_actual + NEW.cantidad
        WHERE id_medicamento = NEW.medicamento_id;
    ELSIF NEW.tipo_movimiento = 'salida' THEN
        IF (SELECT stock_actual FROM medicamentos WHERE id_medicamento = NEW.medicamento_id) < NEW.cantidad THEN
            RAISE EXCEPTION 'No hay suficiente stock para registrar la salida.';
        END IF;

        UPDATE medicamentos
        SET stock_actual = stock_actual - NEW.cantidad
        WHERE id_medicamento = NEW.medicamento_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_stock
AFTER INSERT ON movimientos_inventario
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_stock_inventario();

--==========================================================
--  Trigger para no eliminar cita facturada
--==========================================================
CREATE OR REPLACE FUNCTION fn_prevenir_eliminacion_cita_facturada()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM consultas_medicas WHERE cita_id = OLD.id_cita
    ) OR EXISTS (
        SELECT 1 FROM facturas WHERE cita_id = OLD.id_cita
    ) THEN
        RAISE EXCEPTION 'No se puede eliminar la cita porque ya tiene diagnóstico o factura asociada.';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_eliminar_cita_facturada
BEFORE DELETE ON citas
FOR EACH ROW
EXECUTE FUNCTION fn_prevenir_eliminacion_cita_facturada();

--==========================================================
--  Trigger para Calcula automáticamente el IVA
--==========================================================
CREATE OR REPLACE FUNCTION fn_calcular_iva_factura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.iva IS NULL OR NEW.iva = 0 THEN
        NEW.iva := ROUND(NEW.subtotal * 0.13, 2);
        NEW.total := NEW.subtotal + NEW.iva;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_autocompletar_iva_factura
BEFORE INSERT ON facturas
FOR EACH ROW
EXECUTE FUNCTION fn_calcular_iva_factura();

--==========================================================
--  Trigger para asignar_estado_por_defecto	
--==========================================================
CREATE OR REPLACE FUNCTION fn_estado_mh_por_defecto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado_mh IS NULL THEN
        NEW.estado_mh := 'pendiente';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_estado_mh_por_defecto
BEFORE INSERT ON facturas
FOR EACH ROW
EXECUTE FUNCTION fn_estado_mh_por_defecto();

--==========================================================
--  Trigger para validar_diagnostico_unico	
--==========================================================
CREATE OR REPLACE FUNCTION fn_validar_diagnostico_unico()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM consultas_medicas
        WHERE cita_id = NEW.cita_id
    ) THEN
        RAISE EXCEPTION 'Ya existe un diagnóstico para esta cita.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_diagnostico_unico
BEFORE INSERT ON consultas_medicas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_diagnostico_unico();

--==========================================================
--  Trigger para restringir_eliminacion_usuario_admin	
--==========================================================
CREATE OR REPLACE FUNCTION fn_prevenir_eliminacion_admin()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.rol = 'administrador' THEN
        RAISE EXCEPTION 'No se puede eliminar un usuario administrador.';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restringir_eliminacion_usuario_admin
BEFORE DELETE ON usuarios
FOR EACH ROW
EXECUTE FUNCTION fn_prevenir_eliminacion_admin();
