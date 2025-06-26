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
