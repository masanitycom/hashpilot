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

      // 利益データを取得
      const { data: profitData, error: profitError } = await supabase
        .from('daily_profit_records')
        .select('daily_profit')
        .eq('user_id', userId)

      if (profitError) throw profitError

      // NFTデータを取得
      const { data: nftData, error: nftError } = await supabase
        .from('purchases')
        .select('nft_quantity, purchase_type')
        .eq('user_id', userId)
        .eq('admin_approved', true)

      if (nftError) throw nftError

      // 月末出金データを取得
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from('monthly_withdrawals')
        .select('available_amount')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(1)

      if (withdrawalError && withdrawalError.code !== 'PGRST116') throw withdrawalError

      // 計算
      const totalProfit = profitData?.reduce((sum, p) => sum + (p.daily_profit || 0), 0) || 0
      const manualNfts = nftData?.filter(n => n.purchase_type === 'manual').reduce((sum, n) => sum + (n.nft_quantity || 0), 0) || 0
      const autoNfts = nftData?.filter(n => n.purchase_type === 'auto').reduce((sum, n) => sum + (n.nft_quantity || 0), 0) || 0
      const availableUsdt = withdrawalData?.[0]?.available_amount || 0

      // 1100ドルサイクル計算
      const cyclesCompleted = Math.floor(totalProfit / 1100)
      const remainingProfit = totalProfit - (cyclesCompleted * 1100)
      const nextAction = cyclesCompleted % 2 === 0 ? 'usdt' : 'nft'

      setCycleData({
        next_action: nextAction,
        available_usdt: availableUsdt,
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

  const getProgressPercentage = (remaining: number) => {
    if (remaining <= 0) return 100
    if (remaining >= 1100) return 0
    return ((1100 - remaining) / 1100) * 100
  }

  const getNextMilestone = (remaining: number, nextAction: string) => {
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
            <span className="text-white">${(1100 - cycleData.remaining_profit).toFixed(2)} / $1,100</span>
          </div>
          <Progress value={progress} className="h-2 bg-gray-700">
            <div 
              className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all"
              style={{ width: `${progress}%` }}
            />
          </Progress>
          
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

