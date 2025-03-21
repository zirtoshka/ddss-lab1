\prompt 'Введите имя таблицы (можно database.schema.table): ' user_input
\set table_full :user_input

SELECT set_config('lab1.tab_name', :'table_full', false);

DO $$
DECLARE
    full_table TEXT;
    database_name TEXT;
    schema_name TEXT;
    table_name TEXT;
    dot_count INT;
    rec RECORD;
BEGIN
    full_table := current_setting('lab1.tab_name');

    dot_count := length(full_table) - length(replace(full_table, '.', ''));

    CASE dot_count
        WHEN 0 THEN 
            schema_name := current_schema();
            table_name := full_table;
        WHEN 1 THEN
            schema_name := split_part(full_table, '.', 1);
            table_name := split_part(full_table, '.', 2);
        WHEN 2 THEN
            database_name := split_part(full_table, '.', 1);
            schema_name := split_part(full_table, '.', 2);
            table_name := split_part(full_table, '.', 3);
            
            IF database_name <> current_database() THEN
                RAISE EXCEPTION 'Ошибка: нельзя запрашивать таблицы из другой базы данных (%).', database_name;
            END IF;
        ELSE 
            RAISE EXCEPTION 'Ошибка: неправильный формат ввода. Ожидается максимум две точки.';
    END CASE;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = table_name AND n.nspname = schema_name
    ) THEN
        RAISE EXCEPTION 'Ошибка: таблица "%"."%" не существует.', schema_name, table_name;
    END IF;

    RAISE NOTICE 'Таблица: %', table_name;
    
    RAISE NOTICE ' No.|  Имя столбца    | Атрибуты';
    RAISE NOTICE '----+-----------------+--------------------------------------------------';

    FOR rec IN 
        SELECT 
            a.attnum AS column_number,
            a.attname AS column_name,
            pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
            COALESCE(d.description, '') AS column_comment,
            COALESCE(i.index_name, 'Нет индекса') AS index_info
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
        JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
        LEFT JOIN pg_catalog.pg_description d ON a.attrelid = d.objoid AND a.attnum = d.objsubid
        LEFT JOIN (
            SELECT 
                ic.relname AS index_name,
                unnest(i.indkey) AS indkey,
                i.indrelid
            FROM pg_catalog.pg_index i
            JOIN pg_catalog.pg_class ic ON i.indexrelid = ic.oid
        ) i ON i.indrelid = c.oid AND i.indkey = a.attnum
        WHERE c.relname = table_name
          AND n.nspname = schema_name
          AND a.attnum > 0
        ORDER BY a.attnum
    LOOP
         RAISE NOTICE '% | %  | Type    :  %',
             RPAD(rec.column_number::text, 2, ' '), RPAD(rec.column_name::text, 15, ' '), rec.data_type;
        RAISE NOTICE '   |                  | Commen  :  %', rec.column_comment;
        RAISE NOTICE '   |                  | Index   :  %', rec.index_info;
    END LOOP;

END $$;
