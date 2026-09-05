# HASHPILOT バグ修正履歴

## 🐛 重要なバグ修正履歴

### 買取金額に紹介報酬が反映されていなかった（2026年9月5日修正）

**問題:**
買取金額の計算で**個人収益（日利）しか控除しておらず、紹介報酬が控除されていなかった**。
その分、買取額が本来より高く出ていた（会社側の払い過ぎ）。

**原因:**
`calculate_nft_buyback_amount` が `nft_total_profit.total_profit_for_buyback`
（＝日利のみ。ビュー定義にも「買い取り計算には個人収益のみを使用」とコメントあり）を使っていた。

紛らわしい点として、`calculate_user_buyback_amount`（2026-02-10 の
`FIX-buyback-include-referral-profit.sql` で紹介報酬込みに修正済み）が別に存在するが、
**この関数はユーザー画面からも申請作成からも呼ばれていない**。実際の経路は以下:

```
ユーザー画面の見積もり : calculate_buyback_preview   → calculate_nft_buyback_amount
申請作成             : create_buyback_request      → calculate_nft_buyback_amount
申請履歴の表示        : get_buyback_requests        → buyback_requests.total_buyback_amount
```

つまり画面と記録は一致していたが、**両方とも紹介報酬を引いていなかった**。

**修正内容:**
`calculate_nft_buyback_amount` の1関数のみ修正。3経路すべてに反映される。

```
1枚あたりの紹介報酬 = ユーザーの累計紹介報酬 / 保有NFT枚数（buyback_date IS NULL）
控除対象の利益 = 個人収益(日利) + 上記
買取額 = 基本額 − 利益 / 2   （利益がマイナスなら 基本額 + 利益）
基本額: 手動 $1,000 / 自動 $500、下限 $0
```

**既存 pending 申請の再計算:**
- 52件 $136,439.11 → **$134,445.35**（減額 $1,993.76）
- `completed`（送金済み）は変更しない
- 減額が大きかったユーザー:
  | ユーザー | 修正前 | 修正後 | 差 | 累計紹介報酬 |
  |---------|--------|--------|-----|-------------|
  | 04FF0C | $9,224.50 | $8,631.60 | -$592.90 | $1,181.66 |
  | 230F31 | $918.09 | $474.73 | -$443.36 | $886.97 |
  | 1F85EE | $918.09 | $710.89 | -$207.20 | $414.66 |
  | 394CEC | $1,839.60 | $1,679.96 | -$159.64 | $315.74 |
  | 870323 | $918.52 | $809.43 | -$109.09 | $217.99 |

紹介報酬0のユーザーにも $0.06〜$6.46 の小差が出たが、これは同日実施した
日利補填（買取申請の1〜2日早い停止の修正）で累計日利が動いたことによるもので正常。

**検証:** 画面表示（`calculate_buyback_preview`）と記録（`buyback_requests`）の不一致 **0件**

**バックアップ:** `backup_buyback_requests_20260905`

**⚠️ 注意:** 既に申請済みのユーザーが画面を開くと金額が下がって見える。
説明の要点は「紹介報酬も利益として買取価格から控除する計算に統一した。
控除は受け取った利益の半額なので、受け取り済みの紹介報酬と合わせれば損はしていない」。

**関連スクリプト:**
- `scripts/FIX-nft-buyback-include-referral-permanent.sql` - 関数修正＋既存申請の再計算
- `scripts/CHECK-buyback-amount-5users-20260905.sql` - 解約金額の試算
- `scripts/FIX-create-buyback-request-5users-proxy-20260905.sql` - 代理申請（高齢者5名）

**未対応:** 59D41C に買取申請が2件重複（2026-08-29、各 $5,496.78）

---

### 買取申請ユーザーの日利が申請日の1〜2日前から止まる（2026年9月5日修正）

**問題:**
- 買取（解約）申請を出したユーザーの日利が、**申請日より1〜2日早く停止**していた
- 仕様は「買取申請の翌日から日利停止」（`docs/TODO.md` 2026-02-07確定）

**原因:**
`process_daily_yield_v2` の買取判定が**日付を見ていなかった**。

```sql
-- 問題のあった条件（3箇所）
AND NOT EXISTS (
  SELECT 1 FROM buyback_requests br
  WHERE br.user_id = nm.user_id AND br.status = 'pending'
)
```

日利は「その日の分を翌日に入力」する運用のため、申請が日利入力より先に届くと、
**申請日以前の日利まで配布対象から外れる**。

A512FF の例:
| 日利の日付 | 入力日時(UTC) | 結果 |
|-----------|--------------|------|
| 2026-08-15 | 08-16 17:36 | 配布 |
| （買取申請） | **08-17 12:57** | |
| 2026-08-16 | 08-17 13:31 | **未配布**（申請の34分後に入力） |
| 2026-08-17 | 08-18 07:45 | **未配布** |

