"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Loader2,
  DollarSign,
  Clock,
  CheckCircle,
  AlertCircle,
  Search,
  Download,
  ArrowUp,
  Wallet
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface WithdrawalRecord {
  id: string
  user_id: string
  email: string
  withdrawal_month: string
  total_amount: number
  personal_amount: number
  referral_amount: number
  withdrawal_address: string | null
  withdrawal_method: string | null
  status: string
  created_at: string
  completed_at: string | null
  notes: string | null
  task_completed: boolean
  task_completed_at: string | null
  is_pegasus_exchange?: boolean
  pegasus_exchange_date?: string | null
  pegasus_withdrawal_unlock_date?: string | null
  channel_linked_confirmed?: boolean
  // affiliate_cycleから取得
  phase?: string
  cum_usdt?: number
  withdrawn_referral_usdt?: number
  current_available_usdt?: number
  total_nft_count?: number
  // 前月未送金情報
  prev_month_unpaid?: { amount: number; status: string } | null
  // NFT変動情報
  nft_start_count?: number  // 月初NFT数
  nft_end_count?: number    // 月末NFT数
  nft_added_count?: number  // 月中追加数
  nft_change_date?: string | null  // 変動日
  auto_nft_count?: number   // 自動NFT数
  manual_nft_count?: number // 手動NFT数
  // 当月の紹介報酬（monthly_referral_profitから）
  monthly_referral_amount?: number
  // その月までの累計紹介報酬
  cumulative_referral_amount?: number
}

interface MonthlyStats {
  total_amount: number
  personal_profit_total: number
  referral_profit_total: number
  pending_count: number
  pending_amount: number
  completed_count: number
  completed_amount: number
  on_hold_count: number
  on_hold_amount: number
  under_minimum_count: number
  under_minimum_amount: number
  negative_count: number
  negative_amount: number
}

// デフォルトで前月を表示（月末出金は前月分のため）
const getDefaultMonth = () => {
  const now = new Date()
  const jstDate = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Tokyo' }))

  const year = jstDate.getFullYear()
  const month = jstDate.getMonth() // 0-indexed

  let lastYear = year
  let lastMonth = month - 1
  if (lastMonth < 0) {
    lastMonth = 11
    lastYear = year - 1
  }

  const monthStr = String(lastMonth + 1).padStart(2, '0')
  return `${lastYear}-${monthStr}`
}

// 月プルダウンの選択肢を動的に生成（2025年11月〜現在月）
const getMonthOptions = () => {
  const now = new Date()
  const jstDate = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Tokyo' }))
  const currentYear = jstDate.getFullYear()
  const currentMonth = jstDate.getMonth() // 0-indexed

  const options: { value: string; label: string }[] = []
  let y = currentYear
  let m = currentMonth // 0-indexed: current month

  // 現在月から2025年11月まで降順に生成
  while (y > 2025 || (y === 2025 && m >= 10)) { // m=10 is November (0-indexed)
    const monthStr = String(m + 1).padStart(2, '0')
    options.push({
      value: `${y}-${monthStr}`,
      label: `${y}年${m + 1}月`
    })
    m--
    if (m < 0) {
      m = 11
      y--
    }
  }

  return options
}

