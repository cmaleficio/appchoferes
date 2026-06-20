"""SQLAlchemy models for the application."""

from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, Enum, ForeignKey, func, Table
from sqlalchemy.orm import relationship
from ..core.database import Base
import enum

class ExpenseCategory(str, enum.Enum):
    PEAGE = "peaje"
    HOTEL = "hotel"
    GASOLINA = "gasolina"
    OTROS = "otros"

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    category = Column(Enum(ExpenseCategory), nullable=False)
    amount = Column(Float, nullable=False)
    amount_bs = Column(Float, nullable=True)
    exchange_rate = Column(Float, nullable=True)
    description = Column(String(500), nullable=True)
    is_multiple_tolls = Column(Boolean, nullable=True)
    toll_count = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="expenses")
    tags = relationship("Tag", secondary="expense_tags", back_populates="expenses")

class RouteTrack(Base):
    __tablename__ = "route_tracks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    battery_level = Column(Float, nullable=False)
    recorded_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="route_tracks")
    route = relationship("Route", back_populates="track_points")

class ExpenseRequestStatus(str, enum.Enum):
    PENDIENTE = "pendiente"
    APROBADO = "aprobado"
    RECHAZADO = "rechazado"

class ExpenseRequest(Base):
    __tablename__ = "expense_requests"

    id = Column(Integer, primary_key=True, index=True)
    expense_id = Column(Integer, ForeignKey("expenses.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reason = Column(String(500), nullable=False)
    status = Column(Enum(ExpenseRequestStatus), default=ExpenseRequestStatus.PENDIENTE, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    expense = relationship("Expense", backref="edit_requests")
    user = relationship("User")

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(50), default="driver")
    name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    disabled_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    expenses = relationship("Expense", back_populates="user")
    route_tracks = relationship("RouteTrack", back_populates="user")
    logs = relationship("Log", back_populates="user")

class Route(Base):
    __tablename__ = "routes"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    start_location = Column(String(255), nullable=True)
    end_location = Column(String(255), nullable=True)
    track_points = relationship("RouteTrack", back_populates="route")

class Budget(Base):
    __tablename__ = "budgets"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Float, nullable=False)
    amount_bs = Column(Float, nullable=True)
    exchange_rate = Column(Float, nullable=True)
    period_start = Column(DateTime(timezone=True), nullable=False)
    period_end = Column(DateTime(timezone=True), nullable=False)
    user = relationship("User")

class Tag(Base):
    __tablename__ = "tags"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    expenses = relationship("Expense", secondary="expense_tags", back_populates="tags")

class Log(Base):
    __tablename__ = "logs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action = Column(String(50), nullable=False)
    resource = Column(String(50), nullable=False)
    resource_id = Column(Integer, nullable=True)
    details = Column(String(1000), nullable=True)
    ip_address = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="logs")

from sqlalchemy import Date

class ExchangeRate(Base):
    __tablename__ = "exchange_rates"
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, nullable=False, unique=True, index=True)
    rate = Column(Float, nullable=False)
    source = Column(String(50), default="manual")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Deposit(Base):
    __tablename__ = "deposits"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Float, nullable=False)
    amount_bs = Column(Float, nullable=True)
    exchange_rate = Column(Float, nullable=True)
    description = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")

expense_tags = Table(
    "expense_tags",
    Base.metadata,
    Column("expense_id", Integer, ForeignKey("expenses.id"), primary_key=True),
    Column("tag_id", Integer, ForeignKey("tags.id"), primary_key=True),
)
