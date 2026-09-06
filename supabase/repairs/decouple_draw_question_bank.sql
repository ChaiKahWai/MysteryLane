do $repair$
declare
  original text := pg_get_functiondef('public.record_blind_box_draw(uuid,numeric,text)'::regprocedure);
  blocker text := $block$  v_question_count := public.ensure_blind_box_mcq_bank(p_destination_id);
  if v_question_count < 80 then
    raise exception 'Unable to prepare the minimum Blind Box question bank';
  end if;$block$;
begin
  if position(blocker in original) = 0 then
    raise exception 'Draw function changed: expected question prerequisite not found. No changes applied.';
  end if;
  execute replace(original, blocker, '  -- Question preparation runs after the draw, outside this transaction.');
end;
$repair$;
