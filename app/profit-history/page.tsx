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
  referralProfit: number
  totalProfit: number
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

      // 紹介報酬（user_referral_profit_monthly）- V2システム対応
      const { data: referralProfitData, error: referralError } = await supabase
        .from('user_referral_profit_monthly')
        .select('year, month, profit_amount')
        .eq('user_id', uid)
        .order('year', { ascending: true })
        .order('month', { ascending: true })

      if (referralError && referralError.code !== 'PGRST116') {
        throw referralError
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
            totalProfit: 0
          })
        }

        const monthData = monthlyMap.get(key)!
        monthData.personalProfit += record.daily_profit
      })

      // 紹介報酬を集計（V2: user_referral_profit_monthly）
      referralProfitData?.forEach(record => {
        const year = record.year
        const month = record.month
        const key = `${year}-${month}`

        if (!monthlyMap.has(key)) {
          monthlyMap.set(key, {
            year,
            month,
            personalProfit: 0,
            referralProfit: 0,
            totalProfit: 0
          })
        }

        const monthData = monthlyMap.get(key)!
        monthData.referralProfit += parseFloat(record.profit_amount)
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

              return (
                <Card key={`${profit.year}-${profit.month}`} className="bg-gray-800 border-gray-700">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-lg font-medium text-gray-300">
                      {profit.year}年{profit.month}月
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      {/* 個人利益 */}
                      <div className="bg-gray-900/50 rounded-lg p-4">
                        <div className="text-xs text-gray-400 mb-2">個人利益</div>
                        <div className={`text-2xl font-bold ${
                          profit.personalProfit >= 0 ? "text-blue-400" : "text-red-400"
                        }`}>
                          ${profit.personalProfit.toFixed(3)}
                        </div>
                      </div>

                      {/* 紹介報酬 */}
                      <div className="bg-gray-900/50 rounded-lg p-4">
                        <div className="text-xs text-gray-400 mb-2">紹介報酬</div>
                        {isCurrentMonth ? (
                          <div className="text-center py-1">
                            <div className="text-sm text-gray-400 mb-1">月末集計後に表示</div>
                            <div className="text-2xl font-bold text-gray-500">--</div>
                          </div>
                        ) : (
                          <div className={`text-2xl font-bold ${
                            profit.referralProfit >= 0 ? "text-green-400" : "text-red-400"
                          }`}>
                            ${profit.referralProfit.toFixed(3)}
                          </div>
                        )}
                      </div>

                      {/* 合計 */}
                      <div className="bg-gray-900/50 rounded-lg p-4">
                        <div className="text-xs text-gray-400 mb-2">合計利益</div>
                        <div className={`text-2xl font-bold ${
                          profit.totalProfit >= 0 ? "text-purple-400" : "text-red-400"
                        }`}>
                          ${profit.totalProfit.toFixed(3)}
                        </div>
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
