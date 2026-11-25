create table public.owner_transfers (
    id uuid primary key default gen_random_uuid(),
    from_user_id uuid not null,
    to_user_id uuid not null,
    status text not null default 'pending'
        check (status in ('pending', 'processing', 'completed', 'rejected', 'cancelled')),
    created_at timestamptz not null default now(),
    accepted_at timestamptz,
    resolved_at timestamptz,
    constraint owner_transfers_different_users check (from_user_id <> to_user_id)
);

alter table public.owner_transfers enable row level security;

revoke all on table public.owner_transfers from public, anon, authenticated;
grant all on table public.owner_transfers to service_role;

create unique index owner_transfers_one_active
    on public.owner_transfers ((true))
    where status in ('pending', 'processing');
