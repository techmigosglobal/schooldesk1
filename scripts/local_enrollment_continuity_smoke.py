#!/usr/bin/env python3
"""Enrollment continuity regression. Synthetic local Docker only; rolls back."""
import subprocess
import uuid

DB = 'supabase_db_schooldesk-local'
school, organization, year, grade, section_a, section_b, student, legacy, future, failed, promoted_year, promoted_section = (
    str(uuid.uuid4()) for _ in range(12)
)


def check(expression, message):
    message = message.replace("'", "''")
    return f"do $$ begin if not coalesce(({expression}),false) then raise exception '{message}'; end if; end $$;"


def rejected(statement, message):
    return f"""do $$ begin
      begin {statement}; exception when check_violation then
        if position('{message}' in sqlerrm)=0 then raise; end if; return;
      end;
      raise exception 'Expected rejection: {message}';
    end $$;"""


sql = [f"""
begin;
set local timezone='Asia/Kolkata';
set local lock_timeout='5s';
set local statement_timeout='30s';
insert into organizations(id,name) values('{organization}','Synthetic enrollment regression');
insert into schools(id,organization_id,name) values('{school}','{organization}','Synthetic enrollment regression');
insert into academic_years(id,school_id,year_label,start_date,end_date,is_current)
  values('{year}','{school}','Synthetic',current_date-90,current_date+90,true);
insert into grades(id,school_id,grade_number,grade_name) values('{grade}','{school}',1,'Synthetic');
insert into sections(id,school_id,grade_id,academic_year_id,section_name)
  values('{section_a}','{school}','{grade}','{year}','A'),('{section_b}','{school}','{grade}','{year}','B');
insert into students(id,school_id,first_name,last_name,status,current_section_id,admission_date,is_test_account)
  values('{student}','{school}','Synthetic','Enrollment','active','{section_a}',current_date-7,true);
create temp table original_enrollment as select * from enrollments where student_id='{student}';
"""]
count = f"select count(*) from enrollments where student_id='{student}'"
roster = lambda section, day: f"public.attendance_roster('{school}','{section}','{year}',{day})->'items'"
member = lambda section, day, who=student: f"exists(select 1 from jsonb_array_elements({roster(section, day)}) r where r->>'id'='{who}')"
sql += [check(f"({count})=1", 'New admission creates one enrollment'),
        check(member(section_a, 'current_date-7'), 'Admission day is included'),
        check('not '+member(section_a, 'current_date-8'), 'Day before admission is excluded'),
        f"update students set current_section_id=current_section_id where id='{student}';",
        check(f"({count})=1", 'Ordinary save does not duplicate enrollment'),
        f"update students set current_section_id='{section_b}' where id='{student}';",
        check(f"({count})=2", 'Transfer creates dated enrollment'),
        check(member(section_b, 'current_date'), 'Transferred class receives student today'),
        check('not '+member(section_a, 'current_date'), 'Former class excludes unsaved current membership'),
        check(member(section_a, 'current_date-1'), 'Previous day remains in original class'),
        check('not '+member(section_b, 'current_date-1'), 'Transfer is never backdated'),
        check(f"(select to_jsonb(e) from enrollments e join original_enrollment o on o.id=e.id)=(select to_jsonb(o) from original_enrollment o)", 'Original enrollment remains byte for byte unchanged'),
        f"update students set current_section_id='{section_a}' where id='{student}';",
        check(f"({count})=3", 'Second transfer on same day records latest assignment'),
        check(member(section_a, 'current_date'), 'Latest same-day class wins'),
        f"update students set current_section_id='{section_a}' where id='{student}';",
        check(f"({count})=3", 'Transfer retry is idempotent'),
        f"update students set status='inactive' where id='{student}'; update students set status='active' where id='{student}';",
        check(f"({count})=3", 'Reactivation reuses current matching membership'),
        f"update students set status='inactive',current_section_id='{section_b}' where id='{student}'; update students set status='active' where id='{student}';",
        check(f"({count})=4", 'Reactivation into a changed class creates membership'),
        check(member(section_b, 'current_date'), 'Changed reactivation has a usable roster')]

sql += [f"""insert into students(id,school_id,first_name,last_name,status,current_section_id,admission_date,is_test_account)
  values('{legacy}','{school}','Synthetic','Legacy','active','{section_a}',current_date-7,true);
delete from enrollments where student_id='{legacy}';
update students set current_section_id=current_section_id where id='{legacy}';""",
        check(f"not exists(select 1 from enrollments where student_id='{legacy}')", 'Ordinary save does not invent legacy history'),
        f"update students set current_section_id='{section_b}' where id='{legacy}';",
        check(member(section_b, 'current_date', legacy), 'Legacy transfer receives current membership'),
        check('not '+member(section_a, 'current_date-1', legacy), 'Legacy transfer does not infer past membership')]