なお `FIX-process-daily-yield-v2-exclude-buyback-pending.sql`（2026-02-09）は
冒頭に「買取申請翌日から日利停止」と明記されており、**意図は正しかったが実装が日付条件を欠いていた**。

**影響:**
- 買取申請中の46名、92（ユーザー×日）、**合計 $92.77**
- 最大は 7D5A07（23枚）$20.66、9DDF45（19枚）$12.86、A512FF（8枚）$8.20

**修正内容:**
1. 不足分を `nft_daily_profit` へ補填（258行）、`available_usdt` に加算
2. 関数の3箇所に日付条件を追加（下記）

**マイナス残高は0に丸めない（2026-09-05 方針決定）**
補填でマイナス残高になった6名（CE4129 -0.90 / 8C24E9 -0.23 /
2FFADB・F5AE90・A50F42・FECC53 各 -0.14、計 $1.68）は**そのまま残す**。
実際に発生した損失であり、残高を人為的に0へ書き換えるのは行わない。
全員が買取申請中で当月収入がないため、月末処理では出金レコードが作られず
実害はない（`check_monthly_integrity` にマイナス残高として表示されるのみ）。

```sql
-- 修正後
AND NOT EXISTS (
  SELECT 1 FROM buyback_requests br
  WHERE br.user_id = nm.user_id AND br.status = 'pending'
    AND (br.request_date AT TIME ZONE 'Asia/Tokyo')::date < p_date
)
```

**⚠️ 補填分は配当原資の外から支払っている**
除外されたユーザーを除いて山分けした後の金額なので、補填はその日の配当原資（60%）を
超えて支払う形になる。全ユーザー分を再計算し直す方法もあるが、他の全員の確定済み金額が
動くため採用していない。

**1枚あたりの配布額の計算:**
`daily_yield_log_v2.distribution_dividend / total_nft_count`
（`profit_per_nft` はマージン控除前の値。ユーザー受取は 42% = 70% × 60%）

**関連スクリプト:**
- `scripts/CHECK-A512FF-nft-count-mismatch.sql` - 個別調査
- `scripts/CHECK-A512FF-missing-days-after-buyback.sql` - 未配布日の特定
- `scripts/CHECK-buyback-pending-missing-daily-profit.sql` - 全件集計
- `scripts/FIX-backfill-buyback-early-stop-daily-profit.sql` - 補填（実行済み）

**未対応:**
- 59D41C に買取申請が2件重複（2026-08-29 に9分違い、各6枚 $5,516.64）。
  買取処理時に二重にならないよう片方の取り消しが必要

---

### 7月分の送金完了処理漏れによる8月分への上乗せ（2026年9月2日修正）

**問題:**
- 2026年7月分の月末出金を8月頭に実送金したが、管理画面の「完了済みにする」を実行し忘れた
- `available_usdt` から7月分が引かれないまま、9/1に8/31の日利を投入
- 月末処理が自動実行され、**8月分の出金レコードに7月分が丸ごと上乗せ**された
- そのまま送金していれば7月分の二重払いになっていた

**発覚時の状態:**
| 対象 | 件数 | 合計 |
|------|------|------|
| 7月分（未完了） | 434 | $15,943.59 |
| 8月分（自動作成） | 434 | $30,222.63 |

- 8月分は 2026-09-01 07:37:07 の単一タイムスタンプで自動作成されていた
- 全ユーザーで `available_usdt == 8月分 total_amount` を確認（`total_amount = available_usdt 全額` の仕様どおり）

**原因:**
月末処理は月末日の日利入力で自動発火する（`app/admin/yield/page.tsx`）。
`process_monthly_withdrawals` は `total_amount` を `available_usdt` 全額で作るため、
前月分が減算されていないと翌月分にそのまま乗る。

**修正内容:**
1. 事務が7月分の実送金分（428件 $14,786.89）を完了処理
2. 8月分の `total_amount` を `available_usdt` で上書き（$30,222.63 → **$15,435.74**）
3. `referral_amount` を4パターン式で再計算（`LEAST(total_amount, ...)` で丸め）
4. 未送金6名（CoinW UID未設定・不正）に繰越理由を notes 記録し `on_hold` に統一

**検証:**
```
8月レコード合計 $30,222.63 − 7月完了額 $14,786.89 = $15,435.74
対象者の available_usdt 合計                      = $15,435.74  ← 完全一致
```
`check_monthly_integrity(2026, 8)` は出金漏れ・紹介報酬漏れともにOK。
available_usdt整合性のNG 9名は全員既知のユーザーで新規なし。

**⚠️ 重要: 8月分レコードを削除して作り直してはいけない**
- 新規レコードは必ず `status='on_hold'` / `task_completed=false` で作られる
- `monthly_reward_tasks` への INSERT は `ON CONFLICT (user_id, year, month) DO NOTHING`
- → タスク完了済みユーザー（当時36件）はタスク行が残るためポップアップが出ず、
  `on_hold` のまま永久に `pending` へ進めなくなる
- 必ず **total_amount の上書き**で修正する

