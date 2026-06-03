"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Loader2, Home, Calendar } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface MonthlyProfit {
  year: number
  month: number
  personalProfit: number
  referralProfit: number       // 発生額（monthly_referral_profit）
  totalProfit: number          // 発生額の合計
  withdrawalAmount: number     // 今月のお支払い予定額（monthly_withdrawals.total_amount）
  withdrawnReferral: number    // 今月の出金紹介報酬（monthly_withdrawals.referral_amount）
  hasWithdrawal: boolean       // monthly_withdrawals レコードが存在するか
}

export default function ProfitHistoryPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [userId, setUserId] = useState<string | null>(null)
  const [monthlyProfits, setMonthlyProfits] = useState<MonthlyProfit[]>([])
  const [error, setError] = useState("")

  useEffect(() => {
    checkAuthAndFetchData()
  }, [])

  const checkAuthAndFetchData = async () => {
    try {
      setLoading(true)
      setError("")

      // 認証チェック
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        router.push("/login")
        return
      }

      // ユーザー情報取得
      const { data: userData, error: userError } = await supabase
        .from("users")
        .select("user_id")
        .eq("email", session.user.email)
        .single()

      if (userError) throw userError
      if (!userData) {
        router.push("/login")
        return
      }

      setUserId(userData.user_id)
      await fetchMonthlyProfits(userData.user_id)

    } catch (err: any) {
      console.error("Auth check error:", err)
      setError("認証エラーが発生しました")
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }

  const fetchMonthlyProfits = async (uid: string) => {
    try {
      // 個人利益（user_daily_profit）- 月別集計
      const { data: dailyProfitData, error: dailyError } = await supabase
        .from('user_daily_profit')
        .select('date, daily_profit')
        .eq('user_id', uid)
        .order('date', { ascending: true })

      if (dailyError && dailyError.code !== 'PGRST116') {
        throw dailyError
      }

      // 紹介報酬（monthly_referral_profit）- V2システム対応
      const { data: referralProfitData, error: referralError } = await supabase
        .from('monthly_referral_profit')
        .select('year_month, profit_amount')
        .eq('user_id', uid)
        .order('year_month', { ascending: true })

      if (referralError && referralError.code !== 'PGRST116') {
        throw referralError
      }

      // 月末出金記録（monthly_withdrawals）- お支払い予定額算出用
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from('monthly_withdrawals')
        .select('withdrawal_month, total_amount, referral_amount')
        .eq('user_id', uid)
        .order('withdrawal_month', { ascending: true })

      if (withdrawalError && withdrawalError.code !== 'PGRST116') {
        throw withdrawalError
      }

      // 月別に集計
      const monthlyMap = new Map<string, MonthlyProfit>()

      // 個人利益を集計
      dailyProfitData?.forEach(record => {
        // 日付文字列（YYYY-MM-DD）から直接年月を抽出（タイムゾーン問題を回避）
        const [yearStr, monthStr] = record.date.split('-')
        const year = parseInt(yearStr)
        const month = parseInt(monthStr)
        const key = `${year}-${month}`

        if (!monthlyMap.has(key)) {
          monthlyMap.set(key, {
            year,
            month,
            personalProfit: 0,
            referralProfit: 0,
            totalProfit: 0,
            withdrawalAmount: 0,
            withdrawnReferral: 0,
            hasWithdrawal: false
          })
        }

        const monthData = monthlyMap.get(key)!
        monthData.personalProfit += record.daily_profit
      })

      // 紹介報酬を集計（V2: monthly_referral_profit）
      referralProfitData?.forEach(record => {
        const [yearStr, monthStr] = record.year_month.split('-')
        const year = parseInt(yearStr)
        const month = parseInt(monthStr)
        const key = `${year}-${month}`

        if (!monthlyMap.has(key)) {
          monthlyMap.set(key, {
            year,
            month,
            personalProfit: 0,
            referralProfit: 0,
            totalProfit: 0,
            withdrawalAmount: 0,
            withdrawnReferral: 0,
            hasWithdrawal: false
          })
        }

        const monthData = monthlyMap.get(key)!
        monthData.referralProfit += parseFloat(record.profit_amount)
      })

      // 月末出金データを集計
      withdrawalData?.forEach(record => {
        const [yearStr, monthStr] = record.withdrawal_month.split('-')
        const year = parseInt(yearStr)
        const month = parseInt(monthStr)
        const key = `${year}-${month}`

        if (!monthlyMap.has(key)) {
          monthlyMap.set(key, {
            year,
            month,
            personalProfit: 0,
            referralProfit: 0,
            totalProfit: 0,
            withdrawalAmount: 0,
            withdrawnReferral: 0,
            hasWithdrawal: false
          })
        }

        const monthData = monthlyMap.get(key)!
        monthData.withdrawalAmount = parseFloat(record.total_amount) || 0
        monthData.withdrawnReferral = parseFloat(record.referral_amount) || 0
        monthData.hasWithdrawal = true
      })

      // 合計を計算
      monthlyMap.forEach(monthData => {
        monthData.totalProfit = monthData.personalProfit + monthData.referralProfit
      })

      // 配列に変換し、新しい順にソート
      const monthlyArray = Array.from(monthlyMap.values()).sort((a, b) => {
        if (a.year !== b.year) return b.year - a.year
        return b.month - a.month
      })

      // 当月のデータは紹介報酬を0にする（月末まで確定しないため）
      // 日本時間で現在の年月を取得
      const now = new Date()
      const jstOffset = 9 * 60 // 日本時間は UTC+9
      const jstNow = new Date(now.getTime() + jstOffset * 60 * 1000)
      const currentYear = jstNow.getUTCFullYear()
      const currentMonth = jstNow.getUTCMonth() + 1

      monthlyArray.forEach(monthData => {
        if (monthData.year === currentYear && monthData.month === currentMonth) {
          // 当月の場合、紹介報酬を0にして合計を再計算
          monthData.referralProfit = 0
          monthData.totalProfit = monthData.personalProfit
        }
      })

      setMonthlyProfits(monthlyArray)

    } catch (err: any) {
      console.error("Monthly profit fetch error:", err)
      setError("データの取得に失敗しました")
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 text-white flex items-center justify-center">
        <div className="flex items-center space-x-3">
          <Loader2 className="h-8 w-8 text-blue-400 animate-spin" />
          <span className="text-lg">読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700 sticky top-0 z-50">
        <div className="container mx-auto px-4 py-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Link href="/dashboard">
                <img
                  src="/images/hash-pilot-logo.png"
                  alt="HASH PILOT"
                  className="h-8 rounded-lg"
                />
              </Link>
              <div className="flex items-center space-x-2">
                <Calendar className="h-5 w-5 text-blue-400" />
                <h1 className="text-lg font-bold text-white">利益履歴</h1>
              </div>
            </div>
            <Link href="/dashboard">
              <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white px-2">
                <Home className="h-4 w-4" />
                <span className="hidden sm:inline ml-1">戻る</span>
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <div className="max-w-5xl mx-auto p-4 md:p-8">

        {/* エラー表示 */}
        {error && (
          <Card className="bg-red-900/20 border-red-700 mb-6">
            <CardContent className="pt-6">
              <p className="text-red-400">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* データなし */}
        {!loading && monthlyProfits.length === 0 && (
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="pt-6 text-center">
              <p className="text-gray-400">利益データがありません</p>
            </CardContent>
          </Card>
        )}

        {/* 月別利益一覧 */}
        {monthlyProfits.length > 0 && (
          <div className="space-y-4">
            {monthlyProfits.map((profit) => {
              const now = new Date()
              const isCurrentMonth = profit.year === now.getFullYear() && profit.month === (now.getMonth() + 1)
              const lockedReferral = Math.max(0, profit.referralProfit - profit.withdrawnReferral)

              return (
                <Card key={`${profit.year}-${profit.month}`} className="bg-gray-800 border-gray-700">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-lg font-medium text-gray-300">
                      {profit.year}年{profit.month}月
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* お支払い予定額（上段、メイン） */}
                    <div className="bg-gradient-to-br from-blue-900/40 to-purple-900/40 border border-blue-500/30 rounded-lg p-5">
                      <div className="text-xs text-blue-300 mb-2">💰 お支払い予定額</div>
                      {profit.hasWithdrawal ? (
                        <>
                          <div className={`text-3xl font-bold ${
                            profit.withdrawalAmount >= 0 ? "text-blue-300" : "text-red-400"
                          }`}>
                            ${profit.withdrawalAmount.toFixed(2)}
                          </div>
                          <div className="text-xs text-gray-400 mt-2">
                            （個人利益 + 出金可能な紹介報酬）
                          </div>
                        </>
                      ) : isCurrentMonth ? (
                        <>
                          <div className="text-2xl font-bold text-gray-500">--</div>
                          <div className="text-xs text-gray-400 mt-2">
                            月末集計後に確定
                          </div>
                        </>
                      ) : (
                        <>
                          <div className="text-2xl font-bold text-gray-500">--</div>
                          <div className="text-xs text-gray-400 mt-2">
                            お支払いデータなし
                          </div>
                        </>
                      )}
                    </div>

                    {/* 収支詳細（下段） */}
                    <div className="bg-gray-900/50 rounded-lg p-4 space-y-3">
                      <div className="text-xs text-gray-400">📊 収支詳細</div>

                      {/* 個人利益 */}
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-300">個人利益</span>
                        <span className={`text-lg font-bold ${
                          profit.personalProfit >= 0 ? "text-blue-400" : "text-red-400"
                        }`}>
                          ${profit.personalProfit.toFixed(3)}
                        </span>
                      </div>

                      {/* 紹介報酬（発生額） */}
                      <div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm text-gray-300">紹介報酬（発生額）</span>
                          {isCurrentMonth ? (
                            <span className="text-sm text-gray-500">月末集計後</span>
                          ) : (
                            <span className={`text-lg font-bold ${
                              profit.referralProfit >= 0 ? "text-green-400" : "text-red-400"
                            }`}>
                              ${profit.referralProfit.toFixed(3)}
                            </span>
                          )}
                        </div>

                        {/* 内訳: 出金・ロック */}
                        {!isCurrentMonth && profit.referralProfit > 0 && (
                          <div className="ml-4 mt-2 space-y-1 text-xs">
                            <div className="flex justify-between text-gray-400">
                              <span>🟢 今月出金</span>
                              <span className="text-green-400">${profit.withdrawnReferral.toFixed(2)}</span>
                            </div>
                            {lockedReferral > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>🔒 ロック中</span>
                                <span className="text-orange-400">${lockedReferral.toFixed(2)}</span>
                              </div>
                            )}
                            {lockedReferral > 0 && (
                              <div className="text-gray-500 italic mt-1">
                                ※ ロック分は次回NFT自動付与時または将来の出金で順次開放されます
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                </CardContent>
              </Card>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
