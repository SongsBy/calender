"""Preserve existing users and add rotating refresh sessions.

Revision ID: a31f0b8c9d20
Revises: fe56fa70289e
"""
from alembic import op
import sqlalchemy as sa

revision = "a31f0b8c9d20"
down_revision = "fe56fa70289e"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("user", sa.Column("username", sa.String(30), nullable=True))
    # PostgreSQL loop also handles the unlikely collision in truncated UUIDs.
    op.execute("""
    DO $$
    DECLARE r RECORD; candidate TEXT;
    BEGIN
      FOR r IN SELECT id FROM "user" ORDER BY id LOOP
        candidate := 'legacy_' || left(replace(r.id::text, '-', ''), 23);
        WHILE EXISTS (SELECT 1 FROM "user" WHERE username = candidate) LOOP
          candidate := 'legacy_' || left(md5(random()::text || r.id::text), 23);
        END LOOP;
        UPDATE "user" SET username = candidate WHERE id = r.id;
      END LOOP;
    END $$;
    """)
    op.alter_column("user", "username", nullable=False)
    op.create_index("ix_user_username", "user", ["username"], unique=True)
    op.alter_column("user", "email", existing_type=sa.String(255), nullable=True)
    op.create_table("refresh_sessions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("user.id", ondelete="CASCADE"), nullable=False),
        sa.Column("family_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("replaced_by_id", sa.Uuid()),
    )
    op.create_index("ix_refresh_sessions_user_id", "refresh_sessions", ["user_id"])
    op.create_index("ix_refresh_sessions_family_id", "refresh_sessions", ["family_id"])
    op.create_index("ix_refresh_sessions_token_hash", "refresh_sessions", ["token_hash"], unique=True)


def downgrade():
    # Refuse to invent emails or lose email-less accounts on downgrade.
    op.execute("""DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM "user" WHERE email IS NULL) THEN
        RAISE EXCEPTION 'Assign emails to email-less accounts before downgrading';
      END IF;
    END $$;""")
    op.drop_table("refresh_sessions")
    op.alter_column("user", "email", existing_type=sa.String(255), nullable=False)
    op.drop_index("ix_user_username", table_name="user")
    op.drop_column("user", "username")
