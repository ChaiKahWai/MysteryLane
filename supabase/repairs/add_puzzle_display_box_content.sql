alter table public.puzzle_questions
  add column if not exists display_box_content text;

comment on column public.puzzle_questions.display_box_content is
  'Optional content rendered in a separate box below the direct question, such as a proposed True/False answer or scrambled letters.';
