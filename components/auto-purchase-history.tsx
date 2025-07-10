"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Zap, Clock, RefreshCw, ShoppingCart, TrendingUp } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface AutoPurchaseHistoryProps {
  userId: string
}

interface AutoPurchase {
  purchase_id: string
  purchase_date: string
  nft_quantity: number
  amount_usd: string
  cycle_number: number
}

export function AutoPurchaseHistory({ userId }: AutoPurchaseHistoryProps) {
  const [purchases, setPurchases] = useState<AutoPurchase[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchAutoPurchaseHistory()
    }
  }, [userId])

  const fetchAutoPurchaseHistory = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error: purchaseError } = await supabase.rpc("get_auto_purchase_history", {
        p_user_id: userId,
        p_limit: 10
      })

      if (purchaseError) {
        throw purchaseError
      }

      setPurchases(data || [])
    } catch (err: any) {
      console.error("Auto purchase history fetch error:", err)
      setError("自動購入履歴の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("ja-JP", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    })
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
            <Zap className="h-4 w-4 text-purple-400" />
            自動NFT購入履歴
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <div className="animate-pulse bg-gray-600 h-4 w-32 rounded"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
            <Zap className="h-4 w-4 text-purple-400" />
            自動NFT購入履歴
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-gray-400 text-sm">{error}</p>
          <Button 
            onClick={fetchAutoPurchaseHistory}
            size="sm" 
            className="mt-2 bg-purple-600 hover:bg-purple-700"
          >
            <RefreshCw className="h-3 w-3 mr-1" />
            再試行
          </Button>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Zap className="h-4 w-4 text-purple-400" />
            自動NFT購入履歴
          </div>
          <Button 
            onClick={fetchAutoPurchaseHistory}
            size="sm" 
            variant="ghost"
            className="h-6 w-6 p-0 text-gray-400 hover:text-white"
          >
            <RefreshCw className="h-3 w-3" />
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {purchases.length === 0 ? (
          <div className="text-center py-4">
            <ShoppingCart className="h-8 w-8 text-gray-500 mx-auto mb-2" />
            <p className="text-gray-400 text-sm">自動購入履歴がありません</p>
            <p className="text-xs text-gray-500 mt-1">2200 USDT到達で自動購入されます</p>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between text-xs text-gray-400 mb-2">
              <span>総自動購入: {purchases.length}回</span>
              <span>総NFT: {purchases.reduce((sum, p) => sum + p.nft_quantity, 0)}個</span>
            </div>
            <div className="space-y-2 max-h-48 overflow-y-auto">
              {purchases.map((purchase) => (
                <div 
                  key={purchase.purchase_id}
                  className="bg-purple-900/20 border border-purple-500/30 rounded-lg p-3 space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <TrendingUp className="h-4 w-4 text-purple-400" />
                      <span className="text-purple-400 text-sm font-medium">
                        +{purchase.nft_quantity} NFT
                      </span>
                    </div>
                    <Badge className="bg-purple-600 text-white text-xs">
                      サイクル {purchase.cycle_number}
                    </Badge>
                  </div>
                  
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-gray-400">
                      <Clock className="h-3 w-3 inline mr-1" />
                      {formatDate(purchase.purchase_date)}
                    </span>
                    <span className="text-green-400 font-medium">
                      ${Number(purchase.amount_usd).toLocaleString()}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </CardContent>
    </Card>
  )
}

export { AutoPurchaseHistory }