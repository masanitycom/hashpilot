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
  // V2専用フィールチE  total_profit_amount?: number
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

  // V2シスチE��刁E��替え（常にV2を使用�E�E  const useV2 = true


  // 履歴表示用の月選択（データがある最新月を自動選択するため空斁E��で初期化！E  const [selectedMonth, setSelectedMonth] = useState("")

  // ユーザー受取玁E��計箁E  useEffect(() => {
    const yield_rate = Number.parseFloat(yieldRate) || 0
    const margin_rate = Number.parseFloat(marginRate) || 0
    
    // プラス/マイナス共送E マ�Eジンを引いてから0.6を掛ける
    let calculated_user_rate: number
    if (yield_rate !== 0) {
      // プラスも�Eイナスも同じ計箁E (1 - マ�Eジン玁E ÁE0.6
      const after_margin = yield_rate * (1 - margin_rate / 100)
      calculated_user_rate = after_margin * 0.6
    } else {
      // ゼロの場吁E      calculated_user_rate = 0
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

      // 緊急対忁E basarasystems@gmail.com と support@dshsupport.biz のアクセス許可
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
        // フォールバック: usersチE�Eブルのis_adminフィールドをチェチE��
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

        setError("管琁E��E��限�E確認でエラーが発生しました")
        setAuthLoading(false)
        return
      }

      if (!adminCheck) {
        // フォールバック: usersチE�Eブルのis_adminフィールドをチェチE��
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

        alert("管琁E��E��限がありません")
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
      setError("管琁E��E��限�E確認でエラーが発生しました")
      setAuthLoading(false)
    }
  }

  const fetchHistory = async () => {
    try {
      // V1履歴�E�E1月、利玁E��E��E      const { data: v1Data, error: v1Error } = await supabase
        .from("daily_yield_log")
        .select("*")
        .order("date", { ascending: false })

      if (v1Error) throw v1Error

      // V2履歴�E�E2月、E��顁E�E�E      const { data: v2Data, error: v2Error } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .order("date", { ascending: false })

      if (v2Error) {
        console.warn("V2履歴取得エラー:", v2Error)
      }

      // V1チE�Eタを変換�E�既存形式を維持E��E      const v1History = (v1Data || []).map(item => ({
        ...item,
        system: 'V1' as const,
      }))

      // V2チE�Eタを変換�E�E1形式に合わせる�E�E      const v2History = (v2Data || []).map(item => ({
        id: item.id.toString(),
        date: item.date,
        yield_rate: (item.daily_pnl / item.total_nft_count / 10) || 0,  // 概算�E利玁E        margin_rate: item.fee_rate || 0.30,
        user_rate: (item.daily_pnl / item.total_nft_count / 10 * 0.7 * 0.6) || 0,  // 概箁E        total_users: 0,
        created_at: item.created_at,
        system: 'V2' as const,
        // V2専用チE�Eタ
        total_profit_amount: item.total_profit_amount,
        total_nft_count: item.total_nft_count,
        profit_per_nft: item.profit_per_nft,
      }))

      // 統合して日付頁E��ソーチE      const allHistory = [...v1History, ...v2History].sort((a, b) =>
        new Date(b.date).getTime() - new Date(a.date).getTime()
      )

      setHistory(allHistory)

      // チE�Eタがある最新月を自動選択（�E回�Eみ�E�E      if (allHistory.length > 0 && !selectedMonth) {
        const latestMonth = allHistory[0].date.substring(0, 7)
        setSelectedMonth(latestMonth)
      }
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

      // 全承認済み購入とユーザー惁E��を取得（�Eガサスフラグも含む�E�E      const { data: purchasesData, error: purchasesError } = await supabase
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

      // 運用中と運用開始前に刁E��て雁E��（�Eガサスユーザーは除外！E      const totalInvestmentActive = purchasesData?.reduce((sum, p: any) => {
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

      // ペガサスユーザーの投賁E��を別途集訁E      const pegasusInvestment = purchasesData?.reduce((sum, p: any) => {
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
        avg_yield_rate: avgYieldRate,  // 既にパ�Eセント値なので100倍不要E        total_distributed: totalDistributed,
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
      // ========== 重要E��未来の日付チェチE�� ==========
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const selectedDate = new Date(date)
      selectedDate.setHours(0, 0, 0, 0)

      if (selectedDate > today) {
        throw new Error(`❁E未来の日付！E{date}�E�には設定できません。今日は ${today.toISOString().split('T')[0]} です。`)
      }

      if (useV2) {
        // ========== V2シスチE���E���額�E力！E==========
        const profitAmount = Number.parseFloat(totalProfitAmount)

        console.log('🚀 日利設定開始！E2 - 金額�E力！E', {
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
          console.error('❁ERPC関数エラー:', rpcError)
          throw new Error(`日利処琁E��ラー: ${rpcError.message}`)
        }

        const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

        console.log('✁EV2 RPC関数実行�E劁E', result)

        setMessage({
          type: "success",
          text: `✁E${result.message || '日利設定完亁E��E2�E�E}

処琁E��細:
• 運用利盁E $${profitAmount.toFixed(2)}
• NFT総数: ${result.details?.input?.total_nft_count || 0}倁E• NFT単価利盁E $${((result.details?.input?.profit_per_nft || 0) * 0.7 * 0.6).toFixed(3)}
• 個人利益�E币E $${(result.details?.distribution?.total_distributed || 0).toFixed(2)}
• NFT自動付丁E ${result.details?.distribution?.auto_nft_count || 0}件
※ 紹介報酬は月末に月次処琁E��計算されます`,
        })

        setTotalProfitAmount("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()

        // V2でも月末かチェチE��して自動的に紹介報酬を計箁E        await checkAndProcessMonthlyReferral(date)

      } else {
        // ========== V1シスチE���E�利玁E�E力！E==========
        const yieldValue = Number.parseFloat(yieldRate) / 100  // パ�Eセント�E小数に変換
        const marginValue = Number.parseFloat(marginRate) / 100  // パ�Eセント�E小数に変換

        console.log('🚀 日利設定開始！E1 - 利玁E�E力！E', {
          date,
          yield_rate: yieldValue,
          margin_rate: marginValue,
          is_test_mode: false
        })

        // RPC関数を呼び出す（小数値で送信�E�E        const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_with_cycles', {
          p_date: date,
          p_yield_rate: yieldValue,
          p_margin_rate: marginValue,
          p_is_test_mode: false,
          p_skip_validation: false
        })

        if (rpcError) {
          console.error('❁ERPC関数エラー:', rpcError)
          throw new Error(`日利処琁E��ラー: ${rpcError.message}`)
        }

        const result = Array.isArray(rpcResult) ? rpcResult[0] : rpcResult

        console.log('✁EV1 RPC関数実行�E劁E', result)

        setMessage({
          type: "success",
          text: `✁E${result.message || '日利設定完亁E��E1�E�E}

処琁E��細:
• 日利配币E ${result.total_users || 0}名に総顁E${(result.total_user_profit || 0).toFixed(2)}
• 紹介報酬: ${result.referral_rewards_processed || 0}名に配币E• NFT自動付丁E ${result.auto_nft_purchases || 0}名に付丁E• サイクル更新: ${result.cycle_updates || 0}件`,
        })

        setYieldRate("")
        setDate(new Date().toISOString().split("T")[0])
        fetchHistory()
        fetchStats()

        // 月末かチェチE��して自動的に紹介報酬を計箁E        await checkAndProcessMonthlyReferral(date)
      }
    } catch (error: any) {
      console.error('❁E日利設定エラー:', error)
      setMessage({
        type: "error",
        text: `エラー: ${error.message}`,
      })
    } finally {
      setIsLoading(false)
    }
  }

  // 月末チェチE���E�E�E動紹介報酬計箁E  const checkAndProcessMonthlyReferral = async (settingDate: string) => {
    try {
      const targetDate = new Date(settingDate)
      const year = targetDate.getFullYear()
      const month = targetDate.getMonth() + 1

      // 月末日を取征E      const lastDayOfMonth = new Date(year, month, 0).getDate()
      const currentDay = targetDate.getDate()

      // 月末の日利設定かどぁE��をチェチE��
      const isMonthEnd = currentDay === lastDayOfMonth

      // 月末でなぁE��合�EスキチE�E
      if (!isMonthEnd) {
        console.log(`📅 ${settingDate}は月末ではありません。紹介報酬計算をスキチE�Eします。`)
        return
      }

      // 月末最終日の日利設宁EↁEそ�E月�E紹介報酬を計箁E      const targetYear = year
      const targetMonth = month

      console.log(`📅 ${settingDate}は月末です、E{targetYear}年${targetMonth}月�E紹介報酬を�E動計算しまぁE..`)

      // 月次紹介報酬を計算！EargetYear/targetMonthを使用�E�E      const { data: monthlyResult, error: monthlyError } = await supabase.rpc('process_monthly_referral_reward', {
        p_year: targetYear,
        p_month: targetMonth,
        p_overwrite: false
      })

      if (monthlyError) {
        console.error('❁E月次紹介報酬計算エラー:', monthlyError)
        // エラーでも日利設定�E成功してぁE��ので、警告�Eみ表示
        setMessage(prev => ({
          type: "warning",
          text: (prev?.text || '') + `\n\n⚠�E�E月次紹介報酬の自動計算に失敗しました: ${monthlyError.message}\n手動で実行してください: SELECT * FROM process_monthly_referral_reward(${year}, ${month});`
        }))
        return
      }

      const monthlyData = Array.isArray(monthlyResult) ? monthlyResult[0] : monthlyResult

      if (monthlyData.status === 'ERROR') {
        console.error('❁E月次紹介報酬計算エラー:', monthlyData.message)
        setMessage(prev => ({
          type: "warning",
          text: (prev?.text || '') + `\n\n⚠�E�E${monthlyData.message}`
        }))
        return
      }

      console.log('✅ 月次紹介報酬計算完了:', monthlyData)

      // ========================================
      // 紹介報酬計算完了フラグを設定（タスクポップアップ用）
      // ========================================
      try {
        const { error: markError } = await supabase.rpc('mark_referral_reward_calculated', {
          p_year: targetYear,
          p_month: targetMonth
        })
        if (markError) {
          console.error('⚠️ mark_referral_reward_calculated エラー:', markError)
        } else {
          console.log('✅ 紹介報酬計算完了フラグ設定完了')
        }
      } catch (markErr) {
        console.error('⚠️ mark_referral_reward_calculated 例外:', markErr)
      }

      // ========================================
      // 月末出金処理を自動実行
      // ========================================
      console.log('💰 月末出金処理を開始...')

      // 対象月�E月�E日を作�E�E�Erocess_monthly_withdrawalsの引数用�E�E      const targetMonthDate = `${targetYear}-${String(targetMonth).padStart(2, '0')}-01`

      const { data: withdrawalResult, error: withdrawalError } = await supabase.rpc('process_monthly_withdrawals', {
        p_target_month: targetMonthDate
      })

      let withdrawalMessage = ''
      if (withdrawalError) {
        console.error('❁E月末出金�E琁E��ラー:', withdrawalError)
        withdrawalMessage = `\n⚠�E�E月末出金�E琁E��エラー: ${withdrawalError.message}`
      } else if (withdrawalResult && withdrawalResult.length > 0) {
        const wdData = withdrawalResult[0]
        console.log('✁E月末出金�E琁E�E劁E', wdData)
        withdrawalMessage = `\n💰 月末出釁E ${wdData.processed_count}件�E�総顁E${wdData.total_amount}�E�`
      } else {
        withdrawalMessage = '\n💰 月末出釁E 対象老E��ぁE
      }

      // 成功メチE��ージに追訁E      setMessage(prev => ({
        type: "success",
        text: (prev?.text || '') + `\n\n🎉 月末処琁E��亁E��\n月次紹介報酬: ${monthlyData.details?.total_users || 0}名に$${monthlyData.details?.total_amount || 0}配币E{withdrawalMessage}`
      }))

    } catch (error: any) {
      console.error('月末チェチE��エラー:', error)
    }
  }

  const handleEdit = (item: YieldHistory) => {
    // フォームに既存データをセチE��
    setDate(item.date)

    // DBの値: yield_rate/user_rateは�E�E��、margin_rateは小数値
    setYieldRate(Number.parseFloat(item.yield_rate.toString()).toFixed(3))
    setMarginRate((Number.parseFloat(item.margin_rate.toString()) * 100).toFixed(0))

    // ペ�Eジ上部のフォームにスクロール
    window.scrollTo({ top: 0, behavior: 'smooth' })

    setMessage({
      type: "warning",
      text: `${item.date}の日利設定を修正モードで読み込みました。変更後、「日利を設定」�Eタンで保存してください。`,
    })
  }

  const handleCancel = async (cancelDate: string) => {
    if (!confirm(`${cancelDate}の日利設定をキャンセルしますか�E�この操作�E取り消せません。`)) {
      return
    }

    try {
      // まず管琁E��E��RPC関数を試ぁE      try {
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
        
        console.warn("RPC関数エラー、直接削除に刁E��替ぁE", rpcError)
      } catch (rpcFallbackError) {
        console.warn("RPC関数使用不可、直接削除に刁E��替ぁE", rpcFallbackError)
      }

      // RPC関数が失敗した場合�E直接削除
      const { data: { user } } = await supabase.auth.getUser()

      if (!user) {
        throw new Error("ユーザー認証が忁E��でぁE)
      }

      // V2チE�Eブルから削除�E�E2を優先！E      const { data: existingDataV2, error: checkExistErrorV2 } = await supabase
        .from("daily_yield_log_v2")
        .select("*")
        .eq("date", cancelDate)

      console.log("V2削除対象チE�Eタ:", existingDataV2)

      if (existingDataV2 && existingDataV2.length > 0) {
        // V2チE�Eブルの関連チE�Eタを削除
        const [deleteV2Log, deleteNftProfit, deleteReferralProfit] = await Promise.all([
          supabase.from("daily_yield_log_v2").delete().eq("date", cancelDate),
          supabase.from("nft_daily_profit").delete().eq("date", cancelDate),
          supabase.from("user_referral_profit").delete().eq("date", cancelDate)
        ])

        console.log("V2削除結果:", { deleteV2Log, deleteNftProfit, deleteReferralProfit })

        if (!deleteV2Log.error) {
          setMessage({
            type: "success",
            text: `${cancelDate}の日利設定をキャンセルしました�E�E2�E�`,
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

      // V1チE�Eブルからも削除を試みる（フォールバック�E�E      const { data: existingData, error: checkExistError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .eq("date", cancelDate)

      console.log("削除対象チE�Eタ:", existingData)
      
      if (checkExistError) {
        throw new Error(`チE�Eタ確認エラー: ${checkExistError.message}`)
      }

      if (!existingData || existingData.length === 0) {
        throw new Error("削除対象のチE�Eタが見つかりません")
      }

      // IDを使用して削除を試みめE      const targetId = existingData[0].id
      console.log("削除対象ID:", targetId)

      // IDで削除を試みめE      const { data: deleteByIdData, error: deleteByIdError } = await supabase
        .from("daily_yield_log")
        .delete()
        .eq("id", targetId)
        .select()

      if (deleteByIdError) {
        console.error("ID削除エラー:", deleteByIdError)
        
        // 日付で削除を試みめE        const { data: yieldData, error: deleteYieldError } = await supabase
          .from("daily_yield_log")
          .delete()
          .eq("date", cancelDate)
          .select()

        if (deleteYieldError) {
          console.error("daily_yield_log削除エラー:", deleteYieldError)
          throw new Error(`日利設定�E削除に失敁E ${deleteYieldError.message}`)
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

      // 削除後�E再確誁E      const { data: remainingData, error: finalCheckError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .eq("date", cancelDate)

      console.log("削除後�E残存データ:", remainingData)

      if (!finalCheckError && remainingData && remainingData.length > 0) {
        // 3000%の異常値の場合�E特別な処琁E        if (remainingData[0].margin_rate && parseFloat(remainingData[0].margin_rate) > 1) {
          console.error("異常値チE�Eタの削除に失敗。管琁E��E��連絡してください、E)
          throw new Error("3000%の異常値チE�Eタは手動削除が忁E��です。SupabaseダチE��ュボ�Eドから削除してください、E)
        }
        throw new Error("チE�Eタの削除に失敗しました。権限を確認してください、E)
      }

      const deletedCount = (deleteByIdData?.length || 0) + (profitData?.length || 0)
      setMessage({
        type: "success",
        text: `${cancelDate}の日利設定をキャンセルしました�E�E{deletedCount}件削除�E�`,
      })

      // 少し征E��てから再取征E      setTimeout(() => {
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
      "削除�E�推奨�E�E,
      "正常値に修正�E�E0%に変更�E�E,
      "キャンセル"
    ]
    
    const choice = confirm(`ID:${recordId} (${targetDate}) の3000%異常値チE�EタをどぁE��ますか�E�\n\n1. 削除を試行（推奨�E�\n2. 正常値�E�E0%�E�に修正\n\nOK = 削除、キャンセル = 修正`)

    try {
      if (choice) {
        // 削除を試衁E        setMessage({ type: "warning", text: "削除試行中..." })

        console.log("削除開姁E- ID:", recordId, "Date:", targetDate)

        // すべての削除方法を同時に実衁E        const [deleteById, deleteByCondition, deleteProfits] = await Promise.all([
          supabase.from("daily_yield_log").delete().eq("id", recordId),
          supabase.from("daily_yield_log").delete().eq("date", targetDate).gt("margin_rate", 1),
          supabase.from("user_daily_profit").delete().eq("date", targetDate)
        ])

        console.log("削除結果:", { deleteById, deleteByCondition, deleteProfits })

        // 削除確誁E        await new Promise(resolve => setTimeout(resolve, 1000))
        
        const { data: checkData } = await supabase
          .from("daily_yield_log")
          .select("*")
          .eq("date", targetDate)

        console.log("削除後確誁E", checkData)

        if (checkData && checkData.length === 0) {
          setMessage({
            type: "success",
            text: `${targetDate}の異常値チE�Eタを削除しました`,
          })
        } else {
          // 削除失敗時は自動的に修正を提桁E          if (confirm("削除に失敗しました。�Eージン玁E��30%に修正しますか�E�E)) {
            await handleFixAnomaly(recordId, targetDate)
            return
          } else {
            setMessage({
              type: "error",
              text: "RLSポリシーにより削除が制限されてぁE��す。SupabaseダチE��ュボ�Eドから手動削除してください、E,
            })
          }
        }
      } else {
        // 修正を選抁E        await handleFixAnomaly(recordId, targetDate)
      }

      // 履歴を�E取征E      setTimeout(() => {
        fetchHistory()
        fetchStats()
      }, 1500)

    } catch (error: any) {
      console.error("処琁E��ラー:", error)
      setMessage({
        type: "error",
        text: `処琁E��失敁E ${error.message}`,
      })
    }
  }

  const handleFixAnomaly = async (recordId: string, targetDate: string) => {
    try {
      setMessage({ type: "warning", text: "異常値を修正中..." })

      // 現在のチE�Eタを取征E      const { data: currentData, error: fetchError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .eq("id", recordId)
        .single()

      if (fetchError || !currentData) {
        throw new Error("チE�Eタ取得に失敗しました")
      }

      // 正常なマ�Eジン玁E��E0%�E�に修正
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

      // user_daily_profitも�E計算が忁E��な場吁E      const { error: recalcError } = await supabase.rpc("recalculate_daily_profit", {
        p_date: targetDate
      }).catch(() => {
        console.log("再計算RPC関数が存在しなぁE��合�E手動で修正が忁E��E)
      })

      setMessage({
        type: "success",
        text: `${targetDate}の異常値を修正しました�E��Eージン玁E 3000% ↁE30%�E�`,
      })

    } catch (error: any) {
      console.error("修正エラー:", error)
      setMessage({
        type: "error",
        text: `修正に失敁E ${error.message}`,
      })
    }
  }

  // 認証確認中はローチE��ング表示
  if (authLoading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">認証確認中...</p>
        </div>
      </div>
    )
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
            <p>管琁E��E��限が忁E��です、E/p>
            <Button
              onClick={() => router.push("/dashboard")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              ダチE��ュボ�Eドに戻めE            </Button>
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
          <div className="flex items-center gap-4">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <Shield className="h-6 w-6 text-blue-400" />
              日利設宁E            </h1>
          </div>
          <div className="flex items-center gap-2">
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
            >
              管琁E��E��チE��ュボ�EチE            </Button>
          </div>
        </div>

        {/* 統計情報 */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                  <UsersIcon className="h-4 w-4" />
                  アクチE��ブユーザー
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
                  総投賁E��E                </CardTitle>
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
                <p className="text-xs text-blue-200">運用中�E��Eガサス除く！E/p>
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
                  平坁E��利玁E                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">{stats.avg_yield_rate.toFixed(2)}%</div>
                <p className="text-xs text-purple-200">過去の平坁E/p>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                  <DollarSignIcon className="h-4 w-4" />
                  総�E币E��盁E                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-white">${stats.total_distributed.toLocaleString()}</div>
                <p className="text-xs text-yellow-200">累積�E币E��E/p>
              </CardContent>
            </Card>
          </div>
        )}

        {/* 日利設定フォーム */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              <CalendarIcon className="h-5 w-5" />
              日利設宁E            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {/* 日付フィールド（�E通！E*/}
                <div className="space-y-2">
                  <Label htmlFor="date" className="text-white">
                    日仁E                  </Label>
                  <Input
                    id="date"
                    type="date"
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    required
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>

                {/* V1/V2 刁E��E*/}
                {useV2 ? (
                  // ========== V2: 金額�E劁E==========
                  <>
                    <div className="space-y-2 md:col-span-2">
                      <Label htmlFor="totalProfitAmount" className="text-white flex items-center gap-2">
                        運用利益！E�E�E                        <Badge className="bg-blue-600">V2シスチE��</Badge>
                      </Label>
                      <Input
                        id="totalProfitAmount"
                        type="number"
                        step="0.01"
                        min="-100000"
                        max="1000000"
                        value={totalProfitAmount}
                        onChange={(e) => setTotalProfitAmount(e.target.value)}
                        placeholder="侁E 1580.32 (マイナス可)"
                        required
                        className="bg-gray-700 border-gray-600 text-white"
                      />
                      <p className="text-xs text-gray-400">
                        今日の運用利益を金額！E�E�で入力してください。�Eイナスの場合�E -1580.32 のように入力、E                      </p>
                      {stats && totalProfitAmount && (
                        <div className="mt-2 p-3 bg-gray-700 rounded-lg">
                          <p className="text-sm font-medium text-white">予想配币E��E</p>
                          <p className={`text-lg font-bold ${Number.parseFloat(totalProfitAmount) >= 0 ? "text-green-400" : "text-red-400"}`}>
                            個人利盁E ${(Number.parseFloat(totalProfitAmount) * 0.7 * 0.6).toFixed(2)}
                          </p>
                          <p className="text-xs text-gray-400">
                            NFT総数: {(stats.total_investment / 1000).toFixed(0)}倁E                          </p>
                        </div>
                      )}
                    </div>
                  </>
                ) : (
                  // ========== V1: 利玁E�E劁E==========
                  <>
                    <div className="space-y-2">
                      <Label htmlFor="yieldRate" className="text-white flex items-center gap-2">
                        日利玁E(%)
                        <Badge className="bg-gray-600">V1シスチE��</Badge>
                      </Label>
                      <Input
                        id="yieldRate"
                        type="number"
                        step="0.001"
                        min="-10"
                        max="100"
                        value={yieldRate}
                        onChange={(e) => setYieldRate(e.target.value)}
                        placeholder="侁E 1.500 (マイナス可)"
                        required
                        className="bg-gray-700 border-gray-600 text-white"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="marginRate" className="text-white">
                        マ�Eジン玁E(%)
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
                              text: "マ�Eジン玁E�E100%以下に設定してください"
                            })
                          }
                        }}
                        placeholder="侁E 30"
                        required
                        className="bg-gray-700 border-gray-600 text-white"
                      />
                      <p className="text-xs text-gray-400">
                        ⚠�E�E通常は30%程度、E00%を趁E��る値は設定できません
                      </p>
                    </div>
                  </>
                )}
              </div>

              {/* V1のみ�E�ユーザー受取玁E��示 */}
              {!useV2 && (
                <div className="space-y-2">
                  <Label className="text-white">ユーザー受取玁E/Label>
                  <div className={`text-2xl font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                    {userRate.toFixed(3)}%
                  </div>
                  <p className="text-sm text-gray-400">
                    {Number.parseFloat(yieldRate) !== 0
                      ? `${yieldRate}% ÁE(1 - ${marginRate}%/100) ÁE0.6 = ユーザー受取 ${userRate.toFixed(3)}%`
                      : `0% = ユーザー受取 0%`
                    }
                  </p>
                  {stats && yieldRate && (
                    <div className="mt-2 p-3 bg-gray-700 rounded-lg">
                      <p className="text-sm font-medium text-white">予想配币E��E</p>
                      <p className={`text-lg font-bold ${userRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                        ${((stats.total_investment * userRate) / 100).toLocaleString()}
                      </p>
                      <p className="text-xs text-gray-400">{stats.total_users}名�Eユーザーに配币E��宁E/p>
                    </div>
                  )}
                </div>
              )}


              <Button
                type="submit"
                disabled={isLoading}
                className="w-full md:w-auto bg-red-600 hover:bg-red-700"
              >
                {isLoading ? "処琁E��..." : "日利を設宁E}
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

        {/* 履歴・チE��ト結果 */}
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
                      
                      console.log("全履歴チE�Eタ:", data)
                      if (error) console.error("履歴取得エラー:", error)
                      
                      const { count, error: countError } = await supabase
                        .from("daily_yield_log")
                        .select("*", { count: "exact", head: true })
                      
                      console.log("総レコード数:", count)
                      if (countError) console.error("カウントエラー:", countError)
                      
                      setMessage({
                        type: "success",
                        text: `チE��チE��惁E��をコンソールに出力しました�E�E{count}件�E�`
                      })
                    } catch (err) {
                      console.error("チE��チE��エラー:", err)
                    }
                  }}
                  size="sm" 
                  variant="outline"
                  className="border-yellow-600 text-yellow-300"
                >
                  🔍 DB確誁E                </Button>
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
                  {/* 月選択ドロチE�Eダウン */}
                  <div className="mb-4 flex items-center gap-4">
                    <Label className="text-white">表示朁E</Label>
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
                              {month} ({isV2 ? '金額�E劁E : '利玁E�E劁E})
                            </option>
                          )
                        })}
                    </select>
                  </div>

                  {/* 選択された月�E履歴 */}
                  {(() => {
                    const filteredHistory = history.filter(item => item.date.startsWith(selectedMonth))
                    const isV2 = filteredHistory[0]?.system === 'V2'

                    if (filteredHistory.length === 0) {
                      return <p className="text-gray-400">こ�E月�EチE�Eタはありません</p>
                    }

                    // 月間合計計箁E                    const monthlyTotalProfitPerNft = isV2
                      ? filteredHistory.reduce((sum, item) => sum + ((item.profit_per_nft || 0) * 0.7 * 0.6), 0)
                      : filteredHistory.reduce((sum, item) => sum + Number.parseFloat(item.user_rate?.toString() || '0'), 0)
                    const monthlyTotalProfit = isV2
                      ? filteredHistory.reduce((sum, item) => sum + (item.total_profit_amount || 0), 0)
                      : 0

                    return (
                      <div className="overflow-x-auto">
                        {/* 月間サマリー */}
                        <div className="mb-4 p-4 bg-gradient-to-r from-blue-900/50 to-purple-900/50 rounded-lg border border-blue-700/50">
                          <div className="flex flex-wrap gap-6">
                            <div>
                              <p className="text-xs text-gray-400 mb-1">月間合訁E(NFT単価)</p>
                              <p className={`text-2xl font-bold ${monthlyTotalProfitPerNft >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                                {isV2 ? `$${monthlyTotalProfitPerNft.toFixed(3)}` : `${monthlyTotalProfitPerNft.toFixed(3)}%`}
                              </p>
                            </div>
                            {isV2 && (
                              <div>
                                <p className="text-xs text-gray-400 mb-1">月間運用利益合訁E/p>
                                <p className={`text-2xl font-bold ${monthlyTotalProfit >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                                  ${monthlyTotalProfit.toLocaleString()}
                                </p>
                              </div>
                            )}
                            <div>
                              <p className="text-xs text-gray-400 mb-1">設定日数</p>
                              <p className="text-2xl font-bold text-white">{filteredHistory.length}日</p>
                            </div>
                          </div>
                        </div>
                        <table className="w-full text-sm text-white">
                          <thead>
                            <tr className="border-b border-gray-600">
                              <th className="text-left p-2">日仁E/th>
                              {isV2 ? (
                                <>
                                  <th className="text-left p-2">運用利盁E/th>
                                  <th className="text-left p-2">NFT数</th>
                                  <th className="text-left p-2">NFT単価</th>
                                </>
                              ) : (
                                <>
                                  <th className="text-left p-2">日利玁E/th>
                                  <th className="text-left p-2">マ�Eジン玁E/th>
                                  <th className="text-left p-2">ユーザー利玁E/th>
                                </>
                              )}
                              <th className="text-left p-2">設定日晁E/th>
                              <th className="text-left p-2">操佁E/th>
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
                                    <td className="p-2">{item.total_nft_count}倁E/td>
                                    <td className={`p-2 font-medium ${item.profit_per_nft >= 0 ? "text-green-400" : "text-red-400"}`}>
                                      ${((item.profit_per_nft || 0) * 0.7 * 0.6).toFixed(3)}
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
                                        <span className="ml-1 text-xs">⚠�E�異常値</span>
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
