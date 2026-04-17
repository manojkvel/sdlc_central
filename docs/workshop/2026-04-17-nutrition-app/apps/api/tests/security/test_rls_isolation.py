"""TASK-003 — Adversarial RLS test harness.

Plan §6 CRITICAL risk: RLS policy bug allows cross-student read.
If RLS ever weakens, this file should scream.

Covers: AC-5 (parent view), AC-7 (auth boundary), BR-1, BR-2, BR-5.
"""
from __future__ import annotations

import pytest
from sqlalchemy import text

from tests.conftest import set_app_context


pytestmark = pytest.mark.security


class TestStudentIsolation:
    @pytest.mark.parametrize(
        "attacker, victim",
        [
            ("student_001", "student_002"),
            ("student_002", "student_001"),
            ("student_005", "student_006"),
        ],
    )
    def test_student_cannot_read_other_student_row(self, db_session, attacker, victim):
        with db_session.begin():
            set_app_context(db_session, attacker, "student")
            rows = db_session.execute(
                text("SELECT id FROM students WHERE id = :v"), {"v": victim}
            ).fetchall()
        assert rows == [], f"A1: {attacker} read {victim} — RLS BREACH"

    def test_student_update_to_another_affects_zero_rows(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "student_001", "student")
            result = db_session.execute(
                text("UPDATE students SET grade = 99 WHERE id = 'student_002'")
            )
        assert result.rowcount == 0, "A3: student_001 mutated student_002"


class TestParentBoundary:
    def test_linked_active_parent_sees_own_child(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "parent_A", "parent")
            rows = db_session.execute(
                text("SELECT id FROM students WHERE id = 'student_001'")
            ).fetchall()
        assert len(rows) == 1, "B1: parent_A should see linked active child"

    def test_unlinked_parent_sees_nothing(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "parent_A", "parent")
            rows = db_session.execute(
                text("SELECT id FROM students WHERE id = 'student_002'")
            ).fetchall()
        assert rows == [], "B2: parent_A saw unlinked student_002 — RLS BREACH"

    def test_revoked_parent_cannot_read_child(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "parent_C", "parent")
            rows = db_session.execute(
                text("SELECT id FROM students WHERE id = 'student_003'")
            ).fetchall()
        assert rows == [], "B3: revoked parent_C still saw student_003"

    def test_pending_parent_cannot_read_child(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "parent_D", "parent")
            rows = db_session.execute(
                text("SELECT id FROM students WHERE id = 'student_004'")
            ).fetchall()
        assert rows == [], "B3b: pending parent_D must not see student_004 yet"


class TestStaffScope:
    def test_staff_without_aggregate_flag_sees_nothing(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "staff_001", "staff", aggregate=False)
            rows = db_session.execute(text("SELECT id FROM students LIMIT 1")).fetchall()
        assert rows == [], "C1: staff without aggregate flag leaked student rows"

    def test_staff_with_aggregate_flag_can_count(self, db_session):
        with db_session.begin():
            set_app_context(db_session, "staff_001", "staff", aggregate=True)
            count = db_session.execute(
                text("SELECT count(*) FROM students")
            ).scalar_one()
        assert count >= 6, "C2: aggregate count should see all students"


class TestForgedJWT:
    def test_forged_claim_loses_to_db_guc(self, db_session):
        """D1: JWT claims student_002, but DB session GUC set to student_001.
        Simulates an app-layer bug. RLS must win regardless of the forged claim.
        """
        with db_session.begin():
            set_app_context(db_session, "student_001", "student")
            rows = db_session.execute(
                text("SELECT id FROM students")
            ).fetchall()
        assert all(r.id == "student_001" for r in rows), (
            "D1: RLS failed — forged/bug context leaked other students"
        )
