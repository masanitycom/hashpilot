CREATE TABLE IF NOT EXISTS "public"."nft_master" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "nft_sequence" integer NOT NULL,
    "nft_type" "text" NOT NULL,
    "nft_value" numeric(10,2) NOT NULL,
    "acquired_date" "date" NOT NULL,
    "buyback_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "nft_master_nft_type_check" CHECK (("nft_type" = ANY (ARRAY['manual'::"text", 'auto'::"text"])))
);
CREATE TABLE IF NOT EXISTS "public"."purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" character varying(6),
    "nft_quantity" integer NOT NULL,
    "amount_usd" numeric(10,2) NOT NULL,
    "usdt_address_bep20" character varying(255),
    "usdt_address_trc20" character varying(255),
    "payment_status" character varying(20) DEFAULT 'pending'::character varying,
    "nft_sent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "confirmed_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "admin_approved" boolean DEFAULT false,
    "admin_approved_at" timestamp with time zone,
    "admin_approved_by" "text",
    "payment_proof_url" "text",
    "user_notes" "text",
    "admin_notes" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_auto_purchase" boolean DEFAULT false,
    "cycle_number_at_purchase" integer
);
CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "user_id" character varying(6) NOT NULL,
    "email" character varying(255) NOT NULL,
    "full_name" character varying(255),
    "referrer_user_id" character varying(6),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT false,
    "total_purchases" numeric(10,2) DEFAULT 0,
    "total_referral_earnings" numeric(10,2) DEFAULT 0,
    "has_approved_nft" boolean DEFAULT false,
    "first_nft_approved_at" timestamp with time zone,
    "coinw_uid" "text",
    "reward_address_bep20" "text",
    "nft_address" "text",
    "nft_sent" boolean DEFAULT false,
    "nft_sent_at" timestamp with time zone,
    "nft_sent_by" "text",
    "nft_receive_address" "text",
    "coinw_uid_for_withdrawal" "text",
    "nft_distributed" boolean DEFAULT false,
    "nft_distributed_at" timestamp with time zone,
    "nft_distributed_by" "text",
    "nft_distribution_notes" "text",
    "is_pegasus_exchange" boolean DEFAULT false,
    "pegasus_exchange_date" "date",
    "pegasus_withdrawal_unlock_date" "date",
    "is_active_investor" boolean DEFAULT false,
    "operation_start_date" "date",
    "is_operation_only" boolean DEFAULT false,
    "email_blacklisted" boolean DEFAULT false
);
CREATE TABLE IF NOT EXISTS "public"."admins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text",
    "email" "text" NOT NULL,
    "role" "text" DEFAULT 'admin'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true
);
CREATE TABLE IF NOT EXISTS "public"."affiliate_cycle" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "cycle_number" integer DEFAULT 1 NOT NULL,
    "phase" character varying(10) DEFAULT 'USDT'::character varying NOT NULL,
    "cum_usdt" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "available_usdt" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "total_nft_count" integer DEFAULT 0 NOT NULL,
    "auto_nft_count" integer DEFAULT 0 NOT NULL,
    "manual_nft_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "cycle_start_date" timestamp with time zone,
    "last_updated" timestamp with time zone DEFAULT "now"(),
    "next_action" "text" DEFAULT 'usdt'::"text",
    CONSTRAINT "affiliate_cycle_phase_check" CHECK ((("phase")::"text" = ANY ((ARRAY['USDT'::character varying, 'HOLD'::character varying])::"text"[])))
);
CREATE TABLE IF NOT EXISTS "public"."affiliate_reward" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "referral_user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "level" integer NOT NULL,
    "reward_rate" numeric(4,3) NOT NULL,
    "base_profit" numeric(10,2) NOT NULL,
    "reward_amount" numeric(10,2) NOT NULL,
    "phase" character varying(10) NOT NULL,
    "is_paid" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "affiliate_reward_level_check" CHECK (("level" = ANY (ARRAY[1, 2, 3]))),
    CONSTRAINT "affiliate_reward_phase_check" CHECK ((("phase")::"text" = ANY ((ARRAY['USDT'::character varying, 'HOLD'::character varying])::"text"[])))
);
CREATE TABLE IF NOT EXISTS "public"."backup_auth_users_metadata_20250706" (
    "id" "uuid",
    "email" character varying(255),
    "raw_user_meta_data" "jsonb",
    "created_at" timestamp with time zone,
    "email_confirmed_at" timestamp with time zone,
    "last_sign_in_at" timestamp with time zone
);
CREATE TABLE IF NOT EXISTS "public"."backup_problem_users_20250706" (
    "id" "uuid",
    "user_id" character varying(6),
    "email" character varying(255),
    "referrer_user_id" character varying(6),
    "coinw_uid" character varying(255),
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "raw_user_meta_data" "jsonb",
    "issue_type" "text"
);
CREATE TABLE IF NOT EXISTS "public"."backup_purchases_20250706" (
    "id" "uuid",
    "user_id" character varying(6),
    "nft_quantity" integer,
    "amount_usd" numeric(10,2),
    "usdt_address_bep20" character varying(255),
    "usdt_address_trc20" character varying(255),
    "payment_status" character varying(20),
    "nft_sent" boolean,
    "created_at" timestamp with time zone,
    "confirmed_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "admin_approved" boolean,
    "admin_approved_at" timestamp with time zone,
    "admin_approved_by" "text",
    "payment_proof_url" "text",
    "user_notes" "text",
    "admin_notes" "text"
);
CREATE TABLE IF NOT EXISTS "public"."backup_users_20250706" (
    "id" "uuid",
    "user_id" character varying(6),
    "email" character varying(255),
    "full_name" character varying(255),
    "referrer_user_id" character varying(6),
    "coinw_uid" character varying(255),
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "is_active" boolean,
    "has_approved_nft" boolean,
    "total_purchases" numeric(10,2),
    "total_referral_earnings" numeric(10,2)
);
CREATE TABLE IF NOT EXISTS "public"."buyback_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "email" "text",
    "request_date" timestamp with time zone DEFAULT "now"(),
    "manual_nft_count" integer DEFAULT 0 NOT NULL,
    "auto_nft_count" integer DEFAULT 0 NOT NULL,
    "total_nft_count" integer DEFAULT 0 NOT NULL,
    "manual_buyback_amount" numeric(10,2) DEFAULT 0 NOT NULL,
    "auto_buyback_amount" numeric(10,2) DEFAULT 0 NOT NULL,
    "total_buyback_amount" numeric(10,2) DEFAULT 0 NOT NULL,
    "wallet_address" "text",
    "wallet_type" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "processed_by" "text",
    "processed_at" timestamp with time zone,
    "transaction_hash" "text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "buyback_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'processing'::"text", 'completed'::"text", 'cancelled'::"text", 'rejected'::"text"]))),
    CONSTRAINT "buyback_requests_wallet_type_check" CHECK (("wallet_type" = ANY (ARRAY['USDT-BEP20'::"text", 'CoinW'::"text"])))
);
CREATE TABLE IF NOT EXISTS "public"."company_bonus_from_dormant" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "date" "date" NOT NULL,
    "dormant_user_id" "text" NOT NULL,
    "dormant_user_email" "text",
    "child_user_id" "text" NOT NULL,
    "referral_level" integer NOT NULL,
    "original_amount" numeric(10,3) NOT NULL,
    "company_user_id" "text" DEFAULT '7A9637'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "company_bonus_from_dormant_referral_level_check" CHECK (("referral_level" = ANY (ARRAY[1, 2, 3])))
);
CREATE TABLE IF NOT EXISTS "public"."user_referral_profit" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "referral_level" integer NOT NULL,
    "child_user_id" "text" NOT NULL,
    "profit_amount" numeric(10,3) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_referral_profit_referral_level_check" CHECK (("referral_level" = ANY (ARRAY[1, 2, 3])))
);
CREATE TABLE IF NOT EXISTS "public"."company_daily_profit" (
    "id" integer NOT NULL,
    "date" "date" NOT NULL,
    "total_user_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_company_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "margin_rate" numeric(3,2) NOT NULL,
    "total_base_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "user_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."daily_yield_log" (
    "id" integer NOT NULL,
    "date" "date" NOT NULL,
    "yield_rate" numeric(10,6) NOT NULL,
    "margin_rate" numeric(10,4) NOT NULL,
    "user_rate" numeric(10,6) NOT NULL,
    "is_month_end" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid"
);
CREATE TABLE IF NOT EXISTS "public"."email_recipients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "email_id" "uuid" NOT NULL,
    "user_id" "text" NOT NULL,
    "to_email" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "sent_at" timestamp with time zone,
    "read_at" timestamp with time zone,
    "error_message" "text",
    "resend_email_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "email_recipients_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text", 'read'::"text"]))),
    CONSTRAINT "valid_status" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text", 'read'::"text"])))
);
CREATE TABLE IF NOT EXISTS "public"."email_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "subject" "text" NOT NULL,
    "body" "text" NOT NULL,
    "description" "text",
    "created_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."monthly_reward_tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" character varying(6) NOT NULL,
    "year" integer NOT NULL,
    "month" integer NOT NULL,
    "is_completed" boolean DEFAULT false,
    "completed_at" timestamp without time zone,
    "questions_answered" integer DEFAULT 0,
    "answers" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."monthly_withdrawals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "email" "text" NOT NULL,
    "withdrawal_month" "date" NOT NULL,
    "level1_reward" numeric(10,3) DEFAULT 0,
    "level2_reward" numeric(10,3) DEFAULT 0,
    "level3_reward" numeric(10,3) DEFAULT 0,
    "level4_plus_reward" numeric(10,3) DEFAULT 0,
    "daily_profit" numeric(10,3) DEFAULT 0,
    "total_amount" numeric(10,3) NOT NULL,
    "withdrawal_address" "text",
    "withdrawal_method" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "processed_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "notes" "text",
    "task_completed" boolean DEFAULT false,
    "task_completed_at" timestamp without time zone
);
CREATE TABLE IF NOT EXISTS "public"."nft_daily_profit" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nft_id" "uuid" NOT NULL,
    "user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "daily_profit" numeric(10,3) NOT NULL,
    "yield_rate" numeric(10,6),
    "user_rate" numeric(10,6),
    "base_amount" numeric(10,2),
    "phase" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."nft_holdings" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "nft_type" character varying(20) NOT NULL,
    "purchase_amount" numeric(10,2) DEFAULT 1100.00 NOT NULL,
    "purchase_date" timestamp with time zone DEFAULT "now"(),
    "cycle_number" integer DEFAULT 1 NOT NULL,
    "transaction_id" character varying(100),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "original_purchase_id" "uuid",
    CONSTRAINT "nft_holdings_nft_type_check" CHECK ((("nft_type")::"text" = ANY ((ARRAY['manual_purchase'::character varying, 'auto_buy'::character varying])::"text"[])))
);
CREATE TABLE IF NOT EXISTS "public"."nft_referral_profit" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nft_id" "uuid" NOT NULL,
    "user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "referral_profit" numeric(10,3) NOT NULL,
    "level1_profit" numeric(10,3) DEFAULT 0,
    "level2_profit" numeric(10,3) DEFAULT 0,
    "level3_profit" numeric(10,3) DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_id" "uuid",
    "transaction_hash" character varying(255),
    "network" character varying(10),
    "amount" numeric(10,2),
    "confirmed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."pre_restore_users_20250706" (
    "id" "uuid",
    "user_id" character varying(6),
    "email" character varying(255),
    "full_name" character varying(255),
    "referrer_user_id" character varying(6),
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "is_active" boolean,
    "total_purchases" numeric(10,2),
    "total_referral_earnings" numeric(10,2),
    "has_approved_nft" boolean,
    "first_nft_approved_at" timestamp with time zone,
    "coinw_uid" character varying(255)
);
CREATE TABLE IF NOT EXISTS "public"."referral_commissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referrer_user_id" character varying(6),
    "referred_user_id" character varying(6),
    "purchase_id" "uuid",
    "commission_amount" numeric(10,2),
    "commission_rate" numeric(5,2),
    "level" integer DEFAULT 1,
    "status" character varying(20) DEFAULT 'pending'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."referrals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referrer_user_id" character varying(6),
    "referred_user_id" character varying(6),
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."reward_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question" "text" NOT NULL,
    "option_a" "text" NOT NULL,
    "option_b" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "created_by" "uuid"
);
CREATE TABLE IF NOT EXISTS "public"."system_config" (
    "key" character varying(50) NOT NULL,
    "value" "text" NOT NULL,
    "description" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "updated_by" "uuid"
);
CREATE TABLE IF NOT EXISTS "public"."system_emails" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subject" "text" NOT NULL,
    "body" "text" NOT NULL,
    "from_name" "text" DEFAULT 'HASHPILOT'::"text",
    "from_email" "text" DEFAULT 'noreply@hashpilot.biz'::"text",
    "email_type" "text" NOT NULL,
    "sent_by" "text" NOT NULL,
    "target_group" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "system_emails_email_type_check" CHECK (("email_type" = ANY (ARRAY['broadcast'::"text", 'individual'::"text"]))),
    CONSTRAINT "valid_email_type" CHECK (("email_type" = ANY (ARRAY['broadcast'::"text", 'individual'::"text"])))
);
CREATE TABLE IF NOT EXISTS "public"."system_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "log_type" "text" NOT NULL,
    "operation" "text",
    "user_id" "text",
    "details" "jsonb",
    "message" "text",
    "ip_address" "text",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."system_settings" (
    "id" integer DEFAULT 1 NOT NULL,
    "usdt_address_bep20" "text",
    "usdt_address_trc20" "text",
    "nft_price" numeric(10,2) DEFAULT 1100.00,
    "maintenance_mode" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "single_row" CHECK (("id" = 1))
);
CREATE TABLE IF NOT EXISTS "public"."test_affiliate_reward" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "referral_user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "level" integer NOT NULL,
    "reward_rate" numeric(4,3) NOT NULL,
    "base_profit" numeric(10,2) NOT NULL,
    "reward_amount" numeric(10,2) NOT NULL,
    "phase" character varying(10) NOT NULL,
    "is_paid" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "test_mode" boolean DEFAULT true,
    CONSTRAINT "test_affiliate_reward_level_check" CHECK (("level" = ANY (ARRAY[1, 2, 3]))),
    CONSTRAINT "test_affiliate_reward_phase_check" CHECK ((("phase")::"text" = ANY ((ARRAY['USDT'::character varying, 'HOLD'::character varying])::"text"[])))
);
CREATE TABLE IF NOT EXISTS "public"."test_company_daily_profit" (
    "id" integer NOT NULL,
    "date" "date" NOT NULL,
    "total_user_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_company_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "margin_rate" numeric(3,2) NOT NULL,
    "total_base_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "user_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "test_mode" boolean DEFAULT true
);
CREATE TABLE IF NOT EXISTS "public"."test_daily_yield_log" (
    "id" integer NOT NULL,
    "date" "date" NOT NULL,
    "yield_rate" numeric(5,4) NOT NULL,
    "margin_rate" numeric(3,2) NOT NULL,
    "user_rate" numeric(5,4) NOT NULL,
    "is_month_end" boolean DEFAULT false,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "test_mode" boolean DEFAULT true
);
CREATE TABLE IF NOT EXISTS "public"."test_user_daily_profit" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "yield_rate" numeric(5,4) NOT NULL,
    "user_rate" numeric(5,4) NOT NULL,
    "base_amount" numeric(10,2) NOT NULL,
    "daily_profit" numeric(10,2) NOT NULL,
    "phase" character varying(10) NOT NULL,
    "is_paid" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "test_mode" boolean DEFAULT true,
    CONSTRAINT "test_user_daily_profit_phase_check" CHECK ((("phase")::"text" = ANY ((ARRAY['USDT'::character varying, 'HOLD'::character varying])::"text"[])))
);
CREATE TABLE IF NOT EXISTS "public"."user_daily_profit_backup" (
    "id" integer,
    "user_id" "text",
    "date" "date",
    "yield_rate" numeric(5,4),
    "user_rate" numeric(5,4),
    "base_amount" numeric(10,2),
    "daily_profit" numeric(10,2),
    "phase" character varying(10),
    "is_paid" boolean,
    "created_at" timestamp with time zone,
    "personal_profit" numeric,
    "referral_profit" numeric,
    "updated_at" timestamp without time zone
);
CREATE TABLE IF NOT EXISTS "public"."user_deletion_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deleted_user_id" "text" NOT NULL,
    "deleted_email" "text" NOT NULL,
    "admin_email" "text" NOT NULL,
    "deletion_reason" "text",
    "deleted_data" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."user_monthly_rewards" (
    "id" integer NOT NULL,
    "user_id" "text" NOT NULL,
    "year" integer NOT NULL,
    "month" integer NOT NULL,
    "total_daily_profit" numeric(10,2) DEFAULT 0 NOT NULL,
    "total_referral_rewards" numeric(10,2) DEFAULT 0 NOT NULL,
    "total_rewards" numeric(10,2) DEFAULT 0 NOT NULL,
    "is_paid" boolean DEFAULT false,
    "paid_at" timestamp with time zone,
    "paid_by" "text",
    "payment_transaction_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."user_withdrawal_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "withdrawal_address" "text",
    "coinw_uid" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);
