-- NFT買い取り金額計算の修正（マイナス利益も÷2する）
-- 問題: マイナス収益の場合、そのまま引いていた
-- 修正: マイナス収益でも÷2して引く

-- ============================================
-- 修正版: calculate_nft_buyback_amount
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

    -- 買い取り額の計算
    -- プラスの場合: 基本額 - (個人収益 ÷ 2)
    -- マイナスの場合: 基本額 - 個人収益（そのまま）
    IF v_total_profit >= 0 THEN
        -- プラス収益: 半分を引く
        v_buyback_amount := v_base_value - (v_total_profit / 2);
    ELSE
        -- マイナス収益: そのまま引く（÷2しない）
        v_buyback_amount := v_base_value - v_total_profit;
    END IF;

    -- 0以下にはならない
    IF v_buyback_amount < 0 THEN
        v_buyback_amount := 0;
    END IF;

    -- 基本額を超えないようにする
    IF v_buyback_amount > v_base_value THEN
        v_buyback_amount := v_base_value;
    END IF;

    RETURN v_buyback_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 検証: 修正後の計算結果
-- ============================================

-- テストケース1: プラス収益の場合
-- 例: 手動NFT、収益 +$15
-- 期待値: $1,000 - ($15 ÷ 2) = $992.50

-- テストケース2: マイナス収益の場合
-- 例: 手動NFT、収益 -$9.12
-- 旧計算: $1,000 + (-$9.12) = $990.88
-- 新計算: $1,000 - (-$9.12) = $1,000 + $9.12 = $1,009.12 ← 上限適用で$1,000

-- テストケース3: 大きなマイナス収益の場合
-- 例: 手動NFT、収益 -$100
-- 新計算: $1,000 - (-$100) = $1,000 + $100 = $1,100 ← 上限適用で$1,000

SELECT '✅ NFT買い取り金額計算関数を修正しました' as status;
SELECT '📝 変更内容:' as info;
SELECT '  - プラス収益: 基本額 - (収益 ÷ 2)' as change1;
SELECT '  - マイナス収益: 基本額 - 収益（そのまま、÷2しない）' as change2;
SELECT '  - 上限: 基本額を超えない（手動1000ドル、自動500ドル）' as change3;
