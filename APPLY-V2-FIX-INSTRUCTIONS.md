# V2関数修正の適用手順

## 背景

11/9にマイナス日利（-$5000）でNFTが142個誤付与された問題：
- **原因**: V2関数がマイナス日利でもNFT自動付与を実行
- **応急処置**: 11/19に誤付与されたNFTを削除済み
- **根本修正**: V2関数を修正（プラス日利の時のみNFT付与）

## 修正内容

`process_daily_yield_v2` 関数の360-424行目を修正：

```sql
-- 修正前（問題あり）
FOR v_user_record IN
  SELECT ... WHERE ac.cum_usdt >= 2200
LOOP
  ...
END LOOP;

-- 修正後
IF v_distribution_dividend > 0 THEN  -- ✅ プラス日利の時のみ
  FOR v_user_record IN
    SELECT ... WHERE ac.cum_usdt >= 2200
  LOOP
    ...
  END LOOP;
END IF;  -- ✅ 追加
```

## 適用手順

### STEP 1: Supabase SQL Editorを開く

1. https://supabase.com/ にログイン
2. プロジェクト選択（staging環境）
3. 左メニューから「SQL Editor」をクリック

### STEP 2: 修正版スクリプトを適用

```bash
# ローカルファイルの内容をコピー
cat scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql
```

1. SQL Editorに貼り付け
2. 「Run」ボタンをクリック
3. 成功メッセージを確認

### STEP 3: 動作確認

テストモードで動作確認：

```sql
-- マイナス日利でNFT自動付与が発生しないことを確認
SELECT * FROM process_daily_yield_v2(
  '2025-11-25',  -- テスト日付
  -3000.00,      -- マイナス日利
  TRUE           -- テストモード
);

-- 期待結果:
-- auto_nft_count: 0 （NFT自動付与なし）
-- distribution_dividend: マイナス値
```

### STEP 4: テストデータのクリーンアップ

```sql
-- テストモードで作成したデータを削除
DELETE FROM daily_yield_log_v2 WHERE date = '2025-11-25';
DELETE FROM nft_daily_profit WHERE date = '2025-11-25';
DELETE FROM user_referral_profit WHERE date = '2025-11-25';
DELETE FROM stock_fund WHERE date = '2025-11-25';
```

### STEP 5: 本番環境にも適用

staging環境で問題なければ、本番環境にも同じ手順で適用。

## 確認事項

- [x] 11/9の誤NFTは削除済み（11/19実行）
- [ ] V2関数修正をstaging環境に適用
- [ ] staging環境でテスト実行
- [ ] 本番環境に適用

---

最終更新: 2025-11-23
