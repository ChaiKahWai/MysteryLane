-- Service-only leases prevent simultaneous workers spending quota on one bank.
create table if not exists public.puzzle_preparation_leases (
  destination_id uuid not null references public.blind_box_destinations(destination_id),
  puzzle_type text not null,
  lease_token uuid not null,
  expires_at timestamptz not null,
  primary key (destination_id, puzzle_type)
);
alter table public.puzzle_preparation_leases enable row level security;
revoke all on public.puzzle_preparation_leases from anon, authenticated;
grant all on public.puzzle_preparation_leases to service_role;

create or replace function public.claim_puzzle_preparation(p_destination_id uuid, p_puzzle_type text, p_token uuid)
returns boolean language sql security invoker set search_path = '' as $$
  with claimed as (
    insert into public.puzzle_preparation_leases values (p_destination_id, p_puzzle_type, p_token, now() + interval '140 seconds')
    on conflict (destination_id, puzzle_type) do update
      set lease_token = excluded.lease_token, expires_at = excluded.expires_at
      where public.puzzle_preparation_leases.expires_at < now()
    returning 1
  ) select exists(select 1 from claimed);
$$;
revoke all on function public.claim_puzzle_preparation(uuid,text,uuid) from public, anon, authenticated;
grant execute on function public.claim_puzzle_preparation(uuid,text,uuid) to service_role;
