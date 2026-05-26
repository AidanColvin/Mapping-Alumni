import sqlite3
import os
from typing import List, Dict, Any, Optional
from app.models.domain import SearchResult, Institution
from app.config import settings
from app.utils.logger import get_logger

log = get_logger(__name__)

DB_PATH = settings.database_url.replace("sqlite:///", "") if settings.database_url.startswith("sqlite:///") else "alumnimap.db"

def get_db_connection():
    """Establishes and returns a connection to the SQLite database."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initializes database schema if it doesn't exist."""
    os.makedirs(os.path.dirname(os.path.abspath(DB_PATH)), exist_ok=True)
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS institutions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT UNIQUE NOT NULL,
        wikidata_id TEXT UNIQUE
    );
    """)
    
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS people (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        wikidata_id TEXT UNIQUE,
        source_type TEXT,
        source_url TEXT
    );
    """)
    
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS employment_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id TEXT,
        company_name TEXT,
        title TEXT,
        sector TEXT,
        title_level TEXT,
        confidence REAL,
        is_current INTEGER DEFAULT 1,
        FOREIGN KEY(person_id) REFERENCES people(id)
    );
    """)
    conn.commit()
    conn.close()
    log.info("Database initialized successfully.")

def upsert_search_results(results: List[SearchResult], institution: Any):
    """Saves or updates search records."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        inst_id = institution.wikidata_id or institution.slug
        cursor.execute("""
        INSERT INTO institutions (id, name, slug, wikidata_id)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(wikidata_id) DO UPDATE SET name=excluded.name, slug=excluded.slug;
        """, (inst_id, institution.name, institution.slug, institution.wikidata_id))

        for r in results:
            if not r.person:
                continue
            
            p_id = r.person.wikidata_id or r.person.full_name
            cursor.execute("""
            INSERT INTO people (id, full_name, wikidata_id, source_type, source_url)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(wikidata_id) DO UPDATE SET full_name=excluded.full_name, source_url=excluded.source_url;
            """, (p_id, r.person.full_name, r.person.wikidata_id, r.person.source_type, r.person.source_url))
            
            if r.employment:
                comp_name = r.employment.company.name if r.employment.company else None
                cursor.execute("DELETE FROM employment_history WHERE person_id = ?", (p_id,))
                cursor.execute("""
                INSERT INTO employment_history (person_id, company_name, title, sector, title_level, confidence, is_current)
                VALUES (?, ?, ?, ?, ?, ?, 1);
                """, (p_id, comp_name, r.employment.title, r.sector, r.title_level, r.confidence))
                
        conn.commit()
        log.info(f"Successfully tracked stats data for {len(results)} records.")
    except Exception as e:
        conn.rollback()
        log.error(f"Failed to execute database tracking write: {e}")
    finally:
        conn.close()

def get_stats() -> Dict[str, int]:
    """Returns aggregate statistics for the database to satisfy the /api/stats route."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT COUNT(*) FROM institutions")
        inst_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM people")
        people_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM employment_history")
        emp_count = cursor.fetchone()[0]
        
        return {
            "institutions": inst_count,
            "people": people_count,
            "employment_records": emp_count
        }
    except Exception as e:
        log.error(f"Failed to fetch stats: {e}")
        return {"institutions": 0, "people": 0, "employment_records": 0}
    finally:
        conn.close()
