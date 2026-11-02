-- Hierarchical course content: courses -> chapters -> units -> lessons.
-- Additive and backward-compatible: legacy chapter_title/unit_title remain available.
create table if not exists public.academy_chapters (
  id uuid primary key default gen_random_uuid(),
  course_id text not null references public.academy_courses(id) on delete cascade,
  title text not null,
  description text not null default '',
  sort_order integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, course_id),
  unique (course_id, title)
);

create table if not exists public.academy_units (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.academy_chapters(id) on delete cascade,
  title text not null,
  description text not null default '',
  sort_order integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, chapter_id),
  unique (chapter_id, title)
);

alter table public.academy_lessons
  add column if not exists chapter_id uuid,
  add column if not exists unit_id uuid;

-- Composite foreign keys prevent assigning a chapter from another course
-- or a unit from a different chapter.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'academy_lessons_chapter_course_fk') then
    alter table public.academy_lessons
      add constraint academy_lessons_chapter_course_fk
      foreign key (chapter_id, course_id)
      references public.academy_chapters(id, course_id)
      on delete set null (chapter_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'academy_lessons_unit_chapter_fk') then
    alter table public.academy_lessons
      add constraint academy_lessons_unit_chapter_fk
      foreign key (unit_id, chapter_id)
      references public.academy_units(id, chapter_id)
      on delete set null (unit_id);
  end if;
end $$;

create index if not exists academy_chapters_course_order_idx
  on public.academy_chapters(course_id, sort_order);
create index if not exists academy_units_chapter_order_idx
  on public.academy_units(chapter_id, sort_order);
create index if not exists academy_lessons_hierarchy_order_idx
  on public.academy_lessons(course_id, chapter_id, unit_id, sort_order);

alter table public.academy_chapters enable row level security;
alter table public.academy_units enable row level security;

drop policy if exists "chapters_read_published_or_admin" on public.academy_chapters;
create policy "chapters_read_published_or_admin"
on public.academy_chapters for select to anon, authenticated
using (
  (published = true and exists (
    select 1 from public.academy_courses c
    where c.id = course_id and c.published = true
  ))
  or (select private.is_academy_admin())
);

drop policy if exists "chapters_admin_manage" on public.academy_chapters;
create policy "chapters_admin_manage"
on public.academy_chapters for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

drop policy if exists "units_read_published_or_admin" on public.academy_units;
create policy "units_read_published_or_admin"
on public.academy_units for select to anon, authenticated
using (
  (published = true and exists (
    select 1 from public.academy_chapters ch
    join public.academy_courses c on c.id = ch.course_id
    where ch.id = chapter_id and ch.published = true and c.published = true
  ))
  or (select private.is_academy_admin())
);

drop policy if exists "units_admin_manage" on public.academy_units;
create policy "units_admin_manage"
on public.academy_units for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

grant select on public.academy_chapters, public.academy_units to anon, authenticated;
grant insert, update, delete on public.academy_chapters, public.academy_units to authenticated;
