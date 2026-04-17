"""initial schema + row-level security for NutriKids

TASK-002 — plan AD-2 (RLS is the primary tenant isolation boundary).
Traces to AC-5, AC-7, BR-1, BR-2, BR-5.

Revision ID: 0001_initial
Revises:
Create Date: 2026-04-17
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    op.create_table(
        "users",
        sa.Column("id", sa.Text, primary_key=True),
        sa.Column("role", sa.Text, nullable=False),
        sa.Column("email", sa.Text, nullable=False, unique=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('student','parent','staff','admin')", name="users_role_chk"),
    )

    op.create_table(
        "students",
        sa.Column("id", sa.Text, primary_key=True),
        sa.Column("grade", sa.Integer, nullable=False),
        sa.Column("age_bracket", sa.Text, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["id"], ["users.id"], ondelete="CASCADE"),
        sa.CheckConstraint("grade BETWEEN 3 AND 9", name="students_grade_chk"),
        sa.CheckConstraint(
            "age_bracket IN ('10-11','12-13','14')", name="students_age_bracket_chk"
        ),
    )

    op.create_table(
        "parents",
        sa.Column("id", sa.Text, primary_key=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["id"], ["users.id"], ondelete="CASCADE"),
    )

    op.create_table(
        "parent_child_links",
        sa.Column("id", sa.Text, primary_key=True, server_default=sa.text("gen_random_uuid()::text")),
        sa.Column("parent_id", sa.Text, nullable=False),
        sa.Column("student_id", sa.Text, nullable=False),
        sa.Column("consent_status", sa.Text, nullable=False, server_default="pending"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["parent_id"], ["parents.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["student_id"], ["students.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("parent_id", "student_id", name="uq_parent_student"),
        sa.CheckConstraint(
            "consent_status IN ('pending','active','revoked')", name="pcl_consent_chk"
        ),
    )

    op.create_table(
        "consent_audit_log",
        sa.Column("id", sa.Text, primary_key=True, server_default=sa.text("gen_random_uuid()::text")),
        sa.Column("link_id", sa.Text, nullable=False),
        sa.Column("action", sa.Text, nullable=False),
        sa.Column("mechanism", sa.Text, nullable=False),
        sa.Column("parent_email_hash", sa.Text, nullable=False),
        sa.Column("occurred_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint(
            "action IN ('granted','revoked','renewed')", name="cal_action_chk"
        ),
        sa.CheckConstraint(
            "mechanism IN ('sso_verified','wet_signature')", name="cal_mech_chk"
        ),
    )

    op.execute("ALTER TABLE students ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE students FORCE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE parent_child_links ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE parent_child_links FORCE ROW LEVEL SECURITY")

    op.execute(
        """
        CREATE POLICY student_self_access ON students
          FOR ALL
          USING (
            id = current_setting('app.user_id', true)
            AND current_setting('app.role', true) = 'student'
          )
          WITH CHECK (
            id = current_setting('app.user_id', true)
            AND current_setting('app.role', true) = 'student'
          )
        """
    )

    op.execute(
        """
        CREATE POLICY parent_view_linked ON students
          FOR SELECT
          USING (
            current_setting('app.role', true) = 'parent'
            AND EXISTS (
              SELECT 1 FROM parent_child_links l
              WHERE l.student_id = students.id
                AND l.parent_id = current_setting('app.user_id', true)
                AND l.consent_status = 'active'
            )
          )
        """
    )

    op.execute(
        """
        CREATE POLICY staff_aggregate_only ON students
          FOR SELECT
          USING (
            current_setting('app.role', true) = 'staff'
            AND current_setting('app.aggregate_query', true) = 'true'
          )
        """
    )

    op.execute(
        """
        CREATE POLICY pcl_parent_own ON parent_child_links
          FOR SELECT
          USING (
            current_setting('app.role', true) = 'parent'
            AND parent_id = current_setting('app.user_id', true)
          )
        """
    )

    op.execute(
        """
        CREATE POLICY pcl_student_own ON parent_child_links
          FOR SELECT
          USING (
            current_setting('app.role', true) = 'student'
            AND student_id = current_setting('app.user_id', true)
          )
        """
    )


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS pcl_student_own ON parent_child_links")
    op.execute("DROP POLICY IF EXISTS pcl_parent_own ON parent_child_links")
    op.execute("DROP POLICY IF EXISTS staff_aggregate_only ON students")
    op.execute("DROP POLICY IF EXISTS parent_view_linked ON students")
    op.execute("DROP POLICY IF EXISTS student_self_access ON students")
    op.execute("ALTER TABLE parent_child_links DISABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE students DISABLE ROW LEVEL SECURITY")
    op.drop_table("consent_audit_log")
    op.drop_table("parent_child_links")
    op.drop_table("parents")
    op.drop_table("students")
    op.drop_table("users")
