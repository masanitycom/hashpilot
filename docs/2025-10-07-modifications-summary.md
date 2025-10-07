# 2025年10月7日 システム修正まとめ

## 📋 実施した修正一覧

### 1. NFT購入枚数上限の引き上げ
**ファイル**: `app/nft/page.tsx`
- **変更内容**: 100枚 → 1000枚に変更
- **理由**: ユーザーが大量購入を希望
- **影響範囲**: NFT購入ページのみ

### 2. 自動NFT付与機能の完全実装
**ファイル**: `scripts/fix-auto-nft-grant-add-nft-master.sql`
- **変更内容**:
  - `process_daily_yield_with_cycles`関数の完全書き直し
  - nft_masterテーブルに実際のNFTレコードを作成
  - purchasesテーブルに自動購入レコードを作成（is_auto_purchase=true）
  - NFT単位の日次利益を記録
  - 複数NFT同時付与に対応
- **テスト**: ユーザー7A9637で成功確認済み
- **影響範囲**: 全ユーザーの自動NFT付与処理

### 3. is_auto_purchaseカラムの追加
**ファイル**: `scripts/add-is-auto-purchase-column.sql`
- **変更内容**: purchasesテーブルに自動購入フラグを追加
- **デフォルト値**: FALSE
- **目的**: 手動購入と自動購入を区別

### 4. NFTサイクル状況表示の修正
**ファイル**: `components/cycle-status-card.tsx`
- **変更内容**:
  - NFTカウントをpurchasesテーブルではなくaffiliate_cycleテーブルから取得
  - **重要**: サイクル計算を紹介報酬のみに変更（個人利益を除外）
- **理由**: 仕様の誤解を修正
- **影響範囲**: ユーザーダッシュボードの表示

### 5. HOLDフェーズ中の出金制限
**ファイル**: `scripts/add-hold-phase-withdrawal-restriction.sql`
- **変更内容**: `create_withdrawal_request`関数にHOLDフェーズチェックを追加
- **制限条件**: `phase = 'HOLD' AND cum_usdt >= 1100`
- **理由**: 二重払い防止（cum_usdtは次のNFT購入に使用予定）
- **エラーメッセージ**: 「現在HOLDフェーズ中のため出金できません」
- **影響範囲**: 全ユーザーの出金申請処理

### 6. 月次自動出金からペガサス保留者を除外
**ファイル**: `scripts/fix-monthly-withdrawal-exclude-pegasus.sql`
- **変更内容**: `process_monthly_auto_withdrawal`関数にペガサス除外ロジックを追加
- **除外条件**:
  ```sql
  is_pegasus_exchange = TRUE
  AND (
      pegasus_withdrawal_unlock_date IS NULL
      OR CURRENT_DATE < pegasus_withdrawal_unlock_date
  )
  ```
- **理由**: ペガサス交換者は別途管理が必要
- **影響範囲**: 月末処理のみ

### 7. データ不整合の修正（ユーザー794682）
**ファイル**: `scripts/fix-user-794682-nft-count.sql`
- **問題**: affiliate_cycleには1 NFTとカウントされているが実際のレコードが存在しない
- **修正内容**: NFTカウントを0にリセット
- **原因**: データ入力の不整合（詳細原因は不明）
- **影響範囲**: 該当ユーザーのみ

### 8. CLAUDE.mdドキュメントの更新
**ファイル**: `CLAUDE.md`
- **追加セクション**: NFTサイクルシステムの詳細仕様
- **重要な明記事項**:
  - サイクル計算は紹介報酬のみ（個人利益は含まない）
  - HOLDフェーズ中は出金不可
  - フェーズ遷移ルール
  - 二重払い防止の仕組み

### 9. 最終システムチェックSQLの作成
**ファイル**: `scripts/final-system-check.sql`
- **チェック項目**:
  1. HOLDフェーズ出金制限
  2. ペガサス保留者チェック
  3. 自動NFT付与システム
  4. NFTサイクル整合性
  5. 重要関数の存在確認
  6. システム全体の健全性

---

## 🎯 重要な仕様変更

### NFTサイクル計算ロジックの明確化
**変更前**: 個人利益 + 紹介報酬でサイクル計算（誤解）
**変更後**: 紹介報酬のみでサイクル計算（正しい仕様）

