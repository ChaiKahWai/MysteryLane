alter table public.puzzle_attempt_answers
  add column if not exists question_text_snapshot text,
  add column if not exists correct_answer_snapshot text,
  add column if not exists question_category_snapshot text,
  add column if not exists timer_seconds_snapshot integer;

update public.puzzle_attempt_answers paa
set question_text_snapshot = coalesce(paa.question_text_snapshot, pq.question_text),
    correct_answer_snapshot = coalesce(paa.correct_answer_snapshot, pq.correct_answer),
    question_category_snapshot = coalesce(paa.question_category_snapshot, pq.category),
    timer_seconds_snapshot = coalesce(paa.timer_seconds_snapshot, pq.timer_seconds, 30)
from public.puzzle_questions pq
where pq.puzzle_id = paa.puzzle_id
  and (paa.question_text_snapshot is null
    or paa.correct_answer_snapshot is null
    or paa.question_category_snapshot is null
    or paa.timer_seconds_snapshot is null);

alter table public.puzzle_attempt_answers
  alter column question_text_snapshot set not null,
  alter column correct_answer_snapshot set not null,
  alter column timer_seconds_snapshot set not null;

alter table public.puzzle_attempt_answers
  add constraint puzzle_attempt_answers_timer_snapshot_positive
  check (timer_seconds_snapshot > 0) not valid;

alter table public.puzzle_attempt_answers
  validate constraint puzzle_attempt_answers_timer_snapshot_positive;
