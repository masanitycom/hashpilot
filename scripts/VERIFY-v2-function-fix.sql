-- ========================================
-- V2関数の修正が反映されたか確認
-- ========================================
-- 実行環境: テスト環境 Supabase SQL Editor
-- ========================================

-- 1. process_daily_yield_v2関数の定義を取得
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';

-- 2. nft_master テーブルのスキーマ確認
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default,
  character_maximum_length
FROM information_schema.columns
WHERE table_name = 'nft_master'
ORDER BY ordinal_position;

-- 3. nft_master テーブルの制約確認
SELECT
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'nft_master'
ORDER BY tc.constraint_type, kcu.column_name;

-- 4. 最近のnft_masterレコードを確認（nft_sequenceの値を見る）
SELECT
  user_id,
  nft_type,
  nft_sequence,
  acquired_date,
  created_at
FROM nft_master
ORDER BY created_at DESC
LIMIT 20;
