create table public.inventory_items (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    category text not null check (category in ('B', 'F', 'P', 'C', 'U', 'G')),
    unit text not null,
    low_stock_threshold integer not null default 0 check (low_stock_threshold >= 0),
    is_seed boolean not null default false,
    is_active boolean not null default true,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now()
);

create unique index inventory_items_name_ci on public.inventory_items (lower(name));

create table public.inventory_item_conversions (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null references public.inventory_items(id),
    release_unit text not null check (length(trim(release_unit)) > 0),
    factor numeric(16, 6) not null check (factor > 0),
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now()
);

create unique index inventory_item_conversions_unit_ci
    on public.inventory_item_conversions (item_id, lower(release_unit));

create table public.inventory_branches (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(trim(name)) > 0),
    is_active boolean not null default true,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now()
);

create unique index inventory_branches_name_ci on public.inventory_branches (lower(name));

create table public.inventory_transactions (
    id uuid primary key default gen_random_uuid(),
    item_id uuid not null references public.inventory_items(id),
    movement_type text not null check (movement_type in ('in', 'out')),
    quantity numeric(16, 6) not null check (quantity > 0),
    entry_date date not null,
    detail text not null check (length(trim(detail)) > 0),
    release_unit text,
    release_quantity numeric(16, 6),
    for_branch text,
    created_by uuid references auth.users(id) on delete set null,
    created_by_name text not null default '',
    created_by_email text not null default '',
    created_at timestamptz not null default now(),
    deleted_at timestamptz,
    voided_at timestamptz,
    edit_history jsonb not null default '[]'::jsonb check (jsonb_typeof(edit_history) = 'array'),
    constraint inventory_transactions_release_quantity_check
        check (release_quantity is null or release_quantity > 0)
);

create index inventory_transactions_item_date_idx
    on public.inventory_transactions (item_id, entry_date, created_at);
create index inventory_transactions_created_by_idx
    on public.inventory_transactions (created_by, created_at);

create table public.inventory_branch_movements (
    id uuid primary key default gen_random_uuid(),
    from_branch_id uuid not null references public.inventory_branches(id),
    to_branch_id uuid references public.inventory_branches(id),
    destination_type text not null check (destination_type in ('branch', 'office', 'waste')),
    return_transaction_id uuid unique references public.inventory_transactions(id),
    item_id uuid not null references public.inventory_items(id),
    quantity numeric(16, 6) not null check (quantity > 0),
    movement_date date not null,
    created_by uuid references auth.users(id) on delete set null,
    created_by_name text not null default '',
    created_by_email text not null default '',
    created_at timestamptz not null default now(),
    voided_at timestamptz,
    constraint inventory_branch_movement_destination_check
        check ((destination_type = 'branch' and to_branch_id is not null
                and to_branch_id <> from_branch_id and return_transaction_id is null)
            or (destination_type = 'office' and to_branch_id is null and return_transaction_id is not null)
            or (destination_type = 'waste' and to_branch_id is null and return_transaction_id is null))
);

create index inventory_branch_movements_item_idx
    on public.inventory_branch_movements (item_id, from_branch_id, to_branch_id);

