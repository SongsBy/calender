"""Add two-person calendars, invitations and persistent request limits.

Revision ID: b42c1d9e0f31
Revises: a31f0b8c9d20
"""
from alembic import op
import sqlalchemy as sa

revision = "b42c1d9e0f31"
down_revision = "a31f0b8c9d20"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("calendars",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("timezone", sa.String(100), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_calendars_created_by", "calendars", ["created_by"])
    op.create_table("calendar_members",
        sa.Column("calendar_id", sa.Uuid(), sa.ForeignKey("calendars.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT"), primary_key=True),
        sa.Column("role", sa.String(10), nullable=False),
        sa.Column("slot", sa.Integer(), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("calendar_id", "slot", name="uq_calendar_member_slot"),
        sa.CheckConstraint("(slot = 1 AND role = 'owner') OR (slot = 2 AND role = 'member')", name="ck_calendar_member_role_slot"))
    op.create_index("ix_calendar_members_user_id", "calendar_members", ["user_id"])
    op.create_table("calendar_invitations",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("calendar_id", sa.Uuid(), sa.ForeignKey("calendars.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("code_hash", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("accepted_by", sa.Uuid(), sa.ForeignKey("user.id", ondelete="RESTRICT")),
        sa.Column("revoked_at", sa.DateTime(timezone=True)))
    op.create_index("ix_calendar_invitations_calendar_id", "calendar_invitations", ["calendar_id"])
    op.create_index("ix_calendar_invitations_code_hash", "calendar_invitations", ["code_hash"], unique=True)
    op.create_table("invitation_rate_limits",
        sa.Column("key_hash", sa.String(64), primary_key=True),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_invitation_rate_limits_expires_at", "invitation_rate_limits", ["expires_at"])


def downgrade():
    # Prevent accidentally erasing real shared calendars in a rollback.
    op.execute("""DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM calendars) THEN
        RAISE EXCEPTION 'Export and explicitly remove calendars before downgrading';
      END IF;
    END $$;""")
    op.drop_table("invitation_rate_limits")
    op.drop_table("calendar_invitations")
    op.drop_table("calendar_members")
    op.drop_table("calendars")
