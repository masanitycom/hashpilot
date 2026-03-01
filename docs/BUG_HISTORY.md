# HASHPILOT バグ修正履歴

## 🐛 重要なバグ修正履歴

### 運用開始日未設定ユーザーへの誤配布（2025年11月13日修正）

**問題:**
- `process_daily_yield_with_cycles`関数で、`operation_start_date IS NULL`（運用開始日未設定）のユーザーも日利と紹介報酬の対象になっていた
- 38名のユーザーが合計$340.902の日利を誤って受け取っていた（2025-11-05 ～ 2025-11-11）

**原因:**
```sql
-- 修正前の条件（STEP 2とSTEP 3）
WHERE u.has_approved_nft = true
AND (u.operation_start_date IS NULL OR u.operation_start_date <= p_date)
```

**修正内容:**
```sql
-- 修正後の条件（STEP 2とSTEP 3）
WHERE u.has_approved_nft = true
AND u.operation_start_date IS NOT NULL
AND u.operation_start_date <= p_date
```

**修正箇所:**
- STEP 2: 個人利益計算（ユーザーごとに集計）
- STEP 3: 紹介報酬計算（レベル1/2/3すべて）

**関連スクリプト:**
- `scripts/FIX-operation-start-date-null-users.sql` - 関数修正
- `scripts/CHECK-incorrect-daily-profit-details.sql` - 誤配布データ確認
- `scripts/DELETE-incorrect-daily-profit-CAREFUL.sql` - 誤配布データ削除（要慎重）

**運用ルールの再確認:**
> 運用開始日が設定されていて（IS NOT NULL）、かつその日付が経過している（<= 今日）ユーザーのみが日利と紹介報酬の対象

---

### マイナス日利が配布されない問題（2025年11月13日修正）

**問題:**
- `process_daily_yield_v2`関数がマイナス日利の時に配当を0にしていた
- ユーザーダッシュボードにマイナス日利が表示されない
- 透明性の問題（マイナスが隠されていた）

**原因:**
```sql
-- 修正前のStep 9（行142-150）
IF v_daily_pnl > 0 THEN
  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;
  v_distribution_stock := v_daily_pnl * 0.10;
ELSE
  v_distribution_dividend := 0;  -- ❌ マイナス時は0
  v_distribution_affiliate := 0;
  v_distribution_stock := 0;
END IF;

-- 修正前のStep 11-13
IF v_distribution_dividend > 0 THEN  -- ❌ プラスのみ処理
```

**修正内容:**
```sql
-- 修正後のStep 9（マイナスでも計算）
v_distribution_dividend := v_daily_pnl * 0.60;   -- ✅ 常に計算
v_distribution_affiliate := v_daily_pnl * 0.30;
v_distribution_stock := v_daily_pnl * 0.10;

-- 修正後のStep 11-13
IF v_distribution_dividend != 0 THEN  -- ✅ マイナスでも処理
```

**追加修正:**
- `nm.status = 'active'` → `nm.buyback_date IS NULL`（テスト環境のテーブル構造に対応）

**関連スクリプト:**
- `scripts/FIX-process-daily-yield-v2-final.sql` - 関数修正（最終版）
- `scripts/FIX-process-daily-yield-v2-minimal.sql` - 最小限版
- `scripts/FIX-process-daily-yield-v2-negative.sql` - 詳細コメント版

**テスト結果:**
- ユーザー7A9637の11/12に-$0.912が正しく配布・表示された
- ダッシュボードで「昨日の利益: $-0.912」と表示
- 今月累計は$12.493で正しく計算

**CLAUDE.md仕様の確認:**
> **マイナス利益時**: マージン30%を引く（会社が負担する）
>
> ユーザー受取率 = 日利率 × (1 - 0.30) × 0.6
> 例：-0.2% → -0.2% × 0.7 × 0.6 = -0.084%

---

### NFT承認フラグ未更新問題（2025年11月13日修正）

**問題:**
- 管理者がNFT購入を承認したが、`users.has_approved_nft`が`false`のまま
- `users.operation_start_date`が`null`のまま
- **81名のユーザーが日利を受け取れていなかった**

**原因:**
- NFT承認時に`nft_master`テーブルにはNFTが作成される
- しかし`users`テーブルの以下のフラグが更新されていなかった：
  - `has_approved_nft` → `false`のまま
  - `operation_start_date` → `null`のまま
- このため、NFTは存在するが日利が配布されない状態だった

**影響:**
- 81名のユーザー（合計89個のNFT）が日利を受け取れていなかった
- `nft_master`にはNFTが存在するため、NFT数はカウントされる
- でも`operation_start_date`が未設定のため、日利は0円

