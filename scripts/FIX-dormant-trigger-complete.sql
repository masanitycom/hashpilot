-- ========================================
-- 解約（全NFT売却）時の自動フラグ更新トリガー修正
-- 全NFT売却時に以下を自動設定:
--   - is_active_investor = false
--   - has_approved_nft = false
--   - total_purchases = 0
-- 実行日: 2025-12-23
-- ========================================

-- 既存のトリガー関数を削除して再作成
DROP FUNCTION IF EXISTS update_user_active_status() CASCADE;

CREATE OR REPLACE FUNCTION update_user_active_status()
RETURNS TRIGGER AS $$
DECLARE
  v_remaining_nft_count INTEGER;
BEGIN
  -- そのユーザーの残りNFT数をチェック（buyback_date IS NULL = 未売却）
  SELECT COUNT(*) INTO v_remaining_nft_count
  FROM nft_master
  WHERE user_id = NEW.user_id
    AND buyback_date IS NULL;

  IF v_remaining_nft_count = 0 THEN
    -- 全NFT売却 → 解約済みに設定
    UPDATE users
    SET
      is_active_investor = false,
      has_approved_nft = false,
      total_purchases = 0,
      updated_at = NOW()
    WHERE user_id = NEW.user_id;

    -- affiliate_cycleも更新
    UPDATE affiliate_cycle
    SET
      manual_nft_count = 0,
      total_nft_count = 0,
      last_updated = NOW()
    WHERE user_id = NEW.user_id;

    RAISE NOTICE '✅ ユーザー % が解約済みになりました（全NFT売却）', NEW.user_id;
  ELSE
    -- まだNFTが残っている → アクティブ維持
    UPDATE users
    SET
      is_active_investor = true,
      updated_at = NOW()
    WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- トリガー再作成（NFT買い取り時に自動更新）
DROP TRIGGER IF EXISTS trigger_update_active_status ON nft_master;
CREATE TRIGGER trigger_update_active_status
AFTER UPDATE OF buyback_date ON nft_master
FOR EACH ROW
WHEN (NEW.buyback_date IS NOT NULL AND OLD.buyback_date IS NULL)
EXECUTE FUNCTION update_user_active_status();

-- 確認
SELECT '✅ 解約時自動フラグ更新トリガーを修正しました' as status;
SELECT '   - is_active_investor = false' as update1;
SELECT '   - has_approved_nft = false' as update2;
SELECT '   - total_purchases = 0' as update3;
SELECT '   - affiliate_cycle.manual_nft_count = 0' as update4;
SELECT '   - affiliate_cycle.total_nft_count = 0' as update5;