insert into public.inventory_items (name, category, unit, is_seed) values
    ('Oil', 'F', 'liters', true),
    ('2 Kilo Flour', 'F', 'packs', true),
    ('1 Kilo Flour', 'F', 'packs', true),
    ('250 Grams Flour', 'F', 'packs', true),
    ('Cabbage', 'F', 'kilograms', true),
    ('Carrots', 'F', 'kilograms', true),
    ('Onion Leaves', 'F', 'kilograms', true),
    ('Tissue', 'G', 'packs', true),
    ('Hand Gloves', 'G', 'packs', true),
    ('Coke', 'B', 'cases', true),
    ('Mountain Dew', 'B', 'cases', true),
    ('Yankees', 'B', 'cases', true),
    ('500ml Water', 'B', 'cases', true),
    ('1L Water', 'B', 'cases', true),
    ('Cheesebar', 'F', 'bars', true),
    ('Cellophane-Mini', 'P', 'packs', true),
    ('Cellophane-Tiny', 'P', 'packs', true),
    ('Cellophane-M', 'P', 'packs', true),
    ('Cellophane-L', 'P', 'packs', true),
    ('Ice Wrapper', 'P', 'packs', true),
    ('Stick', 'U', 'bundles', true),
    ('4 Pcs Tray', 'P', 'pieces', true),
    ('4 Pcs Box', 'P', 'pieces', true),
    ('8 Pcs Tray', 'P', 'pieces', true),
    ('8 Pcs Box', 'P', 'pieces', true),
    ('SBox', 'P', 'pieces', true),
    ('MBox', 'P', 'pieces', true),
    ('24 Pcs', 'P', 'pieces', true),
    ('40 Pcs', 'P', 'pieces', true),
    ('Trash Bag', 'C', 'pieces', true),
    ('Mayonnaise', 'F', 'pieces', true),
    ('Sauce', 'F', 'pieces', true),
    ('Bulceta #4', 'P', 'pieces', true),
    ('Bulceta #5', 'P', 'pieces', true),
    ('Bulceta #6', 'P', 'pieces', true),
    ('Bulceta #8 Half', 'P', 'pieces', true),
    ('Bulceta #8', 'P', 'pieces', true),
    ('Bulceta #10 Half', 'P', 'pieces', true),
    ('Bulceta #10', 'P', 'pieces', true),
    ('Water', 'B', 'gallons', true),
    ('Mayo Sachet', 'F', 'pieces', true),
    ('Sauce Sachet', 'F', 'pieces', true),
    ('Dishwashing', 'C', 'pieces', true),
    ('Detergent Powder', 'C', 'pieces', true),
    ('Zonrox', 'C', 'pieces', true),
    ('Downy', 'C', 'pieces', true),
    ('Scotch Tape', 'G', 'pieces', true),
    ('Lighter Gun', 'G', 'pieces', true),
    ('Chop Stick', 'U', 'pieces', true),
    ('Plates', 'U', 'pieces', true),
    ('Sponge', 'C', 'pieces', true),
    ('Steelwool', 'C', 'pieces', true),
    ('Packaging Tape', 'G', 'pieces', true),
    ('Ballpen', 'G', 'pieces', true),
    ('Trapo', 'C', 'pieces', true),
    ('Saucer', 'U', 'pieces', true),
    ('Silhig Lanot', 'C', 'pieces', true),
    ('Scraper', 'U', 'pieces', true),
    ('Marker', 'G', 'pieces', true),
    ('Knife', 'U', 'pieces', true),
    ('Saucer Brush', 'U', 'pieces', true),
    ('Silhig Tukog', 'C', 'pieces', true),
    ('Stapler', 'G', 'pieces', true),
    ('520cc', 'C', 'pieces', true),
    ('1 Kg Detergent Powder', 'C', 'pieces', true),
    ('Spin Mop', 'C', 'pieces', true),
    ('Piller', 'U', 'pieces', true),
    ('Scissor', 'U', 'pieces', true),
    ('Whisk', 'U', 'pieces', true),
    ('Double Sided', 'G', 'pieces', true),
    ('Notebook', 'G', 'pieces', true),
    ('Safe Guard', 'C', 'pieces', true),
    ('Tong', 'U', 'pieces', true),
    ('Extension Wire', 'G', 'pieces', true),
    ('Cashbox', 'G', 'pieces', true),
    ('Bulb', 'G', 'pieces', true),
    ('Receptacle', 'G', 'pieces', true),
    ('Trapo sa Tiil', 'C', 'pieces', true),
    ('Tape Dispenser', 'G', 'pieces', true),
    ('Brush', 'U', 'pieces', true),
    ('Storage Box', 'G', 'pieces', true),
    ('Grater', 'U', 'pieces', true);

