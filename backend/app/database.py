"""
Database Connection & Session Management for Swift Route Logistics Manager.
Using SQLAlchemy 2.0 with PyMySQL.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from .config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """FastAPI Dependency for database session injection with proper cleanup."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
