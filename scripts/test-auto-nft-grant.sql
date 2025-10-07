-- 自動NFT付与テスト用スクリプト
-- ユーザー: 7A9637
-- 作成日: 2025年10月7日

-- ============================================
-- ステップ1: 現在の状態をバックアップ（実行済み）
-- ============================================

-- 📝 バックアップデータ（2025-10-07時点）:
-- user_id: 7A9637
-- cycle_number: 1
-- phase: USDT
-- cum_usdt: 37.80
-- available_usdt: 36.65
-- total_nft_count: 1
-- auto_nft_count: 0
-- manual_nft_count: 1
-- next_action: usdt

-- 現在の affiliate_cycle 状態を確認
SELECT
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    next_action
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 現在の nft_master を確認
SELECT
    id,
    user_id,
    nft_sequence,
    nft_type,
    granted_at,
    buyback_date
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY nft_sequence;

-- ============================================
-- ステップ2: テスト実行 - cum_usdtを1150に設定
-- ============================================

-- cum_usdtを1150に設定（1100超え → 自動NFT付与トリガー）
UPDATE affiliate_cycle
SET
    cum_usdt = 1150.00,
    next_action = 'nft'  -- NFT付与アクション
WHERE user_id = '7A9637';

-- 確認
SELECT
    user_id,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    auto_nft_count,
    next_action
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- ============================================
-- ステップ3: 結果確認
-- ============================================

-- affiliate_cycle の変化を確認
-- 期待される結果:
-- - auto_nft_count が 0 → 1 に増加
-- - total_nft_count が 1 → 2 に増加
-- - cum_usdt が 1150 → 50 にリセット（1100引かれる）
-- - phase が 'NFT' に変わっているかも
SELECT
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    next_action
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- nft_master に新しいNFTが追加されたか確認
SELECT
    id,
    user_id,
    nft_sequence,
    nft_type,
    granted_at,
    buyback_date
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY nft_sequence DESC
LIMIT 5;

-- ============================================
-- ステップ4: 元に戻す（バックアップ値を使用）
-- ============================================

-- 元の状態に戻す
UPDATE affiliate_cycle
SET
    cycle_number = 1,
    phase = 'USDT',
    cum_usdt = 37.80,
    available_usdt = 36.65,
    total_nft_count = 1,
    manual_nft_count = 1,
    auto_nft_count = 0,
    next_action = 'usdt'
WHERE user_id = '7A9637';

-- テストで追加されたNFTを削除（もしあれば）
DELETE FROM nft_master
WHERE user_id = '7A9637'
  AND nft_type = 'auto'
  AND granted_at > '2025-10-07 00:00:00';  -- 今日以降に追加されたもの

-- ============================================
-- 最終確認
-- ============================================

-- 元に戻ったか確認
SELECT
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    auto_nft_count,
    manual_nft_count,
    next_action
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- NFT数を確認
SELECT COUNT(*) as nft_count, nft_type
FROM nft_master
WHERE user_id = '7A9637'
  AND buyback_date IS NULL
GROUP BY nft_type;

-- 期待される結果:
-- auto_nft_count: 0
-- manual_nft_count: 1
-- total_nft_count: 1
-- cum_usdt: 37.80
-- phase: USDT