update public.inventory_items as item
set low_stock_threshold = seed.threshold
from (values
    ('Oil', 7),
    ('2 Kilo Flour', 19),
    ('250 Grams Flour', 4),
    ('Cabbage', 59),
    ('Carrots', 6),
    ('Onion Leaves', 3),
    ('Tissue', 1),
    ('Hand Gloves', 1),
    ('Coke', 2),
    ('Mountain Dew', 1),
    ('500ml Water', 1),
    ('Cheesebar', 75),
    ('Cellophane-L', 2),
    ('Ice Wrapper', 2),
    ('Stick', 2),
    ('4 Pcs Tray', 250),
    ('4 Pcs Box', 225),
    ('8 Pcs Tray', 125),
    ('SBox', 44),
    ('MBox', 19),
    ('24 Pcs', 13),
    ('Mayonnaise', 7),
    ('Sauce', 11),
    ('Bulceta #10', 125),
    ('Water', 3),
    ('Dishwashing', 1),
    ('Downy', 2)
) as seed(name, threshold)
where item.name = seed.name and item.is_seed;

insert into public.inventory_branches (name) values
    ('Legendary Takoyaki · Ampayon'),
    ('Legendary Takoyaki · Urios'),
    ('Legendary Takoyaki · T.Calo'),
    ('Legendary Takoyaki · GMall');

create or replace function public.is_inventory_manager()
returns boolean
language sql
stable
set search_path = pg_catalog, public, auth
as $$
    select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') in ('Production Head', 'Owner'), false);
$$;

revoke all on function public.is_inventory_manager() from public;
grant execute on function public.is_inventory_manager() to authenticated;

create or replace function public.guard_inventory_item()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
    if auth.uid() is null then
        raise exception 'Sign in to manage inventory items.';
    end if;

    if tg_op = 'INSERT' then
        new.created_by := auth.uid();
        if not public.is_inventory_manager() and (new.is_seed or not new.is_active) then
            raise exception 'Staff can only add active, custom inventory items.';
        end if;
        return new;
    end if;

    if new.id is distinct from old.id
        or new.name is distinct from old.name
        or new.category is distinct from old.category
        or new.unit is distinct from old.unit
        or new.is_seed is distinct from old.is_seed
        or new.created_by is distinct from old.created_by
        or new.created_at is distinct from old.created_at then
        raise exception 'Item identity and creation details cannot be changed.';
    end if;

    if not public.is_inventory_manager() then
        raise exception 'Only a Production Head or Owner can update inventory items.';
    end if;

    return new;
end;
$$;

revoke all on function public.guard_inventory_item() from public;

create trigger guard_inventory_item_before_write
before insert or update on public.inventory_items
for each row execute function public.guard_inventory_item();

create or replace function public.guard_inventory_branch()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
    if auth.uid() is null then
        raise exception 'Sign in to manage branches.';
    end if;
    if tg_op = 'INSERT' then
        new.created_by := auth.uid();
        return new;
    end if;
    if new.id is distinct from old.id
        or new.name is distinct from old.name
        or new.created_by is distinct from old.created_by
        or new.created_at is distinct from old.created_at then
        raise exception 'Branch names and creation details cannot be changed.';
    end if;
    return new;
end;
$$;

revoke all on function public.guard_inventory_branch() from public;

create trigger guard_inventory_branch_before_write
before insert or update on public.inventory_branches
for each row execute function public.guard_inventory_branch();

create or replace function public.guard_inventory_item_conversion()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
    v_item_active boolean;
begin
    if auth.uid() is null then
        raise exception 'Sign in to manage unit conversions.';
    end if;
    if length(trim(new.release_unit)) = 0 or new.factor <= 0 then
        raise exception 'A unit and positive conversion factor are required.';
    end if;
    select is_active into v_item_active
    from public.inventory_items
    where id = new.item_id
    for update;
    if not found or not v_item_active then
        raise exception 'Choose an active inventory item.';
    end if;
    if tg_op = 'INSERT' then
        new.created_by := auth.uid();
    elsif new.id is distinct from old.id
        or new.item_id is distinct from old.item_id
        or new.release_unit is distinct from old.release_unit
        or new.created_by is distinct from old.created_by
        or new.created_at is distinct from old.created_at then
        raise exception 'Only a conversion factor can be changed.';
    end if;
    return new;
end;
$$;

revoke all on function public.guard_inventory_item_conversion() from public;

create trigger guard_inventory_item_conversion_before_write
before insert or update on public.inventory_item_conversions
for each row execute function public.guard_inventory_item_conversion();

