


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."pricing_plan_interval" AS ENUM (
    'day',
    'week',
    'month',
    'year'
);


ALTER TYPE "public"."pricing_plan_interval" OWNER TO "postgres";


CREATE TYPE "public"."pricing_type" AS ENUM (
    'one_time',
    'recurring'
);


ALTER TYPE "public"."pricing_type" OWNER TO "postgres";


CREATE TYPE "public"."subscription_status" AS ENUM (
    'trialing',
    'active',
    'canceled',
    'incomplete',
    'incomplete_expired',
    'past_due',
    'unpaid',
    'paused'
);


ALTER TYPE "public"."subscription_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.users (id, email, name, description)
  values (
    new.id,                                -- same UUID as auth.users.id
    new.email,                             -- email from auth
    coalesce(new.raw_user_meta_data->>'full_name', ''), -- or display_name, depending on your signup code
    ''                                     -- description empty by default
  )
  on conflict (id) do nothing; -- prevents duplicates if retriggered
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
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
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_update_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update public.users
  set email = new.email,
      name = coalesce(new.raw_user_meta_data->>'full_name', name),
      updated_at = now()
  where id = new.id;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_update_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."subscription_audit_snapshot"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  insert into public.subscription_audit (
    subscription_id, user_id, status, metadata, price_id, quantity, cancel_at_period_end,
    created, current_period_start, current_period_end,
    ended_at, cancel_at, canceled_at, trial_start, trial_end,
    email, plan_name,
    op, recorded_at, snapshot
  )
  values (
    NEW.id, NEW.user_id, NEW.status, NEW.metadata, NEW.price_id, NEW.quantity, NEW.cancel_at_period_end,
    NEW.created, NEW.current_period_start, NEW.current_period_end,
    NEW.ended_at, NEW.cancel_at, NEW.canceled_at, NEW.trial_start, NEW.trial_end,
    NEW.email, NEW.plan_name,
    TG_OP, now(), to_jsonb(NEW)
  );
  return NEW;
end;
$$;


ALTER FUNCTION "public"."subscription_audit_snapshot"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_audit_snapshot"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  insert into public.user_audit (
    user_id, full_name, email, billing_address, payment_method, mobile, updated_at,
    op, recorded_at, snapshot
  )
  values (
    NEW.id, NEW.full_name, NEW.email, NEW.billing_address, NEW.payment_method, NEW.mobile, NEW.updated_at,
    TG_OP, now(), to_jsonb(NEW)
  );
  return NEW;
end;
$$;


ALTER FUNCTION "public"."user_audit_snapshot"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activity" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "ip_address" character varying
);


ALTER TABLE "public"."activity" OWNER TO "postgres";


ALTER TABLE "public"."activity" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."activity_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."ai_search_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "business_category" "text" NOT NULL,
    "location" "text" NOT NULL,
    "ip" "text"
);


ALTER TABLE "public"."ai_search_logs" OWNER TO "postgres";


ALTER TABLE "public"."ai_search_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."ai_search_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."customer_review" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rating" smallint NOT NULL,
    "title" "text" NOT NULL,
    "review" character varying NOT NULL,
    "review_from" "text" NOT NULL,
    "order" smallint NOT NULL
);


ALTER TABLE "public"."customer_review" OWNER TO "postgres";


ALTER TABLE "public"."customer_review" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."customer_review_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" NOT NULL,
    "stripe_customer_id" "text"
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."faq" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "question" "text" NOT NULL,
    "answer" "text" NOT NULL,
    "order" smallint,
    "published" boolean NOT NULL
);


ALTER TABLE "public"."faq" OWNER TO "postgres";


ALTER TABLE "public"."faq" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."faq_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."news" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text" NOT NULL,
    "link" "text" NOT NULL
);


ALTER TABLE "public"."news" OWNER TO "postgres";


ALTER TABLE "public"."news" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."news_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."onboarding_forms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."onboarding_forms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onboarding_status" (
    "user_id" "uuid" NOT NULL,
    "is_done" boolean DEFAULT false NOT NULL,
    "onboarding_form_id" "uuid",
    "completed_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "onboarding_done_consistency" CHECK (((("is_done" = true) AND ("onboarding_form_id" IS NOT NULL)) OR (("is_done" = false) AND ("onboarding_form_id" IS NULL))))
);


ALTER TABLE "public"."onboarding_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prices" (
    "id" "text" NOT NULL,
    "product_id" "text",
    "active" boolean,
    "description" "text",
    "unit_amount" bigint,
    "currency" "text",
    "type" "public"."pricing_type",
    "interval" "public"."pricing_plan_interval",
    "interval_count" integer,
    "trial_period_days" integer,
    "metadata" "jsonb",
    CONSTRAINT "prices_currency_check" CHECK (("char_length"("currency") = 3))
);


