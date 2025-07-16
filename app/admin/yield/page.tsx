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
import { Checkbox } from "@/components/ui/checkbox"
import { Switch } from "@/components/ui/switch"
import {
  CalendarIcon,
  TrendingUpIcon,
  UsersIcon,
  DollarSignIcon,
  AlertCircle,
  CheckCircle,
  InfoIcon,
  TestTube,
  Trash2,
  Shield,
  ArrowLeft,
  RefreshCw,
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface YieldHistory {
  id: string
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  total_users: number
  created_at: string
}

interface YieldStats {
  total_users: number
  total_investment: number
  avg_yield_rate: number
  total_distributed: number
}

interface TestResult {
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  total_users: number
  total_user_profit: number
  total_company_profit: number
  created_at: string
}

export default function AdminYieldPage() {
  const [date, setDate] = useState(new Date().toISOString().split("T")[0])
  const [yieldRate, setYieldRate] = useState("")
  const [marginRate, setMarginRate] = useState("30")
  const [isTestMode, setIsTestMode] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)
  const [history, setHistory] = useState<YieldHistory[]>([])
  const [stats, setStats] = useState<YieldStats | null>(null)
  const [userRate, setUserRate] = useState(0)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState("")
  const [testResults, setTestResults] = useState<TestResult[]>([])
  const [showTestResults, setShowTestResults] = useState(false)
  const router = useRouter()

  // ユーザー受取率を計算
  useEffect(() => {
    const yield_rate = Number.parseFloat(yieldRate) || 0
    const margin_rate = Number.parseFloat(marginRate) || 0
    // 正しい計算式: 日利率 × (1 - マージン率/100) × 0.6
    const after_margin = yield_rate * (1 - margin_rate / 100)
    const calculated_user_rate = after_margin * 0.6
    
    setUserRate(calculated_user_rate)
  }, [yieldRate, marginRate])

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)

      // 緊急対応: basarasystems@gmail.com と support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
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
          fetchHistory()
          fetchStats()
          return
        }
        
        setError("管理者権限の確認でエラーが発生しました")
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
          fetchHistory()
          fetchStats()
          return
        }
        
        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      fetchHistory()
      fetchStats()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchHistory = async () => {
    try {
      const { data, error } = await supabase
        .from("daily_yield_log")
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

      const { data: purchasesData, error: purchasesError } = await supabase
        .from("purchases")
        .select("amount_usd")
        .eq("admin_approved", true)

      if (purchasesError) throw purchasesError

      const { data: avgYieldData, error: avgYieldError } = await supabase.from("daily_yield_log").select("yield_rate")

      if (avgYieldError) throw avgYieldError

      const { data: totalProfitData, error: totalProfitError } = await supabase
        .from("user_daily_profit")
        .select("daily_profit")

      if (totalProfitError) {
        console.warn("user_daily_profit取得エラー:", totalProfitError)
      }

      const totalInvestment = purchasesData?.reduce((sum, p) => sum + Number.parseFloat(p.amount_usd || "0"), 0) || 0
      const avgYieldRate =
        avgYieldData?.reduce((sum, y) => sum + Number.parseFloat(y.yield_rate || "0"), 0) /
          (avgYieldData?.length || 1) || 0
      const totalDistributed =
        totalProfitData?.reduce((sum, p) => sum + Number.parseFloat(p.daily_profit || "0"), 0) || 0

      setStats({
        total_users: usersData?.length || 0,
        total_investment: totalInvestment,
        avg_yield_rate: avgYieldRate * 100,
        total_distributed: totalDistributed,
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
      // 本番モード固定: サイクル処理付き日利設定
      const { data, error } = await supabase.rpc("process_daily_yield_with_cycles", {
        p_date: date,
        p_yield_rate: Number.parseFloat(yieldRate) / 100,
        p_margin_rate: Number.parseFloat(marginRate) / 100,
        p_is_test_mode: false,
      })

      if (error) throw error

      if (data && data.length > 0) {
        const result = data[0]
        
        // デバッグ用にレスポンスをログ出力
        console.log('サイクル処理結果:', result)
        
        // 安全な値の取得と変換（データベース関数の実際のフィールド名に合わせる）
        const totalUsers = result.processed_users || result.total_users || 0
        const totalProfit = Number.parseFloat(result.total_profit_distributed || result.total_profit || result.total_user_profit || 0) || 0
        const autoNftPurchases = result.auto_purchases_created || result.auto_purchases || result.auto_nft_purchases || 0
        
        // カスタムメッセージがある場合はそれを使用、なければデフォルトメッセージ
        const messageText = result.message || 
          `サイクル処理完了！${totalUsers}名のユーザーに総額$${totalProfit.toFixed(2)}の利益を配布し、${autoNftPurchases}回の自動NFT購入を実行しました。`
        
        setMessage({
          type: "success",
          text: messageText,
        })
      } else {
        setMessage({
          type: "success",
          text: "日利設定が完了しました。",
        })
      }

      setYieldRate("")
      setDate(new Date().toISOString().split("T")[0])
      fetchHistory()
      fetchStats()
    } catch (error: any) {
      setMessage({
        type: "error",
        text: error.message || "日利設定に失敗しました",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const simulateYieldCalculation = async () => {
    try {
      // 複数のデータソースから対象ユーザーを取得
      let cycleData: any[] = []
      let dataSource = ""

      // 1. affiliate_cycleテーブルを試す
      const { data: acData, error: acError } = await supabase
        .from("affiliate_cycle")
        .select("user_id, total_nft_count")
        .gt("total_nft_count", 0)

      if (!acError && acData && acData.length > 0) {
        cycleData = acData
        dataSource = "affiliate_cycle"
      } else {
        // 2. purchasesテーブルから計算
        const { data: purchaseData, error: purchaseError } = await supabase
          .from("purchases")
          .select("user_id, nft_quantity")
          .eq("admin_approved", true)

        if (!purchaseError && purchaseData) {
          // ユーザーごとにNFT数を集計
          const userNftMap = new Map()
          purchaseData.forEach(purchase => {
            const userId = purchase.user_id
            const nftCount = purchase.nft_quantity || 0
            userNftMap.set(userId, (userNftMap.get(userId) || 0) + nftCount)
          })

          cycleData = Array.from(userNftMap.entries()).map(([userId, totalNft]) => ({
            user_id: userId,
            total_nft_count: totalNft
          })).filter(user => user.total_nft_count > 0)
          
          dataSource = "purchases"
        } else {
          // 3. usersテーブルのtotal_purchasesから推定
          const { data: userData, error: userError } = await supabase
            .from("users")
            .select("user_id, total_purchases")
            .gt("total_purchases", 0)

          if (!userError && userData) {
            cycleData = userData.map(user => ({
              user_id: user.user_id,
              total_nft_count: Math.floor(user.total_purchases / 1100) // $1100 = 1NFT
            })).filter(user => user.total_nft_count > 0)
            
            dataSource = "users.total_purchases"
          }
        }
      }

      const totalUsers = cycleData?.length || 0
      const yield_rate = Number.parseFloat(yieldRate) / 100
      const margin_rate = Number.parseFloat(marginRate) / 100
      const user_rate = yield_rate * (1 - margin_rate) * 0.6

      let totalUserProfit = 0
      let totalCompanyProfit = 0

      cycleData?.forEach((user) => {
        const baseAmount = user.total_nft_count * 1100
        const userProfit = baseAmount * user_rate
        const companyProfit = baseAmount * margin_rate + baseAmount * (yield_rate - margin_rate) * 0.1
        
        totalUserProfit += userProfit
        totalCompanyProfit += companyProfit
      })

      // テスト結果を状態に保存
      const testResult: TestResult = {
        date: date,
        yield_rate: yield_rate,
        margin_rate: margin_rate,
        user_rate: user_rate,
        total_users: totalUsers,
        total_user_profit: totalUserProfit,
        total_company_profit: totalCompanyProfit,
        created_at: new Date().toISOString()
      }

      setTestResults(prev => [testResult, ...prev.slice(0, 9)])
      setShowTestResults(true)

      setMessage({
        type: "warning",
        text: `🔒 安全テスト完了: ${totalUsers}名のユーザーに総額$${totalUserProfit.toFixed(2)}の利益が配布される予定です。（データソース: ${dataSource}・本番データ無影響）`,
      })
    } catch (error: any) {
      throw new Error(`テスト計算エラー: ${error.message}`)
    }
  }

  const handleCancel = async (cancelDate: string) => {
    if (!confirm(`${cancelDate}の日利設定をキャンセルしますか？この操作は取り消せません。`)) {
      return
    }

    try {
      // まず管理者用RPC関数を試す
      try {
        const { data: rpcResult, error: rpcError } = await supabase.rpc("admin_cancel_yield_posting", {
          p_date: cancelDate
        })

        if (!rpcError && rpcResult && rpcResult.length > 0) {
          const result = rpcResult[0]
          if (result.success) {
            setMessage({
              type: "success",
              text: result.message,
            })

            setTimeout(() => {
              fetchHistory()
              fetchStats()
            }, 500)
            return
          }
        }
        
        console.warn("RPC関数エラー、直接削除に切り替え:", rpcError)
      } catch (rpcFallbackError) {
        console.warn("RPC関数使用不可、直接削除に切り替え:", rpcFallbackError)
      }

      // RPC関数が失敗した場合の直接削除
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        throw new Error("ユーザー認証が必要です")
      }

      // まず削除対象データの存在確認
      const { data: existingData, error: checkExistError } = await supabase
        .from("daily_yield_log")
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

      // IDで削除を試みる
      const { data: deleteByIdData, error: deleteByIdError } = await supabase
        .from("daily_yield_log")
        .delete()
        .eq("id", targetId)
        .select()

      if (deleteByIdError) {
        console.error("ID削除エラー:", deleteByIdError)
        
        // 日付で削除を試みる
        const { data: yieldData, error: deleteYieldError } = await supabase
          .from("daily_yield_log")
          .delete()
          .eq("date", cancelDate)
          .select()

        if (deleteYieldError) {
          console.error("daily_yield_log削除エラー:", deleteYieldError)
          throw new Error(`日利設定の削除に失敗: ${deleteYieldError.message}`)
        }
        console.log("日付削除結果:", yieldData)
      } else {
        console.log("ID削除成功:", deleteByIdData)
      }

      // user_daily_profitから削除
      const { data: profitExisting, error: profitCheckError } = await supabase
        .from("user_daily_profit")
        .select("count")
        .eq("date", cancelDate)

      console.log("削除対象profit数:", profitExisting)

      const { data: profitData, error: deleteProfitError } = await supabase
        .from("user_daily_profit")
        .delete()
        .eq("date", cancelDate)
        .select()

      if (deleteProfitError) {
        console.warn("user_daily_profit削除エラー:", deleteProfitError)
      } else {
        console.log("削除されたprofit:", profitData?.length || 0)
      }

      // 削除後の再確認
      const { data: remainingData, error: finalCheckError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .eq("date", cancelDate)

      console.log("削除後の残存データ:", remainingData)

      if (!finalCheckError && remainingData && remainingData.length > 0) {
        // 3000%の異常値の場合は特別な処理
        if (remainingData[0].margin_rate && parseFloat(remainingData[0].margin_rate) > 1) {
          console.error("異常値データの削除に失敗。管理者に連絡してください。")
          throw new Error("3000%の異常値データは手動削除が必要です。Supabaseダッシュボードから削除してください。")
        }
        throw new Error("データの削除に失敗しました。権限を確認してください。")
      }

      const deletedCount = (deleteByIdData?.length || 0) + (profitData?.length || 0)
      setMessage({
        type: "success",
        text: `${cancelDate}の日利設定をキャンセルしました（${deletedCount}件削除）`,
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

  const handleForceDelete = async (recordId: string, targetDate: string) => {
    const options = [
      "削除（推奨）",
      "正常値に修正（30%に変更）",
      "キャンセル"
    ]
    
    const choice = confirm(`ID:${recordId} (${targetDate}) の3000%異常値データをどうしますか？\n\n1. 削除を試行（推奨）\n2. 正常値（30%）に修正\n\nOK = 削除、キャンセル = 修正`)

    try {
      if (choice) {
        // 削除を試行
        setMessage({ type: "warning", text: "削除試行中..." })

        console.log("削除開始 - ID:", recordId, "Date:", targetDate)

        // すべての削除方法を同時に実行
        const [deleteById, deleteByCondition, deleteProfits] = await Promise.all([
          supabase.from("daily_yield_log").delete().eq("id", recordId),
          supabase.from("daily_yield_log").delete().eq("date", targetDate).gt("margin_rate", 1),
          supabase.from("user_daily_profit").delete().eq("date", targetDate)
        ])

        console.log("削除結果:", { deleteById, deleteByCondition, deleteProfits })

        // 削除確認
        await new Promise(resolve => setTimeout(resolve, 1000))
        
        const { data: checkData } = await supabase
          .from("daily_yield_log")
          .select("*")
          .eq("date", targetDate)

        console.log("削除後確認:", checkData)

        if (checkData && checkData.length === 0) {
          setMessage({
            type: "success",
            text: `${targetDate}の異常値データを削除しました`,
          })
        } else {
          // 削除失敗時は自動的に修正を提案
          if (confirm("削除に失敗しました。マージン率を30%に修正しますか？")) {
            await handleFixAnomaly(recordId, targetDate)
            return
          } else {
            setMessage({
              type: "error",
              text: "RLSポリシーにより削除が制限されています。Supabaseダッシュボードから手動削除してください。",
            })
          }
        }
      } else {
        // 修正を選択
        await handleFixAnomaly(recordId, targetDate)
      }

      // 履歴を再取得
      setTimeout(() => {
        fetchHistory()
        fetchStats()
      }, 1500)

    } catch (error: any) {
      console.error("処理エラー:", error)
      setMessage({
        type: "error",
        text: `処理に失敗: ${error.message}`,
      })
    }
  }

  const handleFixAnomaly = async (recordId: string, targetDate: string) => {
    try {
      setMessage({ type: "warning", text: "異常値を修正中..." })

      // 現在のデータを取得
      const { data: currentData, error: fetchError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .eq("id", recordId)
        .single()

      if (fetchError || !currentData) {
        throw new Error("データ取得に失敗しました")
      }

      // 正常なマージン率（30%）に修正
      const fixedMarginRate = 0.30 // 30%
      const fixedUserRate = currentData.yield_rate * (1 - fixedMarginRate) * 0.6

      const { data: updateData, error: updateError } = await supabase
        .from("daily_yield_log")
        .update({
          margin_rate: fixedMarginRate,
          user_rate: fixedUserRate
        })
        .eq("id", recordId)
        .select()

      console.log("修正結果:", { updateData, updateError })

      if (updateError) {
        throw updateError
      }

      // user_daily_profitも再計算が必要な場合
      const { error: recalcError } = await supabase.rpc("recalculate_daily_profit", {
        p_date: targetDate
      }).catch(() => {
        console.log("再計算RPC関数が存在しない場合は手動で修正が必要")
      })

      setMessage({
        type: "success",
        text: `${targetDate}の異常値を修正しました（マージン率: 3000% → 30%）`,
      })

    } catch (error: any) {
      console.error("修正エラー:", error)
      setMessage({
        type: "error",
        text: `修正に失敗: ${error.message}`,
      })
    }
  }

  const clearTestResults = () => {
    setTestResults([])
    setShowTestResults(false)
    setMessage({
      type: "success",
      text: "テスト結果をクリアしました",
    })
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
              日利設定
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Badge variant={isTestMode ? "secondary" : "destructive"} className="text-sm">
              {isTestMode ? "テストモード" : "本番モード"}
            </Badge>
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
          </div>
        </div>

        {/* 本番モード固定 */}
        <Card className="border-2 bg-gray-800 border-green-500">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-green-400">
              <Shield className="h-5 w-5" />
              本番モード（固定）
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-green-300 space-y-2">
              <p className="font-medium">
                ✅ 本番モード: ユーザーの実際の残高に影響します
              </p>
              <p className="text-sm">
                設定すると即座にユーザーの利益に反映されます
              </p>
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

            <Card className="bg-gradient-to-br from-blue-900 to-blue-800 border-blue-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-blue-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総投資額
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_investment.toLocaleString()}</div>
                <p className="text-xs text-blue-200">承認済み購入</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-purple-900 to-purple-800 border-purple-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-purple-100">
                  <TrendingUpIcon className="h-4 w-4" />
                  平均日利率
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.avg_yield_rate.toFixed(2)}%</div>
                <p className="text-xs text-purple-200">過去の平均</p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総配布利益
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_distributed.toLocaleString()}</div>
                <p className="text-xs text-yellow-200">累積配布額</p>
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
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
                  <Label htmlFor="yieldRate" className="text-white">
                    日利率 (%)
                  </Label>
                  <Input
                    id="yieldRate"
                    type="number"
                    step="0.01"
                    min="-10"
                    max="100"
                    value={yieldRate}
                    onChange={(e) => setYieldRate(e.target.value)}
                    placeholder="例: 1.5 (マイナス可)"
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
              </div>

              <div className="space-y-2">
                <Label className="text-white">ユーザー受取率</Label>
                <div className={`text-2xl font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                  {userRate.toFixed(3)}%
                </div>
                <p className="text-sm text-gray-400">
                  {yieldRate}% × (1 - {marginRate}%/100) × 0.6 = ユーザー受取 {userRate.toFixed(3)}%
                </p>
                {stats && yieldRate && (
                  <div className="mt-2 p-3 bg-gray-700 rounded-lg">
                    <p className="text-sm font-medium text-white">予想配布額:</p>
                    <p className={`text-lg font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                      ${((stats.total_investment * userRate) / 100).toLocaleString()}
                    </p>
                    <p className="text-xs text-gray-400">{stats.total_users}名のユーザーに配布予定</p>
                  </div>
                )}
              </div>


              <Button
                type="submit"
                disabled={isLoading}
                className={`w-full md:w-auto ${isTestMode ? "bg-blue-600 hover:bg-blue-700" : "bg-red-600 hover:bg-red-700"}`}
              >
                {isLoading ? "処理中..." : isTestMode ? "テスト実行" : "日利を設定"}
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
                >
                  {message.text}
                </AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>

        {/* 履歴・テスト結果 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">
                {showTestResults ? "テスト結果履歴" : "設定履歴"}
              </CardTitle>
              <div className="flex gap-2">
                {showTestResults && (
                  <Button 
                    onClick={() => setShowTestResults(false)} 
                    size="sm" 
                    variant="outline"
                    className="border-gray-600 text-gray-300"
                  >
                    本番履歴に戻る
                  </Button>
                )}
                <Button 
                  onClick={async () => {
                    try {
                      const { data, error } = await supabase
                        .from("daily_yield_log")
                        .select("*")
                        .order("date", { ascending: false })
                      
                      console.log("全履歴データ:", data)
                      if (error) console.error("履歴取得エラー:", error)
                      
                      const { count, error: countError } = await supabase
                        .from("daily_yield_log")
                        .select("*", { count: "exact", head: true })
                      
                      console.log("総レコード数:", count)
                      if (countError) console.error("カウントエラー:", countError)
                      
                      setMessage({
                        type: "success",
                        text: `デバッグ情報をコンソールに出力しました（${count}件）`
                      })
                    } catch (err) {
                      console.error("デバッグエラー:", err)
                    }
                  }}
                  size="sm" 
                  variant="outline"
                  className="border-yellow-600 text-yellow-300"
                >
                  🔍 DB確認
                </Button>
                <Button 
                  onClick={showTestResults ? () => {} : fetchHistory} 
                  size="sm" 
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  更新
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {showTestResults ? (
              // テスト結果表示
              testResults.length === 0 ? (
                <div className="text-center py-8">
                  <p className="text-gray-400 mb-4">テスト結果がありません</p>
                  <p className="text-xs text-blue-400">安全テストモードで計算を実行してください</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <div className="mb-4 p-3 bg-blue-900/20 border border-blue-600/30 rounded">
                    <p className="text-blue-300 text-sm">🔒 テスト環境の結果 - 本番データには影響していません</p>
                  </div>
                  <table className="w-full text-sm text-white">
                    <thead>
                      <tr className="border-b border-gray-600">
                        <th className="text-left p-2">日付</th>
                        <th className="text-left p-2">日利率</th>
                        <th className="text-left p-2">ユーザー利率</th>
                        <th className="text-left p-2">対象ユーザー</th>
                        <th className="text-left p-2">ユーザー利益</th>
                        <th className="text-left p-2">会社利益</th>
                        <th className="text-left p-2">実行日時</th>
                      </tr>
                    </thead>
                    <tbody>
                      {testResults.map((item, index) => (
                        <tr key={index} className="border-b border-gray-700">
                          <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                          <td className={`p-2 font-medium ${item.yield_rate >= 0 ? "text-green-400" : "text-red-400"}`}>
                            {(item.yield_rate * 100).toFixed(3)}%
                          </td>
                          <td className={`p-2 font-medium ${item.user_rate >= 0 ? "text-green-400" : "text-red-400"}`}>
                            {(item.user_rate * 100).toFixed(3)}%
                          </td>
                          <td className="p-2">{item.total_users}名</td>
                          <td className="p-2 text-green-400">${item.total_user_profit.toFixed(2)}</td>
                          <td className="p-2 text-blue-400">${item.total_company_profit.toFixed(2)}</td>
                          <td className="p-2">{new Date(item.created_at).toLocaleString("ja-JP")}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )
            ) : (
              // 本番履歴表示
              history.length === 0 ? (
                <p className="text-gray-400">履歴がありません</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm text-white">
                    <thead>
                      <tr className="border-b border-gray-600">
                        <th className="text-left p-2">日付</th>
                        <th className="text-left p-2">日利率</th>
                        <th className="text-left p-2">マージン率</th>
                        <th className="text-left p-2">ユーザー利率</th>
                        <th className="text-left p-2">設定日時</th>
                        <th className="text-left p-2">操作</th>
                      </tr>
                    </thead>
                    <tbody>
                      {history.map((item) => (
                        <tr key={item.id} className="border-b border-gray-700">
                          <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                          <td
                            className={`p-2 font-medium ${Number.parseFloat(item.yield_rate) >= 0 ? "text-green-400" : "text-red-400"}`}
                          >
                            {(Number.parseFloat(item.yield_rate) * 100).toFixed(3)}%
                          </td>
                          <td className={`p-2 ${Number.parseFloat(item.margin_rate) * 100 > 100 ? "bg-red-900 text-red-300 font-bold" : ""}`}>
                            {(Number.parseFloat(item.margin_rate) * 100).toFixed(0)}%
                            {Number.parseFloat(item.margin_rate) * 100 > 100 && (
                              <span className="ml-1 text-xs">⚠️異常値</span>
                            )}
                          </td>
                          <td
                            className={`p-2 font-medium ${Number.parseFloat(item.user_rate) >= 0 ? "text-green-400" : "text-red-400"}`}
                          >
                            {(Number.parseFloat(item.user_rate) * 100).toFixed(3)}%
                          </td>
                          <td className="p-2">{new Date(item.created_at).toLocaleString("ja-JP")}</td>
                          <td className="p-2 space-x-1">
                            <Button
                              variant="destructive"
                              size="sm"
                              onClick={() => handleCancel(item.date)}
                              className="h-8 px-2 bg-red-600 hover:bg-red-700"
                            >
                              <Trash2 className="h-3 w-3 mr-1" />
                              キャンセル
                            </Button>
                            {Number.parseFloat(item.margin_rate) * 100 > 100 && (
                              <Button
                                variant="destructive"
                                size="sm"
                                onClick={() => handleForceDelete(item.id, item.date)}
                                className="h-8 px-2 bg-orange-600 hover:bg-orange-700"
                              >
                                <Trash2 className="h-3 w-3 mr-1" />
                                修正
                              </Button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}