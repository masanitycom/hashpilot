# 管理画面UI V2対応の変更内容

## 変更方針

環境変数 `NEXT_PUBLIC_USE_YIELD_V2` で V1/V2 を切り替える

- `false` (デフォルト): V1システム（利率％入力）
- `true`: V2システム（金額$入力）

## 必要な変更

### 1. State追加（行47-60付近）

```typescript
// 既存
const [yieldRate, setYieldRate] = useState("")
const [marginRate, setMarginRate] = useState("30")
const [userRate, setUserRate] = useState(0)

// V2用に追加
const [totalProfitAmount, setTotalProfitAmount] = useState("")
const useV2 = process.env.NEXT_PUBLIC_USE_YIELD_V2 === 'true'
```

### 2. handleSubmit関数の変更（行266-334）

```typescript
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault()
  setIsLoading(true)
  setMessage(null)

  try {
    // 未来の日付チェック
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const selectedDate = new Date(date)
    selectedDate.setHours(0, 0, 0, 0)

    if (selectedDate > today) {
      throw new Error(\`❌ 未来の日付（\${date}）には設定できません。今日は \${today.toISOString().split('T')[0]} です。\`)
    }

    // V1 vs V2 分岐
    if (useV2) {
      // ========== V2システム（金額入力） ==========
      const profitAmount = Number.parseFloat(totalProfitAmount)

      console.log('🚀 日利設定開始（V2 - 金額入力）:', {
        date,
        total_profit_amount: profitAmount,
        is_test_mode: false
      })

      const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_v2', {
        p_date: date,
        p_total_profit_amount: profitAmount,
        p_is_test_mode: false
      })

      if (rpcError) {
        console.error('❌ RPC関数エラー:', rpcError)
        throw new Error(\`日利処理エラー: \${rpcError.message}\`)
      }

      const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

      console.log('✅ V2 RPC関数実行成功:', result)

      setMessage({
        type: "success",
        text: \`✅ \${result.message || '日利設定完了（V2）'}

処理詳細:
• 運用利益: \$\${profitAmount.toFixed(2)}
• NFT総数: \${result.details?.input?.total_nft_count || 0}個
• NFT単価利益: \$\${(result.details?.input?.profit_per_nft || 0).toFixed(3)}
• 個人利益配布: \$\${(result.details?.distribution?.total_distributed || 0).toFixed(2)}
• 紹介報酬配布: \$\${(result.details?.distribution?.total_referral || 0).toFixed(2)}（\${result.details?.distribution?.referral_count || 0}件）
• NFT自動付与: \${result.details?.distribution?.auto_nft_count || 0}件\`,
      })

      setTotalProfitAmount("")
      setDate(new Date().toISOString().split("T")[0])
      fetchHistory()
      fetchStats()

    } else {
      // ========== V1システム（利率入力） ==========
      const yieldValue = Number.parseFloat(yieldRate) / 100
      const marginValue = Number.parseFloat(marginRate) / 100

      console.log('🚀 日利設定開始（V1 - 利率入力）:', {
        date,
        yield_rate: yieldValue,
        margin_rate: marginValue,
        is_test_mode: false
      })

      const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_with_cycles', {
        p_date: date,
        p_yield_rate: yieldValue,
        p_margin_rate: marginValue,
        p_is_test_mode: false,
        p_skip_validation: false
      })

      if (rpcError) {
        console.error('❌ RPC関数エラー:', rpcError)
        throw new Error(\`日利処理エラー: \${rpcError.message}\`)
      }

      const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

      console.log('✅ V1 RPC関数実行成功:', result)

      setMessage({
        type: "success",
        text: \`✅ \${result.message || '日利設定完了（V1）'}

処理詳細:
• 日利配布: \${result.total_users || 0}名に総額\$\${(result.total_user_profit || 0).toFixed(2)}
• 紹介報酬: \${result.referral_rewards_processed || 0}名に配布
• NFT自動付与: \${result.auto_nft_purchases || 0}名に付与
• サイクル更新: \${result.cycle_updates || 0}件\`,
      })

      setYieldRate("")
      setDate(new Date().toISOString().split("T")[0])
      fetchHistory()
      fetchStats()
    }

  } catch (error: any) {
    console.error('❌ 日利設定エラー:', error)
    setMessage({
      type: "error",
      text: \`エラー: \${error.message}\`,
    })
  } finally {
    setIsLoading(false)
  }
}
```

### 3. フォーム表示の変更（行896-991）

