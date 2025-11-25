-- ユーザー7A9637のサイクル状況の問題を調査

-- 1. affiliate_cycleの状態
SELECT
    user_id,
    cum_usdt as '紹介報酬累積（サイクル計算に使用）',
    available_usdt as '受取可能額',
    phase as 'フェーズ',
    auto_nft_count as '自動NFT数',
    manual_nft_count as '手動NFT数',
    total_nft_count as '総NFT数'
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 2. 今月の個人利益（nft_daily_profit）
SELECT
    COUNT(*) as 'レコード数',
    SUM(daily_profit) as '今月の個人利益合計'
FROM nft_daily_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30';

-- 3. 全期間の紹介報酬（user_referral_profit）
SELECT
    COUNT(*) as 'レコード数',
    SUM(profit_amount) as '全期間の紹介報酬合計'
FROM user_referral_profit
WHERE user_id = '7A9637';

-- 4. 今月の紹介報酬（user_referral_profit）
SELECT
    COUNT(*) as 'レコード数',
    SUM(profit_amount) as '今月の紹介報酬合計'
FROM user_referral_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30';

-- 予想される結果:
-- cum_usdt = $54.47（全期間の紹介報酬累積）
-- 今月の個人利益 = $15.000
-- 今月の紹介報酬 = まだ計算されていない（月末集計のため）

-- 問題:
-- NFTサイクルは cum_usdt（紹介報酬のみ）で計算
-- 個人利益は含まれない
-- $54.47 = 運用開始からの紹介報酬累積
