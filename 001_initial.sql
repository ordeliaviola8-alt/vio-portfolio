-- Run in Supabase SQL Editor. Public content is readable; private admin data is not.
create extension if not exists pgcrypto;
create table if not exists public.portfolio_content (
  id uuid primary key default gen_random_uuid(),
  section text not null unique,
  content jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
create table if not exists public.private_feedback (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  category text not null check (category in ('Kritik','Saran','Masukan','Pesan')),
  message text not null check (char_length(message) between 5 and 1500),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.admin_credentials (
  id integer primary key default 1 check (id=1),
  password_salt text not null,
  password_hash text not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.login_rate_limits (
  ip_hash text primary key,
  attempts integer not null default 0,
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz
);

alter table public.portfolio_content enable row level security;
alter table public.private_feedback enable row level security;
alter table public.admin_credentials enable row level security;
alter table public.login_rate_limits enable row level security;

-- Public can only read portfolio content. No public write policies are created.
drop policy if exists "Public read portfolio content" on public.portfolio_content;
create policy "Public read portfolio content" on public.portfolio_content for select to anon, authenticated using (true);
-- Feedback, credentials and rate limits have NO anon/authenticated policies.
revoke all on public.private_feedback from anon, authenticated;
revoke all on public.admin_credentials from anon, authenticated;
revoke all on public.login_rate_limits from anon, authenticated;
grant select on public.portfolio_content to anon, authenticated;

-- Function called by Edge Function with service-role credentials only.
create or replace function public.check_login_rate_limit(p_ip_hash text)
returns boolean language plpgsql security definer set search_path=public as $$
declare r public.login_rate_limits%rowtype;
begin
  insert into public.login_rate_limits(ip_hash,attempts,window_started_at)
  values(p_ip_hash,0,now()) on conflict(ip_hash) do nothing;
  select * into r from public.login_rate_limits where ip_hash=p_ip_hash for update;
  if r.blocked_until is not null and r.blocked_until > now() then return false; end if;
  if r.window_started_at < now() - interval '15 minutes' then
    update public.login_rate_limits set attempts=0,window_started_at=now(),blocked_until=null where ip_hash=p_ip_hash;
  end if;
  return true;
end; $$;
create or replace function public.record_login_failure(p_ip_hash text)
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.login_rate_limits(ip_hash,attempts,window_started_at) values(p_ip_hash,1,now())
  on conflict(ip_hash) do update set attempts=case when login_rate_limits.window_started_at < now()-interval '15 minutes' then 1 else login_rate_limits.attempts+1 end,
  window_started_at=case when login_rate_limits.window_started_at < now()-interval '15 minutes' then now() else login_rate_limits.window_started_at end,
  blocked_until=case when (case when login_rate_limits.window_started_at < now()-interval '15 minutes' then 1 else login_rate_limits.attempts+1 end)>=6 then now()+interval '30 minutes' else login_rate_limits.blocked_until end;
end; $$;
revoke all on function public.check_login_rate_limit(text) from public, anon, authenticated;
revoke all on function public.record_login_failure(text) from public, anon, authenticated;
grant execute on function public.check_login_rate_limit(text) to service_role;
grant execute on function public.record_login_failure(text) to service_role;

insert into public.portfolio_content(section,content,sort_order) values
('profile','{"about":"Halo! Aku Viola, biasa dipanggil Pio. Aku adalah siswa SMK jurusan Desain Komunikasi Visual yang senang mengeksplorasi hal baru, menangkap cerita melalui foto dan video, serta menuangkan ide menjadi karya visual.","about_extra":"Di luar dunia kreatif, aku juga suka memasak, makeup & beauty, dan belajar bahasa asing—terutama Mandarin."}',1),
('works','{"items":[]}',2),('hobbies','{"items":[{"icon":"📷","title":"Photography","description":"Finding stories in little details."},{"icon":"🎬","title":"Videography","description":"Keeping moments in motion."},{"icon":"🍰","title":"Cooking","description":"Trying recipes and making something warm."},{"icon":"🈶","title":"Foreign Languages","description":"Learning new words and perspectives."},{"icon":"🪞","title":"Makeup & Beauty","description":"Exploring creativity through details."}]}',3),
('experiences','{"items":[{"period":"School activities","title":"OSIS / Media Sekolah · MC Sekolah","description":"Belajar berkomunikasi, bekerja sama, dan terlibat dalam kegiatan sekolah."},{"period":"Creative team","title":"Tim Fotografi & Videografi","description":"Mendokumentasikan kegiatan dan mengembangkan kemampuan visual."},{"period":"Internship","title":"Seoul Studio, Singkawang","description":"Mengenal alur kerja studio dan pengalaman produksi visual."}]}',4),
('skills','{"items":[{"title":"Photography","level":"Learning","progress":65},{"title":"Basic Graphic Design","level":"Growing","progress":55},{"title":"Videography","level":"Learning","progress":58},{"title":"Video Documentation","level":"Learning","progress":60},{"title":"Basic Photo Editing","level":"Learning","progress":55},{"title":"Mandarin Learning","level":"Beginner","progress":30}]}',5),
('contact','{"items":[{"label":"Instagram","url":"https://instagram.com/yourusername"}]}',6),
('translations','{"id":{},"en":{},"zh":{}}',7),('settings','{"site_title":"Viola Ordelia","tagline":"A Little Space of Creativity"}',8)
on conflict(section) do nothing;

-- Storage bucket is public for portfolio media only. Private messages are never stored here.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('portfolio-media','portfolio-media',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
-- Do not create client upload/update/delete policies. Edge Function uploads after checking admin token.
