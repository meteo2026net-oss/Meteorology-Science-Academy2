-- Content authoring metadata for Meteorology Science Academy
-- Safe additive migration; existing courses and lessons remain compatible.
alter table public.academy_courses
  add column if not exists level text not null default 'beginner'
    check (level in ('beginner','intermediate','advanced')),
  add column if not exists cover_url text not null default '';

alter table public.academy_lessons
  add column if not exists level text not null default 'beginner'
    check (level in ('beginner','intermediate','advanced')),
  add column if not exists estimated_minutes integer not null default 15
    check (estimated_minutes >= 0 and estimated_minutes <= 10000),
  add column if not exists learning_objectives jsonb not null default '[]'::jsonb
    check (jsonb_typeof(learning_objectives) = 'array'),
  add column if not exists chapter_title text not null default 'الفصل الأول',
  add column if not exists unit_title text not null default '';

create index if not exists academy_lessons_published_order_idx
  on public.academy_lessons(course_id, published, sort_order);

comment on column public.academy_lessons.content is
  'Structured lesson document. Version 1 uses content.blocks[] with heading, text, formula, example, image, video, callout, list, table, graph, simulation and question blocks.';
comment on column public.academy_lessons.learning_objectives is
  'JSON array of concise learning objectives displayed at the beginning of the lesson.';
