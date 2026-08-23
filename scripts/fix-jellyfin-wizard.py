#!/usr/bin/env python3
"""
fix-jellyfin-wizard.py

Jellyfin 10.11.x almacena IsStartupWizardCompleted en la tabla
'Configuration'. Si tras una migración esa tabla no existe (o está
incompleta), Jellyfin muestra el wizard aunque haya usuarios.

Este script:
  1. Verifica si existe la tabla Configuration
  2. Si no, la crea con el esquema que Jellyfin 10.11.x espera
  3. Inserta/actualiza IsStartupWizardCompleted=true

Resolución de rutas (en orden de prioridad):
  1. --db <ruta>            ruta exacta a jellyfin.db
  2. --config-dir <ruta>    directorio config/jellyfin (deriva la DB)
  3. --data-root <ruta>     DATA_ROOT (deriva config/jellyfin/data/jellyfin.db)
  4. Variable de entorno DATA_ROOT
  5. Default: C:\\Media     (placeholder genérico, ajústalo a tu DATA_ROOT)

Uso:
    python scripts/fix-jellyfin-wizard.py
    python scripts/fix-jellyfin-wizard.py --inspect
    python scripts/fix-jellyfin-wizard.py --reset-password USER _
    python scripts/fix-jellyfin-wizard.py --data-root "F:\\Videos"
    python scripts/fix-jellyfin-wizard.py --db "F:\\Videos\\config\\jellyfin\\data\\jellyfin.db"
"""

import argparse
import os
import sqlite3
import sys
from pathlib import Path

# Placeholder genérico. Si no defines --data-root / --config-dir / --db ni
# la variable de entorno DATA_ROOT, el script usará esta ruta como ejemplo.
# Ajústala a tu DATA_ROOT real o pásala por variable de entorno.
DEFAULT_DATA_ROOT = Path(r"C:\Media")


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Arregla el wizard de Jellyfin tras una migración rota.",
    )
    parser.add_argument(
        "--data-root",
        help="Ruta raíz de datos (equivale a DATA_ROOT del .env). "
             "Si se omite, se usa $DATA_ROOT o el default.",
    )
    parser.add_argument(
        "--config-dir",
        help="Directorio config/jellyfin (sobrescribe --data-root y $DATA_ROOT).",
    )
    parser.add_argument(
        "--db",
        help="Ruta exacta a jellyfin.db (máxima prioridad).",
    )
    parser.add_argument(
        "--inspect",
        action="store_true",
        help="Solo diagnóstico: muestra el estado de la DB sin modificarla.",
    )
    parser.add_argument(
        "--reset-password",
        nargs=2,
        metavar=("USER", "PASS"),
        help="Marca al usuario USER para que cambie la contraseña en el "
             "siguiente login. El segundo argumento se ignora (compatibilidad "
             "con la versión anterior del script).",
    )
    return parser.parse_args(argv)


def resolve_paths(args):
    """Devuelve (db_path, config_dir) según la prioridad documentada."""
    if args.db:
        db_path = Path(args.db)
        # Estructura estándar: <config_dir>/data/jellyfin.db
        config_dir = db_path.parent.parent
        return db_path, config_dir

    if args.config_dir:
        config_dir = Path(args.config_dir)
        return config_dir / "data" / "jellyfin.db", config_dir

    if args.data_root:
        data_root = Path(args.data_root)
    else:
        env_root = os.environ.get("DATA_ROOT")
        data_root = Path(env_root) if env_root else DEFAULT_DATA_ROOT

    config_dir = data_root / "config" / "jellyfin"
    return config_dir / "data" / "jellyfin.db", config_dir


