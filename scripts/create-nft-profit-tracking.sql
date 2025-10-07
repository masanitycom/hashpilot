-- NFTごとの利益追跡システム
-- 作成日: 2025年10月6日

-- ============================================
-- 1. NFTマスターテーブル（各NFTの基本情報）
-- ============================================
CREATE TABLE IF NOT EXISTS nft_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    nft_sequence INTEGER NOT NULL, -- ユーザー内でのNFT番号（1, 2, 3...）
    nft_type TEXT NOT NULL CHECK (nft_type IN ('manual', 'auto')), -- manual: 手動購入, auto: 自動購入/付与
    nft_value DECIMAL(10,2) NOT NULL, -- NFT価値（1100 or 1100）
    acquired_date DATE NOT NULL, -- 取得日
    buyback_date DATE, -- 買い取り日（NULL = 保有中）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- ユニーク制約: 同じユーザーの同じ番号のNFTは存在しない
    UNIQUE(user_id, nft_sequence)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_nft_master_user_id ON nft_master(user_id);
CREATE INDEX IF NOT EXISTS idx_nft_master_buyback ON nft_master(buyback_date) WHERE buyback_date IS NULL;

-- ============================================
-- 2. NFT日次利益テーブル
-- ============================================
CREATE TABLE IF NOT EXISTS nft_daily_profit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nft_id UUID NOT NULL REFERENCES nft_master(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    date DATE NOT NULL,
    daily_profit DECIMAL(10,3) NOT NULL, -- その日のNFT利益
    yield_rate DECIMAL(10,6), -- 日利率
    user_rate DECIMAL(10,6), -- ユーザー受取率
    base_amount DECIMAL(10,2), -- 運用額（1100固定）
    phase TEXT, -- USDT or HOLD
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- ユニーク制約: 同じNFTの同じ日のデータは1つだけ
    UNIQUE(nft_id, date)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_nft_daily_profit_nft_id ON nft_daily_profit(nft_id);
CREATE INDEX IF NOT EXISTS idx_nft_daily_profit_user_date ON nft_daily_profit(user_id, date);
CREATE INDEX IF NOT EXISTS idx_nft_daily_profit_date ON nft_daily_profit(date);

-- ============================================
-- 3. NFT紹介報酬テーブル（将来の拡張用）
-- ============================================
CREATE TABLE IF NOT EXISTS nft_referral_profit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nft_id UUID NOT NULL REFERENCES nft_master(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    date DATE NOT NULL,
    referral_profit DECIMAL(10,3) NOT NULL, -- その日の紹介報酬
    level1_profit DECIMAL(10,3) DEFAULT 0,
    level2_profit DECIMAL(10,3) DEFAULT 0,
    level3_profit DECIMAL(10,3) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(nft_id, date)
);

CREATE INDEX IF NOT EXISTS idx_nft_referral_profit_nft_id ON nft_referral_profit(nft_id);
CREATE INDEX IF NOT EXISTS idx_nft_referral_profit_user_date ON nft_referral_profit(user_id, date);

-- ============================================
-- 4. ビュー: NFTごとの累計利益
-- ============================================
CREATE OR REPLACE VIEW nft_total_profit AS
SELECT
    nm.id as nft_id,
    nm.user_id,
    nm.nft_sequence,
    nm.nft_type,
    nm.nft_value,
    nm.acquired_date,
    nm.buyback_date,
    COALESCE(SUM(ndp.daily_profit), 0) as total_personal_profit,
    COALESCE(SUM(nrp.referral_profit), 0) as total_referral_profit,
    -- 買い取り計算には個人収益のみを使用（紹介報酬は含めない）
    COALESCE(SUM(ndp.daily_profit), 0) as total_profit_for_buyback
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
LEFT JOIN nft_referral_profit nrp ON nm.id = nrp.nft_id
GROUP BY nm.id, nm.user_id, nm.nft_sequence, nm.nft_type, nm.nft_value, nm.acquired_date, nm.buyback_date;

-- ============================================
-- 5. 関数: NFT買い取り金額計算
-- ============================================
CREATE OR REPLACE FUNCTION calculate_nft_buyback_amount(p_nft_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_nft_type TEXT;
    v_base_value DECIMAL(10,2);
    v_total_profit DECIMAL(10,3);
    v_buyback_amount DECIMAL(10,2);
BEGIN
    -- NFT情報を取得（個人収益のみを使用）
    SELECT nft_type, nft_value, total_profit_for_buyback
    INTO v_nft_type, v_base_value, v_total_profit
    FROM nft_total_profit
    WHERE nft_id = p_nft_id;

    -- 買い取り基本額を決定
    IF v_nft_type = 'manual' THEN
        v_base_value := 1000; -- 手動購入NFTは1000ドル
    ELSE
        v_base_value := 500;  -- 自動購入/付与NFTは500ドル
    END IF;

    -- 買い取り額 = 基本額 - (個人収益累計 ÷ 2)
    -- 注: 紹介報酬は含めない
    v_buyback_amount := v_base_value - (v_total_profit / 2);

    -- 0以下にはならない
    IF v_buyback_amount < 0 THEN
        v_buyback_amount := 0;
    END IF;

    RETURN v_buyback_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. 関数: ユーザーの全NFT買い取り金額計算
-- ============================================
CREATE OR REPLACE FUNCTION calculate_user_all_nft_buyback(
    p_user_id TEXT,
    p_nft_type TEXT DEFAULT NULL -- 'manual', 'auto', or NULL for all
)
RETURNS TABLE(
    nft_count INTEGER,
    total_profit DECIMAL(10,3),
    total_buyback_amount DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INTEGER as nft_count,
        SUM(ntp.total_profit) as total_profit,
        SUM(calculate_nft_buyback_amount(ntp.nft_id)) as total_buyback_amount
    FROM nft_total_profit ntp
    WHERE ntp.user_id = p_user_id
        AND ntp.buyback_date IS NULL -- 保有中のみ
        AND (p_nft_type IS NULL OR ntp.nft_type = p_nft_type);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. コメント
-- ============================================
COMMENT ON TABLE nft_master IS 'NFTマスターテーブル - 各NFTの基本情報を管理';
COMMENT ON TABLE nft_daily_profit IS 'NFT日次利益テーブル - NFTごとの個人収益を記録';
COMMENT ON TABLE nft_referral_profit IS 'NFT紹介報酬テーブル - NFTごとの紹介報酬を記録';
COMMENT ON VIEW nft_total_profit IS 'NFTごとの累計利益ビュー';
COMMENT ON FUNCTION calculate_nft_buyback_amount IS 'NFT1個の買い取り金額を計算';
COMMENT ON FUNCTION calculate_user_all_nft_buyback IS 'ユーザーの全NFTまたは指定タイプのNFT買い取り金額を計算';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ NFT利益追跡システムのテーブルと関数を作成しました';
    RAISE NOTICE '📋 作成されたオブジェクト:';
    RAISE NOTICE '   - nft_master テーブル';
    RAISE NOTICE '   - nft_daily_profit テーブル';
    RAISE NOTICE '   - nft_referral_profit テーブル';
    RAISE NOTICE '   - nft_total_profit ビュー';
    RAISE NOTICE '   - calculate_nft_buyback_amount() 関数';
    RAISE NOTICE '   - calculate_user_all_nft_buyback() 関数';
END $$;
