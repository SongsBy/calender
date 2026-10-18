import re
import uuid
from datetime import UTC, date, datetime
from typing import Literal, Self
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import AwareDatetime, EmailStr, field_validator, model_validator
from sqlalchemy import CheckConstraint, Index, UniqueConstraint, func
from sqlmodel import Field, Relationship, SQLModel


def get_datetime_utc() -> datetime:
    return datetime.now(UTC)


def legacy_username() -> str:
    return "legacy_" + uuid.uuid4().hex[:23]


def normalize_username(value: str) -> str:
    if not isinstance(value, str):
        raise ValueError("Username must be a string")
    value = value.strip().lower()
    if not re.fullmatch(r"[a-z0-9_]{3,30}", value):
        raise ValueError(
            "Username must be 3-30 lowercase letters, numbers or underscores"
        )
    return value


# Shared properties
class UserBase(SQLModel):
    username: str = Field(
        default_factory=legacy_username, unique=True, index=True, max_length=30
    )
    email: EmailStr | None = Field(
        default=None, unique=True, index=True, max_length=255
    )
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255)


# Properties to receive via API on creation
class UserCreate(UserBase):
    @field_validator("username", mode="before")
    @classmethod
    def valid_username(cls, value: str) -> str:
        value = normalize_username(value)
        if value.startswith("legacy_"):
            raise ValueError("This username prefix is reserved")
        return value

    password: str = Field(min_length=8, max_length=128)


class UserRegister(SQLModel):
    username: str = Field(min_length=3, max_length=30)
    email: EmailStr | None = Field(default=None, max_length=255)

    @field_validator("username", mode="before")
    @classmethod
    def valid_username(cls, value: str) -> str:
        return UserCreate.valid_username(value)

    password: str = Field(min_length=8, max_length=128)
    full_name: str | None = Field(default=None, max_length=255)


# Properties to receive via API on update, all are optional
class UserUpdate(SQLModel):
    email: EmailStr | None = Field(default=None, max_length=255)
    is_active: bool | None = None
    is_superuser: bool | None = None
    full_name: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, min_length=8, max_length=128)


class UserUpdateMe(SQLModel):
    full_name: str | None = Field(default=None, max_length=255)
    email: EmailStr | None = Field(default=None, max_length=255)