**修正内容:**
```sql
-- has_approved_nftを一括更新（361件）
UPDATE users
SET has_approved_nft = true
WHERE user_id IN (
    SELECT DISTINCT u.user_id
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    INNER JOIN purchases p ON u.user_id = p.user_id
    WHERE u.has_approved_nft = false
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
);

-- operation_start_dateを一括計算・更新（363件）
UPDATE users u
SET operation_start_date = calculate_operation_start_date(nm.acquired_date)
FROM (
    SELECT DISTINCT ON (user_id)
        user_id,
        acquired_date
    FROM nft_master
    WHERE buyback_date IS NULL
    ORDER BY user_id, acquired_date ASC
) nm
WHERE u.user_id = nm.user_id
    AND u.operation_start_date IS NULL;
```

**関連スクリプト:**
- `scripts/FIX-has-approved-nft-bulk-update.sql` - 一括修正スクリプト

**確認方法:**
```sql
-- 同じ問題がないか確認
SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = false
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.email, u.has_approved_nft, u.operation_start_date;
```

**今後の対策:**
- NFT承認時に`has_approved_nft`と`operation_start_date`を自動更新する仕組みが必要
- または管理画面のNFT承認処理を修正

---

### approve_user_nft関数で運用開始日が未設定になる問題（2025年12月17日修正）

**問題:**
- 12/15運用開始のユーザーが運用益0のまま
- 日利設定は12/16まで設定済みなのに配布されていない

**原因:**
- `approve_user_nft`関数がNFT承認時に以下を設定していなかった：
  - `has_approved_nft = true`
  - `operation_start_date = calculate_operation_start_date(承認日)`
- これにより`process_daily_yield_v2`の対象外になっていた

**修正内容:**
- `approve_user_nft`関数を修正
- `users`テーブル更新時に`has_approved_nft`と`operation_start_date`を設定

**補填処理:**
- 12/15と12/16の日利を手動でバックフィル
- `nft_daily_profit`テーブルに直接挿入（user_daily_profitはビューのため）
- `affiliate_cycle.available_usdt`も更新

**関連スクリプト:**
- `scripts/FIX-approve-user-nft-add-operation-start-date.sql` - 関数修正
- `scripts/FIX-1215-backfill-simple.sql` - 日利補填

---

### V2日利システム完成（2025年11月13日）

**背景:**
- 旧システム: 利率％で入力 → `process_daily_yield_with_cycles`
- V2システム: 金額＄で入力 → `process_daily_yield_v2`
- **機能は全く同じ。入力方法だけ変更。**

**実装内容:**
1. ✅ **日利配布（個人利益）** - 60%を配当として配布
   - マイナス日利も配布する
   - `affiliate_cycle.available_usdt`に加算

2. ✅ **紹介報酬計算・配布** - 30%を紹介報酬として配布
   - Level 1（直接紹介）: 紹介者の日利 × 20%
   - Level 2（間接紹介）: 紹介者の日利 × 10%
   - Level 3（間接紹介）: 紹介者の日利 × 5%
   - **プラスの時のみ計算**（マイナス時は紹介報酬なし）
   - `user_referral_profit`テーブルに記録
   - `affiliate_cycle.cum_usdt`と`available_usdt`に加算

3. ✅ **NFT自動付与（サイクル機能）** - 10%をストック資金
   - `cum_usdt >= $2,200`で自動的に1 NFT付与
   - `nft_master`にレコード作成（`nft_type = 'auto'`）
   - `purchases`にレコード作成
   - `cum_usdt -= 1100`, `available_usdt += 1100`
   - フェーズ更新（USDT / HOLD）

**テスト結果（2025-11-11、+$1580.32）:**
- 個人利益: 255ユーザーに$948.040配布
- 紹介報酬: 135ユーザーに$296.345配布（649件の紹介関係）
  - Level 1: 132ユーザー、$185.224（20%）
  - Level 2: 90ユーザー、$89.735（10%）
  - Level 3: 73ユーザー、$21.386（5%）
- ストック資金: 255ユーザーに$158.450配布
- NFT自動付与: 0件（cum_usdt >= $2,200のユーザーなし）

**具体例（ユーザー7A9637）:**
- 個人利益: $1.370（1 NFT所有）
- 紹介報酬:
  - Level 1: 2人から$0.548（各$0.274 = $1.370 × 20%）
  - Level 2: 3人から$0.548
  - Level 3: 2人から$0.138
  - 合計: $1.234
- affiliate_cycle更新:
  - `cum_usdt`: $1.23（紹介報酬のみ）
  - `available_usdt`: $2.60（個人利益 + 紹介報酬）

