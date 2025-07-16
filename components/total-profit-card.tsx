"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Target, TrendingUp, Loader2, DollarSign, Users } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface TotalProfitCardProps {
  userId: string
  totalInvestment: number
  level1Investment: number
  level2Investment: number
  level3Investment: number
}

interface TotalProfitData {
  yesterdayTotal: number
  monthlyTotal: number
  breakdown: {
    personalYesterday: number
    referralYesterday: number
    personalMonthly: number
    referralMonthly: number
  }
}

export function TotalProfitCard({ 
  userId, 
  totalInvestment,
  level1Investment, 
  level2Investment, 
  level3Investment 
}: TotalProfitCardProps) {
  const [profitData, setProfitData] = useState<TotalProfitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchTotalProfit()
    }
  }, [userId, totalInvestment, level1Investment, level2Investment, level3Investment])

  const fetchTotalProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 昨日の日付を取得
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      // 今月の開始日と終了日を取得
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

      // 昨日の総利益を取得
      const { data: yesterdayData, error: yesterdayError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .single()

      if (yesterdayError && yesterdayError.code !== 'PGRST116') {
        throw yesterdayError
      }

      // 今月の総利益累計を取得
      const { data: monthlyData, error: monthlyError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (monthlyError && monthlyError.code !== 'PGRST116') {
        throw monthlyError
      }

      // 個人利益（実際のデータ）
      const personalYesterday = yesterdayData ? yesterdayData.daily_profit : 0
      const personalMonthly = monthlyData ? 
        monthlyData.reduce((sum, record) => sum + record.daily_profit, 0) : 0

      // 紹介報酬を取得（直接クエリに変更）
      const { data: referralData, error: referralError } = await supabase
        .from('user_daily_profit')
        .select('date, referral_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      let referralYesterday = 0
      let referralMonthly = 0

      if (referralData) {
        referralData.forEach(row => {
          const profit = parseFloat(row.referral_profit) || 0
          
          // 昨日の紹介報酬
          if (row.date === yesterdayStr) {
            referralYesterday += profit
          }
          
          // 月間累計紹介報酬
          referralMonthly += profit
        })
      }

      // 合計を計算
      const yesterdayTotal = personalYesterday + referralYesterday
      const monthlyTotal = personalMonthly + referralMonthly

      setProfitData({
        yesterdayTotal,
        monthlyTotal,
        breakdown: {
          personalYesterday,
          referralYesterday,
          personalMonthly,
          referralMonthly
        }
      })

    } catch (err: any) {
      console.error("Total profit fetch error:", err)
      setError("合計利益データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">合計利益</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <Loader2 className="h-5 w-5 text-yellow-400 animate-spin" />
            <span className="text-sm text-gray-400">読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  const totalReferralInvestment = level1Investment + level2Investment + level3Investment

  return (
    <Card className="bg-gray-800 border-gray-700 border-yellow-500/20">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Target className="h-4 w-4 text-yellow-400" />
          合計利益
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-xs text-gray-400 mb-3 space-y-1">
          <div>個人投資: ${totalInvestment.toLocaleString()}</div>
          <div>紹介投資: ${totalReferralInvestment.toLocaleString()}</div>
        </div>
        
        {/* 昨日の合計利益 */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">昨日の合計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-yellow-400" />
              <span className={`text-sm font-semibold ${
                (profitData?.yesterdayTotal || 0) >= 0 ? "text-yellow-400" : "text-red-400"
              }`}>
                ${(profitData?.yesterdayTotal || 0).toFixed(3)}
              </span>
            </div>
          </div>
          
          {/* 内訳（昨日） */}
          {profitData && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              <div className="flex justify-between">
                <span className="text-green-400 flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />個人:
                </span>
                <span className="text-green-400">${profitData.breakdown.personalYesterday.toFixed(3)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-purple-400 flex items-center gap-1">
                  <Users className="h-3 w-3" />紹介:
                </span>
                <span className="text-purple-400">${profitData.breakdown.referralYesterday.toFixed(3)}</span>
              </div>
            </div>
          )}
        </div>

        {/* 今月の累計合計利益 */}
        <div className="space-y-2 border-t border-gray-600 pt-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">今月累計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-amber-400" />
              <span className={`text-lg font-bold ${
                (profitData?.monthlyTotal || 0) >= 0 ? "text-amber-400" : "text-red-400"
              }`}>
                ${(profitData?.monthlyTotal || 0).toFixed(3)}
              </span>
            </div>
          </div>

          {/* 内訳（今月） */}
          {profitData && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              <div className="flex justify-between">
                <span className="text-green-400 flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />個人:
                </span>
                <span className="text-green-400">${profitData.breakdown.personalMonthly.toFixed(3)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-purple-400 flex items-center gap-1">
                  <Users className="h-3 w-3" />紹介:
                </span>
                <span className="text-purple-400">${profitData.breakdown.referralMonthly.toFixed(3)}</span>
              </div>
            </div>
          )}
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}