create or replace function public.guard_inventory_branch_movement()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
    v_source_name text;
    v_destination_active boolean;
    v_outgoing numeric;
    v_transfer_balance numeric;
    v_excluded_id uuid;
    v_user_metadata jsonb := coalesce(auth.jwt() -> 'user_metadata', '{}'::jsonb);
begin
    if auth.uid() is null or not public.is_inventory_manager() then
        raise exception 'Only a Production Head or Owner can move branch inventory.';
    end if;
    if new.movement_date > (now() at time zone 'Asia/Manila')::date then
        raise exception 'The movement date cannot be in the future.';
    end if;
    if tg_op = 'UPDATE' then
        v_excluded_id := old.id;
        if new.id is distinct from old.id
            or new.from_branch_id is distinct from old.from_branch_id
            or new.to_branch_id is distinct from old.to_branch_id
            or new.destination_type is distinct from old.destination_type
            or new.return_transaction_id is distinct from old.return_transaction_id
            or new.item_id is distinct from old.item_id
            or new.created_by is distinct from old.created_by
            or new.created_by_name is distinct from old.created_by_name
            or new.created_by_email is distinct from old.created_by_email
            or new.created_at is distinct from old.created_at then
            raise exception 'Branch movement identity and creation details cannot be changed.';
        end if;
    end if;

    perform id
    from public.inventory_items
    where id = new.item_id
    for update;
    if not found then
        raise exception 'Choose an existing inventory item.';
    end if;

    perform id
    from public.inventory_branches
    where id = new.from_branch_id or id = new.to_branch_id
    order by id
    for update;

    select name into v_source_name
    from public.inventory_branches
    where id = new.from_branch_id;
    if not found then
        raise exception 'Choose an existing source branch.';
    end if;

    if new.destination_type = 'branch' then
        select is_active into v_destination_active
        from public.inventory_branches
        where id = new.to_branch_id;
        if not found or not v_destination_active then
            raise exception 'Choose an active destination branch.';
        end if;
    end if;

    select coalesce(sum(quantity), 0) into v_outgoing
    from public.inventory_transactions
    where item_id = new.item_id
        and movement_type = 'out'
        and lower(detail) = lower(v_source_name)
        and deleted_at is null
        and voided_at is null;

    select coalesce(sum(
        case when from_branch_id = new.from_branch_id then -quantity else quantity end
    ), 0) into v_transfer_balance
    from public.inventory_branch_movements
    where item_id = new.item_id
        and (from_branch_id = new.from_branch_id or to_branch_id = new.from_branch_id)
        and voided_at is null
        and id is distinct from v_excluded_id;

    if new.voided_at is null
        and new.quantity > v_outgoing + v_transfer_balance + 0.000001 then
        raise exception 'The branch does not have enough stock for this movement.';
    end if;

    if tg_op = 'INSERT' then
        new.created_by := auth.uid();
        new.created_by_email := coalesce(auth.jwt() ->> 'email', '');
        new.created_by_name := trim(concat_ws(
            ' ',
            nullif(v_user_metadata ->> 'first_name', ''),
            nullif(v_user_metadata ->> 'middle_name', ''),
            nullif(v_user_metadata ->> 'surname', '')
        ));
    end if;
    if tg_op = 'INSERT' and new.destination_type = 'office' then
        insert into public.inventory_transactions (
            id, item_id, movement_type, quantity, entry_date, detail, created_by
        ) values (
            new.return_transaction_id,
            new.item_id,
            'in',
            new.quantity,
            new.movement_date,
            'Returned from ' || v_source_name,
            auth.uid()
        );
    end if;
    return new;
end;
$$;

revoke all on function public.guard_inventory_branch_movement() from public;

create trigger guard_inventory_branch_movement_before_insert
before insert or update on public.inventory_branch_movements
for each row execute function public.guard_inventory_branch_movement();

create or replace function public.validate_inventory_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
    v_item_active boolean;
    v_branch_active boolean;
    v_excluded_id uuid;
    v_min_balance numeric;
    v_branch record;
    v_branch_name text;
    v_branch_names text[] := array[]::text[];
    v_branch_balance numeric;
    v_detail_changed boolean := true;
    v_user_metadata jsonb := coalesce(auth.jwt() -> 'user_metadata', '{}'::jsonb);