export default function AdminWithdrawalsPage() {
  const [user, setUser] = useState<any>(null)
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([])
  const [stats, setStats] = useState<MonthlyStats | null>(null)
  const [selectedMonth, setSelectedMonth] = useState<string>("")
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [searchTerm, setSearchTerm] = useState("")
  const [channelFilter, setChannelFilter] = useState<"all" | "confirmed" | "not_confirmed">("all")
  const [statusFilter, setStatusFilter] = useState<"all" | "pending" | "completed" | "on_hold" | "under_minimum" | "negative">("all")
  const [taskFilter, setTaskFilter] = useState<"all" | "completed" | "not_completed">("all")
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState("")
  const [showScrollTop, setShowScrollTop] = useState(false)
  const router = useRouter()

  // 強制的に前月を設定
  useEffect(() => {
    const defaultMonth = getDefaultMonth()
    console.log('Force setting month to:', defaultMonth)
    setSelectedMonth(defaultMonth)
  }, [])

  useEffect(() => {
    const handleScroll = () => {
      setShowScrollTop(window.scrollY > 300)
    }
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  useEffect(() => {
    checkAuth()
  }, [])

  useEffect(() => {
    if (user) {
      fetchWithdrawals()
    }
  }, [user, selectedMonth])

  const checkAuth = async () => {
    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()
      
      if (sessionError || !session?.user) {
        router.push("/login")
        return
      }

      setUser(session.user)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchWithdrawals = async () => {
    try {
      setLoading(true)
      setError("")

      const targetDate = `${selectedMonth}-01`

      console.log('=== Fetching withdrawals for:', targetDate)

      // STEP 1: 月間出金記録を取得（この月のレコードのみ）
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("withdrawal_month", targetDate)
        .order("total_amount", { ascending: false })

      if (withdrawalError) throw withdrawalError

      if (!withdrawalData || withdrawalData.length === 0) {
        console.log('=== No withdrawal records for this month')
        setWithdrawals([])
        setStats({
          total_amount: 0,
          personal_profit_total: 0,
          referral_profit_total: 0,
          pending_count: 0,
          pending_amount: 0,
          completed_count: 0,
          completed_amount: 0,
          on_hold_count: 0,
          on_hold_amount: 0,
          under_minimum_count: 0,
          under_minimum_amount: 0,
          negative_count: 0,
          negative_amount: 0
        })
        setLoading(false)
        return
      }

      // STEP 2: ユーザー情報を取得
      const userIds = withdrawalData.map(w => w.user_id)
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("user_id, email, coinw_uid, nft_receive_address, is_pegasus_exchange, pegasus_withdrawal_unlock_date, channel_linked_confirmed")
        .in("user_id", userIds)

      if (usersError) throw usersError

      // STEP 3: 現在の残高を取得（参考情報）
      const { data: currentCycle, error: cycleError } = await supabase
        .from("affiliate_cycle")
        .select("user_id, available_usdt, cum_usdt, phase, total_nft_count, withdrawn_referral_usdt, auto_nft_count")
        .in("user_id", userIds)

      if (cycleError) throw cycleError

      // STEP 3.5: 前月の未送金レコードを取得
      const prevMonth = new Date(targetDate)
      prevMonth.setMonth(prevMonth.getMonth() - 1)
      const prevMonthStr = prevMonth.toISOString().slice(0, 10)

      const { data: prevMonthData } = await supabase
        .from("monthly_withdrawals")
        .select("user_id, total_amount, status")
        .eq("withdrawal_month", prevMonthStr)
        .in("user_id", userIds)
        .neq("status", "completed")

      const prevMonthMap = new Map(
        (prevMonthData || []).map(p => [p.user_id, { amount: p.total_amount, status: p.status }])
      )

      // STEP 3.6: NFT情報を取得（月中変動検出用）
      const monthStart = new Date(targetDate)
      const monthEnd = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0)
      const monthEndStr = monthEnd.toISOString().split('T')[0]

      const { data: nftData } = await supabase
        .from("nft_master")
        .select("user_id, nft_type, operation_start_date, acquired_date")
        .in("user_id", userIds)
        .is("buyback_date", null)

      // STEP 3.7: 当月の紹介報酬を取得（monthly_referral_profitから）
      const yearMonth = `${monthStart.getFullYear()}-${String(monthStart.getMonth() + 1).padStart(2, '0')}`
      const { data: monthlyReferralData } = await supabase
        .from("monthly_referral_profit")
        .select("user_id, profit_amount")
        .eq("year_month", yearMonth)
        .in("user_id", userIds)
        .range(0, 4999)

      // ユーザーごとの当月紹介報酬を集計
      const monthlyReferralMap = new Map<string, number>()
      ;(monthlyReferralData || []).forEach(r => {
        const current = monthlyReferralMap.get(r.user_id) || 0
        monthlyReferralMap.set(r.user_id, current + Number(r.profit_amount))
      })

      // STEP 3.8: その月までの累計紹介報酬を取得（RPC関数でサーバーサイド集計、1000件制限回避）
      const { data: cumulativeData, error: cumError } = await supabase.rpc('get_cumulative_referral', {
        p_user_ids: userIds,
        p_year_month: yearMonth
      })

      if (cumError) {
        console.error('累計取得エラー:', cumError)
      }

      // ユーザーごとの累計紹介報酬をMapに格納
      const cumulativeReferralMap = new Map<string, number>()
      ;(cumulativeData || []).forEach((r: { user_id: string; cumulative_amount: number }) => {
        cumulativeReferralMap.set(r.user_id, Number(r.cumulative_amount))
      })

      // ユーザーごとのNFT変動情報を計算
      const nftChangeMap = new Map<string, {
        nft_start_count: number
        nft_end_count: number
        nft_added_count: number
        nft_change_date: string | null
        auto_nft_count: number
        manual_nft_count: number
      }>()

      userIds.forEach(userId => {
        const userNfts = (nftData || []).filter(n => n.user_id === userId)
        const nftBeforeMonth = userNfts.filter(n =>
          n.operation_start_date && new Date(n.operation_start_date) < monthStart
        ).length
        const nftAddedDuringMonth = userNfts.filter(n =>
          n.operation_start_date &&
          new Date(n.operation_start_date) >= monthStart &&
          new Date(n.operation_start_date) <= monthEnd
        )
        const autoNftCount = userNfts.filter(n => n.nft_type === 'auto').length
        const manualNftCount = userNfts.filter(n => n.nft_type === 'manual').length

        // 月中追加の最初の日付を取得
        const firstAdditionDate = nftAddedDuringMonth.length > 0
          ? nftAddedDuringMonth
              .map(n => n.operation_start_date)
              .sort()[0]
          : null

        nftChangeMap.set(userId, {
          nft_start_count: nftBeforeMonth,
          nft_end_count: userNfts.length,
          nft_added_count: nftAddedDuringMonth.length,
          nft_change_date: firstAdditionDate,
          auto_nft_count: autoNftCount,
          manual_nft_count: manualNftCount
        })
      })

      // STEP 4: データを結合
      const formattedData = withdrawalData.map((withdrawal: any) => {
        const user = usersData?.find(u => u.user_id === withdrawal.user_id)
        const cycle = currentCycle?.find(c => c.user_id === withdrawal.user_id)
        const nftChange = nftChangeMap.get(withdrawal.user_id)
        const monthlyReferral = monthlyReferralMap.get(withdrawal.user_id) || 0
        const cumulativeReferral = cumulativeReferralMap.get(withdrawal.user_id) || 0

        // 出金可能な紹介報酬を統一計算式で計算
        const cumUsdt = cycle?.cum_usdt || 0
        const withdrawnReferral = cycle?.withdrawn_referral_usdt || 0
        const phase = cycle?.phase || 'USDT'
        const autoNftCountForCalc = cycle?.auto_nft_count || 0
        // 統一式: (auto_nft_count × 1100 + LEAST(cum_usdt, 1100)) - withdrawn_referral_usdt
        const totalPayoutEver = autoNftCountForCalc * 1100 + Math.min(Math.max(cumUsdt, 0), 1100)
        const withdrawableReferral = Math.max(0, totalPayoutEver - withdrawnReferral)

        return {
          ...withdrawal,
          email: user?.email || '',
          withdrawal_address: withdrawal.withdrawal_address || user?.coinw_uid || user?.nft_receive_address || null,
          withdrawal_method: withdrawal.withdrawal_method || (user?.coinw_uid ? 'coinw' : user?.nft_receive_address ? 'bep20' : null),
          is_pegasus_exchange: user?.is_pegasus_exchange || false,
          pegasus_withdrawal_unlock_date: user?.pegasus_withdrawal_unlock_date || null,
          channel_linked_confirmed: user?.channel_linked_confirmed || false,
          // 参考情報: 現在の残高
          current_available_usdt: cycle?.available_usdt || 0,
          cum_usdt: cumUsdt,
          withdrawn_referral_usdt: withdrawnReferral,
          phase: phase,
          total_nft_count: cycle?.total_nft_count || 0,
          // 出金レコードの個人利益・紹介報酬を使う（なければ後方互換）
          personal_amount: withdrawal.personal_amount ?? withdrawal.total_amount,
          referral_amount: withdrawal.referral_amount ?? 0,
          // 出金可能な紹介報酬（参考表示用）
          withdrawable_referral: withdrawableReferral,
          // 前月未送金情報
          prev_month_unpaid: prevMonthMap.get(withdrawal.user_id) || null,
          // NFT変動情報
          nft_start_count: nftChange?.nft_start_count || 0,
          nft_end_count: nftChange?.nft_end_count || 0,
          nft_added_count: nftChange?.nft_added_count || 0,
          nft_change_date: nftChange?.nft_change_date || null,
          auto_nft_count: nftChange?.auto_nft_count || 0,
          manual_nft_count: nftChange?.manual_nft_count || 0,
          // 当月の紹介報酬（monthly_referral_profitから）
          monthly_referral_amount: monthlyReferral,
          // その月までの累計紹介報酬
          cumulative_referral_amount: cumulativeReferral,
        }
      })

      console.log('=== Formatted data count:', formattedData.length)
      setWithdrawals(formattedData)

      // 統計情報を計算（出金レコードの personal_amount と referral_amount を使用）
      // HOLDユーザーは既払い分を引いた金額で計算
      const personalProfitTotal = formattedData.reduce((sum, w) => sum + Number(w.personal_amount || 0), 0)
      const referralProfitTotal = formattedData.reduce((sum, w) => {
        const referralAmount = Number(w.referral_amount || 0)
        const withdrawnReferral = Number(w.withdrawn_referral_usdt || 0)
        // HOLDユーザーは既払い分を引く
        const adjustedAmount = w.phase === 'HOLD'
          ? Math.max(0, referralAmount - withdrawnReferral)
          : referralAmount
        return sum + adjustedAmount
      }, 0)
      const totalAmount = formattedData.reduce((sum, w) => sum + Number(w.total_amount || 0), 0)

      const pendingWithdrawals = formattedData.filter(w => w.status === 'pending')
      const completedWithdrawals = formattedData.filter(w => w.status === 'completed')
      const onHoldWithdrawals = formattedData.filter(w => w.status === 'on_hold')
      const underMinimumWithdrawals = formattedData.filter(w => w.status === 'under_minimum')
      const negativeWithdrawals = formattedData.filter(w => w.status === 'negative')

      const stats: MonthlyStats = {
        total_amount: totalAmount,
        personal_profit_total: personalProfitTotal,
        referral_profit_total: referralProfitTotal,
        pending_count: pendingWithdrawals.length,
        pending_amount: pendingWithdrawals.reduce((sum, w) => sum + (w.total_amount || 0), 0),
        completed_count: completedWithdrawals.length,
        completed_amount: completedWithdrawals.reduce((sum, w) => sum + (w.total_amount || 0), 0),
        on_hold_count: onHoldWithdrawals.length,
        on_hold_amount: onHoldWithdrawals.reduce((sum, w) => sum + (w.total_amount || 0), 0),
        under_minimum_count: underMinimumWithdrawals.length,
        under_minimum_amount: underMinimumWithdrawals.reduce((sum, w) => sum + (w.total_amount || 0), 0),
        negative_count: negativeWithdrawals.length,
        negative_amount: negativeWithdrawals.reduce((sum, w) => sum + (w.total_amount || 0), 0),
      }
      setStats(stats)

    } catch (err: any) {
      console.error("Error fetching withdrawals:", err)
      setError("出金データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const markAsCompleted = async (ids: string[]) => {
    try {
      setProcessing(true)

      // 新しいRPC関数を使用して出金完了処理（available_usdtも減算）
      // p_withdrawal_idsはUUID[]型なので文字列配列をそのまま渡す
      const { data, error } = await supabase.rpc("complete_withdrawals_batch", {
        p_withdrawal_ids: ids
      })

      if (error) {
        throw error
      }

      // 結果を確認（RPC関数の戻り値はout_プレフィックス付き）
      const results = data || []
      const successCount = results.filter((r: any) => r.out_success).length
      const failCount = results.filter((r: any) => !r.out_success).length

      // 繰越元も完了になったケースを集計
      const carryoverInfo = results
        .filter((r: any) => r.out_success && r.out_error_message && r.out_error_message.includes('繰越元'))
        .map((r: any) => `${r.out_user_id}: ${r.out_error_message}`)

      if (failCount > 0) {
        // 失敗したユーザーIDとエラーメッセージを表示
        const errors = results.filter((r: any) => !r.out_success).map((r: any) => {
          // out_user_idがある場合はそれを使用、なければwithdrawalsからユーザーIDを取得
          const userId = r.out_user_id || withdrawals.find(w => w.id === r.out_withdrawal_id)?.user_id || '不明'
          return `ユーザー ${userId}: ${r.out_error_message}`
        }).join('\n')
        alert(`出金完了処理結果:\n成功: ${successCount}件\n失敗: ${failCount}件\n\nエラー詳細:\n${errors}`)
      } else {
        let message = `${successCount}件の出金を完了済みにしました（available_usdtから減算済み）`
        if (carryoverInfo.length > 0) {
          message += `\n\n📋 繰越元も完了:\n${carryoverInfo.join('\n')}`
        }
        alert(message)
      }

      setSelectedIds(new Set())
      fetchWithdrawals()
    } catch (err: any) {
      console.error("Error marking as completed:", err)
      alert("ステータス更新に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const exportCSV = () => {
    const headers = [
      "ユーザーID", "メールアドレス", "フェーズ", "個人利益", "紹介報酬", "出金合計",
      "$10未満",
      "月初NFT", "月末NFT", "NFT変動日", "自動NFT", "手動NFT",
      "前月未送金", "前月ステータス",
      "累計紹介報酬", "ロック額", "既払い紹介報酬", "払い出し可能額",
      "送金方法", "CoinW UID/送金先",
      "CH紐付け", "タスク状況", "ステータス", "作成日", "完了日", "備考"
    ]

    // 出金レコードに保存されている個人利益・紹介報酬を使用
    const csvData = filteredWithdrawals.map((w: any) => {
        // 統一計算式で払い出し可能額を計算
        const cumUsdt = w.cum_usdt || 0
        const withdrawnReferral = w.withdrawn_referral_usdt || 0
        const csvAutoNft = w.auto_nft_count || 0
        const csvTotalPayout = csvAutoNft * 1100 + Math.min(Math.max(cumUsdt, 0), 1100)
        const lockAmount = w.phase === 'HOLD' ? Math.max(0, cumUsdt - 1100) : 0
        const withdrawableFromHold = Math.max(0, csvTotalPayout - withdrawnReferral)

        // HOLDユーザーは既払い分を引いた金額を表示
        const displayReferralAmount = w.phase === 'HOLD'
          ? Math.max(0, (w.referral_amount || 0) - withdrawnReferral)
          : (w.referral_amount || 0)

        // 前月未送金情報
        const prevMonthAmount = w.prev_month_unpaid ? Number(w.prev_month_unpaid.amount).toFixed(2) : ""
        const prevMonthStatus = w.prev_month_unpaid ? w.prev_month_unpaid.status : ""

        // NFT変動情報
        const nftChangeDate = w.nft_change_date
          ? new Date(w.nft_change_date).toLocaleDateString('ja-JP')
          : ""

        return [
          w.user_id,
          w.email,
          w.phase || '-',
          (w.personal_amount || 0).toFixed(3),
          displayReferralAmount.toFixed(3),
          w.total_amount.toFixed(3),
          w.status === 'under_minimum' ? '○' : '',
          w.nft_start_count || 0,
          w.nft_end_count || 0,
          nftChangeDate,
          w.auto_nft_count || 0,
          w.manual_nft_count || 0,
          prevMonthAmount,
          prevMonthStatus,
          cumUsdt.toFixed(3),
          lockAmount.toFixed(3),
          withdrawnReferral.toFixed(3),
          withdrawableFromHold.toFixed(3),
          w.withdrawal_method === 'coinw' ? 'CoinW' : w.withdrawal_method === 'bep20' ? 'BEP20' : "未設定",
          w.withdrawal_address || "未設定",
          w.channel_linked_confirmed ? "確認済み" : "未確認",
          w.task_completed ? "完了" : "未完了",
          w.status,
          new Date(w.created_at).toLocaleDateString('ja-JP'),
          w.completed_at ? new Date(w.completed_at).toLocaleDateString('ja-JP') : "",
          w.notes || ""
        ]
      })

    const csvContent = [headers, ...csvData]
      .map(row => row.map(field => `"${field}"`).join(","))
      .join("\n")

    // BOM（Byte Order Mark）を追加してExcelで文字化けを防ぐ
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF])
    const blob = new Blob([bom, csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `withdrawals_${selectedMonth}.csv`
    link.click()
  }

  const filteredWithdrawals = withdrawals
    .filter(w => {
      // 検索フィルター
      if (searchTerm) {
        const matchesSearch = w.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
          w.email.toLowerCase().includes(searchTerm.toLowerCase())
        if (!matchesSearch) return false
      }
      // CH紐付けフィルター
      if (channelFilter === "confirmed" && !w.channel_linked_confirmed) return false
      if (channelFilter === "not_confirmed" && w.channel_linked_confirmed) return false
      // ステータスフィルター
      if (statusFilter !== "all" && w.status !== statusFilter) return false
      // タスク状況フィルター
      if (taskFilter === "completed" && !w.task_completed) return false
      if (taskFilter === "not_completed" && w.task_completed) return false
      return true
    })
    .sort((a, b) => Number(b.total_amount) - Number(a.total_amount))

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge className="bg-yellow-600 text-white">送金待ち</Badge>
      case 'completed':
        return <Badge className="bg-green-600 text-white">送金完了</Badge>
      case 'on_hold':
        return <Badge className="bg-red-600 text-white">保留中</Badge>
      case 'under_minimum':
        return <Badge className="bg-purple-600 text-white">$10未満</Badge>
      case 'negative':
        return <Badge className="bg-gray-600 text-white">マイナス</Badge>
      case 'not_created':
        return <Badge className="bg-gray-600 text-white">未作成</Badge>
      default:
        return <Badge className="bg-gray-600 text-white">{status}</Badge>
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
              <div>
                <h1 className="text-xl font-bold text-white flex items-center gap-2">
                  <Wallet className="h-5 w-5 text-yellow-400" />
                  月末出金管理
                  {selectedMonth && (
                    <span className="text-blue-400 ml-2">
                      ({new Date(selectedMonth + '-01').toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })})
                    </span>
                  )}
                </h1>
                <p className="text-sm text-gray-400">月末自動出金の処理と管理</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Link href="/admin">
                <Button variant="outline" size="sm" className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600">
                  管理者ダッシュボード
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 統計セクション */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-6 gap-4 mb-8">
            {/* 個人利益合計 */}
            <Card className="bg-green-900/20 border-green-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-green-400" />
                  <div>
                    <p className="text-xs text-green-300">個人利益合計</p>
                    <p className="text-xl font-bold text-green-400">
                      ${stats.personal_profit_total.toFixed(2)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 紹介報酬合計 */}
            <Card className="bg-orange-900/20 border-orange-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-orange-400" />
                  <div>
                    <p className="text-xs text-orange-300">紹介報酬合計</p>
                    <p className="text-xl font-bold text-orange-400">
                      ${stats.referral_profit_total.toFixed(2)}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 総出金額 */}
            <Card className="bg-blue-900/20 border-blue-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <DollarSign className="h-6 w-6 text-blue-400" />
                  <div>
                    <p className="text-xs text-blue-300">総出金額（$10以上）</p>
                    <p className="text-xl font-bold text-blue-400">
                      ${stats.total_amount.toFixed(2)}
                    </p>
                    <p className="text-xs text-blue-300 mt-1">
                      {withdrawals.length}人
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 送金待ち */}
            <Card className="bg-yellow-900/20 border-yellow-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <Clock className="h-6 w-6 text-yellow-400" />
                  <div>
                    <p className="text-xs text-yellow-300">送金待ち</p>
                    <p className="text-xl font-bold text-yellow-400">
                      ${stats.pending_amount.toFixed(2)}
                    </p>
                    <p className="text-xs text-yellow-300 mt-1">{stats.pending_count}人</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 送金完了 */}
            <Card className="bg-emerald-900/20 border-emerald-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <CheckCircle className="h-6 w-6 text-emerald-400" />
                  <div>
                    <p className="text-xs text-emerald-300">送金完了</p>
                    <p className="text-xl font-bold text-emerald-400">
                      ${stats.completed_amount.toFixed(2)}
                    </p>
                    <p className="text-xs text-emerald-300 mt-1">{stats.completed_count}人</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 保留中 */}
            <Card className="bg-red-900/20 border-red-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <AlertCircle className="h-6 w-6 text-red-400" />
                  <div>
                    <p className="text-xs text-red-300">保留中（タスク未完了）</p>
                    <p className="text-xl font-bold text-red-400">
                      ${stats.on_hold_amount.toFixed(2)}
                    </p>
                    <p className="text-xs text-red-300 mt-1">{stats.on_hold_count}人</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* $10未満 */}
            {stats.under_minimum_count > 0 && (
              <Card className="bg-purple-900/20 border-purple-700/50">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-2">
                    <DollarSign className="h-6 w-6 text-purple-400" />
                    <div>
                      <p className="text-xs text-purple-300">$10未満（出金対象外）</p>
                      <p className="text-xl font-bold text-purple-400">
                        ${stats.under_minimum_amount.toFixed(2)}
                      </p>
                      <p className="text-xs text-purple-300 mt-1">{stats.under_minimum_count}人</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}

            {/* マイナス */}
            {stats.negative_count > 0 && (
              <Card className="bg-gray-800/50 border-gray-600/50">
                <CardContent className="p-4">
                  <div className="flex items-center space-x-2">
                    <AlertCircle className="h-6 w-6 text-gray-400" />
                    <div>
                      <p className="text-xs text-gray-300">マイナス（出金対象外）</p>
                      <p className="text-xl font-bold text-gray-400">
                        ${stats.negative_amount.toFixed(2)}
                      </p>
                      <p className="text-xs text-gray-300 mt-1">{stats.negative_count}人</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>
        )}

        {/* 操作パネル */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardHeader>
            <CardTitle className="text-white">操作パネル</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex items-center space-x-2">
                <label className="text-sm text-gray-300 whitespace-nowrap">対象月:</label>
                <select
                  value={selectedMonth}
                  onChange={(e) => setSelectedMonth(e.target.value)}
                  className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm min-w-[140px]"
                >
                  {getMonthOptions().map(opt => (
                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                  ))}
                </select>
              </div>

              <Button
                onClick={() => markAsCompleted(Array.from(selectedIds))}
                disabled={selectedIds.size === 0 || processing}
                className="bg-green-600 hover:bg-green-700"
              >
                選択した項目を完了済みに
              </Button>

              <Button
                onClick={exportCSV}
                variant="outline"
                className="border-gray-600 text-black bg-white hover:bg-gray-100"
              >
                <Download className="h-4 w-4 mr-2" />
                CSV出力
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* 検索・フィルター */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex-1 min-w-[200px]">
                <div className="relative">
                  <Search className="h-4 w-4 absolute left-3 top-3 text-gray-400" />
                  <Input
                    placeholder="ユーザーID・メールアドレスで検索..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>
              <select
                value={channelFilter}
                onChange={(e) => setChannelFilter(e.target.value as "all" | "confirmed" | "not_confirmed")}
                className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
              >
                <option value="all">CH紐付け: 全て</option>
                <option value="confirmed">確認済み</option>
                <option value="not_confirmed">未確認</option>
              </select>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as "all" | "pending" | "completed" | "on_hold" | "under_minimum" | "negative")}
                className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
              >
                <option value="all">ステータス: 全て</option>
                <option value="pending">送金待ち</option>
                <option value="completed">送金完了</option>
                <option value="on_hold">保留中</option>
                <option value="under_minimum">$10未満</option>
                <option value="negative">マイナス</option>
              </select>
              <select
                value={taskFilter}
                onChange={(e) => setTaskFilter(e.target.value as "all" | "completed" | "not_completed")}
                className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
              >
                <option value="all">タスク: 全て</option>
                <option value="completed">完了</option>
                <option value="not_completed">未完了</option>
              </select>
            </div>
          </CardContent>
        </Card>

        {/* 出金一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">出金一覧 ({filteredWithdrawals.length}件)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-3 px-2">
                      <Checkbox
                        checked={selectedIds.size === filteredWithdrawals.length && filteredWithdrawals.length > 0}
                        onCheckedChange={(checked) => {
                          if (checked) {
                            setSelectedIds(new Set(filteredWithdrawals.map(w => w.id)))
                          } else {
                            setSelectedIds(new Set())
                          }
                        }}
                        className="border-2 border-white/70 data-[state=checked]:bg-blue-500 data-[state=checked]:border-blue-500 h-5 w-5"
                      />
                    </th>
                    <th className="text-left py-3 px-2 text-gray-300">ユーザー</th>
                    <th className="text-center py-3 px-2 text-gray-300">フェーズ</th>
                    <th className="text-right py-3 px-2 text-gray-300">個人利益</th>
                    <th className="text-right py-3 px-2 text-gray-300">紹介報酬</th>
                    <th className="text-right py-3 px-2 text-gray-300">出金合計</th>
                    <th className="text-center py-3 px-2 text-gray-300">NFT変動</th>
                    <th className="text-left py-3 px-2 text-gray-300">CoinW UID/送金先</th>
                    <th className="text-center py-3 px-2 text-gray-300">CH紐付け</th>
                    <th className="text-left py-3 px-2 text-gray-300">タスク状況</th>
                    <th className="text-left py-3 px-2 text-gray-300">ステータス</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredWithdrawals.map((withdrawal: any) => (
                    <tr key={withdrawal.id} className={`border-b border-gray-700/50 hover:bg-gray-700/20 ${
                      withdrawal.status === 'under_minimum' ? 'bg-purple-900/10' :
                      withdrawal.status === 'negative' ? 'bg-gray-800/50 opacity-60' : ''
                    }`}>
                      <td className="py-3 px-2">
                        <Checkbox
                          checked={selectedIds.has(withdrawal.id)}
                          onCheckedChange={(checked) => {
                            const newSet = new Set(selectedIds)
                            if (checked) {
                              newSet.add(withdrawal.id)
                            } else {
                              newSet.delete(withdrawal.id)
                            }
                            setSelectedIds(newSet)
                          }}
                          disabled={withdrawal.status === 'not_created' || withdrawal.status === 'under_minimum' || withdrawal.status === 'negative'}
                          className="border-2 border-white/70 data-[state=checked]:bg-blue-500 data-[state=checked]:border-blue-500 h-5 w-5 disabled:border-gray-600"
                        />
                      </td>
                      <td className="py-3 px-2">
                        <div>
                          <div className="font-medium text-white">{withdrawal.user_id}</div>
                          <div className="text-xs text-gray-400">{withdrawal.email}</div>
                          {withdrawal.is_pegasus_exchange && (
                            <div className="mt-1">
                              <Badge className="bg-yellow-600 text-white text-xs">🐴 ペガサス交換</Badge>
                            </div>
                          )}
                          {withdrawal.prev_month_unpaid && (
                            <div className="mt-1">
                              <Badge className="bg-red-500 text-white text-xs">
                                ⚠️ 前月未送金 ${Number(withdrawal.prev_month_unpaid.amount).toFixed(0)}
                              </Badge>
                            </div>
                          )}
                        </div>
                      </td>
                      {/* フェーズ表示（その月の累計から計算） */}
                      <td className="py-3 px-2 text-center">
                        {(() => {
                          const cumulative = withdrawal.cumulative_referral_amount || 0
                          const displayAutoNft = withdrawal.auto_nft_count || 0
                          // 正しい計算: cum_usdt = 累計 - (auto_nft_count × 2200)
                          const displayCumUsdt = Math.max(0, cumulative - displayAutoNft * 2200)
                          const calculatedPhase = displayCumUsdt >= 1100 ? 'HOLD' : 'USDT'
                          const cycleCount = displayAutoNft

                          return calculatedPhase === 'USDT' ? (
                            <div>
                              <Badge className="bg-green-600 text-white">💰 USDT</Badge>
                              {cycleCount > 0 && (
                                <div className="text-xs text-gray-400 mt-1">
                                  {cycleCount}サイクル完了
                                </div>
                              )}
                            </div>
                          ) : (
                            <div>
                              <Badge className="bg-orange-600 text-white">🔒 HOLD</Badge>
                              <div className="text-xs text-gray-400 mt-1">
                                ${(2200 - displayCumUsdt).toFixed(0)}でNFT
                              </div>
                            </div>
                          )
                        })()}
                      </td>
                      {/* 個人利益 */}
                      <td className="py-3 px-2 text-right">
                        <span className="text-green-400">
                          ${(withdrawal.personal_amount || 0).toFixed(2)}
                        </span>
                      </td>
                      {/* 紹介報酬 */}
                      <td className="py-3 px-2 text-right">
                        {(() => {
                          const monthlyReferral = withdrawal.monthly_referral_amount || 0
                          const cumulativeReferral = withdrawal.cumulative_referral_amount || 0
                          const referralAmount = withdrawal.referral_amount || 0
                          const autoNftCount = withdrawal.auto_nft_count || 0

                          return (
                            <div className="space-y-1">
                              {/* 当月の紹介報酬（monthly_referral_profitから） */}
                              <div className="text-blue-400 font-medium" title="当月紹介報酬">
                                ${monthlyReferral.toFixed(2)}
                              </div>

                              {/* その月までの累計紹介報酬 */}
                              <div className="text-xs text-purple-300" title="この月までの累計紹介報酬">
                                累計: ${cumulativeReferral.toFixed(2)}
                              </div>

                              {/* 今回出金額（referral_amount） */}
                              {referralAmount > 0 && (
                                <div className="text-xs text-green-400 font-medium" title="今回出金する紹介報酬">
                                  出金: ${referralAmount.toFixed(2)}
                                </div>
                              )}

                              {/* 自動NFT購入がある場合 */}
                              {autoNftCount > 0 && (
                                <div className="text-xs text-pink-300" title="自動NFT購入回数">
                                  🤖 NFT{autoNftCount}回
                                </div>
                              )}
                            </div>
                          )
                        })()}
                      </td>
                      {/* 出金合計 */}
                      <td className="py-3 px-2 text-right">
                        <div>
                          <span className={`font-bold ${
                            withdrawal.total_amount >= 10 ? 'text-blue-400' : 'text-gray-400'
                          }`}>
                            ${(withdrawal.total_amount || 0).toFixed(2)}
                          </span>
                          {/* 内訳表示 */}
                          <div className="text-xs text-gray-400 mt-1">
                            個人: ${(withdrawal.personal_amount || 0).toFixed(2)}
                            {(withdrawal.referral_amount || 0) > 0 && (
                              <span className="ml-1">+ 紹介: ${(withdrawal.referral_amount || 0).toFixed(2)}</span>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="py-3 px-2 text-center">
                        <div className="space-y-1">
                          {/* NFT変動表示 */}
                          {withdrawal.nft_added_count > 0 ? (
                            <div className="flex flex-col items-center">
                              <Badge className="bg-yellow-600 text-white text-xs">
                                ⚠️ {withdrawal.nft_start_count}→{withdrawal.nft_end_count}
                              </Badge>
                              <span className="text-xs text-yellow-400">
                                ({withdrawal.nft_change_date ? new Date(withdrawal.nft_change_date).toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric' }) : ''})
                              </span>
                            </div>
                          ) : (
                            <span className="text-blue-400">
                              {withdrawal.nft_end_count || withdrawal.total_nft_count || 0}枚
                            </span>
                          )}
                          {/* 自動NFT表示 */}
                          {withdrawal.auto_nft_count > 0 && (
                            <div className="text-xs text-purple-400">
                              🤖 自動{withdrawal.auto_nft_count}
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-2">
                        <div className="text-white">
                          {withdrawal.withdrawal_method === 'coinw' ? (
                            <div>
                              <span className="text-xs text-blue-400">CoinW:</span>
                              <div>{withdrawal.withdrawal_address}</div>
                            </div>
                          ) : withdrawal.withdrawal_method === 'bep20' ? (
                            <div>
                              <span className="text-xs text-green-400">BEP20:</span>
                              <div className="truncate max-w-32">{withdrawal.withdrawal_address}</div>
                            </div>
                          ) : (
                            <span className="text-red-400">❌ 未設定</span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-2 text-center">
                        {withdrawal.channel_linked_confirmed ? (
                          <Badge className="bg-cyan-600 text-white">確認済</Badge>
                        ) : (
                          <Badge className="bg-gray-600 text-white">未確認</Badge>
                        )}
                      </td>
                      <td className="py-3 px-2">
                        {withdrawal.task_completed ? (
                          <Badge className="bg-green-600 text-white">完了済み</Badge>
                        ) : withdrawal.status === 'not_created' ? (
                          <Badge className="bg-gray-600 text-white">-</Badge>
                        ) : (
                          <Badge className="bg-yellow-600 text-white">未完了</Badge>
                        )}
                        {withdrawal.task_completed_at && (
                          <div className="text-xs text-gray-400 mt-1">
                            {new Date(withdrawal.task_completed_at).toLocaleDateString('ja-JP')}
                          </div>
                        )}
                      </td>
                      <td className="py-3 px-2">
                        {getStatusBadge(withdrawal.status)}
                        {withdrawal.status === 'not_created' && withdrawal.total_amount < 10 && (
                          <div className="text-xs text-gray-500 mt-1">$10未満のため未作成</div>
                        )}
                        {withdrawal.status === 'not_created' && withdrawal.total_amount >= 10 && !withdrawal.withdrawal_method && (
                          <div className="text-xs text-red-400 mt-1">送金先未設定</div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              
              {filteredWithdrawals.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  出金記録がありません
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {error && (
          <div className="mt-4 p-4 bg-red-900/20 border border-red-500/50 rounded-lg">
            <p className="text-red-200">{error}</p>
          </div>
        )}

        {/* トップに戻るボタン */}
        {showScrollTop && (
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="fixed bottom-8 right-8 group bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white p-4 rounded-2xl shadow-2xl z-50 transition-all duration-300 hover:scale-110 hover:shadow-blue-500/25"
            title="トップに戻る"
          >
            <ArrowUp className="h-5 w-5 group-hover:-translate-y-1 transition-transform duration-200" />
          </button>
        )}
      </div>
    </div>
  )
}