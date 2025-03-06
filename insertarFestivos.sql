USE [AUTOMATIC_BI_PRO];

-- Insertar los festivos proporcionados
INSERT INTO dbo.Festivos (FechaFestiva)
VALUES 
('2023-01-01'), ('2023-01-09'), ('2023-03-20'), ('2023-04-06'), ('2023-04-07'),
('2023-04-09'), ('2023-05-01'), ('2023-05-22'), ('2023-06-12'), ('2023-06-19'),
('2023-07-03'), ('2023-07-20'), ('2023-08-07'), ('2023-08-21'), ('2023-10-16'),
('2023-11-06'), ('2023-11-13'), ('2023-12-08'), ('2023-12-25'),

('2024-01-01'), ('2024-01-08'), ('2024-03-25'), ('2024-03-28'), ('2024-03-29'),
('2024-03-31'), ('2024-05-01'), ('2024-05-13'), ('2024-06-03'), ('2024-06-07'),
('2024-07-01'), ('2024-07-20'), ('2024-08-07'), ('2024-08-19'), ('2024-10-14'),
('2024-11-04'), ('2024-11-11'), ('2024-12-08'), ('2024-12-25'),

('2025-01-01'), ('2025-01-06'), ('2025-03-24'), ('2025-04-17'), ('2025-04-18'),
('2025-04-20'), ('2025-05-01'), ('2025-05-29'), ('2025-06-19'), ('2025-06-29'),
('2025-06-30'), ('2025-07-20'), ('2025-08-07'), ('2025-08-18'), ('2025-10-13'),
('2025-11-03'), ('2025-11-17'), ('2025-12-08'), ('2025-12-25'),

('2026-01-01'), ('2026-01-06'), ('2026-03-23'), ('2026-04-02'), ('2026-04-03'),
('2026-04-05'), ('2026-05-01'), ('2026-05-14'), ('2026-06-04'), ('2026-06-15'),
('2026-06-29'), ('2026-07-20'), ('2026-08-07'), ('2026-08-17'), ('2026-10-12'),
('2026-11-02'), ('2026-11-16'), ('2026-12-08'), ('2026-12-25');

-- Insertar todos los domingos de 2023 a 2026
DECLARE @Fecha DATE = '2023-01-01';
WHILE @Fecha <= '2026-12-31'
BEGIN
    IF DATEPART(WEEKDAY, @Fecha) = 7  -- 1 = Domingo en SQL Server
        INSERT INTO dbo.Festivos (FechaFestiva) 
        SELECT @Fecha 
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Festivos WHERE FechaFestiva = @Fecha);
    SET @Fecha = DATEADD(DAY, 1, @Fecha);
END;

-- Agregar la columna DiaSemana
ALTER TABLE dbo.Festivos ADD DiaSemana CHAR(1);

-- Actualizar la columna con la inicial del día de la semana
UPDATE dbo.Festivos
SET DiaSemana = CASE 
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Monday' THEN 'L'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Tuesday' THEN 'M'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Wednesday' THEN 'X'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Thursday' THEN 'J'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Friday' THEN 'V'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Saturday' THEN 'S'
    WHEN DATENAME(WEEKDAY, FechaFestiva) = 'Sunday' THEN 'D'
END;

-- Verificar resultados
SELECT * FROM dbo.Festivos ORDER BY FechaFestiva;