begin
    if auth.uid() is null then
        raise exception 'Sign in to record inventory changes.';
    end if;

    if tg_op = 'UPDATE' then
        v_excluded_id := old.id;
        v_detail_changed := new.detail is distinct from old.detail;
        if new.item_id is distinct from old.item_id
            or new.movement_type is distinct from old.movement_type then
            raise exception 'Change the item or movement type by recording a separate transaction.';
        end if;
        if not public.is_inventory_manager() then
            if old.created_by is distinct from auth.uid()
                or (old.created_at at time zone 'Asia/Manila')::date <> (now() at time zone 'Asia/Manila')::date
                or new.deleted_at is distinct from old.deleted_at
                or new.voided_at is distinct from old.voided_at then
                raise exception 'Staff can only edit their own entries on the day they were recorded.';
            end if;
        end if;
        if new.created_by is distinct from old.created_by
            or new.created_at is distinct from old.created_at
            or new.created_by_name is distinct from old.created_by_name
            or new.created_by_email is distinct from old.created_by_email then
            raise exception 'The recorded-by details cannot be changed.';
        end if;
    else
        new.created_by := auth.uid();
        new.created_by_email := coalesce(auth.jwt() ->> 'email', '');
        new.created_by_name := trim(concat_ws(
            ' ',
            nullif(v_user_metadata ->> 'first_name', ''),
            nullif(v_user_metadata ->> 'middle_name', ''),
            nullif(v_user_metadata ->> 'surname', '')
        ));
    end if;

    if new.entry_date > (now() at time zone 'Asia/Manila')::date then
        raise exception 'The entry date cannot be in the future.';
    end if;
    if new.quantity <= 0 or length(trim(new.detail)) = 0 then
        raise exception 'A positive quantity and a description are required.';
    end if;

    select is_active into v_item_active
    from public.inventory_items
    where id = new.item_id
    for update;
    if not found or (tg_op = 'INSERT' and not v_item_active) then
        raise exception 'Choose an active inventory item.';
    end if;

    if new.movement_type = 'out'
        and new.detail not in ('Waste', 'Spoilage', 'Damaged', 'Lost')
        and v_detail_changed then
        select is_active into v_branch_active
        from public.inventory_branches
        where lower(name) = lower(new.detail)
        for update;
        if not found or not v_branch_active then
            raise exception 'Choose an active destination branch.';
        end if;
    end if;

    if new.deleted_at is null and new.voided_at is null then
        with ledger as (
            select entry_date, movement_type,
                case when movement_type = 'in' then quantity else -quantity end as delta,
                created_at, id
            from public.inventory_transactions
            where item_id = new.item_id
                and deleted_at is null
                and voided_at is null
                and id is distinct from v_excluded_id
            union all
            select new.entry_date, new.movement_type,
                case when new.movement_type = 'in' then new.quantity else -new.quantity end,
                new.created_at, new.id
            where new.deleted_at is null and new.voided_at is null
        ),
        running_balances as (
            select sum(delta) over (
                order by entry_date,
                    case when movement_type = 'in' then 0 else 1 end,
                    created_at, id
            ) as balance
            from ledger
        )
        select min(balance) into v_min_balance from running_balances;

        if v_min_balance < -0.000001 then
            raise exception 'This change would make the inventory balance negative.';
        end if;
    end if;

    if tg_op = 'UPDATE' then
        if old.movement_type = 'out'
            and old.detail not in ('Waste', 'Spoilage', 'Damaged', 'Lost') then
            v_branch_names := array_append(v_branch_names, old.detail);
        end if;
    end if;
    if new.movement_type = 'out' and new.detail not in ('Waste', 'Spoilage', 'Damaged', 'Lost') then
        v_branch_names := array_append(v_branch_names, new.detail);
    end if;
    for v_branch_name in
        select distinct branch_name
        from unnest(v_branch_names) as branches(branch_name)
        order by branch_name
    loop
        select id, name into v_branch
        from public.inventory_branches
        where lower(name) = lower(v_branch_name)
        for update;
        if not found then
            continue;
        end if;

        select coalesce(sum(movement.movement_quantity), 0) into v_branch_balance
        from (
            select quantity as movement_quantity
            from public.inventory_transactions
            where item_id = new.item_id
                and movement_type = 'out'
                and lower(detail) = lower(v_branch.name)
                and deleted_at is null
                and voided_at is null
                and id is distinct from v_excluded_id
            union all
            select new.quantity
            where new.movement_type = 'out'
                and lower(new.detail) = lower(v_branch.name)
                and new.deleted_at is null
                and new.voided_at is null
        ) as movement;

        select v_branch_balance + coalesce(sum(
            case when to_branch_id = v_branch.id then quantity else -quantity end
        ), 0) into v_branch_balance
        from public.inventory_branch_movements
        where item_id = new.item_id
            and (from_branch_id = v_branch.id or to_branch_id = v_branch.id)
            and voided_at is null;

        if v_branch_balance < -0.000001 then
            raise exception 'This change would make the branch balance negative.';
        end if;
    end loop;

    if tg_op = 'UPDATE' then
        update public.inventory_branch_movements
        set quantity = new.quantity,
            movement_date = new.entry_date,
            voided_at = case
                when new.deleted_at is not null or new.voided_at is not null then now()
                else null
            end
        where return_transaction_id = new.id;
    end if;

    return new;