```typescript
// cycle-status-card.tsx での変更
// ⭐ NFTサイクルは紹介報酬のみで計算（個人利益は含めない）
const referralProfit = await calculateMonthlyReferralProfit(userId, monthStart, monthEnd)
const totalProfit = referralProfit  // 個人利益は含めない
```

### フェーズと出金の関係
| フェーズ | cum_usdt | available_usdt | 出金可否 |
|---------|----------|----------------|----------|
| USDT | < 1100 | 個人利益のみ | ✅ 可能 |
| HOLD | >= 1100 | 個人利益のみ | ⚠️ 不可（cum_usdtは次のNFT購入予定） |
| NFT付与 | >= 2200 → リセット | +1100追加 | ✅ 可能 |

---

## 🧪 テスト結果

### 自動NFT付与テスト（ユーザー7A9637）
1. **初期状態**: cum_usdt = 1080
2. **日利計算実行**: 5%の利率で実行
3. **結果**:
   - ✅ NFTが自動付与された
   - ✅ nft_masterにレコードが作成された
   - ✅ purchasesにis_auto_purchase=trueで記録された
   - ✅ affiliate_cycleのカウントが更新された
   - ✅ available_usdtに1100ドルが加算された

### システム整合性チェック
- **総NFT数**: 718個（affiliate_cycle）
- **実際のNFT数**: 717個（nft_master）
- **不整合**: ユーザー794682の1件のみ → 修正済み

---

## 📝 実行が必要なSQLスクリプト

本番環境で以下のスクリプトを順番に実行してください：

1. `scripts/add-is-auto-purchase-column.sql`
   - purchasesテーブルにカラム追加

2. `scripts/fix-auto-nft-grant-add-nft-master.sql`
   - 自動NFT付与機能の完全実装

3. `scripts/add-hold-phase-withdrawal-restriction.sql`
   - HOLD中の出金制限追加

4. `scripts/fix-monthly-withdrawal-exclude-pegasus.sql`
   - 月次出金からペガサス除外

5. `scripts/fix-user-794682-nft-count.sql`
   - データ不整合の修正

6. `scripts/final-system-check.sql`
   - 全体チェック実行（確認用）

---

## ⚠️ 注意事項

### 環境変数
`.env.local`の設定:
```bash
NEXT_PUBLIC_SYSTEM_PREPARING=true  # 10/14までtrue維持
```
- **理由**: テスト運用中の注意書きを表示するため
- **変更予定**: 10/14以降にfalseに変更

### データベース関数
以下の関数が更新されています：
- `process_daily_yield_with_cycles` - 自動NFT付与機能
- `create_withdrawal_request` - HOLD中の出金制限
- `process_monthly_auto_withdrawal` - ペガサス除外

### フロントエンド
以下のコンポーネントが更新されています：
- `cycle-status-card.tsx` - サイクル計算ロジック変更
- `app/nft/page.tsx` - 購入上限変更

---

## 🔍 今後の監視ポイント

1. **自動NFT付与の動作**
   - nft_masterにレコードが正しく作成されるか
   - purchasesテーブルにis_auto_purchase=trueで記録されるか
   - available_usdtに1100ドルが正しく加算されるか

2. **HOLD中の出金制限**
   - HOLDフェーズのユーザーが出金申請できないか
   - エラーメッセージが正しく表示されるか

3. **ペガサス除外**
   - 月末処理でペガサス交換者が除外されるか
   - 出金制限解除日以降は正常に処理されるか

4. **データ整合性**
   - affiliate_cycleとnft_masterのNFTカウントが一致するか
   - 不整合が発生した場合の原因調査

---

## 📊 影響を受けるユーザー数

- **全ユーザー**: 189人
- **NFT保有者**: 110人
- **HOLD中のユーザー**: システムチェックで確認可能
- **ペガサス交換者**: 現時点で0人（今後追加予定）

---

## ✅ 完了確認

- [x] 自動NFT付与機能の実装と動作確認
- [x] HOLDフェーズ出金制限の実装
- [x] ペガサス除外ロジックの実装
- [x] データ不整合の修正
- [x] ドキュメント更新
- [x] システムチェックSQL作成
- [x] Git commit & push

---

最終更新: 2025年10月7日
作成者: Claude Code
