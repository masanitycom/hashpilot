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

interface YieldHistory {
  id: string
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  total_users: number
  created_at: string
  system?: 'V1' | 'V2'
  // V2専用フィールド
  total_profit_amount?: number
  total_nft_count?: number
  profit_per_nft?: number
}

interface YieldStats {
  total_users: number
  total_investment: number
  total_investment_pending: number
  pegasus_investment: number
  avg_yield_rate: number
  total_distributed: number
}

export default function AdminYieldPage() {
  const [date, setDate] = useState(new Date().toISOString().split("T")[0])
  const [yieldRate, setYieldRate] = useState("")
  const [marginRate, setMarginRate] = useState("30")
  const [totalProfitAmount, setTotalProfitAmount] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)
  const [history, setHistory] = useState<YieldHistory[]>([])
  const [stats, setStats] = useState<YieldStats | null>(null)
  const [userRate, setUserRate] = useState(0)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [authLoading, setAuthLoading] = useState(true)
  const [error, setError] = useState("")
  const router = useRouter()

  // V2システム切り替え（常にV2を使用）
  const useV2 = true

  // 月次紹介報酬計算用のstate
  const [monthlyYearMonth, setMonthlyYearMonth] = useState(new Date().toISOString().slice(0, 7)) // YYYY-MM
  const [monthlyLoading, setMonthlyLoading] = useState(false)
  const [monthlyMessage, setMonthlyMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)

  // 履歴表示用の月選択
  const [selectedMonth, setSelectedMonth] = useState(new Date().toISOString().slice(0, 7)) // YYYY-MM

  // ユーザー受取率を計算
  useEffect(() => {
    const yield_rate = Number.parseFloat(yieldRate) || 0
    const margin_rate = Number.parseFloat(marginRate) || 0
    
    // プラス/マイナス共通: マージンを引いてから0.6を掛ける
    let calculated_user_rate: number
    if (yield_rate !== 0) {
      // プラスもマイナスも同じ計算: (1 - マージン率) × 0.6
      const after_margin = yield_rate * (1 - margin_rate / 100)
      calculated_user_rate = after_margin * 0.6
    } else {
      // ゼロの場合
      calculated_user_rate = 0
    }
    
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
      // V1履歴（11月、利率％）
      const { data: v1Data, error: v1Error } = await supabase
        .from("daily_yield_log")
        .select("*")
        .order("date", { ascending: false })

      if (v1Error) throw v1Error

      // V2履歴（12月、金額$）
      const { data: v2Data, error: v2Error } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .order("date", { ascending: false })

      if (v2Error) {
        console.warn("V2履歴取得エラー:", v2Error)
      }

      // V1データを変換（既存形式を維持）
      const v1History = (v1Data || []).map(item => ({
        ...item,
        system: 'V1' as const,
      }))

      // V2データを変換（V1形式に合わせる）
      const v2History = (v2Data || []).map(item => ({
        id: item.id.toString(),
        date: item.date,
        yield_rate: (item.daily_pnl / item.total_nft_count / 10) || 0,  // 概算の利率
        margin_rate: item.fee_rate || 0.30,
        user_rate: (item.daily_pnl / item.total_nft_count / 10 * 0.7 * 0.6) || 0,  // 概算
        total_users: 0,
        created_at: item.created_at,
        system: 'V2' as const,
        // V2専用データ
        total_profit_amount: item.total_profit_amount,
        total_nft_count: item.total_nft_count,
        profit_per_nft: item.profit_per_nft,
      }))

      // 統合して日付順にソート
      const allHistory = [...v1History, ...v2History].sort((a, b) =>
        new Date(b.date).getTime() - new Date(a.date).getTime()
      )

      setHistory(allHistory)
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

      // 全承認済み購入とユーザー情報を取得（ペガサスフラグも含む）
      const { data: purchasesData, error: purchasesError } = await supabase
        .from("purchases")
        .select("amount_usd, user_id, users!inner(operation_start_date, is_pegasus_exchange)")
        .eq("admin_approved", true)

      if (purchasesError) throw purchasesError

      const today = new Date().toISOString().split('T')[0]

      const { data: avgYieldData, error: avgYieldError } = await supabase.from("daily_yield_log").select("yield_rate")

      if (avgYieldError) throw avgYieldError

      const { data: totalProfitData, error: totalProfitError } = await supabase
        .from("user_daily_profit")
        .select("daily_profit")

      if (totalProfitError) {
        console.warn("user_daily_profit取得エラー:", totalProfitError)
      }

      // 運用中と運用開始前に分けて集計（ペガサスユーザーは除外）
      const totalInvestmentActive = purchasesData?.reduce((sum, p: any) => {
        const opStartDate = p.users?.operation_start_date
        const isPegasus = p.users?.is_pegasus_exchange
        if (!isPegasus && opStartDate && opStartDate <= today) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      const totalInvestmentPending = purchasesData?.reduce((sum, p: any) => {
        const opStartDate = p.users?.operation_start_date
        const isPegasus = p.users?.is_pegasus_exchange
        if (!isPegasus && opStartDate && opStartDate > today) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      // ペガサスユーザーの投資額を別途集計
      const pegasusInvestment = purchasesData?.reduce((sum, p: any) => {
        const isPegasus = p.users?.is_pegasus_exchange
        if (isPegasus) {
          return sum + (p.amount_usd * (1000 / 1100))
        }
        return sum
      }, 0) || 0

      const totalInvestment = totalInvestmentActive
      const avgYieldRate =
        avgYieldData?.reduce((sum, y) => sum + Number.parseFloat(y.yield_rate || "0"), 0) /
          (avgYieldData?.length || 1) || 0
      const totalDistributed =
        totalProfitData?.reduce((sum, p) => sum + Number.parseFloat(p.daily_profit || "0"), 0) || 0

      setStats({
        total_users: usersData?.length || 0,
        total_investment: totalInvestment,
        total_investment_pending: totalInvestmentPending,
        pegasus_investment: pegasusInvestment,
        avg_yield_rate: avgYieldRate,  // 既にパーセント値なので100倍不要
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
      // ========== 重要：未来の日付チェック ==========
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const selectedDate = new Date(date)
      selectedDate.setHours(0, 0, 0, 0)

      if (selectedDate > today) {
        throw new Error(`❌ 未来の日付（${date}）には設定できません。今日は ${today.toISOString().split('T')[0]} です。`)
      }

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
          throw new Error(`日利処理エラー: ${rpcError.message}`)
        }

        const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

        console.log('✅ V2 RPC関数実行成功:', result)

        setMessage({
          type: "success",
          text: `✅ ${result.message || '日利設定完了（V2）'}

処理詳細:
• 運用利益: $${profitAmount.toFixed(2)}
• NFT総数: ${result.details?.input?.total_nft_count || 0}個
• NFT単価利益: $${(result.details?.input?.profit_per_nft || 0).toFixed(3)}
• 個人利益配布: $${(result.details?.distribution?.total_distributed || 0).toFixed(2)}
• 紹介報酬配布: $${(result.details?.distribution?.total_referral || 0).toFixed(2)}（${result.details?.distribution?.referral_count || 0}件）
• NFT自動付与: ${result.details?.distribution?.auto_nft_count || 0}件`,
        })

        setTotalProfitAmount("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()

      } else {
        // ========== V1システム（利率入力） ==========
        const yieldValue = Number.parseFloat(yieldRate) / 100  // パーセント→小数に変換
        const marginValue = Number.parseFloat(marginRate) / 100  // パーセント→小数に変換

        console.log('🚀 日利設定開始（V1 - 利率入力）:', {
          date,
          yield_rate: yieldValue,
          margin_rate: marginValue,
          is_test_mode: false
        })

        // RPC関数を呼び出す（小数値で送信）
        const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_with_cycles', {
          p_date: date,
          p_yield_rate: yieldValue,
          p_margin_rate: marginValue,
          p_is_test_mode: false,
          p_skip_validation: false
        })

        if (rpcError) {
          console.error('❌ RPC関数エラー:', rpcError)
          throw new Error(`日利処理エラー: ${rpcError.message}`)
        }

        const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

        console.log('✅ V1 RPC関数実行成功:', result)

        setMessage({
          type: "success",
          text: `✅ ${result.message || '日利設定完了（V1）'}

処理詳細:
• 日利配布: ${result.total_users || 0}名に総額$${(result.total_user_profit || 0).toFixed(2)}
• 紹介報酬: ${result.referral_rewards_processed || 0}名に配布
• NFT自動付与: ${result.auto_nft_purchases || 0}名に付与
• サイクル更新: ${result.cycle_updates || 0}件`,
        })

        setYieldRate("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()

        // 月末かチェックして自動的に紹介報酬を計算
        await checkAndProcessMonthlyReferral(date)
      }
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

  // 月末チェック＆自動紹介報酬計算
  const checkAndProcessMonthlyReferral = async (settingDate: string) => {
    try {
      const targetDate = new Date(settingDate)
      const year = targetDate.getFullYear()
      const month = targetDate.getMonth() + 1

      // 月末日を取得
      const lastDayOfMonth = new Date(year, month, 0).getDate()
      const currentDay = targetDate.getDate()

      // 月末の日利設定か、月初1日（前月分の設定）かをチェック
      const isMonthEnd = currentDay === lastDayOfMonth
      const isFirstDayOfMonth = currentDay === 1

      // 月末でも月初1日でもない場合はスキップ
      if (!isMonthEnd && !isFirstDayOfMonth) {
        console.log(`📅 ${settingDate}は月末でも月初でもありません`)
        return
      }

      // 月初1日の場合は、前月分の紹介報酬を計算
      let targetYear = year
      let targetMonth = month

      if (isFirstDayOfMonth) {
        // 前月を計算
        if (month === 1) {
          targetYear = year - 1
          targetMonth = 12
        } else {
          targetMonth = month - 1
        }
        console.log(`📅 ${settingDate}は月初1日です。前月（${targetYear}年${targetMonth}月）の紹介報酬を自動計算します...`)
      } else {
        console.log(`📅 ${settingDate}は月末です。紹介報酬を自動計算します...`)
      }

      // 月次紹介報酬を計算（targetYear/targetMonthを使用）
      const { data: monthlyResult, error: monthlyError } = await supabase.rpc('process_monthly_referral_reward', {
        p_year: targetYear,
        p_month: targetMonth,
        p_overwrite: false
      })

      if (monthlyError) {
        console.error('❌ 月次紹介報酬計算エラー:', monthlyError)
        // エラーでも日利設定は成功しているので、警告のみ表示
        setMessage(prev => ({
          type: "warning",
          text: (prev?.text || '') + `\n\n⚠️ 月次紹介報酬の自動計算に失敗しました: ${monthlyError.message}\n手動で実行してください: SELECT * FROM process_monthly_referral_reward(${year}, ${month});`
        }))
        return
      }

      const monthlyData = Array.isArray(monthlyResult) ? monthlyResult[0] : monthlyResult

      if (monthlyData.status === 'ERROR') {
        console.error('❌ 月次紹介報酬計算エラー:', monthlyData.message)
        setMessage(prev => ({
          type: "warning",
          text: (prev?.text || '') + `\n\n⚠️ ${monthlyData.message}`
        }))
        return
      }

      console.log('✅ 月次紹介報酬計算成功:', monthlyData)

      // 成功メッセージに追記
      setMessage(prev => ({
        type: "success",
        text: (prev?.text || '') + `\n\n🎉 月末処理完了！\n月次紹介報酬: ${monthlyData.details?.total_users || 0}名に$${monthlyData.details?.total_amount || 0}配布`
      }))

    } catch (error: any) {
      console.error('月末チェックエラー:', error)
    }
  }

  const handleEdit = (item: YieldHistory) => {
    // フォームに既存データをセット
    setDate(item.date)

    // DBの値: yield_rate/user_rateは％値、margin_rateは小数値
    setYieldRate(Number.parseFloat(item.yield_rate.toString()).toFixed(3))
    setMarginRate((Number.parseFloat(item.margin_rate.toString()) * 100).toFixed(0))

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

      // V2テーブルから削除（V2を優先）
      const { data: existingDataV2, error: checkExistErrorV2 } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .eq("date", cancelDate)

      console.log("V2削除対象データ:", existingDataV2)

      if (existingDataV2 && existingDataV2.length > 0) {
        // V2テーブルの関連データを削除
        const [deleteV2Log, deleteNftProfit, deleteReferralProfit] = await Promise.all([
          supabase.from("daily_yield_log_v2").delete().eq("date", cancelDate),
          supabase.from("nft_daily_profit").delete().eq("date", cancelDate),
          supabase.from("user_referral_profit").delete().eq("date", cancelDate)
        ])

        console.log("V2削除結果:", { deleteV2Log, deleteNftProfit, deleteReferralProfit })

        if (!deleteV2Log.error) {
          setMessage({
            type: "success",
            text: `${cancelDate}の日利設定をキャンセルしました（V2）`,
          })
          setTimeout(() => {
            fetchHistory()
            fetchStats()
          }, 500)
          return
        } else {
          console.error("V2削除エラー:", deleteV2Log.error)
        }
      }

      // V1テーブルからも削除を試みる（フォールバック）
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

  // 月次紹介報酬計算ハンドラー
  const handleMonthlyReferralCalculation = async () => {
    if (!confirm(`${monthlyYearMonth}の月次紹介報酬を計算しますか？\n\nこの処理により：\n- 指定月の個人利益を集計\n- 紹介報酬を計算（Level 1-3）\n- cum_usdtとavailable_usdtに加算\n- NFT自動付与（$2,200以上）\n\n実行しますか？`)) {
      return
    }

    setMonthlyLoading(true)
    setMonthlyMessage(null)

    try {
      const { data: rpcResult, error: rpcError } = await supabase.rpc('process_monthly_referral_profit', {
        p_year_month: monthlyYearMonth,
        p_is_test_mode: false
      })

      if (rpcError) {
        console.error('❌ 月次計算エラー:', rpcError)
        throw new Error(`月次計算エラー: ${rpcError.message}`)
      }

      const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

      console.log('✅ 月次計算成功:', result)

      if (result.status === 'ERROR') {
        throw new Error(result.message)
      }

      setMonthlyMessage({
        type: "success",
        text: `✅ ${result.message || '月次紹介報酬計算完了'}

処理詳細:
• 総紹介報酬: $${(result.details.total_referral_profit || 0).toFixed(2)}
• 紹介報酬レコード数: ${result.details.referral_count || 0}件
• 対象ユーザー数: ${result.details.user_count || 0}名
• NFT自動付与: ${result.details.auto_nft_count || 0}名`,
      })

      fetchHistory()
      fetchStats()
    } catch (error: any) {
      console.error('❌ 月次計算エラー:', error)
      setMonthlyMessage({
        type: "error",
        text: `エラー: ${error.message}`,
      })
    } finally {
      setMonthlyLoading(false)
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
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
    <div className="min-h-screen bg-black">
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
            <Badge variant="destructive" className="text-sm">
              本番モード
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

        {/* 月次紹介報酬計算 */}
        <Card className="bg-gradient-to-r from-purple-900 to-indigo-900 border-purple-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              <UsersIcon className="h-5 w-5" />
              月次紹介報酬計算
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {monthlyMessage && (
              <Alert className={monthlyMessage.type === "success" ? "bg-green-900/50 border-green-500" : "bg-red-900/50 border-red-500"}>
                {monthlyMessage.type === "success" ? <CheckCircle className="h-4 w-4" /> : <AlertCircle className="h-4 w-4" />}
                <AlertDescription className="whitespace-pre-line text-white">
                  {monthlyMessage.text}
                </AlertDescription>
              </Alert>
            )}

            <div className="space-y-4">
              <div className="bg-purple-800/30 p-4 rounded-lg">
                <h3 className="text-white font-medium mb-2">📋 月次紹介報酬とは？</h3>
                <ul className="text-sm text-purple-100 space-y-1 list-disc list-inside">
                  <li>指定月の個人利益を集計</li>
                  <li>紹介報酬を計算（Level 1: 20%, Level 2: 10%, Level 3: 5%）</li>
                  <li>cum_usdtとavailable_usdtに加算</li>
                  <li>NFT自動付与（$2,200以上）</li>
                </ul>
              </div>

              <div className="space-y-2">
                <Label htmlFor="monthly-year-month" className="text-white">
                  対象年月（YYYY-MM）
                </Label>
                <Input
                  id="monthly-year-month"
                  type="month"
                  value={monthlyYearMonth}
                  onChange={(e) => setMonthlyYearMonth(e.target.value)}
                  className="bg-gray-700 text-white border-gray-600"
                />
              </div>

              <Button
                onClick={handleMonthlyReferralCalculation}
                disabled={monthlyLoading || !monthlyYearMonth}
                className="w-full bg-purple-600 hover:bg-purple-700 text-white"
              >
                {monthlyLoading ? (
                  <>
                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                    計算中...
                  </>
                ) : (
                  <>
                    <UsersIcon className="mr-2 h-4 w-4" />
                    月次紹介報酬を計算
                  </>
                )}
              </Button>

              <div className="bg-yellow-900/30 p-3 rounded-lg">
                <p className="text-xs text-yellow-200">
                  ⚠️ 注意: この処理は通常、月末に実行します。同じ月の計算を2回実行することはできません。
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

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
                          <p className={`text-lg font-bold ${Number.parseFloat(totalProfitAmount) >= 0 ? "text-green-400" : "text-red-400"}`}>
                            個人利益: ${(Number.parseFloat(totalProfitAmount) * 0.7 * 0.6).toFixed(2)}
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
                  <div className={`text-2xl font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                    {userRate.toFixed(3)}%
                  </div>
                  <p className="text-sm text-gray-400">
                    {Number.parseFloat(yieldRate) !== 0
                      ? `${yieldRate}% × (1 - ${marginRate}%/100) × 0.6 = ユーザー受取 ${userRate.toFixed(3)}%`
                      : `0% = ユーザー受取 0%`
                    }
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
                設定履歴
              </CardTitle>
              <div className="flex gap-2">
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
                  onClick={fetchHistory}
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
            {history.length === 0 ? (
                <p className="text-gray-400">履歴がありません</p>
              ) : (
                <div>
                  {/* 月選択ドロップダウン */}
                  <div className="mb-4 flex items-center gap-4">
                    <Label className="text-white">表示月:</Label>
                    <select
                      value={selectedMonth}
                      onChange={(e) => setSelectedMonth(e.target.value)}
                      className="bg-gray-700 text-white border border-gray-600 rounded px-3 py-2"
                    >
                      {Array.from(new Set(history.map(item => item.date.substring(0, 7))))
                        .sort()
                        .reverse()
                        .map(month => {
                          const isV2 = history.find(item => item.date.startsWith(month))?.system === 'V2'
                          return (
                            <option key={month} value={month}>
                              {month} ({isV2 ? '金額入力' : '利率入力'})
                            </option>
                          )
                        })}
                    </select>
                  </div>

                  {/* 選択された月の履歴 */}
                  {(() => {
                    const filteredHistory = history.filter(item => item.date.startsWith(selectedMonth))
                    const isV2 = filteredHistory[0]?.system === 'V2'

                    if (filteredHistory.length === 0) {
                      return <p className="text-gray-400">この月のデータはありません</p>
                    }

                    return (
                      <div className="overflow-x-auto">
                        <table className="w-full text-sm text-white">
                          <thead>
                            <tr className="border-b border-gray-600">
                              <th className="text-left p-2">日付</th>
                              {isV2 ? (
                                <>
                                  <th className="text-left p-2">運用利益</th>
                                  <th className="text-left p-2">NFT数</th>
                                  <th className="text-left p-2">単価利益</th>
                                </>
                              ) : (
                                <>
                                  <th className="text-left p-2">日利率</th>
                                  <th className="text-left p-2">マージン率</th>
                                  <th className="text-left p-2">ユーザー利率</th>
                                </>
                              )}
                              <th className="text-left p-2">設定日時</th>
                              <th className="text-left p-2">操作</th>
                            </tr>
                          </thead>
                          <tbody>
                            {filteredHistory.map((item) => (
                              <tr key={item.id} className="border-b border-gray-700">
                                <td className="p-2">{new Date(item.date).toLocaleDateString("ja-JP")}</td>
                                {isV2 ? (
                                  <>
                                    <td className={`p-2 font-medium ${item.total_profit_amount >= 0 ? "text-green-400" : "text-red-400"}`}>
                                      ${item.total_profit_amount?.toLocaleString()}
                                    </td>
                                    <td className="p-2">{item.total_nft_count}個</td>
                                    <td className={`p-2 font-medium ${item.profit_per_nft >= 0 ? "text-green-400" : "text-red-400"}`}>
                                      ${item.profit_per_nft?.toFixed(3)}
                                    </td>
                                  </>
                                ) : (
                                  <>
                                    <td className={`p-2 font-medium ${Number.parseFloat(item.yield_rate.toString()) >= 0 ? "text-green-400" : "text-red-400"}`}>
                                      {Number.parseFloat(item.yield_rate.toString()).toFixed(3)}%
                                    </td>
                                    <td className={`p-2 ${Number.parseFloat(item.margin_rate.toString()) > 1 ? "bg-red-900 text-red-300 font-bold" : ""}`}>
                                      {(Number.parseFloat(item.margin_rate.toString()) * 100).toFixed(0)}%
                                      {Number.parseFloat(item.margin_rate.toString()) > 1 && (
                                        <span className="ml-1 text-xs">⚠️異常値</span>
                                      )}
                                    </td>
                                    <td className={`p-2 font-medium ${Number.parseFloat(item.user_rate.toString()) >= 0 ? "text-green-400" : "text-red-400"}`}>
                                      {Number.parseFloat(item.user_rate.toString()).toFixed(3)}%
                                    </td>
                                  </>
                                )}
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
                                    onClick={() => handleForceDelete(item.id, item.date)}
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
                    )
                  })()}
                </div>
              )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}