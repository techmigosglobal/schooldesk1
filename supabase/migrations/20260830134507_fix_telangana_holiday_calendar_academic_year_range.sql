-- The supplied Telangana 2026-27 calendar includes dates through 19 Apr
-- 2027, while the local academic-year row ends on 31 Mar 2027. Match the
-- labelled academic year rather than requiring the holiday range to fit
-- inside the academic-year end date.

update public.holidays
set holiday_name = 'Vinayaka Nimarjanam',
    updated_at = now()
where holiday_name = 'Vinayaka Nimaranam'
  and from_date = date '2026-09-25'
  and to_date = date '2026-09-25'
  and type = 'telangana';

with holiday(holiday_name, from_date, to_date, type) as (
  values
    ('Muharram (Ashoora)', date '2026-06-26', date '2026-06-26', 'telangana'),
    ('Bonalu', date '2026-08-10', date '2026-08-10', 'telangana'),
    ('Independence Day', date '2026-08-15', date '2026-08-15', 'telangana'),
    ('Varamahalakshmi Vratha', date '2026-08-21', date '2026-08-21', 'telangana'),
    ('Rakhi', date '2026-08-28', date '2026-08-28', 'telangana'),
    ('Krishna Jayanthi', date '2026-09-04', date '2026-09-04', 'telangana'),
    ('Vinayaka Chavithi', date '2026-09-14', date '2026-09-14', 'telangana'),
    ('Vinayaka Nimarjanam', date '2026-09-25', date '2026-09-25', 'telangana'),
    ('Mahatma Gandhi Jayanti', date '2026-10-02', date '2026-10-02', 'telangana'),
    ('Dussehra Holidays', date '2026-10-10', date '2026-10-21', 'telangana'),
    ('Deepawali Holidays', date '2026-11-06', date '2026-11-08', 'telangana'),
    ('Gurunanak Jayanthi', date '2026-11-24', date '2026-11-24', 'telangana'),
    ('Christmas & New Year Holidays', date '2026-12-25', date '2027-01-01', 'telangana'),
    ('Bhogi / Makara Sankranti Holidays', date '2027-01-14', date '2027-01-16', 'telangana'),
    ('Republic Day', date '2027-01-26', date '2027-01-26', 'telangana'),
    ('Vasant Panchami', date '2027-02-11', date '2027-02-11', 'telangana'),
    ('Maha Shivaratri', date '2027-03-06', date '2027-03-06', 'telangana'),
    ('Ramzan Id (Tentative Date)', date '2027-03-10', date '2027-03-10', 'telangana'),
    ('Holi', date '2027-03-22', date '2027-03-22', 'telangana'),
    ('Good Friday', date '2027-03-26', date '2027-03-26', 'telangana'),
    ('Gudi Padwa', date '2027-04-07', date '2027-04-07', 'telangana'),
    ('Ambedkar Jayanthi', date '2027-04-14', date '2027-04-14', 'telangana'),
    ('Rama Navami', date '2027-04-15', date '2027-04-15', 'telangana'),
    ('Mahaveer Jayanthi', date '2027-04-19', date '2027-04-19', 'telangana')
)
insert into public.holidays (
  school_id, academic_year_id, holiday_name, from_date, to_date, type
)
select y.school_id, y.id, h.holiday_name, h.from_date, h.to_date, h.type
from public.academic_years y
cross join holiday h
where y.year_label in ('2026-2027', '2026/2027', '2026-27')
  and y.start_date <= date '2026-06-26'
  and not exists (
    select 1
    from public.holidays existing
    where existing.school_id = y.school_id
      and existing.academic_year_id = y.id
      and existing.holiday_name = h.holiday_name
      and existing.from_date = h.from_date
      and existing.to_date = h.to_date
      and existing.type = h.type
  );
