-- 休眠ユーザーシステムと会社ボーナス実装
-- 作成日: 2025年10月7日
--
-- 全NFT売却したユーザーを「休眠」扱いにし、
-- その期間の紹介報酬を会社アカウント（7A9637）が受け取る

-- ============================================
-- 1. is_active_investor フラグを追加
-- ============================================

-- usersテーブルに投資家アクティブフラグを追加
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_active_investor BOOLEAN DEFAULT FALSE;

-- 既存ユーザーのフラグを更新（NFT保有者はアクティブ）
UPDATE users
SET is_active_investor = (
    SELECT COALESCE(total_nft_count > 0, FALSE)
    FROM affiliate_cycle
    WHERE affiliate_cycle.user_id = users.user_id
);

-- インデックス追加
CREATE INDEX IF NOT EXISTS idx_users_active_investor
ON users(is_active_investor)
WHERE is_active_investor = TRUE;

-- ============================================
-- 2. 会社ボーナステーブル作成
-- ============================================

CREATE TABLE IF NOT EXISTS company_bonus_from_dormant (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    dormant_user_id TEXT NOT NULL,      -- 休眠中のユーザーID
    dormant_user_email TEXT,             -- 休眠ユーザーのメール（参照用）
    child_user_id TEXT NOT NULL,         -- 報酬発生元のユーザーID
    referral_level INTEGER NOT NULL,     -- Level 1, 2, 3
    original_amount DECIMAL(10,3) NOT NULL,  -- 本来休眠ユーザーが受け取るはずだった金額
    company_user_id TEXT DEFAULT '7A9637',   -- 会社メインアカウント
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CHECK (referral_level IN (1, 2, 3))
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_company_bonus_date ON company_bonus_from_dormant(date);
CREATE INDEX IF NOT EXISTS idx_company_bonus_dormant_user ON company_bonus_from_dormant(dormant_user_id);
CREATE INDEX IF NOT EXISTS idx_company_bonus_child_user ON company_bonus_from_dormant(child_user_id);

-- ============================================
-- 3. NFT買い取り処理でis_active_investorを自動更新
-- ============================================

-- process_buyback_request関数を更新（全NFT売却時にフラグ更新）
CREATE OR REPLACE FUNCTION update_user_active_status()
RETURNS TRIGGER AS $$
BEGIN
    -- nft_masterのbuyback_dateが更新されたとき
    -- そのユーザーの保有NFT数をチェック
    UPDATE users
    SET is_active_investor = (
        SELECT COUNT(*) > 0
        FROM nft_master
        WHERE user_id = NEW.user_id
          AND buyback_date IS NULL
    )
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- トリガー作成（NFT買い取り時に自動更新）
DROP TRIGGER IF EXISTS trigger_update_active_status ON nft_master;
CREATE TRIGGER trigger_update_active_status
AFTER UPDATE OF buyback_date ON nft_master
FOR EACH ROW
EXECUTE FUNCTION update_user_active_status();

-- ============================================
-- 4. NFT購入時にis_active_investorを自動更新
-- ============================================

CREATE OR REPLACE FUNCTION set_user_active_on_nft_purchase()
RETURNS TRIGGER AS $$
BEGIN
    -- 新しいNFTが作成されたとき、そのユーザーをアクティブに
    UPDATE users
    SET is_active_investor = TRUE
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- トリガー作成（NFT作成時に自動更新）
DROP TRIGGER IF EXISTS trigger_set_active_on_purchase ON nft_master;
CREATE TRIGGER trigger_set_active_on_purchase
AFTER INSERT ON nft_master
FOR EACH ROW
EXECUTE FUNCTION set_user_active_on_nft_purchase();

-- ============================================
-- 5. 会社ボーナス集計ビュー
-- ============================================

CREATE OR REPLACE VIEW company_bonus_summary AS
SELECT
    date,
    COUNT(*) as bonus_count,
    SUM(original_amount) as total_bonus,
    COUNT(DISTINCT dormant_user_id) as dormant_users_count,
    COUNT(DISTINCT child_user_id) as active_children_count
FROM company_bonus_from_dormant
GROUP BY date
ORDER BY date DESC;

-- ============================================
-- 6. 休眠ユーザー一覧ビュー
-- ============================================

CREATE OR REPLACE VIEW dormant_users_list AS
SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.total_nft_count as current_nft_count,
    ac.cycle_number,
    (
        SELECT COUNT(*)
        FROM users child
        WHERE child.referrer_user_id = u.user_id
          AND child.is_active_investor = TRUE
    ) as active_children_count,
    (
        SELECT SUM(original_amount)
        FROM company_bonus_from_dormant
        WHERE dormant_user_id = u.user_id
          AND date >= CURRENT_DATE - INTERVAL '30 days'
    ) as company_bonus_last_30_days
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.is_active_investor = FALSE
  AND u.user_id != '7A9637'  -- 会社アカウントは除外
ORDER BY company_bonus_last_30_days DESC NULLS LAST;

-- ============================================
-- 7. コメント
-- ============================================

COMMENT ON COLUMN users.is_active_investor IS 'NFT保有中=TRUE、全売却=FALSE';
COMMENT ON TABLE company_bonus_from_dormant IS '休眠ユーザーの紹介報酬を会社が受け取った記録';
COMMENT ON VIEW company_bonus_summary IS '会社ボーナスの日次サマリー';
COMMENT ON VIEW dormant_users_list IS '休眠ユーザー一覧と会社ボーナス貢献度';

-- ============================================
-- 8. 既存データの整合性チェック
-- ============================================

DO $$
DECLARE
    v_total_users INTEGER;
    v_active_users INTEGER;
    v_dormant_users INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_users FROM users WHERE user_id != '7A9637';
    SELECT COUNT(*) INTO v_active_users FROM users WHERE is_active_investor = TRUE;
    SELECT COUNT(*) INTO v_dormant_users FROM users WHERE is_active_investor = FALSE AND user_id != '7A9637';

    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ 休眠ユーザーシステムをセットアップしました';
    RAISE NOTICE '============================================';
    RAISE NOTICE '📊 ユーザー統計:';
    RAISE NOTICE '   - 総ユーザー数: %', v_total_users;
    RAISE NOTICE '   - アクティブ投資家: %', v_active_users;
    RAISE NOTICE '   - 休眠ユーザー: %', v_dormant_users;
    RAISE NOTICE '';
    RAISE NOTICE '📋 作成されたオブジェクト:';
    RAISE NOTICE '   - users.is_active_investor カラム';
    RAISE NOTICE '   - company_bonus_from_dormant テーブル';
    RAISE NOTICE '   - company_bonus_summary ビュー';
    RAISE NOTICE '   - dormant_users_list ビュー';
    RAISE NOTICE '   - 自動更新トリガー (買い取り時/購入時)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  次のステップ:';
    RAISE NOTICE '   - 紹介報酬計算ロジックの更新が必要です';
    RAISE NOTICE '   - scripts/update-referral-calculation-for-dormant.sql を実行してください';
    RAISE NOTICE '============================================';
END $$;
