#!/usr/bin/env python3
"""COMP3311 Assignment 2 — ass2 skeleton.

Implement progressively Q1..Q5.

Rules:
- Use psycopg2
- Parameterised queries only
- Deterministic output and ordering
"""

from __future__ import annotations

import math
import re
import sys
from dataclasses import dataclass
from typing import Optional, List

import psycopg2

DAY = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


@dataclass
class Term:
    id: int
    unswid: int
    year: int
    term: str
    starting: str
    ending: str


class Shell:
    def __init__(self, dsn: str = "dbname=mymyunsw"):
        self.conn = psycopg2.connect(dsn)
        self.conn.autocommit = False
        self.in_config = False
        self.admin = False
        self.current_term: Optional[Term] = None

    def _require_term(self) -> bool:
        if self.current_term is None:
            print("Term not configured. Use /c then term <...>.")
            return False
        return True

    # ---------- Q1 ----------
    def cmd_term(self, sem_unswid: int) -> None:
        cur = self.conn.cursor()
        cur.execute("SELECT MAX(unswid) FROM semesters")
        max_unswid = cur.fetchone()[0]

        if sem_unswid > max_unswid:
            print("Term not set up yet, you cannot set this term.")
            self.conn.rollback()
            return

        cur.execute(
            "SELECT id, unswid, year, term, starting, ending "
            "FROM semesters WHERE unswid = %s",
            (sem_unswid,),
        )
        row = cur.fetchone()
        if row:
            self.current_term = Term(*row)
            self.conn.commit()
        else:
            print("Invalid term.")
            self.conn.rollback()

    def cmd_show(self) -> None:
        if self.current_term is None:
            print("Term { unset }")
            return
        t = self.current_term
        print(
            f"Term {{ unswid: {t.unswid}, year: {t.year}, term: {t.term}, "
            f"starting: {t.starting}, ending: {t.ending} }}"
        )

    # ---------- Q2 ----------
    def cmd_student(self, zid_raw: str) -> None:
        zid = parse_zid(zid_raw)
        if zid is None:
            print("Student not found.")
            return

        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT p.unswid, p.id, p.name, p.email, s.stype
            FROM people p
            JOIN students s ON s.id = p.id
            WHERE p.unswid = %s
            """,
            (zid,),
        )
        row = cur.fetchone()
        if not row:
            print("Student not found.")
            return
        unswid, student_id, name, email, stype = row

        program_str = "Unknown"
        faculty_str = "Unknown"

        cur.execute(
            """
            SELECT pr.code, pr.name, pr.offeredby
            FROM program_enrolments pe
            JOIN programs pr ON pr.id = pe.program
            JOIN semesters sem ON sem.id = pe.semester
            WHERE pe.student = %s
              AND sem.starting <= %s
            ORDER BY sem.starting DESC, pe.id DESC
            LIMIT 1
            """,
            (student_id, self.current_term.starting),
        )
        prog = cur.fetchone()

        if prog:
            program_str = f"{prog[0]} {prog[1]}"

            cur.execute("SELECT id FROM orgunit_types WHERE name = %s", ("Faculty",))
            ft = cur.fetchone()
            if ft:
                faculty_type_id = ft[0]
                current_unit = prog[2]
                visited = set()
                while current_unit is not None and current_unit not in visited:
                    visited.add(current_unit)
                    cur.execute(
                        "SELECT utype, name FROM orgunits WHERE id = %s",
                        (current_unit,),
                    )
                    u = cur.fetchone()
                    if not u:
                        break
                    if u[0] == faculty_type_id:
                        faculty_str = u[1]
                        break
                    cur.execute(
                        "SELECT owner FROM orgunit_groups WHERE member = %s "
                        "ORDER BY owner LIMIT 1",
                        (current_unit,),
                    )
                    g = cur.fetchone()
                    current_unit = g[0] if g else None

        print("Student {")
        print(f"  zid: z{unswid}")
        print(f"  id:  {student_id}")
        print(f"  name: {name}")
        print(f"  email: {email}")
        print(f"  stype: {stype}")
        print(f"  program: {program_str}")
        print(f"  faculty: {faculty_str}")
        print("}")

    # ---------- Q3 ----------
    def _lookup_student(self, zid_raw: str) -> Optional[int]:
        zid = parse_zid(zid_raw)
        if zid is None:
            return None
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT s.id FROM students s
            JOIN people p ON p.id = s.id
            WHERE p.unswid = %s
            """,
            (zid,),
        )
        row = cur.fetchone()
        return row[0] if row else None

    def _print_timetable(self, student_id: int) -> None:
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT cl.dayofwk, cl.starttime, cl.endtime,
                   sub.code,
                   ct.unswid AS ctype,
                   COALESCE(b.unswid, '?') AS bld,
                   r.name AS room_name,
                   cl.id
            FROM course_enrolments ce
            JOIN courses co ON co.id = ce.course
            JOIN subjects sub ON sub.id = co.subject
            JOIN classes cl ON cl.course = co.id
            JOIN class_types ct ON ct.id = cl.ctype
            JOIN rooms r ON r.id = cl.room
            LEFT JOIN buildings b ON b.id = r.building
            WHERE ce.student = %s AND co.semester = %s
            ORDER BY cl.dayofwk, cl.starttime, sub.code, ct.unswid,
                     bld, room_name, cl.id
            """,
            (student_id, self.current_term.id),
        )
        rows = cur.fetchall()
        print("Timetable {")
        for r in rows:
            day, st, en, code, ctype, bld, room, _cid = r
            print(f"  {DAY[day]} {st:02d}-{en:02d} {code} {ctype} {bld} {room}")
        print("}")

    def cmd_enrol(self, zid_raw: str, codes: List[str]) -> None:
        student_id = self._lookup_student(zid_raw)
        if student_id is None:
            print("Student not found.")
            return

        cur = self.conn.cursor()
        codes = [c.upper() for c in codes[:3]]
        sem_id = self.current_term.id
        duplicate_codes = []

        try:
            for code in codes:
                cur.execute(
                    "SELECT id FROM subjects WHERE UPPER(code) = %s "
                    "ORDER BY id LIMIT 1",
                    (code,),
                )
                sub = cur.fetchone()
                if not sub:
                    self.conn.rollback()
                    print(f"Subject {code} not found.")
                    return
                subject_id = sub[0]

                cur.execute(
                    "SELECT id FROM courses WHERE subject = %s AND semester = %s "
                    "ORDER BY id LIMIT 1",
                    (subject_id, sem_id),
                )
                cou = cur.fetchone()
                if not cou:
                    self.conn.rollback()
                    print(f"{code} not offered in this term.")
                    return
                course_id = cou[0]

                cur.execute(
                    """
                    INSERT INTO course_enrolments (student, course, mark, grade)
                    VALUES (%s, %s, NULL, NULL)
                    ON CONFLICT (student, course) DO NOTHING
                    RETURNING 1
                    """,
                    (student_id, course_id),
                )
                if cur.fetchone() is None:
                    duplicate_codes.append(code)

            self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise

        for code in duplicate_codes:
            print(f"Already enrolled in {code}.")

        self._print_timetable(student_id)

    def cmd_timetable(self, zid_raw: str) -> None:
        student_id = self._lookup_student(zid_raw)
        if student_id is None:
            print("Student not found.")
            return
        self._print_timetable(student_id)

    # ---------- Q4 ----------
    def cmd_plan(self, zid_raw: str, codes: List[str]) -> None:
        student_id = self._lookup_student(zid_raw)
        if student_id is None:
            print("Student not found.")
            return

        cur = self.conn.cursor()
        codes = [c.upper() for c in codes[:3]]
        sem_id = self.current_term.id

        requirements = []

        for code in codes:
            cur.execute(
                "SELECT id FROM subjects WHERE UPPER(code) = %s "
                "ORDER BY id LIMIT 1",
                (code,),
            )
            sub = cur.fetchone()
            if not sub:
                print(f"Subject {code} not found.")
                return
            subject_id = sub[0]

            cur.execute(
                "SELECT id FROM courses WHERE subject = %s AND semester = %s "
                "ORDER BY id LIMIT 1",
                (subject_id, sem_id),
            )
            cou = cur.fetchone()
            if not cou:
                print(f"{code} not offered in this term.")
                return
            course_id = cou[0]

            for ctype_code in ("LEC", "TUT"):
                cur.execute(
                    """
                    SELECT cl.id, cl.dayofwk, cl.starttime, cl.endtime,
                           COALESCE(b.unswid, '?') AS bld,
                           r.name AS room_name,
                           r.unswid AS room_uid
                    FROM classes cl
                    JOIN class_types ct ON ct.id = cl.ctype
                    JOIN rooms r ON r.id = cl.room
                    LEFT JOIN buildings b ON b.id = r.building
                    WHERE cl.course = %s AND ct.unswid = %s
                    ORDER BY cl.dayofwk, cl.starttime, cl.endtime,
                             r.unswid NULLS LAST, cl.id
                    """,
                    (course_id, ctype_code),
                )
                candidates = cur.fetchall()
                if candidates:
                    requirements.append((code, ctype_code, candidates))

        n = len(requirements)
        chosen = [None] * n

        def clash(a, b):
            if a[1] != b[1]:
                return False
            return a[2] < b[3] and b[2] < a[3]

        def dfs(i):
            if i == n:
                return True
            for cand in requirements[i][2]:
                if any(clash(cand, chosen[j]) for j in range(i)):
                    continue
                chosen[i] = cand
                if dfs(i + 1):
                    return True
                chosen[i] = None
            return False

        if not dfs(0):
            print("No feasible plan.")
            return

        type_order = {"LEC": 0, "TUT": 1}
        output_rows = []
        for i, req in enumerate(requirements):
            code, ctype, _ = req
            cl = chosen[i]
            output_rows.append(
                (code, type_order.get(ctype, 99), cl[1], cl[2], cl[3], cl[4], cl[5], ctype)
            )
        output_rows.sort(key=lambda x: (x[0], x[1], x[2], x[3], x[4]))

        print("Plan {")
        for code, _, day, st, en, bld, room, ctype in output_rows:
            print(f"  {code} {ctype} {DAY[day]} {st:02d}-{en:02d} {bld} {room}")
        print("}")

    # ---------- Q5 ----------
    def cmd_offer(self, code: str, expected: int, nlec: int) -> None:
        if not self.admin:
            print("Admin mode required.")
            return

        code = code.upper()
        cur = self.conn.cursor()

        cur.execute(
            "SELECT id FROM subjects WHERE UPPER(code) = %s ORDER BY id LIMIT 1",
            (code,),
        )
        sub = cur.fetchone()
        if not sub:
            print(f"Subject {code} not found.")
            return
        subject_id = sub[0]

        cur.execute(
            """
            SELECT id, unswid, starting, ending
            FROM semesters
            WHERE starting > %s
            ORDER BY starting ASC, unswid ASC
            LIMIT 1
            """,
            (self.current_term.starting,),
        )
        nxt = cur.fetchone()
        if not nxt:
            print("No next term in database.")
            return
        next_sem_id, next_sem_unswid, next_start, next_end = nxt

        cur.execute("SELECT id FROM class_types WHERE unswid = %s", ("LEC",))
        lec_row = cur.fetchone()
        if not lec_row:
            print("LEC class type missing.")
            return
        lec_type_id = lec_row[0]

        cur.execute("SELECT id FROM class_types WHERE unswid = %s", ("TUT",))
        tut_row = cur.fetchone()
        tut_type_id = tut_row[0] if tut_row else None

        ntut = math.ceil(expected / 25) if expected > 0 else 0
        group_size = math.ceil(expected / ntut) if ntut > 0 else 0
        lec_capacity = max(expected, 1)

        try:
            cur.execute("SELECT COALESCE(MAX(id), 0) + 1 FROM courses")
            course_id = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO courses (id, subject, semester) VALUES (%s, %s, %s)",
                (course_id, subject_id, next_sem_id),
            )

            cur.execute(
                """
                SELECT r.id, r.capacity,
                       COALESCE(b.unswid, '?') AS bld,
                       r.name AS room_name
                FROM rooms r
                LEFT JOIN buildings b ON b.id = r.building
                ORDER BY r.capacity ASC,
                         COALESCE(b.unswid, '') ASC,
                         COALESCE(r.unswid, r.name) ASC,
                         r.id ASC
                """
            )
            rooms_all = cur.fetchall()

            cur.execute(
                """
                SELECT cl.room, cl.dayofwk, cl.starttime, cl.endtime
                FROM classes cl
                JOIN courses co ON co.id = cl.course
                WHERE co.semester = %s
                ORDER BY cl.room, cl.dayofwk, cl.starttime
                """,
                (next_sem_id,),
            )
            existing = list(cur.fetchall())

            lec_slots = [(d, s, s + 2) for d in range(5) for s in (9, 11, 13, 15)]
            tut_slots = [(d, s, s + 1) for d in range(5) for s in range(9, 18)]

            placed = []
            created = []

            def has_conflict(room_id, day, start, end):
                for src in (existing, placed):
                    for e in src:
                        if e[0] == room_id and e[1] == day \
                                and e[2] < end and start < e[3]:
                            return True
                return False

            def find_and_place(slots, cap_needed, ctype_id, ctype_code):
                for (day, start, end) in slots:
                    for room_id, cap, bld, room_name in rooms_all:
                        if cap < cap_needed:
                            continue
                        if has_conflict(room_id, day, start, end):
                            continue
                        cur.execute("SELECT COALESCE(MAX(id), 0) + 1 FROM classes")
                        new_id = cur.fetchone()[0]
                        cur.execute(
                            """
                            INSERT INTO classes
                              (id, course, room, ctype, dayofwk,
                               starttime, endtime, startdate, enddate, repeats)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            """,
                            (new_id, course_id, room_id, ctype_id, day,
                             start, end, next_start, next_end, 1),
                        )
                        placed.append((room_id, day, start, end))
                        created.append((ctype_code, day, start, end, bld, room_name))
                        return True
                return False

            for _ in range(nlec):
                if not find_and_place(lec_slots, lec_capacity, lec_type_id, "LEC"):
                    self.conn.rollback()
                    print("No feasible timetable.")
                    return

            if ntut > 0 and tut_type_id is not None:
                for _ in range(ntut):
                    if not find_and_place(tut_slots, group_size, tut_type_id, "TUT"):
                        self.conn.rollback()
                        print("No feasible timetable.")
                        return

            self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise

        print(f"Offering created: {code} in term {next_sem_unswid} "
              f"(course_id={course_id})")
        for ctype, day, st, en, bld, room in created:
            print(f"  {ctype} {DAY[day]} {st:02d}-{en:02d} {bld} {room}")


def parse_zid(z: str) -> Optional[int]:
    z = z.strip()
    m = re.fullmatch(r"z?(\d{7})", z, flags=re.IGNORECASE)
    if not m:
        return None
    return int(m.group(1))


def main() -> None:
    sh = Shell()

    for raw in sys.stdin:
        line = raw.rstrip("\n").rstrip("\r")
        if not line.strip():
            continue
        print(f"> {line}")

        parts = line.strip().split()
        cmd = parts[0].lower()

        try:
            if cmd in ("/c", "/d"):
                sh.in_config = True
                continue
            if cmd == "exit":
                sh.in_config = False
                continue
            if cmd == "show":
                sh.cmd_show()
                continue
            if cmd == "term":
                if len(parts) < 2:
                    print("Invalid term.")
                    continue
                try:
                    sem_unswid = int(parts[1])
                except ValueError:
                    print("Invalid term.")
                    continue
                sh.cmd_term(sem_unswid)
                continue
            if cmd == "admin":
                if len(parts) != 2 or parts[1].lower() not in ("on", "off"):
                    print("Usage: admin on|off")
                else:
                    sh.admin = (parts[1].lower() == "on")
                continue
            if cmd == "student":
                if not sh._require_term():
                    continue
                if len(parts) < 2:
                    print("Student not found.")
                    continue
                sh.cmd_student(parts[1])
                continue
            if cmd == "enrol":
                if not sh._require_term():
                    continue
                if len(parts) < 2:
                    print("Student not found.")
                    continue
                sh.cmd_enrol(parts[1], parts[2:])
                continue
            if cmd == "timetable":
                if not sh._require_term():
                    continue
                if len(parts) < 2:
                    print("Student not found.")
                    continue
                sh.cmd_timetable(parts[1])
                continue
            if cmd == "plan":
                if not sh._require_term():
                    continue
                if len(parts) < 2:
                    print("Student not found.")
                    continue
                sh.cmd_plan(parts[1], parts[2:])
                continue
            if cmd == "offer":
                if not sh._require_term():
                    continue
                if len(parts) < 4:
                    print("Unknown command.")
                    continue
                try:
                    expected = int(parts[2])
                    nlec = int(parts[3])
                except ValueError:
                    print("Unknown command.")
                    continue
                sh.cmd_offer(parts[1], expected, nlec)
                continue

            print("Unknown command.")

        except Exception:
            sh.conn.rollback()
            raise


if __name__ == "__main__":
    main()