**関連スクリプト:**
- `scripts/FIX-process-daily-yield-v2-complete-clean.sql` - 完成版RPC関数
- `scripts/TEST-process-daily-yield-v2-positive.sql` - テストスクリプト

**管理画面での使用:**
- `app/admin/yield/page.tsx`で既に`process_daily_yield_v2`を使用中
- 入力: 日付、金額（＄）
- 出力: 日利配布、紹介報酬、NFT自動付与の詳細

---

### 本番環境の緊急修正（2025年11月15日）

**🚨 重大な問題が発見され、システム停止が必要となりました。**

#### 問題の詳細

1. **運用開始前のユーザーへの誤配布**
   - `operation_start_date IS NULL` または `operation_start_date > 配布日` のユーザーにも日利と紹介報酬が配布されていた
   - 本番環境のV1システム（`process_daily_yield_with_cycles`）で発生
   - テスト環境で同じ問題が発見・修正済みだったが、本番環境には未適用だった

2. **NFT承認フラグ未更新（本番環境）**
   - **91ユーザー**が `has_approved_nft = false` または `operation_start_date = NULL`
   - これらのユーザーは合計 **$81,000の投資**（81個のNFT）
   - 実際にはNFTを保有しているが、日利を受け取れていない状態

3. **V1システムの根本的な欠陥**
   - `process_daily_yield_with_cycles`関数が `operation_start_date` をチェックしていなかった
   - STEP 2（個人利益配布）でチェック不足
   - STEP 3（紹介報酬配布）でチェック不足
   - STEP 4（NFT自動付与）でチェック不足

#### 影響範囲

**誤配布されたユーザー:**
- operation_start_date = NULL: 38ユーザー、$81,000投資
- operation_start_date > 配布日: その他のユーザー
- 誤配布された金額: 調査中（`URGENT-CHECK-incorrect-profit-distribution.sql`で確認可能）

**総投資額の変化:**
- 以前: $680,000
- 現在: $714,000
- 内訳:
  - 運用中（ペガサス除く）: $714,000（714 NFT、271ユーザー）
  - 運用開始前（ペガサス除く）: $81,000（81 NFT、38ユーザー）← これが誤配布の原因
  - ペガサス: $87,000（87 NFT、65ユーザー）

#### 緊急対応手順

詳細は **`PRODUCTION_EMERGENCY_FIX.md`** を参照

**STEP 0: システム停止**
- 日利処理を一時停止
- 管理画面で新しい日利を設定しない

**STEP 1: 誤配布データの確認**
```bash
scripts/URGENT-CHECK-incorrect-profit-distribution.sql
```
- operation_start_date = NULL のユーザーへの配布
- operation_start_date > 配布日 のユーザーへの配布
- 誤配布の合計金額、日付別の詳細、ユーザーリスト

**STEP 2: V1システム関数の修正**
```bash
scripts/FIX-process-daily-yield-v1-operation-start-date.sql
```
修正内容:
- STEP 2（個人利益配布）: `operation_start_date IS NOT NULL AND operation_start_date <= p_date` を追加
- STEP 3（紹介報酬配布）: 紹介される側と紹介者の両方の `operation_start_date` をチェック
- STEP 4（NFT自動付与）: `operation_start_date` をチェック

**STEP 3: NFT承認フラグの修正**
```bash
scripts/FIX-production-has-approved-nft-bulk-update.sql
```
- 91ユーザーの `has_approved_nft` を `true` に更新
- 91ユーザーの `operation_start_date` を設定
- 各ユーザーの最初のNFT取得日から `calculate_operation_start_date()` で計算

**STEP 4: 誤配布データの削除**
```bash
scripts/DELETE-incorrect-profit-distribution-CAREFUL.sql
```
⚠️ **この操作は取り消せません。必ずバックアップを取ってください。**

処理内容:
1. `affiliate_cycle.available_usdt` から個人利益分を差し引く
2. `affiliate_cycle.cum_usdt` から紹介報酬分を差し引く
3. `affiliate_cycle.phase` を再計算
4. `nft_daily_profit` から誤配布レコードを削除
5. `user_referral_profit` から誤配布レコードを削除

**STEP 5: システム再開**
- すべての修正が完了後、日利処理を再開
- 検証スクリプトで問題がないことを確認

#### 関連スクリプト

**調査用:**
- `scripts/URGENT-CHECK-incorrect-profit-distribution.sql` - 誤配布データの詳細確認
- `scripts/CHECK-production-v1-profit-analysis.sql` - 本番環境の利益分析
- `scripts/CHECK-total-investment-calculation.sql` - 総投資額計算の確認

