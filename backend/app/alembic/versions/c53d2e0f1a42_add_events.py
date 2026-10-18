"""Add timed and all-day calendar events.

Revision ID: c53d2e0f1a42
Revises: b42c1d9e0f31
"""
from alembic import op
import sqlalchemy as sa

revision = "c53d2e0f1a42"
down_revision = "b42c1d9e0f31"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "events",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("calendar_id", sa.Uuid(), sa.ForeignKey("calendars.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(5000)),
        sa.Column("all_day", sa.Boolean(), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True)),
        sa.Column("ends_at", sa.DateTime(timezone=True)),
        sa.Column("start_date", sa.Date()),
        sa.Column("end_date", sa.Date()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("length(btrim(title)) > 0", name="ck_events_title_not_blank"),
        sa.CheckConstraint(
            "(all_day = false AND starts_at IS NOT NULL AND ends_at IS NOT NULL "
            "AND start_date IS NULL AND end_date IS NULL AND ends_at > starts_at) OR "
            "(all_day = true AND start_date IS NOT NULL AND end_date IS NOT NULL "
            "AND starts_at IS NULL AND ends_at IS NULL AND end_date > start_date)",
            name="ck_events_period",
        ),
    )
    op.create_index("ix_events_calendar_time", "events", ["calendar_id", "starts_at", "ends_at"])
    op.create_index("ix_events_calendar_date", "events", ["calendar_id", "start_date", "end_date"])
    op.create_index("ix_events_created_by", "events", ["created_by"])


def downgrade():
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM events) THEN
            RAISE EXCEPTION 'Export and explicitly remove events before downgrading';
        END IF;
    END $$;""")
    op.drop_table("events")
