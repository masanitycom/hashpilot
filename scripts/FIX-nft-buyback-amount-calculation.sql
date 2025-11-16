-- NFT買い取り金額計算の修正
-- 問題: マイナス収益の場合、÷2することで買い取り額が基本額を超える
-- 修正: マイナスの場合は÷2せずにそのまま引く

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
    -- マイナスの場合: 基本額 + 個人収益（そのまま）
    IF v_total_profit >= 0 THEN
        -- プラス収益: 半分を引く
        v_buyback_amount := v_base_value - (v_total_profit / 2);
    ELSE
        -- マイナス収益: そのまま足す（マイナスなので実質引く）
        v_buyback_amount := v_base_value + v_total_profit;
    END IF;

    -- 0以下にはならない
    IF v_buyback_amount < 0 THEN
        v_buyback_amount := 0;
    END IF;

    RETURN v_buyback_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 検証: 修正後の計算結果
-- ============================================

-- テストケース1: プラス収益の場合
-- 例: 手動NFT、収益 +$10
-- 期待値: $1,000 - ($10 ÷ 2) = $995

-- テストケース2: マイナス収益の場合
-- 例: 手動NFT、収益 -$4.90
-- 期待値: $1,000 + (-$4.90) = $995.10（$1,000を超えない）

SELECT '✅ NFT買い取り金額計算関数を修正しました' as status;
SELECT '📝 変更内容:' as info;
SELECT '  - プラス収益: 基本額 - (収益 ÷ 2)' as change1;
SELECT '  - マイナス収益: 基本額 + 収益（そのまま）' as change2;