def inspect(conn):
    cursor = conn.cursor()
    print("=" * 60)
    print("INSPECT")
    print("=" * 60)

    # 1. ¿Existe la tabla Configuration?
    cursor.execute("""
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='Configuration'
    """)
    has_config = bool(cursor.fetchone())
    print(f"\n  Tabla 'Configuration' existe: {has_config}")

    if has_config:
        cursor.execute("PRAGMA table_info(Configuration)")
        cols = [c[1] for c in cursor.fetchall()]
        print(f"  Columnas: {cols}")
        cursor.execute("SELECT * FROM Configuration")
        rows = cursor.fetchall()
        print(f"  Filas: {len(rows)}")
        for row in rows[:20]:
            print(f"    {row}")

    # 2. Preguntar a Jellyfin por la count de "wizard" related
    cursor.execute("""
        SELECT name FROM sqlite_master
        WHERE type='table' AND (name LIKE '%Config%' OR name LIKE '%Wizard%')
    """)
    print(f"\n  Tablas con 'Config' o 'Wizard': {cursor.fetchall()}")

    # 3. Users
    cursor.execute("SELECT Username, length(Password) FROM Users ORDER BY Username")
    print(f"\n  Usuarios:")
    for u, l in cursor.fetchall():
        print(f"    {u} (password hash: {l} chars)")

    # 4. Listar contenido de /config/jellyfin (parent dir)
    print(f"\n  Contenido de {CONFIG_DIR}:")
    if CONFIG_DIR.exists():
        for item in sorted(CONFIG_DIR.iterdir()):
            try:
                if item.is_file():
                    print(f"    {item.name}  ({item.stat().st_size} bytes)")
                else:
                    cnt = sum(1 for _ in item.iterdir())
                    print(f"    {item.name}/  ({cnt} items)")
            except Exception as e:
                print(f"    {item.name}  ({e})")

    # 5. Contenido de /config/jellyfin/config (donde esta system.xml en algunos casos)
    sub_config = CONFIG_DIR / "config"
    if sub_config.exists():
        print(f"\n  Contenido de {sub_config}:")
        for f in sorted(sub_config.iterdir()):
            if f.is_file():
                print(f"    {f.name}  ({f.stat().st_size} bytes)")


def ensure_config_table(conn):
    cursor = conn.cursor()

    # Comprobar si existe
    cursor.execute("""
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='Configuration'
    """)
    has = bool(cursor.fetchone())

    if not has:
        print("\n  Creando tabla 'Configuration'...")
        # Esquema tipico de Jellyfin 10.11.x
        cursor.execute("""
            CREATE TABLE Configuration (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            )
        """)
        print("  OK tabla creada.")

    # Setear flag
    cursor.execute("""
        INSERT OR REPLACE INTO Configuration (key, value) VALUES (?, ?)
    """, ("IsStartupWizardCompleted", "true"))
    print(f"  flag IsStartupWizardCompleted = true (1 fila afectada)")

    # Tambien poner algunos flags utiles si no estan
    otros = [
        ("EnableRemoteAccess", "false"),
        ("EnableUPnP", "false"),
        ("EnableAutomaticRestart", "true"),
        ("EnableMetrics", "false"),
        ("EnableNormalizedItemByNameIds", "true"),
    ]
    for k, v in otros:
        cursor.execute(
            "INSERT OR IGNORE INTO Configuration (key, value) VALUES (?, ?)",
            (k, v)
        )

    conn.commit()
    print("  Commit OK")


def reset_password(conn, username, _new_password_ignored):
    cursor = conn.cursor()
    cursor.execute("SELECT Username FROM Users WHERE Username = ?", (username,))
    if not cursor.fetchone():
        print(f"  Usuario '{username}' no existe")
        return

    cursor.execute(
        "UPDATE Users SET MustUpdatePassword = 1 WHERE Username = ?",
        (username,)
    )
    conn.commit()
    print(f"  '{username}' debe cambiar password en el primer login")


def main():
    global DB_PATH, CONFIG_DIR
    if sys.platform == "win32":
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args(sys.argv[1:])
    DB_PATH, CONFIG_DIR = resolve_paths(args)

    if not DB_PATH.exists():
        print(f"ERROR: no se encuentra la DB en {DB_PATH}")
        print("Pásale la ruta con --db, --config-dir, --data-root o $DATA_ROOT.")
        sys.exit(1)

    conn = sqlite3.connect(str(DB_PATH))
    try:
        if args.inspect:
            inspect(conn)
            return

        inspect(conn)
        print()

        if args.reset_password:
            username, _dummy = args.reset_password
            reset_password(conn, username, _dummy)
        else:
            ensure_config_table(conn)

        print("\n" + "=" * 60)
        print("SIGUIENTE PASO")
        print("=" * 60)
        print("  podman compose restart jellyfin")
        print("  Esperar 10 segundos")
        print("  Abrir http://localhost:8096  ->  ahora debería mostrar LOGIN")
        print()
        print("  Si NO arranca: podman logs jellyfin --tail 50")
        print("  Si todo OK: python scripts/fix-jellyfin-wizard.py --inspect")
        print("                para confirmar que ahora la tabla Configuration existe")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
