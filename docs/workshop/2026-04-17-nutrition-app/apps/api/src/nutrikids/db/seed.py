"""Dev seed — idempotent. Creates 6 students, 4 parents, 3 active parent-child links, 2 staff.

Run with:
    DATABASE_URL=... python -m nutrikids.db.seed
"""
from __future__ import annotations

from sqlalchemy import text

from nutrikids.db.session import engine


SEED_SQL = """
INSERT INTO users (id, role, email) VALUES
  ('student_001','student','student_001@oakwood.edu'),
  ('student_002','student','student_002@oakwood.edu'),
  ('student_003','student','student_003@oakwood.edu'),
  ('student_004','student','student_004@oakwood.edu'),
  ('student_005','student','student_005@oakwood.edu'),
  ('student_006','student','student_006@oakwood.edu'),
  ('parent_A','parent','parent_a@example.com'),
  ('parent_B','parent','parent_b@example.com'),
  ('parent_C','parent','parent_c@example.com'),
  ('parent_D','parent','parent_d@example.com'),
  ('staff_001','staff','cafeteria@oakwood.edu'),
  ('staff_002','staff','nurse@oakwood.edu')
ON CONFLICT (id) DO NOTHING;

INSERT INTO students (id, grade, age_bracket) VALUES
  ('student_001', 5, '10-11'),
  ('student_002', 6, '12-13'),
  ('student_003', 6, '12-13'),
  ('student_004', 7, '12-13'),
  ('student_005', 8, '14'),
  ('student_006', 4, '10-11')
ON CONFLICT (id) DO NOTHING;

INSERT INTO parents (id) VALUES
  ('parent_A'),('parent_B'),('parent_C'),('parent_D')
ON CONFLICT (id) DO NOTHING;

INSERT INTO parent_child_links (id, parent_id, student_id, consent_status) VALUES
  ('link_A1','parent_A','student_001','active'),
  ('link_B2','parent_B','student_002','active'),
  ('link_C3','parent_C','student_003','revoked'),
  ('link_D4','parent_D','student_004','pending')
ON CONFLICT (parent_id, student_id) DO UPDATE
  SET consent_status = EXCLUDED.consent_status;
"""


def seed() -> None:
    with engine().begin() as conn:
        conn.execute(text(SEED_SQL))


if __name__ == "__main__":
    seed()
    print("Seed complete.")
