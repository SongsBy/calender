"""Track native calendar imports without changing existing events."""
from alembic import op
import sqlalchemy as sa

revision = "d64e3f102b53"
down_revision = "c53d2e0f1a42"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "event_import_sources",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("event_id", sa.Uuid(), sa.ForeignKey("events.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("calendar_id", sa.Uuid(), sa.ForeignKey("calendars.id", ondelete="CASCADE"), nullable=False),
        sa.Column("imported_by", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("installation_id", sa.Uuid(), nullable=False),
        sa.Column("source_calendar_id", sa.String(128), nullable=False),
        sa.Column("source_event_id", sa.String(128), nullable=False),
        sa.Column("occurrence_key", sa.String(128), nullable=False),
        sa.Column("imported_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("imported_by", "installation_id", "calendar_id", "source_calendar_id", "source_event_id", "occurrence_key", name="uq_event_import_source"),
    )


def downgrade():
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM event_import_sources) THEN
            RAISE EXCEPTION 'Export import records before downgrading';
        END IF;
    END $$;""")
    op.drop_table("event_import_sources")