class UpdatePassword(SQLModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


# Database model, database table inferred from class name
class User(UserBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    hashed_password: str
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    items: list[Item] = Relationship(back_populates="owner", cascade_delete=True)


# Properties to return via API, id is always required
class UserPublic(UserBase):
    id: uuid.UUID
    created_at: datetime | None = None


class UsersPublic(SQLModel):
    data: list[UserPublic]
    count: int


# Shared properties
class ItemBase(SQLModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)


# Properties to receive on item creation
class ItemCreate(ItemBase):
    pass


# Properties to receive on item update
class ItemUpdate(SQLModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)


# Database model, database table inferred from class name
class Item(ItemBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    owner: User | None = Relationship(back_populates="items")


# Properties to return via API, id is always required
class ItemPublic(ItemBase):
    id: uuid.UUID
    owner_id: uuid.UUID
    created_at: datetime | None = None


class ItemsPublic(SQLModel):
    data: list[ItemPublic]
    count: int


# Generic message
class Message(SQLModel):
    message: str


# JSON payload containing access token
class Token(SQLModel):
    access_token: str
    refresh_token: str
    expires_in: int
    token_type: str = "bearer"


# Contents of JWT token
class TokenPayload(SQLModel):
    sub: uuid.UUID
    sid: uuid.UUID
    token_type: Literal["access"]
    exp: int
    iat: int


class NewPassword(SQLModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class RefreshRequest(SQLModel):
    refresh_token: str = Field(min_length=32, max_length=256)


class RefreshSession(SQLModel, table=True):
    __tablename__ = "refresh_sessions"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="user.id", ondelete="CASCADE", index=True)
    family_id: uuid.UUID = Field(index=True)
    token_hash: str = Field(unique=True, index=True, max_length=64)
    created_at: datetime = Field(default_factory=get_datetime_utc)
    expires_at: datetime
    used_at: datetime | None = None
    revoked_at: datetime | None = None
    replaced_by_id: uuid.UUID | None = None


class CalendarCreate(SQLModel):
    name: str = Field(min_length=1, max_length=100)
    timezone: str = Field(default="Asia/Seoul", max_length=100)

    @field_validator("name", mode="before")
    @classmethod
    def trim_name(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("캘린더 이름을 입력해주세요.")
        return value.strip()

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError, ValueError:
            raise ValueError("올바른 IANA 시간대를 입력해주세요.")
        return value


class Calendar(SQLModel, table=True):
    __tablename__ = "calendars"
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    name: str = Field(max_length=100)
    timezone: str = Field(default="Asia/Seoul", max_length=100)
    created_by: uuid.UUID = Field(
        foreign_key="user.id", ondelete="RESTRICT", index=True
    )
    created_at: datetime = Field(default_factory=get_datetime_utc)


class CalendarMember(SQLModel, table=True):
    __tablename__ = "calendar_members"
    __table_args__ = (
        UniqueConstraint("calendar_id", "slot", name="uq_calendar_member_slot"),
        CheckConstraint(
            "(slot = 1 AND role = 'owner') OR (slot = 2 AND role = 'member')",
            name="ck_calendar_member_role_slot",
        ),
    )
    calendar_id: uuid.UUID = Field(
        foreign_key="calendars.id", ondelete="CASCADE", primary_key=True
    )
    user_id: uuid.UUID = Field(
        foreign_key="user.id", ondelete="RESTRICT", primary_key=True, index=True
    )
    role: str = Field(max_length=10)
    slot: int
    joined_at: datetime = Field(default_factory=get_datetime_utc)


class CalendarInvitation(SQLModel, table=True):
    __tablename__ = "calendar_invitations"
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    calendar_id: uuid.UUID = Field(
        foreign_key="calendars.id", ondelete="CASCADE", index=True
    )
    created_by: uuid.UUID = Field(foreign_key="user.id", ondelete="RESTRICT")
    code_hash: str = Field(unique=True, index=True, max_length=64)
    expires_at: datetime
    created_at: datetime = Field(default_factory=get_datetime_utc)
    used_at: datetime | None = None
    accepted_by: uuid.UUID | None = Field(
        default=None, foreign_key="user.id", ondelete="RESTRICT"
    )
    revoked_at: datetime | None = None


class InvitationRateLimit(SQLModel, table=True):
    __tablename__ = "invitation_rate_limits"
    key_hash: str = Field(primary_key=True, max_length=64)
    attempts: int
    expires_at: datetime = Field(index=True)


class CalendarMemberPublic(SQLModel):
    id: uuid.UUID
    full_name: str | None
    role: Literal["owner", "member"]
    slot: int


class CalendarPublic(SQLModel):
    id: uuid.UUID
    name: str
    timezone: str
    created_at: datetime
    members: list[CalendarMemberPublic]


class CalendarsPublic(SQLModel):
    data: list[CalendarPublic]
    count: int


class InvitationPublic(SQLModel):
    id: uuid.UUID
    code: str
    expires_at: datetime


class InvitationAccept(SQLModel):
    code: str = Field(min_length=1, max_length=64)


class EventBase(SQLModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    all_day: bool = False
    starts_at: AwareDatetime | None = None
    ends_at: AwareDatetime | None = None
    start_date: date | None = None
    end_date: date | None = None

    @field_validator("title", mode="before")
    @classmethod
    def trim_title(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("일정 제목을 입력해주세요.")
        return value.strip()

    @model_validator(mode="after")
    def validate_period(self) -> Self:
        # End values are exclusive, including the end date of all-day events.
        if self.all_day:
            if self.starts_at is not None or self.ends_at is not None:
                raise ValueError("종일 일정에는 시작·종료 시각을 지정할 수 없습니다.")
            if self.start_date is None or self.end_date is None:
                raise ValueError("종일 일정의 시작·종료 날짜가 필요합니다.")
            if self.end_date <= self.start_date:
                raise ValueError("종료 날짜는 시작 날짜보다 뒤여야 합니다.")
        else:
            if self.start_date is not None or self.end_date is not None:
                raise ValueError("시간 일정에는 종일 날짜를 지정할 수 없습니다.")
            if self.starts_at is None or self.ends_at is None:
                raise ValueError("일정의 시작·종료 시각이 필요합니다.")
            if self.ends_at <= self.starts_at:
                raise ValueError("종료 시각은 시작 시각보다 뒤여야 합니다.")
        return self


class Event(EventBase, table=True):
    __tablename__ = "events"
    __table_args__ = (
        CheckConstraint("length(btrim(title)) > 0", name="ck_events_title_not_blank"),
        CheckConstraint(
            "(all_day = false AND starts_at IS NOT NULL AND ends_at IS NOT NULL "
            "AND start_date IS NULL AND end_date IS NULL AND ends_at > starts_at) OR "
            "(all_day = true AND start_date IS NOT NULL AND end_date IS NOT NULL "
            "AND starts_at IS NULL AND ends_at IS NULL AND end_date > start_date)",
            name="ck_events_period",
        ),
        Index("ix_events_calendar_time", "calendar_id", "starts_at", "ends_at"),
        Index("ix_events_calendar_date", "calendar_id", "start_date", "end_date"),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    calendar_id: uuid.UUID = Field(foreign_key="calendars.id", ondelete="CASCADE")
    created_by: uuid.UUID = Field(
        foreign_key="user.id", ondelete="RESTRICT", index=True
    )
    created_at: datetime = Field(
        default_factory=get_datetime_utc,
        sa_column_kwargs={"server_default": func.now()},
    )
    updated_at: datetime = Field(
        default_factory=get_datetime_utc,
        sa_column_kwargs={"server_default": func.now(), "onupdate": get_datetime_utc},
    )


class EventCreate(EventBase):
    model_config = {"extra": "forbid"}


class EventUpdate(SQLModel):
    model_config = {"extra": "forbid"}
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    all_day: bool | None = None
    starts_at: AwareDatetime | None = None
    ends_at: AwareDatetime | None = None
    start_date: date | None = None
    end_date: date | None = None


class EventPublic(EventBase):
    id: uuid.UUID
    calendar_id: uuid.UUID
    created_by: uuid.UUID
    created_at: datetime
    updated_at: datetime


class EventsPublic(SQLModel):
    data: list[EventPublic]
    count: int


class EventImportItem(EventCreate):
    source_calendar_id: str = Field(min_length=1, max_length=128)
    source_event_id: str = Field(min_length=1, max_length=128)
    occurrence_key: str = Field(min_length=1, max_length=128)


class EventImportRequest(SQLModel):
    model_config = {"extra": "forbid"}
    installation_id: uuid.UUID
    events: list[EventImportItem] = Field(min_length=1, max_length=100)


class EventImportResult(SQLModel):
    created_count: int
    skipped_count: int
    data: list[EventPublic]


class EventImportSource(SQLModel, table=True):
    __tablename__ = "event_import_sources"
    __table_args__ = (UniqueConstraint(
        "imported_by", "installation_id", "calendar_id", "source_calendar_id",
        "source_event_id", "occurrence_key", name="uq_event_import_source",
    ),)
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    event_id: uuid.UUID = Field(foreign_key="events.id", ondelete="CASCADE", unique=True)
    calendar_id: uuid.UUID = Field(foreign_key="calendars.id", ondelete="CASCADE")
    imported_by: uuid.UUID = Field(foreign_key="user.id", ondelete="RESTRICT")
    installation_id: uuid.UUID
    source_calendar_id: str = Field(max_length=128)
    source_event_id: str = Field(max_length=128)
    occurrence_key: str = Field(max_length=128)
    imported_at: datetime = Field(default_factory=get_datetime_utc)
