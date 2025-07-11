"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { DollarSign, Zap, Clock, Target, TrendingUp } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface CycleStatusCardProps {
  userId: string
}

interface CycleData {
  next_action: string
  available_usdt: number
  total_nft_count: number
  auto_nft_count: number
  manual_nft_count: number
  cum_profit: number
  remaining_profit: number
}

export function CycleStatusCard({ userId }: CycleStatusCardProps) {
  const [cycleData, setCycleData] = useState<CycleData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchCycleData()
    }
  }, [userId])

  const fetchCycleData = async () => {
    try {
      setLoading(true)
      setError("")

      // 現在の月の利益データを取得（MonthlyProfitCardと同じ方法）
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (profitError && profitError.code !== 'PGRST116') throw profitError

      // NFTデータを取得
      const { data: nftData, error: nftError } = await supabase
        .from('purchases')
        .select('nft_quantity')
        .eq('user_id', userId)
        .eq('admin_approved', true)

      if (nftError) throw nftError

      // 計算
      const totalProfit = profitData?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0
      const totalNfts = nftData?.reduce((sum, n) => sum + (n.nft_quantity || 0), 0) || 0
      // 自動/手動の区別は一旦なしで総数のみ表示
      const manualNfts = totalNfts
      const autoNfts = 0

      // 1100ドルサイクル計算
      const cyclesCompleted = Math.floor(totalProfit / 1100)
      const remainingProfit = totalProfit % 1100
      const nextAction = cyclesCompleted % 2 === 0 ? 'usdt' : 'nft'

      setCycleData({
        next_action: nextAction,
        available_usdt: 0, // 一旦0で設定
        total_nft_count: manualNfts + autoNfts,
        auto_nft_count: autoNfts,
        manual_nft_count: manualNfts,
        cum_profit: totalProfit,
        remaining_profit: remainingProfit
      })
    } catch (err: any) {
      console.error("Cycle data fetch error:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const getPhaseInfo = (nextAction: string) => {
    if (nextAction === 'nft') {
      return {
        label: "🎯 NFT購入フェーズ",
        description: "次の1100ドルでNFT自動購入",
        color: "bg-purple-600",
        icon: <Target className="h-4 w-4" />
      }
    } else {
      return {
        label: "💰 USDT受取フェーズ", 
        description: "次の1100ドルはUSDT受取",
        color: "bg-green-600",
        icon: <DollarSign className="h-4 w-4" />
      }
    }
  }

  const getProgressPercentage = (currentProfit: number) => {
    if (currentProfit <= 0) return 0
    if (currentProfit >= 1100) return 100
    return (currentProfit / 1100) * 100
  }

  const getNextMilestone = (currentProfit: number, nextAction: string) => {
    const remaining = 1100 - currentProfit
    if (remaining <= 0) {
      return {
        target: 1100,
        label: nextAction === 'nft' ? "NFT購入準備完了" : "USDT受取準備完了",
        remaining: 0
      }
    } else {
      return {
        target: 1100,
        label: nextAction === 'nft' ? "NFT購入まで" : "USDT受取まで",
        remaining: remaining
      }
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center space-x-2">
            <div className="animate-pulse bg-gray-600 h-4 w-32 rounded"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error || !cycleData) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <p className="text-gray-400 text-sm">{error || "サイクル情報なし"}</p>
        </CardContent>
      </Card>
    )
  }

  const phaseInfo = getPhaseInfo(cycleData.next_action)
  const progress = getProgressPercentage(cycleData.remaining_profit)
  const milestone = getNextMilestone(cycleData.remaining_profit, cycleData.next_action)

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Zap className="h-4 w-4 text-blue-400" />
          NFTサイクル状況
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* 現在のフェーズ */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {phaseInfo.icon}
            <span className="text-white text-sm font-medium">{phaseInfo.label}</span>
          </div>
          <Badge className={phaseInfo.color}>
            次: {cycleData.next_action.toUpperCase()}
          </Badge>
        </div>

        <p className="text-xs text-gray-400">{phaseInfo.description}</p>

        {/* 進捗バー */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-400">次の1100ドルまでの進捗</span>
            <span className="text-white">${cycleData.remaining_profit.toFixed(2)} / $1,100</span>
          </div>
          <div className="relative">
            <div className="h-3 bg-gray-700 rounded-full overflow-hidden">
              <div 
                className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all duration-300"
                style={{ width: `${progress}%` }}
              />
            </div>
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-xs font-semibold text-white drop-shadow-lg">
                {progress.toFixed(1)}%
              </span>
            </div>
          </div>
          
          {milestone.remaining > 0 && (
            <p className="text-xs text-gray-400">
              {milestone.label}: あと${milestone.remaining.toFixed(2)}
            </p>
          )}
        </div>

        {/* NFT保有状況 */}
        <div className="grid grid-cols-3 gap-3 pt-2 border-t border-gray-700">
          <div className="text-center">
            <div className="text-lg font-bold text-blue-400">{cycleData.total_nft_count}</div>
            <div className="text-xs text-gray-400">総NFT数</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-green-400">{cycleData.manual_nft_count}</div>
            <div className="text-xs text-gray-400">🛒 手動購入</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-purple-400">{cycleData.auto_nft_count}</div>
            <div className="text-xs text-gray-400">🔄 自動購入</div>
          </div>
        </div>

        {/* 利用可能残高 */}
        {cycleData.available_usdt > 0 && (
          <div className="bg-green-900/20 border border-green-500/30 rounded-lg p-3">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-green-400" />
              <span className="text-green-400 text-sm font-medium">
                受取可能: ${cycleData.available_usdt.toFixed(2)}
              </span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

