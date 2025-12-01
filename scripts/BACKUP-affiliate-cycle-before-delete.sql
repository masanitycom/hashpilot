-- ========================================
-- affiliate_cycleテーブルのバックアップ
-- ========================================

SELECT
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    auto_nft_count,
    manual_nft_count,
    updated_at
FROM affiliate_cycle
ORDER BY user_id;
