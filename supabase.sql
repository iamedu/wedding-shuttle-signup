-- Run this in Supabase SQL Editor: https://frhspbqpdbwbxzszuwkq.supabase.co → SQL Editor

-- 1. Create table
create table if not exists public.shuttle_bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamp with time zone default now(),
  name text not null,
  seats int not null check (seats > 0 and seats <= 6),
  shuttle_time text not null,
  phone text,
  accessibility text
);

-- 2. Enable RLS
alter table public.shuttle_bookings enable row level security;

-- 3. Allow public read and insert (for guest sign-up, no auth)
drop policy if exists "Allow public read" on public.shuttle_bookings;
create policy "Allow public read" on public.shuttle_bookings for select using (true);

drop policy if exists "Allow public insert" on public.shuttle_bookings;
create policy "Allow public insert" on public.shuttle_bookings for insert with check (true);

-- 4. View for remaining seats
create or replace view public.shuttle_capacity as
select 
  t.time as shuttle_time,
  36 as capacity,
  coalesce(sum(b.seats),0) as booked,
  36 - coalesce(sum(b.seats),0) as remaining
from (values ('2:20 PM — WaFd Bank → Venue'), ('2:50 PM — WaFd Bank → Venue'), ('3:20 PM — WaFd Bank → Venue')) as t(time)
left join public.shuttle_bookings b on b.shuttle_time = t.time
group by t.time;

-- 5. Function to safely book with check (prevents race)
create or replace function public.book_shuttle(p_name text, p_seats int, p_time text, p_phone text, p_access text)
returns json as $$
declare
  v_booked int;
  v_remaining int;
begin
  select coalesce(sum(seats),0) into v_booked from public.shuttle_bookings where shuttle_time = p_time;
  v_remaining := 36 - v_booked;
  if v_remaining < p_seats then
    return json_build_object('ok', false, 'remaining', v_remaining, 'error', 'Not enough seats');
  end if;
  insert into public.shuttle_bookings (name, seats, shuttle_time, phone, accessibility) 
  values (p_name, p_seats, p_time, p_phone, p_access);
  return json_build_object('ok', true, 'remaining', v_remaining - p_seats);
end;
$$ language plpgsql security definer;