```tsx
<form onSubmit={handleSubmit} className="space-y-4">
  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
    {/* 日付フィールド（共通） */}
    <div className="space-y-2">
      <Label htmlFor="date" className="text-white">
        日付
      </Label>
      <Input
        id="date"
        type="date"
        value={date}
        onChange={(e) => setDate(e.target.value)}
        required
        className="bg-gray-700 border-gray-600 text-white"
      />
    </div>

    {/* V1/V2 分岐 */}
    {useV2 ? (
      // ========== V2: 金額入力 ==========
      <>
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="totalProfitAmount" className="text-white flex items-center gap-2">
            運用利益（$）
            <Badge className="bg-blue-600">V2システム</Badge>
          </Label>
          <Input
            id="totalProfitAmount"
            type="number"
            step="0.01"
            min="-100000"
            max="1000000"
            value={totalProfitAmount}
            onChange={(e) => setTotalProfitAmount(e.target.value)}
            placeholder="例: 1580.32 (マイナス可)"
            required
            className="bg-gray-700 border-gray-600 text-white"
          />
          <p className="text-xs text-gray-400">
            今日の運用利益を金額（$）で入力してください。マイナスの場合は -1580.32 のように入力。
          </p>
          {stats && totalProfitAmount && (
            <div className="mt-2 p-3 bg-gray-700 rounded-lg">
              <p className="text-sm font-medium text-white">予想配布額:</p>
              <p className={\`text-lg font-bold \${Number.parseFloat(totalProfitAmount) >= 0 ? "text-green-400" : "text-red-400"}\`}>
                個人利益: \${(Number.parseFloat(totalProfitAmount) * 0.7 * 0.6).toFixed(2)}
              </p>
              <p className="text-xs text-gray-400">
                NFT総数: {(stats.total_investment / 1000).toFixed(0)}個
              </p>
            </div>
          )}
        </div>
      </>
    ) : (
      // ========== V1: 利率入力 ==========
      <>
        <div className="space-y-2">
          <Label htmlFor="yieldRate" className="text-white flex items-center gap-2">
            日利率 (%)
            <Badge className="bg-gray-600">V1システム</Badge>
          </Label>
          <Input
            id="yieldRate"
            type="number"
            step="0.001"
            min="-10"
            max="100"
            value={yieldRate}
            onChange={(e) => setYieldRate(e.target.value)}
            placeholder="例: 1.500 (マイナス可)"
            required
            className="bg-gray-700 border-gray-600 text-white"
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="marginRate" className="text-white">
            マージン率 (%)
          </Label>
          <Input
            id="marginRate"
            type="number"
            step="1"
            min="0"
            max="100"
            value={marginRate}
            onChange={(e) => {
              const value = Number.parseFloat(e.target.value) || 0
              if (value <= 100) {
                setMarginRate(e.target.value)
              } else {
                setMarginRate("100")
                setMessage({
                  type: "warning",
                  text: "マージン率は100%以下に設定してください"
                })
              }
            }}
            placeholder="例: 30"
            required
            className="bg-gray-700 border-gray-600 text-white"
          />
          <p className="text-xs text-gray-400">
            ⚠️ 通常は30%程度。100%を超える値は設定できません
          </p>
        </div>
      </>
    )}
  </div>

  {/* V1のみ：ユーザー受取率表示 */}
  {!useV2 && (
    <div className="space-y-2">
      <Label className="text-white">ユーザー受取率</Label>
      <div className={\`text-2xl font-bold \${userRate >= 0 ? "text-green-400" : "text-red-400"}\`}>
        {userRate.toFixed(3)}%
      </div>
      <p className="text-sm text-gray-400">
        {Number.parseFloat(yieldRate) !== 0
          ? \`\${yieldRate}% × (1 - \${marginRate}%/100) × 0.6 = ユーザー受取 \${userRate.toFixed(3)}%\`
          : \`0% = ユーザー受取 0%\`
        }
      </p>
      {stats && yieldRate && (
        <div className="mt-2 p-3 bg-gray-700 rounded-lg">
          <p className="text-sm font-medium text-white">予想配布額:</p>
          <p className={\`text-lg font-bold \${userRate >= 0 ? "text-green-400" : "text-red-400"}\`}>
            \${((stats.total_investment * userRate) / 100).toLocaleString()}
          </p>
          <p className="text-xs text-gray-400">{stats.total_users}名のユーザーに配布予定</p>
        </div>
      )}
    </div>
  )}

  <Button
    type="submit"
    disabled={isLoading}
    className="w-full md:w-auto bg-red-600 hover:bg-red-700"
  >
    {isLoading ? "処理中..." : "日利を設定"}
  </Button>
</form>
```

## 実装手順

1. ✅ 環境変数例ファイル作成済み（`.env.local.v2-migration-example`）
2. ⏳ `app/admin/yield/page.tsx` を上記の変更で修正
3. ⏳ ローカルでテスト（`NEXT_PUBLIC_USE_YIELD_V2=false`）
4. ⏳ ローカルでテスト（`NEXT_PUBLIC_USE_YIELD_V2=true`）
5. ⏳ コミット＆プッシュ（V1モードのまま）
6. ⏳ 移行日に環境変数を変更してデプロイ

## 注意事項

- この変更はV1の動作に影響しません
- 環境変数が未設定の場合はV1モードで動作（デフォルト）
- V2モードに切り替えるまでV1として動作し続けます