sql += [rejected(f"update students set current_section_id='00000000-0000-4000-8000-000000000022' where id='{legacy}'", 'school current academic year'),
        check(f"(select current_section_id='{section_b}'::uuid from students where id='{legacy}')", 'Foreign section rejection rolls back student assignment'),
        f"update academic_years set is_current=false where id='{year}';",
        rejected(f"update students set current_section_id='{section_a}' where id='{legacy}'", 'school current academic year'),
        f"update academic_years set is_current=true where id='{year}';",
        f"""insert into students(id,school_id,first_name,last_name,status,current_section_id,admission_date,is_test_account)
          values('{future}','{school}','Synthetic','Future','active','{section_a}',current_date-7,true);
          insert into enrollments(school_id,student_id,section_id,academic_year_id,status,created_at)
          values('{school}','{future}','{section_b}','{year}','active',(current_date+1)::timestamp at time zone 'Asia/Kolkata');""",
        rejected(f"update students set current_section_id='{section_b}' where id='{future}'", 'future-dated enrollment'),
        check(f"(select current_section_id='{section_a}'::uuid from students where id='{future}')", 'Future history rejection preserves assignment'),
        f"""delete from enrollments where student_id='{future}' and section_id='{section_b}';
          insert into enrollments(school_id,student_id,section_id,academic_year_id,status,created_at)
          select school_id,student_id,'{section_b}',academic_year_id,status,created_at from enrollments where student_id='{future}';""",
        rejected(f"update students set current_section_id='{section_b}' where id='{future}'", 'ambiguous enrollment history'),
        f"""insert into students(id,school_id,first_name,last_name,status,current_section_id,admission_date,is_test_account)
          values('{failed}','{school}','Synthetic','Atomic','active','{section_a}',current_date-7,true);
          create function pg_temp.reject_enrollment() returns trigger language plpgsql as $$ begin
            if new.student_id='{failed}'::uuid then raise exception 'Synthetic enrollment failure'; end if; return new;
          end $$;
          create trigger local_enrollment_failure before insert on public.enrollments
            for each row execute function pg_temp.reject_enrollment();
          do $$ begin
            begin update students set current_section_id='{section_b}' where id='{failed}';
            exception when raise_exception then if sqlerrm='Synthetic enrollment failure' then return; end if; raise; end;
            raise exception 'Expected synthetic enrollment failure';
          end $$;""",
        check(f"(select current_section_id='{section_a}'::uuid from students where id='{failed}') and (select count(*)=1 from enrollments where student_id='{failed}')", 'Enrollment insert failure rolls back entire class change'),
        check("not has_function_privilege('anon','public.ensure_initial_student_enrollment()','execute') and not has_function_privilege('authenticated','public.ensure_initial_student_enrollment()','execute')", 'Enrollment trigger is not a public callable repair API'),
        f"""update academic_years set is_current=false where id='{year}';
          insert into academic_years(id,school_id,year_label,start_date,end_date,is_current)
            values('{promoted_year}','{school}','Next synthetic year',current_date-1,current_date+365,true);
          insert into sections(id,school_id,grade_id,academic_year_id,section_name)
            values('{promoted_section}','{school}','{grade}','{promoted_year}','Promoted');
          update students set current_section_id='{promoted_section}' where id='{legacy}';""",
        check(f"(select count(*)=1 from enrollments where student_id='{legacy}' and academic_year_id='{year}') and (select count(*)=1 from enrollments where student_id='{legacy}' and academic_year_id='{promoted_year}')", 'Promotion creates next-year membership and retains previous-year enrollment'),
        check(f"exists(select 1 from jsonb_array_elements(attendance_roster('{school}','{promoted_section}','{promoted_year}',current_date)->'items') r where r->>'id'='{legacy}')", 'Promoted class receives the student'),
        "rollback; select 'PASS enrollment continuity: admission dates, same-day transfers, retry, activation, legacy boundaries, scope/year guards, future/ambiguous history, atomic rollback, promotion and trigger grants';"]

result = subprocess.run(['docker', '--context', 'default', 'exec', '-i', DB, 'psql',
                         '-X', '-U', 'postgres', '-d', 'postgres', '-Atq', '-v', 'ON_ERROR_STOP=1'],
                        input='\n'.join(sql), text=True, capture_output=True)
print(result.stdout.strip())
if result.stderr.strip():
    print(result.stderr.strip())
raise SystemExit(result.returncode)
