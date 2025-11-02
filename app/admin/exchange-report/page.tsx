"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  ArrowLeft,
  Download,
  RefreshCw,
  TrendingUp,
  TrendingDown,
  Users,
  DollarSign,
  Calendar,
  Building2,
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface PeriodReport {
  periodName: string
  operationStartDate: string
  newUsers: {
    count: number
    manualNFT: number
  }
  continuingUsers: {
    count: number
    manualNFT: number
    autoNFT: number
    total: number
  }
  cancellations: {
    count: number
    amount: number
  }
  totalDepositRequired: number
}

export default function ExchangeReportPage() {
  const [period1, setPeriod1] = useState<PeriodReport | null>(null)
  const [period2, setPeriod2] = useState<PeriodReport | null>(null)
  const [loading, setLoading] = useState(true)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)

      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await fetchReports()
        return
      }

      const { data: adminCheck } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminCheck) {
        setIsAdmin(true)
        await fetchReports()
      } else {
        router.push("/")
      }
    } catch (error) {
      console.error("Auth error:", error)
      router.push("/login")
    }
  }

  const fetchReports = async () => {
    try {
      setLoading(true)
      const today = new Date()
      const year = today.getFullYear()
      const month = today.getMonth() + 1

      // 期間1: 前月21日～今月5日（今月15日運用開始）
      const period1Start = new Date(year, month - 2, 21) // 前月21日
      const period1End = new Date(year, month - 1, 5) // 今月5日
      const period1OperationStart = new Date(year, month - 1, 15) // 今月15日

      // 期間2: 今月6日～今月20日（翌月1日運用開始）
      const period2Start = new Date(year, month - 1, 6) // 今月6日
      const period2End = new Date(year, month - 1, 20) // 今月20日
      const period2OperationStart = new Date(year, month, 1) // 翌月1日

      const report1 = await calculatePeriodReport(
        period1Start,
        period1End,
        period1OperationStart,
        `前月21日～今月5日承認分`
      )
      const report2 = await calculatePeriodReport(
        period2Start,
        period2End,
        period2OperationStart,
        `今月6日～今月20日承認分`
      )

      setPeriod1(report1)
      setPeriod2(report2)
    } catch (error) {
      console.error("Report fetch error:", error)
    } finally {
      setLoading(false)
    }
  }

  const calculatePeriodReport = async (
    periodStart: Date,
    periodEnd: Date,
    operationStart: Date,
    periodName: string
  ): Promise<PeriodReport> => {
    const periodStartStr = periodStart.toISOString().split('T')[0]
    const periodEndStr = periodEnd.toISOString().split('T')[0]
    const operationStartStr = operationStart.toISOString().split('T')[0]

    // 1. 全承認済み購入データを一度に取得
    const { data: allPurchases } = await supabase
      .from('purchases')
      .select('user_id, amount_usd, admin_approved_at')
      .eq('admin_approved', true)
      .order('admin_approved_at', { ascending: true })

    // 2. ユーザーごとの初回承認日と購入額を計算
    const userFirstApproval = new Map<string, string>()
    const userTotalPurchases = new Map<string, number>()

    if (allPurchases) {
      for (const purchase of allPurchases) {
        // 初回承認日を記録
        if (!userFirstApproval.has(purchase.user_id)) {
          userFirstApproval.set(purchase.user_id, purchase.admin_approved_at)
        }
        // 購入額を累積
        const current = userTotalPurchases.get(purchase.user_id) || 0
        userTotalPurchases.set(purchase.user_id, current + purchase.amount_usd * (1000 / 1100))
      }
    }

    // 3. 新規ユーザーを特定
    const newUserIds = new Set<string>()
    let newUserManualNFT = 0

    for (const [userId, firstApprovalDate] of userFirstApproval.entries()) {
      if (firstApprovalDate >= periodStartStr && firstApprovalDate <= periodEndStr + ' 23:59:59') {
        newUserIds.add(userId)
        newUserManualNFT += userTotalPurchases.get(userId) || 0
      }
    }

    // 4. 継続ユーザーを取得
    const { data: continuingUsers } = await supabase
      .from('users')
      .select('user_id')
      .eq('has_approved_nft', true)
      .lte('operation_start_date', operationStartStr)

    let continuingUserCount = 0
    let continuingManualNFT = 0

    if (continuingUsers) {
      for (const user of continuingUsers) {
        if (!newUserIds.has(user.user_id)) {
          continuingUserCount++
          continuingManualNFT += userTotalPurchases.get(user.user_id) || 0
        }
      }
    }

    // 5. 自動付与NFTの合計
    const { data: autoNFTData } = await supabase
      .from('affiliate_cycle')
      .select('auto_nft_count')
      .gt('auto_nft_count', 0)

    let totalAutoNFT = 0
    if (autoNFTData) {
      totalAutoNFT = autoNFTData.reduce((sum, cycle) =>
        sum + (cycle.auto_nft_count * 1000), 0)
    }

    // 解約: この期間に承認された買い取り申請
    const { data: cancellations } = await supabase
      .from('buyback_requests')
      .select('nft_count')
      .eq('status', 'completed')
      .gte('completed_at', periodStartStr)
      .lte('completed_at', periodEndStr + ' 23:59:59')

    let cancellationCount = 0
    let cancellationAmount = 0

    if (cancellations) {
      cancellationCount = cancellations.length
      cancellationAmount = cancellations.reduce((sum, c) =>
        sum + (c.nft_count * 1000), 0)
    }

    const continuingTotal = continuingManualNFT + totalAutoNFT
    const totalDepositRequired = newUserManualNFT + continuingTotal - cancellationAmount

    return {
      periodName,
      operationStartDate: operationStartStr,
      newUsers: {
        count: newUserIds.size,
        manualNFT: newUserManualNFT,
      },
      continuingUsers: {
        count: continuingUserCount,
        manualNFT: continuingManualNFT,
        autoNFT: totalAutoNFT,
        total: continuingTotal,
      },
      cancellations: {
        count: cancellationCount,
        amount: cancellationAmount,
      },
      totalDepositRequired,
    }
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push("/login")
  }

  if (!isAdmin || loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <div className="text-white text-xl">読み込み中...</div>
      </div>
    )
  }

  const ReportCard = ({ report }: { report: PeriodReport }) => (
    <Card className="bg-gradient-to-br from-gray-800 to-gray-900 border-gray-700">
      <CardHeader className="border-b border-gray-700">
        <CardTitle className="text-white flex items-center gap-2">
          <Calendar className="h-5 w-5 text-blue-400" />
          {report.periodName}
        </CardTitle>
        <p className="text-sm text-gray-400">運用開始日: {report.operationStartDate}</p>
      </CardHeader>
      <CardContent className="pt-6 space-y-6">
        {/* 新規ユーザー */}
        <div className="bg-green-900/20 border border-green-700 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp className="h-5 w-5 text-green-400" />
            <h3 className="text-lg font-semibold text-green-400">新規ユーザー</h3>
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-300">人数:</span>
              <span className="text-white font-semibold">{report.newUsers.count}人</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">手動購入NFT:</span>
              <span className="text-green-400 font-semibold">${report.newUsers.manualNFT.toLocaleString()}</span>
            </div>
          </div>
        </div>

        {/* 継続ユーザー */}
        <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-3">
            <Users className="h-5 w-5 text-blue-400" />
            <h3 className="text-lg font-semibold text-blue-400">継続ユーザー</h3>
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-300">人数:</span>
              <span className="text-white font-semibold">{report.continuingUsers.count}人</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">手動購入NFT:</span>
              <span className="text-blue-400 font-semibold">${report.continuingUsers.manualNFT.toLocaleString()}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">自動付与NFT:</span>
              <span className="text-purple-400 font-semibold">${report.continuingUsers.autoNFT.toLocaleString()}</span>
            </div>
            <div className="flex justify-between border-t border-blue-700 pt-2 mt-2">
              <span className="text-gray-300 font-semibold">小計:</span>
              <span className="text-white font-bold">${report.continuingUsers.total.toLocaleString()}</span>
            </div>
          </div>
        </div>

        {/* 解約 */}
        <div className="bg-red-900/20 border border-red-700 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-3">
            <TrendingDown className="h-5 w-5 text-red-400" />
            <h3 className="text-lg font-semibold text-red-400">解約</h3>
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-300">人数:</span>
              <span className="text-white font-semibold">{report.cancellations.count}人</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">金額:</span>
              <span className="text-red-400 font-semibold">-${report.cancellations.amount.toLocaleString()}</span>
            </div>
          </div>
        </div>

        {/* 取引所入金額 */}
        <div className="bg-gradient-to-r from-yellow-900/30 to-amber-900/30 border-2 border-yellow-500 rounded-lg p-6">
          <div className="flex items-center gap-2 mb-3">
            <Building2 className="h-6 w-6 text-yellow-400" />
            <h3 className="text-xl font-bold text-yellow-400">取引所入金額</h3>
          </div>
          <div className="text-center">
            <div className="text-4xl font-bold text-white">
              ${report.totalDepositRequired.toLocaleString()}
            </div>
            <p className="text-xs text-gray-400 mt-2">手数料除く</p>
          </div>
        </div>
      </CardContent>
    </Card>
  )

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black">
      {/* ヘッダー */}
      <header className="bg-gray-900 border-b border-gray-700 sticky top-0 z-50">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/admin">
                <Button variant="ghost" size="sm" className="text-gray-400 hover:text-white">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  管理画面に戻る
                </Button>
              </Link>
              <h1 className="text-2xl font-bold text-white">取引所入金報告</h1>
            </div>
            <div className="flex items-center space-x-2">
              <Button onClick={fetchReports} variant="outline" size="sm" className="text-gray-300 border-gray-600">
                <RefreshCw className="h-4 w-4 mr-2" />
                更新
              </Button>
              <Button onClick={handleLogout} variant="ghost" size="sm" className="text-red-400 hover:text-red-300">
                ログアウト
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-6 py-8">
        <div className="mb-6">
          <Card className="bg-blue-900/20 border-blue-700">
            <CardContent className="p-4">
              <p className="text-blue-200 text-sm">
                <strong>運用開始日ルール:</strong>
                <br />
                • 毎月5日までに承認 → 当月15日より運用開始
                <br />
                • 毎月20日までに承認 → 翌月1日より運用開始
                <br />
                <br />
                取引所には、新規ユーザー + 継続ユーザー（全投資額） - 解約分 を入金してください。
              </p>
            </CardContent>
          </Card>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {period1 && <ReportCard report={period1} />}
          {period2 && <ReportCard report={period2} />}
        </div>
      </main>
    </div>
  )
}