**修正用:**
- `scripts/FIX-process-daily-yield-v1-operation-start-date.sql` - V1関数修正
- `scripts/FIX-production-has-approved-nft-bulk-update.sql` - フラグ一括修正
- `scripts/DELETE-incorrect-profit-distribution-CAREFUL.sql` - 誤配布データ削除

**ドキュメント:**
- `PRODUCTION_EMERGENCY_FIX.md` - 緊急修正手順の詳細マニュアル

#### 運用ルールの再確認

**日利・紹介報酬の対象となる条件:**
```sql
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= p_date
```

**重要:**
- 運用開始日が設定されていて（IS NOT NULL）
- かつその日付が経過している（<= 今日）
- ユーザーのみが日利と紹介報酬の対象

**テスト環境との違い:**
- テスト環境: 2025年11月13日に修正済み（`FIX-operation-start-date-null-users.sql`）
- 本番環境: 2025年11月15日に同じ問題が発見され、緊急修正が必要

#### 今後の対策

1. **自動フラグ更新**
   - NFT承認時に `has_approved_nft` と `operation_start_date` を自動更新する仕組みを実装
   - 管理画面のNFT承認処理を修正

2. **V2システムへの移行**
   - 本番環境も将来的にV2システムに移行予定
   - V2システムでは `operation_start_date` チェックが組み込み済み
   - テスト環境で十分にテスト後、本番環境に適用

3. **定期監査**
   - 定期的に誤配布がないかチェックするスクリプトを実行
   - `has_approved_nft = false` だがNFTが存在するユーザーを検出
   - `operation_start_date = NULL` だがNFTが存在するユーザーを検出

---

### approve_user_nft関数の運用開始日設定漏れ（2025年12月17日修正）

**問題:**
- `approve_user_nft`関数でNFTを承認した際に、`users.has_approved_nft`と`users.operation_start_date`が設定されなかった
- そのため、承認済みNFTがあるユーザーでも日利配布の対象外になっていた
- 12/15運用開始予定のユーザーが日利を受け取れない状態だった

**原因:**
```sql
-- 修正前：has_approved_nftとoperation_start_dateが設定されていなかった
UPDATE users u
SET
    total_purchases = u.total_purchases + v_purchase.amount_usd,
    updated_at = NOW()
WHERE u.user_id = v_target_user_id;
```

**修正内容:**
```sql
-- 修正後：has_approved_nftとoperation_start_dateを設定
UPDATE users u
SET
    total_purchases = u.total_purchases + v_purchase.amount_usd,
    has_approved_nft = true,
    operation_start_date = CASE
        WHEN u.operation_start_date IS NULL THEN calculate_operation_start_date(NOW())
        WHEN u.operation_start_date > calculate_operation_start_date(NOW()) THEN calculate_operation_start_date(NOW())
        ELSE u.operation_start_date
    END,
    updated_at = NOW()
WHERE u.user_id = v_target_user_id;
```

**関連スクリプト:**
- `scripts/FIX-approve-user-nft-add-operation-start-date.sql` - 関数修正
- `scripts/FIX-missing-operation-start-date-users.sql` - 既存ユーザーの一括修正
- `scripts/CHECK-1215-operation-start-users.sql` - 問題確認用

**修正後の動作:**
- NFT承認時に`has_approved_nft = true`が自動設定される
- NFT承認時に`operation_start_date`が自動計算・設定される
- 既にoperation_start_dateが設定されている場合は、早い方を維持

**日利配布の条件（再確認）:**
```sql
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= p_date
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
```

---

### ペガサスユーザー2026年1月のバグ

- 1/20にペガサス除外条件が誤って削除された
- 61人のペガサスユーザー（is_pegasus_exchange = true）に日利が誤配布された
- 1/20〜1/25の6日間、504レコード、-$236.88
- 修正スクリプト: `FIX-delete-pegasus-wrong-profit-and-restore-exclusion.sql`

---

### NFT重複・不整合の修正履歴（2025年12月23日）

**修正対象ユーザー:**
| ユーザーID | 問題 | 修正内容 |
|------------|------|----------|
| CA7902 | NFT2枚（購入は1枚） | 重複NFT削除 |
| 0E0171 | NFT2枚（購入は1枚） | 重複NFT削除 |
| 3194C4 | 解約済みだがtotal_purchases残存 | フラグ修正 |
| 4CE189 | テストアカウント | 完全削除 |
| 794682 | NFT1枚（購入記録なし） | NFT削除・フラグ修正 |

**原因:** 2025年10月7日のマイグレーション時にNFTが重複作成された

**関連スクリプト:**
- `scripts/CHECK-nft-mismatch-users.sql` - 不整合調査
- `scripts/FIX-nft-mismatch-users.sql` - 不整合修正

---

最終更新: 2026年3月1日