ALTER TABLE "public"."prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "text" NOT NULL,
    "active" boolean,
    "name" "text",
    "description" "text",
    "sort" smallint,
    "metadata" "jsonb"
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscription_audit" (
    "audit_id" bigint NOT NULL,
    "subscription_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "public"."subscription_status",
    "metadata" "jsonb",
    "price_id" "text",
    "quantity" integer,
    "cancel_at_period_end" boolean,
    "created" timestamp with time zone,
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "cancel_at" timestamp with time zone,
    "canceled_at" timestamp with time zone,
    "trial_start" timestamp with time zone,
    "trial_end" timestamp with time zone,
    "email" "text",
    "plan_name" "text",
    "op" "text" NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "snapshot" "jsonb" NOT NULL,
    CONSTRAINT "subscription_audit_op_check" CHECK (("op" = ANY (ARRAY['INSERT'::"text", 'UPDATE'::"text"])))
);


ALTER TABLE "public"."subscription_audit" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."subscription_audit_audit_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."subscription_audit_audit_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."subscription_audit_audit_id_seq" OWNED BY "public"."subscription_audit"."audit_id";



CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "public"."subscription_status",
    "metadata" "jsonb",
    "price_id" "text",
    "quantity" integer,
    "cancel_at_period_end" boolean,
    "created" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "current_period_start" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "current_period_end" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "ended_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "cancel_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "canceled_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "trial_start" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "trial_end" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "email" "text" NOT NULL,
    "plan_name" "text" NOT NULL
);


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_audit" (
    "audit_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "full_name" "text",
    "email" "text",
    "billing_address" "text",
    "payment_method" "text",
    "mobile" "text",
    "updated_at" timestamp with time zone,
    "op" "text" NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "snapshot" "jsonb" NOT NULL,
    CONSTRAINT "user_audit_op_check" CHECK (("op" = ANY (ARRAY['INSERT'::"text", 'UPDATE'::"text"])))
);


ALTER TABLE "public"."user_audit" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."user_audit_audit_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."user_audit_audit_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."user_audit_audit_id_seq" OWNED BY "public"."user_audit"."audit_id";



CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "billing_address" "jsonb",
    "payment_method" "jsonb",
    "mobile" "text",
    "updated_at" timestamp without time zone,
    "email" "text"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."subscription_audit" ALTER COLUMN "audit_id" SET DEFAULT "nextval"('"public"."subscription_audit_audit_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."user_audit" ALTER COLUMN "audit_id" SET DEFAULT "nextval"('"public"."user_audit_audit_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."activity"
    ADD CONSTRAINT "activity_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_search_logs"
    ADD CONSTRAINT "ai_search_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_review"
    ADD CONSTRAINT "customer_review_order_key" UNIQUE ("order");



ALTER TABLE ONLY "public"."customer_review"
    ADD CONSTRAINT "customer_review_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."faq"
    ADD CONSTRAINT "faq_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."news"
    ADD CONSTRAINT "news_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onboarding_forms"
    ADD CONSTRAINT "onboarding_forms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onboarding_forms"
    ADD CONSTRAINT "onboarding_forms_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."onboarding_status"
    ADD CONSTRAINT "onboarding_status_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."prices"
    ADD CONSTRAINT "prices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscription_audit"
    ADD CONSTRAINT "subscription_audit_pkey" PRIMARY KEY ("audit_id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."user_audit"
    ADD CONSTRAINT "user_audit_pkey" PRIMARY KEY ("audit_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_subscription_audit_sub_id_time" ON "public"."subscription_audit" USING "btree" ("subscription_id", "recorded_at" DESC);



CREATE INDEX "idx_user_audit_user_time" ON "public"."user_audit" USING "btree" ("user_id", "recorded_at" DESC);



CREATE OR REPLACE TRIGGER "trg_subscriptions_audit_ins" AFTER INSERT ON "public"."subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."subscription_audit_snapshot"();



CREATE OR REPLACE TRIGGER "trg_subscriptions_audit_upd" AFTER UPDATE ON "public"."subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."subscription_audit_snapshot"();



CREATE OR REPLACE TRIGGER "trg_users_audit_ins" AFTER INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."user_audit_snapshot"();



CREATE OR REPLACE TRIGGER "trg_users_audit_upd" AFTER UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."user_audit_snapshot"();



ALTER TABLE ONLY "public"."activity"
    ADD CONSTRAINT "activity_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."onboarding_forms"
    ADD CONSTRAINT "onboarding_forms_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."onboarding_status"
    ADD CONSTRAINT "onboarding_status_onboarding_form_id_fkey" FOREIGN KEY ("onboarding_form_id") REFERENCES "public"."onboarding_forms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."onboarding_status"
    ADD CONSTRAINT "onboarding_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prices"
    ADD CONSTRAINT "prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_price_id_fkey" FOREIGN KEY ("price_id") REFERENCES "public"."prices"("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_audit"
    ADD CONSTRAINT "user_audit_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



CREATE POLICY "Allow public read-only access." ON "public"."prices" FOR SELECT USING (true);



CREATE POLICY "Allow public read-only access." ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Anyone can insert" ON "public"."user_audit" FOR INSERT WITH CHECK (true);



CREATE POLICY "Anyone can view" ON "public"."customer_review" FOR SELECT USING (true);



CREATE POLICY "Anyone can view" ON "public"."faq" FOR SELECT USING (true);



CREATE POLICY "Can only view own subs data." ON "public"."subscriptions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Can update own user data." ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Can view own user data." ON "public"."users" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can delete their own logs" ON "public"."activity" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own activity logs" ON "public"."activity" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own activity logs" ON "public"."activity" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own logs" ON "public"."activity" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."activity" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ai_search_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_review" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."faq" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "init own status" ON "public"."onboarding_status" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."news" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "news.read.public" ON "public"."news" FOR SELECT USING (true);



ALTER TABLE "public"."onboarding_forms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."onboarding_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "read own form" ON "public"."onboarding_forms" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "read own status" ON "public"."onboarding_status" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "update own form" ON "public"."onboarding_forms" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "update own status" ON "public"."onboarding_status" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."user_audit" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "write own form" ON "public"."onboarding_forms" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."prices";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."products";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_update_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_update_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_update_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."subscription_audit_snapshot"() TO "anon";
GRANT ALL ON FUNCTION "public"."subscription_audit_snapshot"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."subscription_audit_snapshot"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_audit_snapshot"() TO "anon";
GRANT ALL ON FUNCTION "public"."user_audit_snapshot"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_audit_snapshot"() TO "service_role";


















GRANT ALL ON TABLE "public"."activity" TO "anon";
GRANT ALL ON TABLE "public"."activity" TO "authenticated";
GRANT ALL ON TABLE "public"."activity" TO "service_role";



GRANT ALL ON SEQUENCE "public"."activity_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."activity_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."activity_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."ai_search_logs" TO "anon";
GRANT ALL ON TABLE "public"."ai_search_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_search_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ai_search_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ai_search_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ai_search_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."customer_review" TO "anon";
GRANT ALL ON TABLE "public"."customer_review" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_review" TO "service_role";



GRANT ALL ON SEQUENCE "public"."customer_review_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."customer_review_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."customer_review_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."faq" TO "anon";
GRANT ALL ON TABLE "public"."faq" TO "authenticated";
GRANT ALL ON TABLE "public"."faq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."faq_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."faq_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."faq_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."news" TO "anon";
GRANT ALL ON TABLE "public"."news" TO "authenticated";
GRANT ALL ON TABLE "public"."news" TO "service_role";



GRANT ALL ON SEQUENCE "public"."news_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."news_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."news_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."onboarding_forms" TO "anon";
GRANT ALL ON TABLE "public"."onboarding_forms" TO "authenticated";
GRANT ALL ON TABLE "public"."onboarding_forms" TO "service_role";



GRANT ALL ON TABLE "public"."onboarding_status" TO "anon";
GRANT ALL ON TABLE "public"."onboarding_status" TO "authenticated";
GRANT ALL ON TABLE "public"."onboarding_status" TO "service_role";



GRANT ALL ON TABLE "public"."prices" TO "anon";
GRANT ALL ON TABLE "public"."prices" TO "authenticated";
GRANT ALL ON TABLE "public"."prices" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."subscription_audit" TO "service_role";



GRANT ALL ON SEQUENCE "public"."subscription_audit_audit_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."user_audit" TO "anon";
GRANT ALL ON TABLE "public"."user_audit" TO "authenticated";
GRANT ALL ON TABLE "public"."user_audit" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_audit_audit_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_audit_audit_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_audit_audit_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

revoke delete on table "public"."subscription_audit" from "anon";

revoke insert on table "public"."subscription_audit" from "anon";

revoke references on table "public"."subscription_audit" from "anon";

revoke select on table "public"."subscription_audit" from "anon";

revoke trigger on table "public"."subscription_audit" from "anon";

revoke truncate on table "public"."subscription_audit" from "anon";

revoke update on table "public"."subscription_audit" from "anon";

revoke delete on table "public"."subscription_audit" from "authenticated";

revoke insert on table "public"."subscription_audit" from "authenticated";

revoke references on table "public"."subscription_audit" from "authenticated";

revoke select on table "public"."subscription_audit" from "authenticated";

revoke trigger on table "public"."subscription_audit" from "authenticated";

revoke truncate on table "public"."subscription_audit" from "authenticated";

revoke update on table "public"."subscription_audit" from "authenticated";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


