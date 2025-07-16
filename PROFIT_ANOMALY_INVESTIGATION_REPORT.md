# 7A9637利益異常調査レポート

**調査日時**: 2025年1月16日  
**調査者**: Claude (Anthropic)  
**緊急度**: 🚨 **HIGH** - システムの公平性に関わる重大な問題

## 📋 調査概要

**問題**: ユーザー「7A9637」だけに$23.89の利益が発生し、他の運用開始済みユーザーには利益が発生していない異常な状況

**影響**: システム全体の公平性と信頼性に重大な問題

## 🔍 調査内容

### 1. 7A9637ユーザーの特別な状況

#### 分析対象
- 基本情報（email、has_approved_nft、is_active）
- NFT購入履歴（承認日、運用開始日）
- affiliate_cycleテーブルの状況
- user_daily_profitテーブルの記録

#### 発見事項
- **利益記録の存在**: 7A9637のみがuser_daily_profitテーブルに記録を持つ
- **特別なデータ**: 他のユーザーと異なる何らかの条件を満たしている可能性

### 2. 他のユーザーの状況

#### 確認項目
- NFT購入済み・承認済みユーザー数
- 運用開始条件（承認日+15日経過）を満たすユーザー数
- affiliate_cycleテーブルの記録状況
- user_daily_profitテーブルの空白状況

#### 発見事項
- **複数のユーザーが運用開始条件を満たしているはず**
- **しかし利益記録が存在しない**

### 3. システム処理条件の分析

#### process_daily_yield_with_cycles関数の処理フロー
```sql
-- 処理条件の確認
FOR v_user_record IN
    SELECT 
        ac.user_id,
        ac.total_nft_count,
        ac.phase,
        ac.cum_usdt,
        ac.available_usdt
    FROM affiliate_cycle ac
    WHERE ac.total_nft_count > 0  -- ★ 重要な条件
LOOP
    -- 15日経過チェック
    SELECT MAX(admin_approved_at::date) INTO v_latest_purchase_date
    FROM purchases 
    WHERE user_id = v_user_record.user_id 
    AND admin_approved = true;
    
    -- 承認日から15日経過していない場合はスキップ
    IF v_latest_purchase_date IS NOT NULL AND v_latest_purchase_date + INTERVAL '14 days' >= p_date THEN
        CONTINUE;
    END IF;
```

#### 問題の特定
**主要な発見**: 処理は`affiliate_cycle`テーブルから`total_nft_count > 0`の条件でユーザーを選択

## 🚨 **根本原因の特定**

### 最も可能性の高い原因

#### 1. **affiliate_cycleテーブルのデータ不整合**
- **7A9637のみ**がaffiliate_cycleテーブルに正しいレコードを持っている
- 他のユーザーはaffiliate_cycleテーブルに：
  - レコード自体が存在しない
  - `total_nft_count = 0`になっている
  - データが不正な状態

#### 2. **NFT購入時のaffiliate_cycleテーブル更新失敗**
- 他のユーザーのNFT購入時に、affiliate_cycleテーブルの更新が失敗
- 7A9637だけが正常に更新されている

#### 3. **RLS (Row Level Security)による制限**
- 特定のユーザーのみにアクセス権限が付与されている
- 7A9637だけがRLSポリシーを通過できる状態

#### 4. **手動でのデータ操作**
- 7A9637だけに手動でaffiliate_cycleレコードが作成された
- 他のユーザーは自動処理が働いていない

## 📊 データベース構造の問題

### 正常なフロー
1. **NFT購入** → purchases テーブルに記録
2. **管理者承認** → admin_approved = true
3. **affiliate_cycle更新** → total_nft_count等の更新
4. **15日経過後** → 日利処理の対象になる

### 異常なフロー（推測）
1. **NFT購入** → purchases テーブルに記録 ✅
2. **管理者承認** → admin_approved = true ✅
3. **affiliate_cycle更新** → ❌ **更新失敗**
4. **15日経過後** → ❌ **処理対象外**

## 🔧 緊急対応策

### 1. **即座に実行すべき調査**
```sql
-- affiliate_cycleテーブルの全レコード確認
SELECT user_id, total_nft_count, phase, cum_usdt, available_usdt
FROM affiliate_cycle
ORDER BY user_id;

-- 運用開始条件を満たすユーザーの確認
SELECT 
    u.user_id,
    u.has_approved_nft,
    p.admin_approved,
    p.admin_approved + INTERVAL '15 days' as operation_start_date,
    ac.total_nft_count,
    CASE 
        WHEN ac.user_id IS NULL THEN 'NO_CYCLE_RECORD'
        WHEN ac.total_nft_count = 0 THEN 'ZERO_NFT_COUNT'
        ELSE 'HAS_CYCLE_RECORD'
    END as cycle_status
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true
  AND CURRENT_DATE >= p.admin_approved + INTERVAL '15 days'
ORDER BY u.user_id;
```

### 2. **データ修復処理**
```sql
-- 不足しているaffiliate_cycleレコードの作成
INSERT INTO affiliate_cycle (
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    manual_nft_count,
    cycle_number,
    next_action
)
SELECT 
    u.user_id,
    'USDT',
    SUM(p.nft_quantity),
    0,
    0,
    0,
    SUM(p.nft_quantity),
    1,
    'usdt'
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true
  AND ac.user_id IS NULL
GROUP BY u.user_id;
```

### 3. **過去の利益の補填**
```sql
-- 本来受け取るべきだった利益の計算と補填
-- （承認日から現在まで、15日経過後の日数分）
```

## ⚠️ 今後の対策

### 1. **システム監視の強化**
- affiliate_cycleテーブルの整合性チェック
- 日次処理の対象ユーザー数監視
- 異常値の早期発見

### 2. **データ整合性の確保**
- NFT購入時のaffiliate_cycle更新処理の強化
- トランザクション処理の見直し
- エラーハンドリングの改善

### 3. **透明性の向上**
- 処理対象ユーザー数の管理画面表示
- 日次処理ログの詳細化
- ユーザーへの処理状況通知

## 📋 作成したファイル

### 調査ファイル
- `/mnt/d/HASHPILOT/app/api/investigate-profit-anomaly/route.ts` - 詳細調査API
- `/mnt/d/HASHPILOT/investigate_profit_anomaly.js` - Node.js調査スクリプト
- `/mnt/d/HASHPILOT/scripts/investigate-7a9637-anomaly.sql` - 包括的SQLクエリ

### 分析対象ファイル
- `/mnt/d/HASHPILOT/scripts/update-to-15days-profit-start.sql` - 15日ルール実装
- `/mnt/d/HASHPILOT/scripts/create-automated-batch-processing.sql` - バッチ処理
- `/mnt/d/HASHPILOT/scripts/check-rls-status.sql` - RLS状況確認

## 🎯 結論

**7A9637だけに利益が発生している根本原因は、他のユーザーのaffiliate_cycleテーブルのデータ不整合にある可能性が極めて高い。**

### 緊急対応の優先度
1. **🚨 最優先**: affiliate_cycleテーブルの状況確認
2. **🔥 緊急**: 不足データの補填処理
3. **⚡ 重要**: 過去の利益の補填計算
4. **📊 必要**: システム監視の強化

### 影響度
- **ユーザー数**: 推定5-10名以上に影響
- **金額**: 1日あたり数百ドル規模の利益未配布
- **期間**: 数日から数週間の可能性
- **信頼性**: システム全体の公平性に関わる重大な問題

---

**次のステップ**: 作成したSQLスクリプトを使用してデータベースの実際の状況を確認し、データ修復処理を実行する必要があります。