**再発防止:**
- `components/admin-unsettled-withdrawal-alert.tsx` - 前月以前に未清算レコード
  （`completed` でなく notes も空）があれば警告。20日以降は全画面モーダル
- `app/admin/layout.tsx` - 全管理画面に表示
- `app/admin/yield/page.tsx` - 未清算があれば**月末日の日利入力をブロック**

判定に `pending` だけを使ってはいけない。7月分は434件中428件を送金しており、
`on_hold`（タスク未完了）にも送金する運用のため検知漏れする。
意図的に送金しないユーザーは notes に「翌月分に繰越」と書く運用とし、
notes に「繰越」を含むものだけを除外する。「notes が空でないもの」を除外条件にすると、
修正スクリプトが書き込んだ notes まで警告対象から外れてしまう
（8月分の修正で全434件に notes が入ったため）。

**関連スクリプト:**
- `scripts/CHECK-july-august-reconcile.sql` - 7月/8月の突き合わせ
- `scripts/CHECK-identify-remitted-subset.sql` - 実送金レコードの特定
- `scripts/CHECK-after-july-completion.sql` - 完了処理直後の検証
- `scripts/FIX-august-withdrawal-remove-july-overlap.sql` - 8月分の修正（本体）
- `scripts/CHECK-july-unremitted-6users.sql` - 未送金6名の理由確認
- `scripts/FIX-july-unremitted-6users-carryover-note.sql` - 繰越理由の記録

**サブサイト（hashpilotsub）:**
同様の事象が発生。実送金額 $172.75。月末処理は Edge Function
`sync-yield-from-main` の `runMonthEnd()` から cron で自動実行されるため、
管理画面のガードは効かない。引き継ぎは `HANDOFF-2026-09-02-withdrawal-settlement.md`。

---


### 3月分の月末出金・紹介報酬の漏れ（2026年4月11日修正）

**問題:**
- 5ユーザーの3月出金レコードが作成されなかった
- 紹介報酬も4名＋Level2/3含め計8件が漏れた（合計$304.03）

**影響ユーザー:**

出金レコード漏れ（5名）:
| ユーザー | 出金額 |
|----------|--------|
| 7D5A07 | $490.60 |
| A512FF | $262.57 |
| C703A5 | $75.94 |
| 694677 | $2.71 |
| 23176C | $2.71 |

紹介報酬漏れ（5名、$304.03）:
| ユーザー | 補填額 | Level |
|----------|--------|-------|
| 7D5A07 | $6.91 | L1 |
| 04FF0C | $138.20 | L1 |
| A512FF | $55.28 | L1 |
| 230F31 | $69.10 | L2 |
| 1F85EE | $34.54 | L3 |

**原因:**
1. **承認日の手動変更**: 3名（7D5A07, A512FF, C703A5）のNFT承認日が後から変更されていた
   - 実際の承認は3/27〜3/30だが、承認日を3/4〜3/8に書き換えた
   - これにより`affiliate_cycle`が再更新され、月末処理で漏れた
2. **新規ユーザー**: 2名（694677, 23176C）は3月に初回購入でaffiliate_cycleが新規作成された
3. **紹介報酬**: `approve_user_nft`のOSD上書きバグにより`users.operation_start_date`が未来日に変更され、紹介報酬計算から除外

**共通点:**
- 全5名が3月中に`approve_user_nft`によりaffiliate_cycleが更新/新規作成された
- 正常だった他のユーザーは2月出金完了バッチが最後のaffiliate_cycle更新だった

**追加発見:**
- 7D5A07とA512FFの`available_usdt`が過大（過去の出金完了時に減算されていなかった）
  - 7D5A07: $1,598.60 → 正しい値$518.39に修正
  - A512FF: $737.44 → 正しい値$274.48に修正
  - 原因: 過去の`complete_withdrawals_batch`が`available_usdt`をリセット方式で計算していた時期あり

**修正内容:**
- 出金レコード5名を手動作成
- 紹介報酬8件を手動補填、cum_usdt/available_usdt更新
- `process_monthly_withdrawals`に検証パス（二重チェック）追加
- `process_monthly_withdrawals`のtotal_amountをavailable_usdt全額に修正
- `check_monthly_integrity`関数を新規作成（4項目の自動整合性チェック）
- NFT購入ページの保有数表示バグ修正（$1,000→$1,100で割る）

**⚠️ 教訓: 承認日の手動変更は極力避けること**
- 承認日を変更するとaffiliate_cycleが再更新され、月末処理で予期しない漏れが発生する
- やむを得ず変更する場合は、月末処理後に`check_monthly_integrity`で検証すること

**関連スクリプト:**
- `scripts/FIX-march-missing-withdrawal-5users.sql`
- `scripts/FIX-march-missing-referral-all.sql`
- `scripts/FIX-7D5A07-march-referral-and-approve-bug.sql`
- `scripts/FIX-process-monthly-withdrawals-with-verification.sql`
- `scripts/CREATE-monthly-integrity-check.sql`

---

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

最終更新: 2026年9月5日
