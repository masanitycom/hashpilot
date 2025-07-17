# HASHPILOT利益$0問題 調査・修正レポート

**作成日**: 2025年7月17日  
**調査者**: Claude (Anthropic)  
**問題レベル**: 🚨 システム緊急停止レベル

## 📋 問題の概要

HASHPILOTシステムで全てのユーザーの利益が$0になっている重大な問題を調査し、根本原因を特定して修正を実装しました。

## 🔍 発見された問題

### 1. **運用開始日の条件チェック欠如** ⚠️ **最重要**
- **問題**: `process_daily_yield_with_cycles`関数に運用開始日（NFT承認+15日）の条件チェックがない
- **影響**: NFT承認直後から利益計算が開始され、実際は運用開始前のため$0利益となる
- **根本原因**: 関数のクエリで運用開始日の条件 `(p.admin_approved_at + INTERVAL '15 days')::date <= p_date` が抜けていた

### 2. **重複キーエラーによる処理停止** ⚠️ **機能停止**
- **問題**: `user_daily_profit`テーブルへのINSERT時に重複キーエラーが発生
- **エラー**: `duplicate key value violates unique constraint "user_daily_profit_user_id_date_key"`
- **影響**: 日利設定機能が一切使用不可能
- **原因**: UPSERTではなく単純なINSERTを使用していた

### 3. **基準金額計算の誤り** ⚠️ **計算間違い**
- **問題**: 利益計算の基準を1100ドル/NFTで計算していた
- **正しい計算**: 実際の運用額は1000ドル/NFT（100ドルは手数料）
- **影響**: 利益額が10%過大に計算される可能性

## 🛠️ 実装した修正

### 修正1: 運用開始日条件の追加
```sql
-- 運用開始済みユーザーのみ処理する条件を追加
INNER JOIN purchases p ON ac.user_id = p.user_id
WHERE ac.total_nft_count > 0
  AND p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  -- 【重要修正】運用開始日（承認日+15日）が処理日以前のユーザーのみ処理
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= p_date
```

### 修正2: UPSERT機能の実装
```sql
-- 重複エラーを回避するUPSERT処理
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
)
VALUES (
    v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate, v_base_amount, 
    v_new_phase, NOW()
)
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase,
    created_at = NOW();
```

### 修正3: 正しい基準金額計算
```sql
-- 【重要修正】基準金額（NFT数 × 1000）- 実際の運用額は1000ドル/NFT
v_base_amount := v_user_record.total_nft_count * 1000;
```

## 📊 修正効果の予測

### 修正前（問題状態）
- **処理対象ユーザー**: 0名（運用開始日チェックなし）
- **利益発生**: $0（運用開始前のため）
- **システム状態**: 機能停止（重複エラー）

### 修正後（期待される状態）
- **処理対象ユーザー**: 運用開始済みユーザーのみ
- **利益計算**: 正確な基準金額（1000ドル/NFT）で計算
- **システム安定性**: UPSERT機能により重複エラー解消

## 🎯 具体的な利益計算例

### ユーザー7A9637の場合
- **NFT購入**: 1個（$1100）
- **運用額**: $1000（手数料$100除く）
- **日利率**: 1.6%
- **マージン後**: 1.6% × 70% = 1.12%
- **ユーザー受取**: 1.12% × 60% = 0.672%
- **1日の利益**: $1000 × 0.672% = **$6.72**

## 📝 実装されたファイル

### 修正SQLスクリプト
- `/scripts/fix-zero-profit-complete.sql` - 完全修正版

### 削除された不要ファイル
- 調査用の一時JSファイル（3個）
- 重複したSQL修正ファイル（2個）

## ⚠️ 重要な注意事項

### 1. 運用開始日の計算
- NFT承認日から**15日後**に運用開始
- この期間中は利益が発生しない（仕様通り）

### 2. 過去データのクリーンアップ
- 運用開始日前の無効な`user_daily_profit`データは自動削除される
- データ整合性が保たれる

### 3. ログ機能の強化
- 処理開始・完了・エラーの詳細ログ記録
- デバッグ情報の充実

## 🚀 今後の推奨事項

### 1. 即座に実行すべき作業
1. **修正SQLスクリプトの実行**: `/scripts/fix-zero-profit-complete.sql`
2. **テスト実行**: 修正された関数でのテスト処理
3. **本番実行**: 1.6%日利での実際の処理

### 2. 監視項目
- 運用開始済みユーザー数の確認
- 利益計算の正確性検証
- システムログでのエラー監視

### 3. 今後の改善点
- 運用開始日の自動チェック機能
- 利益計算の可視化ダッシュボード
- より詳細なエラーハンドリング

## 📈 期待される結果

修正実装後、以下の改善が期待されます：

1. **利益の正常発生**: 運用開始済みユーザーに正確な利益が計算される
2. **システム安定性**: 重複エラーの解消により安定稼働
3. **計算精度**: 正しい基準金額による正確な利益計算
4. **監査証跡**: 詳細なログによる処理の透明性

---

**修正ファイル**: `/scripts/fix-zero-profit-complete.sql`  
**実行手順**: SQL管理画面でスクリプトを実行  
**緊急度**: 🚨 即座に実行が必要  
**検証方法**: テスト実行 → 本番実行 → 利益確認