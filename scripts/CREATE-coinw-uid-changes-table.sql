-- ========================================
-- CoinW UID変更申請テーブル作成
-- ユーザーがCoinW UIDを変更申請 → 管理者承認で有効化
-- 承認時にchannel_linked_confirmed = trueに自動設定
-- ========================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS coinw_uid_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id VARCHAR(6) NOT NULL REFERENCES users(user_id),
  old_coinw_uid VARCHAR(255),
  new_coinw_uid VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by VARCHAR(255),
  rejection_reason TEXT
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_coinw_uid_changes_user_id ON coinw_uid_changes(user_id);
CREATE INDEX IF NOT EXISTS idx_coinw_uid_changes_status ON coinw_uid_changes(status);
CREATE INDEX IF NOT EXISTS idx_coinw_uid_changes_created_at ON coinw_uid_changes(created_at DESC);

-- RLS有効化
ALTER TABLE coinw_uid_changes ENABLE ROW LEVEL SECURITY;

-- ポリシー: ユーザーは自分の申請のみ参照可能
CREATE POLICY "Users can view own coinw_uid_changes" ON coinw_uid_changes
  FOR SELECT USING (
    user_id = (SELECT user_id FROM users WHERE id = auth.uid())
  );

-- ポリシー: ユーザーは申請を作成可能
CREATE POLICY "Users can insert coinw_uid_changes" ON coinw_uid_changes
  FOR INSERT WITH CHECK (
    user_id = (SELECT user_id FROM users WHERE id = auth.uid())
  );

-- ポリシー: 管理者は全件参照・更新可能
CREATE POLICY "Admins can manage coinw_uid_changes" ON coinw_uid_changes
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND (is_admin = true OR email IN ('basarasystems@gmail.com', 'support@dshsupport.biz'))
    )
  );

-- ========================================
-- CoinW UID変更申請を承認するRPC関数
-- 承認時にchannel_linked_confirmedも自動でtrueに
-- ========================================
CREATE OR REPLACE FUNCTION approve_coinw_uid_change(
  p_change_id UUID,
  p_admin_email VARCHAR
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  user_id VARCHAR(6),
  new_coinw_uid VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id VARCHAR(6);
  v_new_coinw_uid VARCHAR(255);
  v_status VARCHAR(20);
BEGIN
  -- 申請レコードを取得
  SELECT c.user_id, c.new_coinw_uid, c.status
  INTO v_user_id, v_new_coinw_uid, v_status
  FROM coinw_uid_changes c
  WHERE c.id = p_change_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, '申請が見つかりません'::TEXT, NULL::VARCHAR(6), NULL::VARCHAR(255);
    RETURN;
  END IF;

  IF v_status != 'pending' THEN
    RETURN QUERY SELECT false, '既に処理済みの申請です'::TEXT, v_user_id, v_new_coinw_uid;
    RETURN;
  END IF;

  -- usersテーブルを更新（coinw_uid と channel_linked_confirmed）
  UPDATE users
  SET
    coinw_uid = v_new_coinw_uid,
    channel_linked_confirmed = true,
    updated_at = NOW()
  WHERE users.user_id = v_user_id;

  -- 申請ステータスを更新
  UPDATE coinw_uid_changes
  SET
    status = 'approved',
    reviewed_at = NOW(),
    reviewed_by = p_admin_email
  WHERE id = p_change_id;

  RETURN QUERY SELECT true, 'CoinW UIDを承認しました'::TEXT, v_user_id, v_new_coinw_uid;
END;
$$;

-- ========================================
-- CoinW UID変更申請を却下するRPC関数
-- ========================================
CREATE OR REPLACE FUNCTION reject_coinw_uid_change(
  p_change_id UUID,
  p_admin_email VARCHAR,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  user_id VARCHAR(6)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id VARCHAR(6);
  v_status VARCHAR(20);
BEGIN
  -- 申請レコードを取得
  SELECT c.user_id, c.status
  INTO v_user_id, v_status
  FROM coinw_uid_changes c
  WHERE c.id = p_change_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, '申請が見つかりません'::TEXT, NULL::VARCHAR(6);
    RETURN;
  END IF;

  IF v_status != 'pending' THEN
    RETURN QUERY SELECT false, '既に処理済みの申請です'::TEXT, v_user_id;
    RETURN;
  END IF;

  -- 申請ステータスを却下に更新
  UPDATE coinw_uid_changes
  SET
    status = 'rejected',
    reviewed_at = NOW(),
    reviewed_by = p_admin_email,
    rejection_reason = p_reason
  WHERE id = p_change_id;

  RETURN QUERY SELECT true, 'CoinW UID変更申請を却下しました'::TEXT, v_user_id;
END;
$$;

-- 権限付与
GRANT SELECT, INSERT ON coinw_uid_changes TO authenticated;
GRANT EXECUTE ON FUNCTION approve_coinw_uid_change(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_coinw_uid_change(UUID, VARCHAR, TEXT) TO authenticated;

-- 確認
SELECT '✅ coinw_uid_changes テーブルとRPC関数を作成しました' as status;
