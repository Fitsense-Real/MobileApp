#!/bin/bash
# Uso: snap.sh <base>  → una línea por tabla: nombre filas md5(contenido ordenado)
export PGPASSWORD=x
psql -h localhost -U postgres -d "$1" -Atc "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by 1" | while read t; do
  psql -h localhost -U postgres -d "$1" -Atc "select '$t', count(*), coalesce(md5(string_agg(x::text, '|' order by x::text)),'-') from \"$t\" x"
done
