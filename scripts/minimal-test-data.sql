-- ============================================================
-- 最小限のテストデータ（手動実行可能）
-- ============================================================
-- テスト環境: https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/sql
-- ============================================================

-- RLSを一時的に無効化
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- 管理者データ
-- ============================================================

INSERT INTO admins (id, user_id, email, role, created_at, is_active) VALUES
('381f27ea-187a-4e53-bfbc-e160feb0630f', 'ADMIN3', 'masataka.tak@gmail.com', 'super_admin', '2025-06-17 14:21:23.84339+00', true),
('13716eac-5520-4341-bbd8-2d2dbcf4550e', 'ADMIN2', 'basarasystems@gmail.com', 'admin', '2025-06-17 12:44:55.331184+00', true),
('c1afe8d9-5f3d-4cc6-9210-709082a5dcfa', '14375a3b-1235-4721-92a7-c1df33b22edd', 'support@dshsupport.biz', 'admin', '2025-07-11 06:42:10.726502+00', true);

-- ============================================================
-- ペガサスユーザー2名（本番データから抽出）
-- ============================================================

-- ペガサスユーザー1: 0E0171
INSERT INTO users (id, user_id, email, full_name, referrer_user_id, created_at, updated_at, is_active, total_purchases, total_referral_earnings, has_approved_nft, first_nft_approved_at, coinw_uid, nft_receive_address, is_pegasus_exchange, pegasus_exchange_date, pegasus_withdrawal_unlock_date, operation_start_date) VALUES
('89efa936-f2d5-412e-b4f1-af0c9c36cd3a', '0E0171', 'yumie4300@gmail.com', NULL, '1A1610', '2025-08-19 04:34:55.586374+00', '2025-11-04 06:19:37.669+00', true, 2200.00, 0.00, true, NULL, '26187034', '0x739ecb5D89FC1E9780A322a65B1B61e097ba6e0a', true, NULL, NULL, '2025-09-01');

-- ペガサスユーザー2: ECC482
INSERT INTO users (id, user_id, email, full_name, referrer_user_id, created_at, updated_at, is_active, total_purchases, total_referral_earnings, has_approved_nft, coinw_uid, is_pegasus_exchange, operation_start_date) VALUES
('47c9802b-fa8d-4324-8c89-372bf8338f76', 'ECC482', 'tatsurou113@gmail.com', NULL, '917123', '2025-10-27 04:55:32.996348+00', '2025-11-04 06:26:54.886+00', true, 1100.00, 0.00, false, '26391495', true, '2025-11-15');

-- 通常ユーザー1名（比較用）
INSERT INTO users (id, user_id, email, full_name, referrer_user_id, created_at, updated_at, is_active, total_purchases, has_approved_nft, coinw_uid, is_pegasus_exchange, operation_start_date) VALUES
('6e26e691-f7a4-4afb-837c-c958c297382d', '07712F', 'math.kazino@gmail.com', NULL, '1BAA30', '2025-07-04 06:44:05.315295+00', '2025-10-09 04:20:38.809869+00', true, 1100.00, true, '3785072', false, '2025-07-15');

-- ============================================================
-- affiliate_cycleデータ
-- ============================================================

INSERT INTO affiliate_cycle (user_id, cycle_number, phase, cum_usdt, available_usdt, total_nft_count, manual_nft_count, auto_nft_count) VALUES
('0E0171', 1, 'USDT', 0, 0, 2, 2, 0),
('ECC482', 1, 'USDT', 0, 0, 1, 1, 0),
('07712F', 1, 'USDT', 0, 0, 1, 1, 0);

-- ============================================================
-- purchasesデータ
-- ============================================================

INSERT INTO purchases (id, user_id, nft_quantity, amount_usd, admin_approved, admin_approved_at, created_at) VALUES
(gen_random_uuid(), '0E0171', 2, 2200.00, true, '2025-08-19 05:00:00+00', '2025-08-19 04:34:55+00'),
(gen_random_uuid(), 'ECC482', 1, 1100.00, true, '2025-10-27 05:00:00+00', '2025-10-27 04:55:32+00'),
(gen_random_uuid(), '07712F', 1, 1100.00, true, '2025-07-04 07:00:00+00', '2025-07-04 06:44:05+00');

-- ============================================================
-- RLSを再有効化
-- ============================================================

ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 確認
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM admins) as admins,
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM affiliate_cycle) as cycles,
    (SELECT COUNT(*) FROM purchases) as purchases,
    (SELECT COUNT(*) FROM users WHERE is_pegasus_exchange = true) as pegasus_users;