end;
$$;

revoke all on function public.validate_inventory_transaction() from public;

create trigger validate_inventory_transaction_before_write
before insert or update on public.inventory_transactions
for each row execute function public.validate_inventory_transaction();

alter table public.inventory_items enable row level security;
alter table public.inventory_item_conversions enable row level security;
alter table public.inventory_branches enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.inventory_branch_movements enable row level security;

create policy inventory_items_read on public.inventory_items
    for select to authenticated using (true);
create policy inventory_items_insert on public.inventory_items
    for insert to authenticated with check (
        public.is_inventory_manager()
        or (created_by = auth.uid() and not is_seed and is_active)
    );
create policy inventory_items_update on public.inventory_items
    for update to authenticated using (public.is_inventory_manager())
    with check (public.is_inventory_manager());

create policy inventory_item_conversions_read on public.inventory_item_conversions
    for select to authenticated using (true);
create policy inventory_item_conversions_insert on public.inventory_item_conversions
    for insert to authenticated with check (auth.uid() is not null);
create policy inventory_item_conversions_update on public.inventory_item_conversions
    for update to authenticated using (auth.uid() is not null)
    with check (auth.uid() is not null);

create policy inventory_branches_read on public.inventory_branches
    for select to authenticated using (true);
create policy inventory_branches_insert on public.inventory_branches
    for insert to authenticated with check (auth.uid() is not null);
create policy inventory_branches_update on public.inventory_branches
    for update to authenticated using (public.is_inventory_manager())
    with check (public.is_inventory_manager());

create policy inventory_transactions_read on public.inventory_transactions
    for select to authenticated using (true);
create policy inventory_transactions_insert on public.inventory_transactions
    for insert to authenticated with check (created_by = auth.uid() and deleted_at is null and voided_at is null);
create policy inventory_transactions_update on public.inventory_transactions
    for update to authenticated
    using (
        public.is_inventory_manager()
        or (
            created_by = auth.uid()
            and (created_at at time zone 'Asia/Manila')::date = (now() at time zone 'Asia/Manila')::date
        )
    )
    with check (
        public.is_inventory_manager()
        or (
            created_by = auth.uid()
            and (created_at at time zone 'Asia/Manila')::date = (now() at time zone 'Asia/Manila')::date
        )
    );

create policy inventory_branch_movements_read on public.inventory_branch_movements
    for select to authenticated using (true);
create policy inventory_branch_movements_insert on public.inventory_branch_movements
    for insert to authenticated with check (public.is_inventory_manager());

revoke all on public.inventory_items, public.inventory_item_conversions, public.inventory_branches,
    public.inventory_transactions, public.inventory_branch_movements
    from public, anon;
grant select, insert, update on public.inventory_items, public.inventory_item_conversions,
    public.inventory_branches, public.inventory_transactions,
    public.inventory_branch_movements to authenticated;
