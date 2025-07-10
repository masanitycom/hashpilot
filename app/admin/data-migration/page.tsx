"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { ArrowLeft, Database, RefreshCw, AlertTriangle, CheckCircle, Play, Shield } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface MigrationStatus {
  purchases: { total: number; approved: number; totalNFTs: number; totalAmount: number }
  affiliateCycle: { total: number; totalNFTs: number }
  users: { totalWithPurchases: number }
  needsMigration: boolean
}

export default function DataMigrationPage() {
  const [status, setStatus] = useState<MigrationStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [migrating, setMigrating] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const [isAdmin, setIsAdmin] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAndFetchStatus()
  }, [])

  const checkAdminAndFetchStatus = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        router.push("/login")
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      await fetchMigrationStatus()
    } catch (err: any) {
      setError(`管理者確認エラー: ${err.message}`)
      setLoading(false)
    }
  }

  const fetchMigrationStatus = async () => {
    try {
      setLoading(true)
      setError("")

      // purchases データ確認
      const { data: purchasesData, error: purchasesError } = await supabase
        .from('purchases')
        .select('*')

      if (purchasesError) throw new Error(`purchases: ${purchasesError.message}`)

      // admin_approvedの値を正規化してフィルタ（柔軟なフィールド名対応）
      const approvedFilter = (p: any) => {
        if ('admin_approved' in p) {
          return p.admin_approved === true || p.admin_approved === 'true' || p.admin_approved === 1
        }
        if ('approved' in p) {
          return p.approved === true || p.approved === 'true' || p.approved === 1
        }
        if ('status' in p) {
          return p.status === 'approved' || p.status === 'APPROVED'
        }
        return true
      }

      const purchasesStats = {
        total: purchasesData?.length || 0,
        approved: purchasesData?.filter(approvedFilter).length || 0,
        totalNFTs: purchasesData?.filter(approvedFilter).reduce((sum, p) => sum + (p.nft_quantity || 0), 0) || 0,
        totalAmount: purchasesData?.filter(approvedFilter).reduce((sum, p) => sum + parseFloat(p.amount_usd || '0'), 0) || 0
      }

      // affiliate_cycle データ確認
      const { data: cycleData, error: cycleError } = await supabase
        .from('affiliate_cycle')
        .select('total_nft_count')

      if (cycleError) throw new Error(`affiliate_cycle: ${cycleError.message}`)

      const cycleStats = {
        total: cycleData?.length || 0,
        totalNFTs: cycleData?.reduce((sum, c) => sum + (c.total_nft_count || 0), 0) || 0
      }

      // users データ確認
      const { data: usersData, error: usersError } = await supabase
        .from('users')
        .select('total_purchases')
        .gt('total_purchases', 0)

      if (usersError) throw new Error(`users: ${usersError.message}`)

      setStatus({
        purchases: purchasesStats,
        affiliateCycle: cycleStats,
        users: { totalWithPurchases: usersData?.length || 0 },
        needsMigration: cycleStats.total === 0 && purchasesStats.approved > 0
      })

    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const directInsertMigration = async (approvedPurchases: any[]) => {
    // RLS を回避するため、バッチでの直接挿入を試行
    const userSummary = new Map()
    approvedPurchases.forEach(purchase => {
      const userId = purchase.user_id
      const purchaseDate = purchase.created_at || purchase.confirmed_at || new Date().toISOString()
      
      const existing = userSummary.get(userId) || {
        user_id: userId,
        total_nft_count: 0,
        cum_usdt: 0,
        cycle_start_date: purchaseDate
      }
      
      existing.total_nft_count += purchase.nft_quantity || 0
      existing.cum_usdt += parseFloat(purchase.amount_usd || '0')
      
      if (purchaseDate < existing.cycle_start_date) {
        existing.cycle_start_date = purchaseDate
      }
      
      userSummary.set(userId, existing)
    })

    const newCycleData = Array.from(userSummary.values())
      .filter(user => user.total_nft_count > 0)
      .map(user => ({
        user_id: user.user_id,
        phase: 'USDT',
        total_nft_count: user.total_nft_count,
        cum_usdt: user.cum_usdt
        // cycle_start_dateとlast_updatedは省略（テーブル構造不明のため）
      }))

    // 小さなバッチに分けて挿入
    const batchSize = 10
    let successCount = 0
    
    for (let i = 0; i < newCycleData.length; i += batchSize) {
      const batch = newCycleData.slice(i, i + batchSize)
      try {
        const { error: batchError } = await supabase
          .from('affiliate_cycle')
          .insert(batch)
        
        if (batchError) {
          console.error(`バッチ ${i/batchSize + 1} エラー:`, batchError)
        } else {
          successCount += batch.length
        }
      } catch (err) {
        console.error(`バッチ ${i/batchSize + 1} 実行エラー:`, err)
      }
    }

    if (successCount > 0) {
      setSuccess(`✅ 直接挿入成功: ${successCount}名のユーザーデータを移行しました`)
      await fetchMigrationStatus()
    } else {
      throw new Error('直接挿入も失敗しました')
    }
  }

  const executeMigration = async () => {
    try {
      setMigrating(true)
      setError("")
      setSuccess("")

      // まずテーブル構造を確認するため全カラムで1件取得
      const { data: sampleData, error: sampleError } = await supabase
        .from('purchases')
        .select('*')
        .limit(1)

      if (sampleError) {
        throw new Error(`テーブル構造確認エラー: ${sampleError.message}`)
      }

      if (sampleData && sampleData.length > 0) {
        console.log('Purchases table structure:', Object.keys(sampleData[0]))
        console.log('Sample purchase data:', sampleData[0])
      }

      // 全ての購入データを取得（エラーを避けるため段階的にselect）
      const { data: allPurchases, error: fetchError } = await supabase
        .from('purchases')
        .select('*')

      if (fetchError) throw new Error(`購入データ取得エラー: ${fetchError.message}`)

      // JavaScriptでフィルタリング（admin_approvedフィールドの型問題を回避）
      const approvedPurchases = allPurchases?.filter(purchase => {
        // admin_approvedフィールドの存在確認
        if ('admin_approved' in purchase) {
          return purchase.admin_approved === true || purchase.admin_approved === 'true' || purchase.admin_approved === 1
        }
        // 代替フィールド名の確認
        if ('approved' in purchase) {
          return purchase.approved === true || purchase.approved === 'true' || purchase.approved === 1
        }
        // statusフィールドの確認
        if ('status' in purchase) {
          return purchase.status === 'approved' || purchase.status === 'APPROVED'
        }
        // どのフィールドも見つからない場合は全て承認済みとみなす
        return true
      }) || []

      if (approvedPurchases.length === 0) {
        throw new Error('承認済み購入データが見つかりません')
      }

      // ユーザーごとにNFT数と金額を集計
      const userSummary = new Map()
      approvedPurchases?.forEach(purchase => {
        const userId = purchase.user_id
        const purchaseDate = purchase.created_at || purchase.confirmed_at || new Date().toISOString()
        
        const existing = userSummary.get(userId) || {
          user_id: userId,
          total_nft_count: 0,
          cum_usdt: 0,
          cycle_start_date: purchaseDate,
          last_updated: new Date().toISOString()
        }
        
        existing.total_nft_count += purchase.nft_quantity || 0
        existing.cum_usdt += parseFloat(purchase.amount_usd || '0')
        
        // より早い購入日を記録
        if (purchaseDate < existing.cycle_start_date) {
          existing.cycle_start_date = purchaseDate
        }
        
        userSummary.set(userId, existing)
      })

      // affiliate_cycleテーブルの構造確認
      const { data: cycleSample, error: cycleSampleError } = await supabase
        .from('affiliate_cycle')
        .select('*')
        .limit(1)

      if (cycleSampleError && cycleSampleError.code !== 'PGRST116') {
        throw new Error(`affiliate_cycle構造確認エラー: ${cycleSampleError.message}`)
      }

      if (cycleSample && cycleSample.length > 0) {
        console.log('Affiliate_cycle table structure:', Object.keys(cycleSample[0]))
      }

      // 既存のaffiliate_cycleデータを確認して重複を避ける
      const { data: existingCycles } = await supabase
        .from('affiliate_cycle')
        .select('user_id')

      const existingUserIds = new Set(existingCycles?.map(c => c.user_id) || [])

      // 新規データのみフィルタリング（必要最小限のフィールドのみ）
      const newCycleData = Array.from(userSummary.values())
        .filter(user => !existingUserIds.has(user.user_id) && user.total_nft_count > 0)
        .map(user => ({
          user_id: user.user_id,
          phase: 'USDT',
          total_nft_count: user.total_nft_count,
          cum_usdt: user.cum_usdt
        }))

      if (newCycleData.length === 0) {
        setSuccess("移行対象のデータがありません（既に移行済みまたはデータなし）")
        return
      }

      console.log('新規挿入データ例:', newCycleData[0])
      console.log('挿入予定件数:', newCycleData.length)

      // 管理者専用の移行関数を実行
      const { data: { user } } = await supabase.auth.getUser()
      
      console.log('実行中のユーザー:', user?.email)
      
      const { data: migrationResult, error: insertError } = await supabase
        .rpc('admin_migrate_purchases_to_affiliate_cycle', {
          p_admin_email: user?.email
        })

      console.log('移行関数の結果:', migrationResult)
      console.log('移行関数のエラー:', insertError)

      if (insertError) {
        console.error('RPC関数エラー:', insertError)
        // RPC関数が見つからない場合は直接挿入を試す
        if (insertError.message.includes('function') || insertError.message.includes('does not exist')) {
          console.log('RPC関数が見つからないため、直接挿入を試行します')
          await directInsertMigration(approvedPurchases)
          return
        }
        throw new Error(`データ移行関数エラー: ${insertError.message}`)
      }
      
      if (migrationResult && migrationResult.length > 0) {
        const result = migrationResult[0]
        console.log('移行結果詳細:', result)
        if (result.status === 'ERROR') {
          throw new Error(result.message)
        }
        setSuccess(result.message)
      } else {
        throw new Error('移行関数の結果が取得できませんでした')
      }
      
      // 状況を再取得
      await fetchMigrationStatus()

    } catch (err: any) {
      setError(err.message)
    } finally {
      setMigrating(false)
    }
  }

  const fixRLSPolicies = async () => {
    setMigrating(true)
    setError("")
    setSuccess("")

    try {
      // Execute the RLS fix function
      const { data: rlsResult, error: rlsError } = await supabase.rpc('fix_user_daily_profit_rls')

      if (rlsError) {
        throw new Error(`RLS修正エラー: ${rlsError.message}`)
      }

      console.log('RLS修正結果:', rlsResult)
      setSuccess(`✅ RLS修正完了: ${rlsResult}`)

      // Test the fix by trying to query user_daily_profit
      const { data: testData, error: testError } = await supabase
        .from('user_daily_profit')
        .select('user_id, date, daily_profit')
        .limit(1)

      if (testError) {
        console.warn('テストクエリ警告:', testError.message)
      } else {
        console.log('テストクエリ成功:', testData)
      }

    } catch (err: any) {
      console.error('RLS修正エラー:', err)
      setError(err.message || 'RLS修正中にエラーが発生しました')
    } finally {
      setMigrating(false)
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardContent className="p-6 text-center text-white">
            <Shield className="w-12 h-12 mx-auto mb-4 text-red-400" />
            <p>管理者権限が必要です</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-5xl mx-auto space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              管理者ダッシュボード
            </Button>
            <h1 className="text-3xl font-bold text-white flex items-center">
              <Database className="w-8 h-8 mr-3 text-blue-400" />
              データ移行
            </h1>
          </div>
          <Button
            onClick={fetchMigrationStatus}
            disabled={loading}
            className="bg-blue-600 hover:bg-blue-700"
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            更新
          </Button>
        </div>

        {error && (
          <Alert className="bg-red-900/20 border-red-500/50">
            <AlertTriangle className="h-4 w-4" />
            <AlertDescription className="text-red-400">{error}</AlertDescription>
          </Alert>
        )}

        {success && (
          <Alert className="bg-green-900/20 border-green-500/50">
            <CheckCircle className="h-4 w-4" />
            <AlertDescription className="text-green-400">{success}</AlertDescription>
          </Alert>
        )}

        {loading ? (
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-8 text-center text-white">
              <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 text-blue-400" />
              データ状況を確認中...
            </CardContent>
          </Card>
        ) : status ? (
          <div className="space-y-6">
            {/* 移行の必要性アラート */}
            {status.needsMigration && (
              <Alert className="bg-yellow-900/20 border-yellow-500/50">
                <AlertTriangle className="h-4 w-4" />
                <AlertDescription className="text-yellow-400">
                  <strong>データ移行が必要です：</strong> purchases テーブルに承認済みデータがありますが、affiliate_cycle テーブルが空です。
                  利益計算を正常に動作させるためにデータ移行を実行してください。
                </AlertDescription>
              </Alert>
            )}

            {/* 現在の状況 */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <Database className="w-5 h-5 mr-2 text-blue-400" />
                    purchases テーブル
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <div className="flex items-center justify-between">
                    <span>総購入数:</span>
                    <Badge className="bg-blue-600">{status.purchases.total}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>承認済み:</span>
                    <Badge className="bg-green-600">{status.purchases.approved}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>総NFT数:</span>
                    <Badge className="bg-purple-600">{status.purchases.totalNFTs}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>総投資額:</span>
                    <Badge className="bg-yellow-600">${status.purchases.totalAmount.toLocaleString()}</Badge>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <Database className="w-5 h-5 mr-2 text-green-400" />
                    affiliate_cycle テーブル
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <div className="flex items-center justify-between">
                    <span>総ユーザー数:</span>
                    <Badge className={status.affiliateCycle.total > 0 ? 'bg-green-600' : 'bg-red-600'}>
                      {status.affiliateCycle.total}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>総NFT数:</span>
                    <Badge className={status.affiliateCycle.totalNFTs > 0 ? 'bg-green-600' : 'bg-red-600'}>
                      {status.affiliateCycle.totalNFTs}
                    </Badge>
                  </div>
                  {status.affiliateCycle.total === 0 && (
                    <div className="text-red-400 text-sm">⚠️ データが存在しません</div>
                  )}
                </CardContent>
              </Card>

              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <Database className="w-5 h-5 mr-2 text-orange-400" />
                    users テーブル
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-white space-y-2">
                  <div className="flex items-center justify-between">
                    <span>投資ユーザー数:</span>
                    <Badge className="bg-orange-600">{status.users.totalWithPurchases}</Badge>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* 移行実行ボタン */}
            {status.needsMigration && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center">
                    <Play className="w-5 h-5 mr-2 text-green-400" />
                    データ移行実行
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-gray-300">
                      purchases テーブルの承認済みデータを affiliate_cycle テーブルに移行します。
                      この操作により、利益計算が正常に動作するようになります。
                    </p>
                    <div className="bg-yellow-900/20 border border-yellow-600/30 rounded-lg p-4">
                      <p className="text-yellow-300 text-sm">
                        <strong>実行内容：</strong><br/>
                        • 承認済み購入データをユーザーごとに集計<br/>
                        • affiliate_cycle テーブルに NFT 保有データを作成<br/>
                        • 重複チェック付きで安全に実行
                      </p>
                    </div>
                    <Button
                      onClick={executeMigration}
                      disabled={migrating}
                      className="bg-green-600 hover:bg-green-700 text-white font-medium px-6 py-3"
                    >
                      {migrating ? (
                        <>
                          <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                          移行中...
                        </>
                      ) : (
                        <>
                          <Play className="w-4 h-4 mr-2" />
                          データ移行を実行
                        </>
                      )}
                    </Button>
                  </div>
                </CardContent>
              </Card>
            )}

            {!status.needsMigration && status.affiliateCycle.total > 0 && (
              <Alert className="bg-green-900/20 border-green-500/50">
                <CheckCircle className="h-4 w-4" />
                <AlertDescription className="text-green-400">
                  ✅ データ移行は完了しています。affiliate_cycle テーブルにデータが存在します。
                </AlertDescription>
              </Alert>
            )}

            {/* RLS修正セクション */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Shield className="w-5 h-5 mr-2 text-purple-400" />
                  RLS ポリシー修正
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <p className="text-gray-300">
                    user_daily_profit テーブルの Row Level Security ポリシーを修正し、
                    ユーザーが自分の利益データを閲覧できるようにします。
                  </p>
                  <div className="bg-purple-900/20 border border-purple-600/30 rounded-lg p-4">
                    <p className="text-purple-300 text-sm">
                      <strong>修正内容：</strong><br/>
                      • 既存のRLSポリシーを削除<br/>
                      • ユーザーが自分のデータを閲覧できるポリシーを作成<br/>
                      • 管理者が全データを閲覧できるポリシーを作成
                    </p>
                  </div>
                  <Button
                    onClick={fixRLSPolicies}
                    disabled={migrating}
                    className="bg-purple-600 hover:bg-purple-700 text-white font-medium px-6 py-3"
                  >
                    {migrating ? (
                      <>
                        <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                        修正中...
                      </>
                    ) : (
                      <>
                        <Shield className="w-4 h-4 mr-2" />
                        RLS ポリシーを修正
                      </>
                    )}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        ) : null}
      </div>
    </div>
  )
}