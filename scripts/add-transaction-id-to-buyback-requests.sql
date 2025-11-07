-- buyback_requestsテーブルにtransaction_idカラムを追加

ALTER TABLE buyback_requests
ADD COLUMN IF NOT EXISTS transaction_id TEXT;

-- コメント追加
COMMENT ON COLUMN buyback_requests.transaction_id IS 'NFT返却時のトランザクションID（ブロックチェーン）';

-- 確認
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'buyback_requests'
AND column_name = 'transaction_id';
