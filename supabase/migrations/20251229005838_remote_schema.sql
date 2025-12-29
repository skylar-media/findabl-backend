create extension if not exists "pg_net" with schema "extensions";

drop policy "news.read.public" on "public"."news";

drop policy "read own form" on "public"."onboarding_forms";

drop policy "update own form" on "public"."onboarding_forms";

drop policy "write own form" on "public"."onboarding_forms";

drop policy "init own status" on "public"."onboarding_status";

drop policy "read own status" on "public"."onboarding_status";

drop policy "update own status" on "public"."onboarding_status";

drop policy "Anyone can insert" on "public"."user_audit";

drop policy "Can only view own subs data." on "public"."subscriptions";

drop policy "Can update own user data." on "public"."users";

alter table "public"."onboarding_forms" drop constraint "onboarding_forms_user_id_fkey";

alter type "public"."subscription_status" rename to "subscription_status__old_version_to_be_dropped";

create type "public"."subscription_status" as enum ('active', 'canceled', 'incomplete', 'incomplete_expired', 'past_due', 'paused', 'trialing', 'unpaid');

alter table "public"."subscription_audit" alter column status type "public"."subscription_status" using status::text::"public"."subscription_status";

alter table "public"."subscriptions" alter column status type "public"."subscription_status" using status::text::"public"."subscription_status";

drop type "public"."subscription_status__old_version_to_be_dropped";

alter table "public"."subscription_audit" enable row level security;

alter table "public"."users" add column "company_address" character varying;

alter table "public"."users" add column "company_name" text;

alter table "public"."onboarding_forms" add constraint "onboarding_forms_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."onboarding_forms" validate constraint "onboarding_forms_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$BEGIN
  INSERT INTO public.users (
    id,
    full_name,
    mobile,
    email,
    company_name,
    company_address
  )
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'phone',
    NEW.email,
    NEW.raw_user_meta_data->>'company_name',
    NEW.raw_user_meta_data->>'company_address'
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name        = COALESCE(EXCLUDED.full_name, public.users.full_name),
    mobile           = COALESCE(EXCLUDED.mobile,    public.users.mobile),
    email            = COALESCE(EXCLUDED.email,     public.users.email),
    company_name     = COALESCE(EXCLUDED.company_name, public.users.company_name),
    company_address  = COALESCE(EXCLUDED.company_address, public.users.company_address),
    updated_at       = NOW(); -- if this column exists

  RETURN NEW;
END;$function$
;

CREATE OR REPLACE FUNCTION public.handle_update_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$BEGIN
  UPDATE public.users
  SET
    email           = NEW.email,
    name            = COALESCE(NEW.raw_user_meta_data->>'full_name', name),
    mobile          = COALESCE(NEW.raw_user_meta_data->>'phone', mobile),
    company_name    = COALESCE(NEW.raw_user_meta_data->>'company_name', company_name),
    company_address = COALESCE(NEW.raw_user_meta_data->>'company_address', company_address),
    updated_at      = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
END;$function$
;

grant delete on table "public"."subscription_audit" to "anon";

grant insert on table "public"."subscription_audit" to "anon";

grant references on table "public"."subscription_audit" to "anon";

grant select on table "public"."subscription_audit" to "anon";

grant trigger on table "public"."subscription_audit" to "anon";

grant truncate on table "public"."subscription_audit" to "anon";

grant update on table "public"."subscription_audit" to "anon";

grant delete on table "public"."subscription_audit" to "authenticated";

grant insert on table "public"."subscription_audit" to "authenticated";

grant references on table "public"."subscription_audit" to "authenticated";

grant select on table "public"."subscription_audit" to "authenticated";

grant trigger on table "public"."subscription_audit" to "authenticated";

grant truncate on table "public"."subscription_audit" to "authenticated";

grant update on table "public"."subscription_audit" to "authenticated";


  create policy "Anyone can ready the news"
  on "public"."news"
  as permissive
  for select
  to public
using (true);



  create policy "User can insert their own form"
  on "public"."onboarding_forms"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "User can read their own form"
  on "public"."onboarding_forms"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "User can update their own form"
  on "public"."onboarding_forms"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "User can insert"
  on "public"."onboarding_status"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "User can read"
  on "public"."onboarding_status"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "User can update"
  on "public"."onboarding_status"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Can only view own subs data."
  on "public"."subscriptions"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "Can update own user data."
  on "public"."users"
  as permissive
  for update
  to public
using ((auth.uid() = id))
with check ((auth.uid() = id));


drop trigger if exists "on_auth_user_updated" on "auth"."users";

CREATE TRIGGER on_auth_user_updated AFTER UPDATE OF raw_user_meta_data, email ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


