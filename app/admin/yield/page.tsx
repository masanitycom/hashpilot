"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import {
  CalendarIcon,
  TrendingUpIcon,
  UsersIcon,
  DollarSignIcon,
  AlertCircle,
  CheckCircle,
  InfoIcon,
  Trash2,
  Shield,
  ArrowLeft,
  RefreshCw,
  Edit,
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface YieldHistoryV2 {
  id: string
  date: string
  total_profit_amount: number
  total_nft_count: number
  profit_per_nft: number
  cumulative_gross_profit: number
  cumulative_fee: number
  cumulative_net_profit: number
  daily_pnl: number
  distribution_dividend: number
  distribution_affiliate: number
  distribution_stock: number
  is_month_end: boolean
  created_at: string
}

interface YieldStats {
  total_users: number
  active_users_count: number
  total_nft_count: number
  total_investment: number
  total_investment_pending: number
  pegasus_investment: number
  total_distributed: number
  latest_cumulative_net: number
}

export default function AdminYieldPage() {
  const [date, setDate] = useState(new Date().toISOString().split("T")[0])
  const [totalProfitAmount, setTotalProfitAmount] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)
  const [history, setHistory] = useState<YieldHistoryV2[]>([])
  const [stats, setStats] = useState<YieldStats | null>(null)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [authLoading, setAuthLoading] = useState(true)
  const [error, setError] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        setAuthLoading(false)
        router.push("/login")
        return
      }

      setCurrentUser(user)

      // 緊急対応: basarasystems@gmail.com と support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        setAuthLoading(false)
        fetchHistory()
        fetchStats()
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin check error:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()

        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          setAuthLoading(false)
          fetchHistory()
          fetchStats()
          return
        }

        setError("管理者権限の確認でエラーが発生しました")
        setAuthLoading(false)
        return
      }

      if (!adminCheck) {
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()

        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          setAuthLoading(false)
          fetchHistory()
          fetchStats()
          return
        }

        alert("管理者権限がありません")
        setAuthLoading(false)
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      setAuthLoading(false)
      fetchHistory()
      fetchStats()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
      setAuthLoading(false)
    }
  }

  const fetchHistory = async () => {
    try {
      const { data, error } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .order("date", { ascending: false })
        .limit(10)

      if (error) throw error
      setHistory(data || [])
    } catch (error) {
      console.error("履歴取得エラー:", error)
    }
  }

  const fetchStats = async () => {
    try {
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("id")
        .eq("is_active", true)
        .eq("has_approved_nft", true)

      if (usersError) throw usersError

      // 運用中のNFT数を取得（ペガサス除く）
      const today = new Date().toISOString().split('T')[0]

      // NFTマスターデータを取得
      const { data: nftData, error: nftError } = await supabase
        .from("nft_master")
        .select("id, user_id")
        .is("buyback_date", null)

      if (nftError) {
        console.error("NFTデータ取得エラー:", nftError)
        throw nftError
      }

      // ユーザー情報を取得
      const userIds = [...new Set(nftData?.map((nft: any) => nft.user_id) || [])]
      const { data: usersInfo, error: usersInfoError } = await supabase
        .from("users")
        .select("id, operation_start_date, is_pegasus_exchange")
        .in("id", userIds)

      if (usersInfoError) {
        console.error("ユーザー情報取得エラー:", usersInfoError)
        throw usersInfoError
      }

      // ユーザー情報をマップに変換
      const userMap = new Map(usersInfo?.map((u: any) => [u.id, u]) || [])

      // 運用中のNFTをフィルタリング
      const activeNfts = nftData?.filter((nft: any) => {
        const user = userMap.get(nft.user_id)
        if (!user) return false
        const opStartDate = user.operation_start_date
        const isPegasus = user.is_pegasus_exchange
        return !isPegasus && opStartDate && opStartDate <= today
      }) || []

      const totalNftCount = activeNfts.length

      // 運用中NFTを持つユニークユーザー数を取得
      const activeUserIds = new Set(activeNfts.map((nft: any) => nft.user_id))
      const activeUsersCount = activeUserIds.size

      // 全承認済み購入を取得
      const { data: purchasesData, error: purchasesError } = await supabase
        .from("purchases")
        .select("amount_usd, user_id")
        .eq("admin_approved", true)

      if (purchasesError) {
        console.error("購入データ取得エラー:", purchasesError)
        throw purchasesError
      }

      // 運用中と運用開始前に分けて集計（ペガサスユーザーは除外）
      const totalInvestmentActive = purchasesData?.reduce((sum, p: any) => {
        const user = userMap.get(p.user_id)
        if (!user) return sum
        const opStartDate = user.operation_start_date
        const isPegasus = user.is_pegasus_exchange
        if (!isPegasus && opStartDate && opStartDate <= today) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      const totalInvestmentPending = purchasesData?.reduce((sum, p: any) => {
        const user = userMap.get(p.user_id)
        if (!user) return sum
        const opStartDate = user.operation_start_date
        const isPegasus = user.is_pegasus_exchange
        if (!isPegasus && opStartDate && opStartDate > today) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      // ペガサスユーザーの投資額を別途集計
      const pegasusInvestment = purchasesData?.reduce((sum, p: any) => {
        const user = userMap.get(p.user_id)
        if (!user) return sum
        const isPegasus = user.is_pegasus_exchange
        if (isPegasus) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      // 累積配布額（最新のN_d）
      const { data: latestYield, error: latestYieldError } = await supabase
        .from("daily_yield_log_v2")
        .select("cumulative_net_profit")
        .order("date", { ascending: false })
        .limit(1)
        .single()

      if (latestYieldError && latestYieldError.code !== 'PGRST116') {
        console.warn("latest yield取得エラー:", latestYieldError)
      }

      const totalInvestment = totalInvestmentActive

      setStats({
        total_users: usersData?.length || 0,
        active_users_count: activeUsersCount,
        total_nft_count: totalNftCount,
        total_investment: totalInvestment,
        total_investment_pending: totalInvestmentPending,
        pegasus_investment: pegasusInvestment,
        total_distributed: latestYield?.cumulative_net_profit || 0,
        latest_cumulative_net: latestYield?.cumulative_net_profit || 0,
      })
    } catch (error) {
      console.error("統計取得エラー:", error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setMessage(null)

    try {
      // ========== 重要：未来の日付チェック ==========
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const selectedDate = new Date(date)
      selectedDate.setHours(0, 0, 0, 0)

      if (selectedDate > today) {
        throw new Error(`❌ 未来の日付（${date}）には設定できません。今日は ${today.toISOString().split('T')[0]} です。`)
      }

      const profitAmount = Number.parseFloat(totalProfitAmount)

      if (isNaN(profitAmount)) {
        throw new Error("有効な金額を入力してください")
      }

      console.log('🚀 日利設定開始（v2システム）:', {
        date,
        total_profit_amount: profitAmount,
        is_test_mode: false
      })

      // RPC関数を呼び出す（v2システム）
      const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_v2', {
        p_date: date,
        p_total_profit_amount: profitAmount,
        p_is_test_mode: false
      })

      if (rpcError) {
        console.error('❌ RPC関数エラー:', rpcError)
        throw new Error(`日利処理エラー: ${rpcError.message}`)
      }

      const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

      console.log('✅ RPC関数実行成功:', result)

      if (result.status !== 'SUCCESS') {
        throw new Error(result.message || '日利処理に失敗しました')
      }

      const details = result.details

      setMessage({
        type: "success",
        text: `✅ ${result.message || '日利設定完了'}

処理詳細:
• 入力: 全体利益 $${details.input.total_profit_amount.toFixed(2)}
• NFT数: ${details.input.total_nft_count}個 → 1NFTあたり $${details.input.profit_per_nft.toFixed(4)}

累積計算:
• 累積利益（手数料前）: $${details.cumulative.G_d.toFixed(2)}
• 累積手数料: $${details.cumulative.F_d.toFixed(2)}
• 顧客累積利益: $${details.cumulative.N_d.toFixed(2)}
• 当日利益: $${details.cumulative['ΔN_d'].toFixed(2)}

分配:
• 配当 (60%): $${details.distribution.dividend.toFixed(2)}
• アフィリ (30%): $${details.distribution.affiliate.toFixed(2)}
• ストック (10%): $${details.distribution.stock.toFixed(2)}`,
      })

      setTotalProfitAmount("")
      setDate(new Date().toISOString().split("T")[0])
      fetchHistory()
      fetchStats()
    } catch (error: any) {
      console.error('❌ 日利設定エラー:', error)
      setMessage({
        type: "error",
        text: `エラー: ${error.message}`,
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleEdit = (item: YieldHistoryV2) => {
    // フォームに既存データをセット
    setDate(item.date)
    setTotalProfitAmount(item.total_profit_amount.toFixed(2))

    // ページ上部のフォームにスクロール
    window.scrollTo({ top: 0, behavior: 'smooth' })

    setMessage({
      type: "warning",
      text: `${item.date}の日利設定を修正モードで読み込みました。変更後、「日利を設定」ボタンで保存してください。`,
    })
  }

  const handleCancel = async (cancelDate: string) => {
    if (!confirm(`${cancelDate}の日利設定をキャンセルしますか？この操作は取り消せません。`)) {
      return
    }

    try {
      const { data: { user } } = await supabase.auth.getUser()

      if (!user) {
        throw new Error("ユーザー認証が必要です")
      }

      // まず削除対象データの存在確認
      const { data: existingData, error: checkExistError } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .eq("date", cancelDate)

      console.log("削除対象データ:", existingData)

      if (checkExistError) {
        throw new Error(`データ確認エラー: ${checkExistError.message}`)
      }

      if (!existingData || existingData.length === 0) {
        throw new Error("削除対象のデータが見つかりません")
      }

      // IDを使用して削除を試みる
      const targetId = existingData[0].id
      console.log("削除対象ID:", targetId)

      // 関連データを削除
      const { error: deleteYieldError } = await supabase
        .from("daily_yield_log_v2")
        .delete()
        .eq("id", targetId)

      if (deleteYieldError) {
        console.error("daily_yield_log_v2削除エラー:", deleteYieldError)
        throw new Error(`日利設定の削除に失敗: ${deleteYieldError.message}`)
      }

      // nft_daily_profitから削除
      const { error: deleteProfitError } = await supabase
        .from("nft_daily_profit")
        .delete()
        .eq("date", cancelDate)

      if (deleteProfitError) {
        console.warn("nft_daily_profit削除エラー:", deleteProfitError)
      }

      // user_referral_profitから削除
      const { error: deleteReferralError } = await supabase
        .from("user_referral_profit")
        .delete()
        .eq("date", cancelDate)

      if (deleteReferralError) {
        console.warn("user_referral_profit削除エラー:", deleteReferralError)
      }

      // stock_fundから削除
      const { error: deleteStockError } = await supabase
        .from("stock_fund")
        .delete()
        .eq("date", cancelDate)

      if (deleteStockError) {
        console.warn("stock_fund削除エラー:", deleteStockError)
      }

      setMessage({
        type: "success",
        text: `${cancelDate}の日利設定をキャンセルしました`,
      })

      // 少し待ってから再取得
      setTimeout(() => {
        fetchHistory()
        fetchStats()
      }, 500)

    } catch (error: any) {
      console.error("キャンセルエラー:", error)
      setMessage({
        type: "error",
        text: error.message || "キャンセルに失敗しました",
      })
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>管理者権限が必要です。</p>
            <Button
              onClick={() => router.push("/dashboard")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-7xl mx-auto p-4 space-y-6">
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
              <Shield className="w-8 h-8 mr-3 text-blue-400" />
              日利設定（v2システム）
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Badge variant="destructive" className="text-sm">
              本番モード
            </Badge>
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
          </div>
        </div>

        {/* システム説明 */}
        <Card className="border-2 bg-gray-800 border-blue-500">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-blue-400">
              <InfoIcon className="h-5 w-5" />
              新システムの仕様
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-blue-300 space-y-2">
              <p className="font-medium">
                ✅ 累積ベースの日利計算（金額入力方式）
              </p>
              <ul className="text-sm space-y-1 ml-4">
                <li>• 入力: 全体運用利益（金額）を入力</li>
                <li>• 計算: 全NFTで均等割り → 30%手数料 → 60/30/10分配</li>
                <li>• 累積管理: 累積利益（手数料前）、累積手数料、顧客累積利益、当日利益を記録</li>
                <li>• ユーザーには当日利益のみ表示（手数料構造は非表示）</li>
              </ul>
            </div>
          </CardContent>
        </Card>

        {/* 統計情報 */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                  <UsersIcon className="h-4 w-4" />
                  アクティブユーザー
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.total_users}</div>
                <p className="text-xs text-green-200">NFT承認済み</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-purple-900 to-purple-800 border-purple-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-purple-100">
                  <TrendingUpIcon className="h-4 w-4" />
                  運用中NFT数
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.total_nft_count}個</div>
                <p className="text-xs text-purple-200">ペガサス除く</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-blue-900 to-blue-800 border-blue-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-blue-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総投資額
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">
                  ${stats.total_investment.toLocaleString()}
                  {stats.pegasus_investment > 0 && (
                    <span className="text-sm text-gray-400 ml-2">
                      (ペガサス: ${stats.pegasus_investment.toLocaleString()})
                    </span>
                  )}
                </div>
                <p className="text-xs text-blue-200">運用中（ペガサス除く）</p>
                {stats.total_investment_pending > 0 && (
                  <div className="mt-2 pt-2 border-t border-blue-600">
                    <div className="text-lg font-semibold text-yellow-300">${stats.total_investment_pending.toLocaleString()}</div>
                    <p className="text-xs text-yellow-200">運用開始前</p>
                  </div>
                )}
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                  <DollarSignIcon className="h-4 w-4" />
                  顧客累積利益
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_distributed.toLocaleString()}</div>
                <p className="text-xs text-yellow-200">最新の累積額（手数料引き後）</p>
              </CardContent>
            </Card>
          </div>
        )}

        {/* 日利設定フォーム */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              <CalendarIcon className="h-5 w-5" />
              日利設定
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
                <div className="space-y-2">
                  <Label htmlFor="totalProfitAmount" className="text-white">
                    全体運用利益 ($)
                  </Label>
                  <Input
                    id="totalProfitAmount"
                    type="number"
                    step="0.01"
                    value={totalProfitAmount}
                    onChange={(e) => setTotalProfitAmount(e.target.value)}
                    placeholder="例: 500.00 (マイナス可: -100.00)"
                    required
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                  <p className="text-xs text-gray-400">
                    💡 全NFT合計の運用利益を入力（プラス/マイナス可）
                  </p>
                </div>
              </div>

              {stats && totalProfitAmount && (
                <div className="space-y-3 p-4 bg-gray-700 rounded-lg">
                  <h3 className="text-sm font-medium text-white">計算プレビュー:</h3>

                  <div className="grid grid-cols-3 gap-4">
                    <div>
                      <p className="text-xs text-gray-400">全体運用利益</p>
                      <p className="text-lg font-bold text-white">
                        ${Number.parseFloat(totalProfitAmount).toFixed(2)}
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">対象NFT数</p>
                      <p className="text-lg font-bold text-blue-400">
                        {stats.total_nft_count}個
                      </p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">配布対象ユーザー数</p>
                      <p className="text-lg font-bold text-green-400">
                        {stats.active_users_count}名
                      </p>
                    </div>
                  </div>

                  <div className="border-t border-gray-600 pt-3">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-xs text-gray-400">1 NFTあたり利益</p>
                        <p className="text-lg font-bold text-blue-400">
                          ${(Number.parseFloat(totalProfitAmount) / stats.total_nft_count).toFixed(4)}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-400">平均（1ユーザーあたり）</p>
                        <p className="text-lg font-bold text-green-400">
                          ${(Number.parseFloat(totalProfitAmount) / stats.active_users_count).toFixed(2)}
                        </p>
                      </div>
                    </div>
                  </div>

                  <div className="border-t border-gray-600 pt-3">
                    <p className="text-xs text-gray-400 mb-2">分配予定（ΔN_d > 0の場合）:</p>
                    <div className="grid grid-cols-3 gap-2 text-xs">
                      <div className="bg-gray-800 p-2 rounded">
                        <p className="text-gray-400">配当 (60%)</p>
                        <p className="font-bold text-green-400">
                          ${(Math.max(0, Number.parseFloat(totalProfitAmount)) * 0.6).toFixed(2)}
                        </p>
                      </div>
                      <div className="bg-gray-800 p-2 rounded">
                        <p className="text-gray-400">アフィリ (30%)</p>
                        <p className="font-bold text-yellow-400">
                          ${(Math.max(0, Number.parseFloat(totalProfitAmount)) * 0.3).toFixed(2)}
                        </p>
                      </div>
                      <div className="bg-gray-800 p-2 rounded">
                        <p className="text-gray-400">ストック (10%)</p>
                        <p className="font-bold text-purple-400">
                          ${(Math.max(0, Number.parseFloat(totalProfitAmount)) * 0.1).toFixed(2)}
                        </p>
                      </div>
                    </div>
                    <p className="text-xs text-gray-500 mt-2">
                      ※ マイナスの場合は分配なし（$0）
                    </p>
                  </div>
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

            {message && (
              <Alert
                className={`mt-4 ${
                  message.type === "error"
                    ? "border-red-500 bg-red-900/20"
                    : message.type === "warning"
                      ? "border-yellow-500 bg-yellow-900/20"
                      : "border-green-500 bg-green-900/20"
                }`}
              >
                {message.type === "error" ? (
                  <AlertCircle className="h-4 w-4" />
                ) : message.type === "warning" ? (
                  <InfoIcon className="h-4 w-4" />
                ) : (
                  <CheckCircle className="h-4 w-4" />
                )}
                <AlertDescription
                  className={
                    message.type === "error"
                      ? "text-red-300"
                      : message.type === "warning"
                        ? "text-yellow-300"
                        : "text-green-300"
                  }
                  style={{ whiteSpace: 'pre-line' }}
                >
                  {message.text}
                </AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>

        {/* 履歴 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">
                設定履歴（v2システム）
              </CardTitle>
              <Button
                onClick={fetchHistory}
                size="sm"
                className="bg-blue-600 hover:bg-blue-700"
              >
                <RefreshCw className="w-4 h-4 mr-2" />
                更新
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            {history.length === 0 ? (
                <p className="text-gray-400">履歴がありません</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm text-white">
                    <thead>
                      <tr className="border-b border-gray-600">
                        <th className="text-left p-2">日付</th>
                        <th className="text-left p-2">運用利益</th>
                        <th className="text-left p-2">NFT数</th>
                        <th className="text-left p-2">累積利益<br/><span className="text-xs text-gray-400">(手数料前)</span></th>
                        <th className="text-left p-2">累積手数料</th>
                        <th className="text-left p-2">顧客累積利益</th>
                        <th className="text-left p-2">当日利益</th>
                        <th className="text-left p-2">設定日時</th>
                        <th className="text-left p-2">操作</th>
                      </tr>
                    </thead>
                    <tbody>
                      {history.map((item) => (
                        <tr key={item.id} className="border-b border-gray-700">
                          <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                          <td
                            className={`p-2 font-medium ${item.total_profit_amount >= 0 ? "text-green-400" : "text-red-400"}`}
                          >
                            ${item.total_profit_amount.toFixed(2)}
                          </td>
                          <td className="p-2">{item.total_nft_count}個</td>
                          <td className="p-2 text-blue-400">${item.cumulative_gross_profit.toFixed(2)}</td>
                          <td className="p-2 text-yellow-400">${item.cumulative_fee.toFixed(2)}</td>
                          <td className="p-2 text-purple-400">${item.cumulative_net_profit.toFixed(2)}</td>
                          <td
                            className={`p-2 font-bold ${item.daily_pnl >= 0 ? "text-green-400" : "text-red-400"}`}
                          >
                            ${item.daily_pnl.toFixed(2)}
                          </td>
                          <td className="p-2">{new Date(item.created_at).toLocaleString("ja-JP")}</td>
                          <td className="p-2 space-x-1">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleEdit(item)}
                              className="h-8 px-2 bg-blue-600 hover:bg-blue-700 text-white border-blue-500"
                            >
                              <Edit className="h-3 w-3 mr-1" />
                              修正
                            </Button>
                            <Button
                              variant="destructive"
                              size="sm"
                              onClick={() => handleCancel(item.date)}
                              className="h-8 px-2 bg-red-600 hover:bg-red-700 text-white"
                            >
                              <Trash2 className="h-3 w-3 mr-1" />
                              削除
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
