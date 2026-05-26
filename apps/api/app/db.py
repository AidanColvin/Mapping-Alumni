"""SQLite connection + schema initialization + upsert helpers."""
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from app.config import settings

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"
_SQLITE_PREFIX = "sqlite:///"


def _db_file() -> Path:
    url = settings.database_url
    if not url.startswith(_SQLITE_PREFIX):
        raise ValueError("Only SQLite is supported in MVP. Set DATABASE_URL=sqlite:///./path/to/db")
    path = Path(url[len(_SQLITE_PREFIX):])
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


@contextmanager
def get_conn() -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(_db_file())
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA journal_mode = WAL;")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    """Apply all .sql migrations in order. Idempotent."""
    with get_conn() as conn:
        for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
            conn.executescript(sql_file.read_text())


# --- upsert helpers used by alumni_search pipeline ---

def upsert_institution(conn: sqlite3.Connection, inst) -> None:
    conn.execute(
        """INSERT INTO institutions (id, name, slug, country, wikidata_id)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET name=excluded.name, country=excluded.country""",
        (inst.id, inst.name, inst.slug, inst.country, inst.wikidata_id),
    )


def upsert_person(conn: sqlite3.Connection, person, confidence: float) -> None:
    conn.execute(
        """INSERT INTO people (id, full_name, source_url, source_type, retrieved_at, confidence)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET confidence=excluded.confidence""",
        (
            person.id,
            person.full_name,
            person.source_url,
            person.source_type,
            person.retrieved_at.isoformat(),
            confidence,
        ),
    )


def upsert_company(conn: sqlite3.Connection, company) -> None:
    conn.execute(
        """INSERT INTO companies (id, name, slug, sector, domain)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(id) DO NOTHING""",
        (company.id, company.name, company.slug, company.sector, company.domain),
    )


def upsert_employment(conn: sqlite3.Connection, person_id: str, emp) -> None:
    company_id = emp.company.id if emp.company else None
    conn.execute(
        """INSERT INTO employment_history
             (person_id, company_id, title, title_level, sector, is_current)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (person_id, company_id, emp.title, emp.title_level, emp.sector, int(emp.is_current)),
    )
