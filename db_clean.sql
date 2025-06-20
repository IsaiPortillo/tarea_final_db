-- =====================================================
-- SISTEMA INTEGRAL DE GESTIÓN CLÍNICA PRIVADA
-- Base de Datos PostgreSQL
-- =====================================================

-- Crear la base de datos
-- CREATE DATABASE clinica_privada;
-- \c clinica_privada;

-- =====================================================
-- CATÁLOGOS Y TABLAS MAESTRAS
-- =====================================================

-- Catálogo de alergias
CREATE TABLE alergias_catalogo (
    id_alergia SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    gravedad VARCHAR(20) CHECK (gravedad IN ('leve', 'moderada', 'grave')),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seguros médicos
CREATE TABLE seguros_medicos (
    id_seguro SERIAL PRIMARY KEY,
    nombre_seguro VARCHAR(100) NOT NULL,
    aseguradora VARCHAR(100) NOT NULL,
    tipo VARCHAR(50) CHECK (tipo IN ('publico', 'privado', 'particular')),
    descuento DECIMAL(5,2) DEFAULT 0.00,
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Especialidades médicas
CREATE TABLE especialidades (
    id_especialidad SERIAL PRIMARY KEY,
    nombre_especialidad VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    codigo_mh VARCHAR(20), -- Código para facturación MH
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Laboratorios farmacéuticos
CREATE TABLE laboratorios (
    id_laboratorio SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    pais VARCHAR(50),
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Presentaciones de medicamentos
CREATE TABLE presentaciones (
    id_presentacion SERIAL PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL UNIQUE, -- tableta, capsula, jarabe, etc.
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Concentraciones de medicamentos
CREATE TABLE concentraciones (
    id_concentracion SERIAL PRIMARY KEY,
    descripcion VARCHAR(50) NOT NULL UNIQUE, -- 500mg, 250mg/5ml, etc.
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tipos de movimiento de inventario
CREATE TABLE tipo_movimiento (
    id_tipo SERIAL PRIMARY KEY,
    tipo_nombre VARCHAR(30) NOT NULL UNIQUE, -- entrada, salida, ajuste, vencimiento
    descripcion TEXT,
    afecta_stock BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- GESTIÓN DE PACIENTES
-- =====================================================

-- Pacientes
CREATE TABLE pacientes (
    id_paciente SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    genero CHAR(1) CHECK (genero IN ('M', 'F')),
    dui VARCHAR(10) UNIQUE,
    pasaporte VARCHAR(20),
    nit VARCHAR(17),
    direccion_completa TEXT,
    telefono VARCHAR(15),
    email VARCHAR(100),
    contacto_emergencia VARCHAR(200),
    tipo_sangre VARCHAR(5) CHECK (tipo_sangre IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    id_seguro INTEGER REFERENCES seguros_medicos(id_seguro),
    estado_civil VARCHAR(20) CHECK (estado_civil IN ('soltero', 'casado', 'divorciado', 'viudo', 'union_libre')),
    profesion VARCHAR(100),
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_registro VARCHAR(50)
);

-- Alergias de pacientes
CREATE TABLE alergias_paciente (
    id_alergia_paciente SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id_paciente) ON DELETE CASCADE,
    alergia_id INTEGER NOT NULL REFERENCES alergias_catalogo(id_alergia),
    fecha_deteccion DATE,
    observaciones TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(paciente_id, alergia_id)
);

-- =====================================================
-- GESTIÓN DE PERSONAL MÉDICO
-- =====================================================

-- Personal médico
CREATE TABLE personal_medico (
    id_personal SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    dui VARCHAR(10) UNIQUE NOT NULL,
    nit VARCHAR(17),
    nup VARCHAR(20), -- Número Único Previsional
    especialidad_id INTEGER REFERENCES especialidades(id_especialidad),
    numero_jvpm VARCHAR(20) UNIQUE, -- Junta de Vigilancia de la Profesión Médica
    telefono VARCHAR(15),
    email VARCHAR(100),
    direccion TEXT,
    fecha_contratacion DATE NOT NULL,
    estado_activo BOOLEAN DEFAULT TRUE,
    horario_atencion JSONB, -- Almacenar horarios flexibles
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- GESTIÓN DE MEDICAMENTOS E INVENTARIO
-- =====================================================

-- Medicamentos
CREATE TABLE medicamentos (
    id_medicamento SERIAL PRIMARY KEY,
    nombre_comercial VARCHAR(150) NOT NULL,
    nombre_generico VARCHAR(150) NOT NULL,
    id_laboratorio INTEGER REFERENCES laboratorios(id_laboratorio),
    id_presentacion INTEGER REFERENCES presentaciones(id_presentacion),
    id_concentracion INTEGER REFERENCES concentraciones(id_concentracion),
    lote VARCHAR(50),
    fecha_vencimiento DATE,
    stock_actual INTEGER DEFAULT 0,
    stock_minimo INTEGER DEFAULT 0,
    precio_compra DECIMAL(10,2),
    precio_venta DECIMAL(10,2),
    requiere_receta BOOLEAN DEFAULT TRUE,
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Movimientos de inventario
CREATE TABLE movimientos_inventario (
    id_movimiento SERIAL PRIMARY KEY,
    medicamento_id INTEGER NOT NULL REFERENCES medicamentos(id_medicamento),
    id_tipo INTEGER NOT NULL REFERENCES tipo_movimiento(id_tipo),
    cantidad INTEGER NOT NULL,
    stock_anterior INTEGER,
    stock_nuevo INTEGER,
    motivo TEXT,
    usuario_id VARCHAR(50) NOT NULL,
    fecha_movimiento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- GESTIÓN DE CITAS Y CONSULTAS
-- =====================================================

-- Citas
CREATE TABLE citas (
    id_cita SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id_paciente),
    medico_id INTEGER NOT NULL REFERENCES personal_medico(id_personal),
    fecha_hora TIMESTAMP NOT NULL,
    motivo_consulta TEXT,
    estado_cita VARCHAR(20) DEFAULT 'programada' 
        CHECK (estado_cita IN ('programada', 'confirmada', 'en_proceso', 'completada', 'cancelada', 'no_asistio')),
    observaciones TEXT,
    costo_consulta DECIMAL(8,2),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_creacion VARCHAR(50)
);

-- Consultas médicas
CREATE TABLE consultas_medicas (
    id_consulta SERIAL PRIMARY KEY,
    cita_id INTEGER NOT NULL REFERENCES citas(id_cita),
    motivo_consulta TEXT,
    examen_fisico TEXT,
    diagnostico_principal TEXT NOT NULL,
    tratamiento_indicado TEXT,
    proxima_cita DATE,
    fecha_consulta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    peso DECIMAL(5,2),
    altura DECIMAL(4,2),
    presion_arterial VARCHAR(10),
    temperatura DECIMAL(4,1),
    observaciones_generales TEXT
);

-- Diagnósticos secundarios
CREATE TABLE diagnosticos_secundarios (
    id_diagnostico SERIAL PRIMARY KEY,
    consulta_id INTEGER NOT NULL REFERENCES consultas_medicas(id_consulta) ON DELETE CASCADE,
    descripcion TEXT NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exámenes solicitados
CREATE TABLE examenes_solicitados (
    id_examen SERIAL PRIMARY KEY,
    consulta_id INTEGER NOT NULL REFERENCES consultas_medicas(id_consulta) ON DELETE CASCADE,
    nombre_examen VARCHAR(200) NOT NULL,
    tipo_examen VARCHAR(50), -- laboratorio, imagen, especializado
    observaciones TEXT,
    urgente BOOLEAN DEFAULT FALSE,
    fecha_solicitud TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_resultado DATE,
    resultado TEXT
);

-- Medicamentos recetados
CREATE TABLE medicamento_recetado (
    id_receta SERIAL PRIMARY KEY,
    consulta_id INTEGER NOT NULL REFERENCES consultas_medicas(id_consulta) ON DELETE CASCADE,
    id_medicamento INTEGER REFERENCES medicamentos(id_medicamento),
    nombre_medicamento VARCHAR(200), -- Por si no está en inventario
    dosis VARCHAR(100) NOT NULL,
    frecuencia VARCHAR(100) NOT NULL,
    duracion_tratamiento VARCHAR(100),
    instrucciones_especiales TEXT,
    fecha_prescripcion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- SERVICIOS MÉDICOS Y FACTURACIÓN
-- =====================================================

-- Servicios médicos
CREATE TABLE servicios_medicos (
    id_servicio SERIAL PRIMARY KEY,
    nombre_servicio VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    codigo_tributario VARCHAR(20), -- Para facturación MH
    categoria_servicio VARCHAR(50),
    especialidad_id INTEGER REFERENCES especialidades(id_especialidad),
    estado_activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Facturas
CREATE TABLE facturas (
    id_factura SERIAL PRIMARY KEY,
    numero_factura VARCHAR(50) NOT NULL UNIQUE,
    serie_factura VARCHAR(10),
    paciente_id INTEGER REFERENCES pacientes(id_paciente),
    fecha_emision TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_documento VARCHAR(3) CHECK (tipo_documento IN ('CCF', 'FCF', 'NCR', 'NDB')),
    subtotal DECIMAL(12,2) NOT NULL,
    iva DECIMAL(12,2) DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL,
    estado_mh VARCHAR(20) DEFAULT 'pendiente' 
        CHECK (estado_mh IN ('pendiente', 'enviado', 'aceptado', 'rechazado')),
    uuid_mh UUID,
    codigo_generacion VARCHAR(100),
    sello_recepcion VARCHAR(500),
    fecha_transmision TIMESTAMP,
    observaciones TEXT,
    usuario_emisor VARCHAR(50)
);

-- Detalle de facturas
CREATE TABLE detalle_facturas (
    id_detalle SERIAL PRIMARY KEY,
    factura_id INTEGER NOT NULL REFERENCES facturas(id_factura) ON DELETE CASCADE,
    servicio_id INTEGER REFERENCES servicios_medicos(id_servicio),
    descripcion_servicio VARCHAR(200),
    cantidad INTEGER NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    numero_linea INTEGER NOT NULL
);

-- =====================================================
-- AUDITORÍA Y BITÁCORA
-- =====================================================

-- Bitácora de actividades
CREATE TABLE bitacora_actividad (
    id_bitacora SERIAL PRIMARY KEY,
    usuario_bd VARCHAR(50) NOT NULL,
    accion VARCHAR(20) NOT NULL CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE')),
    tabla_afectada VARCHAR(50) NOT NULL,
    id_registro_afectado INTEGER,
    descripcion TEXT,
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_usuario INET,
    aplicacion VARCHAR(100)
);

-- =====================================================
-- ÍNDICES PARA OPTIMIZACIÓN
-- =====================================================

-- Índices para pacientes
CREATE INDEX idx_pacientes_dui ON pacientes(dui);
CREATE INDEX idx_pacientes_nombres ON pacientes(nombres, apellidos);
CREATE INDEX idx_pacientes_fecha_nacimiento ON pacientes(fecha_nacimiento);

-- Índices para citas
CREATE INDEX idx_citas_fecha_hora ON citas(fecha_hora);
CREATE INDEX idx_citas_paciente ON citas(paciente_id);
CREATE INDEX idx_citas_medico ON citas(medico_id);
CREATE INDEX idx_citas_estado ON citas(estado_cita);

-- Índices para facturación
CREATE INDEX idx_facturas_fecha ON facturas(fecha_emision);
CREATE INDEX idx_facturas_paciente ON facturas(paciente_id);
CREATE INDEX idx_facturas_numero ON facturas(numero_factura);
CREATE INDEX idx_facturas_estado_mh ON facturas(estado_mh);

-- Índices para inventario
CREATE INDEX idx_medicamentos_nombre ON medicamentos(nombre_comercial, nombre_generico);
CREATE INDEX idx_medicamentos_vencimiento ON medicamentos(fecha_vencimiento);
CREATE INDEX idx_movimientos_fecha ON movimientos_inventario(fecha_movimiento);