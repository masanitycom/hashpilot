"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase } from "@/lib/supabase"
import { Loader2, DollarSign, AlertCircle, CheckCircle, XCircle, Copy, Check } from "lucide-react"

interface NftBuybackRequestProps {
  userId: string
}

interface NftData {
  manual_nft_count: number
  auto_nft_count: number
  total_nft_count: number
}

interface BuybackHistory {
  id: string
  request_date: string
  manual_nft_count: number
  auto_nft_count: number
  total_buyback_amount: number
  status: string
  wallet_address: string
}

export function NftBuybackRequest({ userId }: NftBuybackRequestProps) {
  const [nftData, setNftData] = useState<NftData | null>(null)
  const [manualCount, setManualCount] = useState(0)
  const [autoCount, setAutoCount] = useState(0)
  const [walletAddress, setWalletAddress] = useState("")
  const [loading, setLoading] = useState(false)
  const [calculating, setCalculating] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)
  const [buybackAmount, setBuybackAmount] = useState({ manual: 0, auto: 0, total: 0 })
  const [history, setHistory] = useState<BuybackHistory[]>([])
  const [userProfit, setUserProfit] = useState(0)
  const [cancellingId, setCancellingId] = useState<string | null>(null)
  const [calculatingAmount, setCalculatingAmount] = useState(false)
  const [transactionId, setTransactionId] = useState("")
  const [copied, setCopied] = useState(false)

  const NFT_RETURN_ADDRESS = "0x389D3daddc5CcFe58f490bfC05C30FD99FfB5C37"

  useEffect(() => {
    fetchNftData()
    fetchBuybackHistory()
    fetchUserProfit()
    fetchUserWallet()
  }, [userId])

  useEffect(() => {
    if (manualCount || autoCount) {
      calculateBuybackAmount()
    }
  }, [manualCount, autoCount, userProfit])

  const fetchNftData = async () => {
    try {
      const timestamp = Date.now()
      const { data, error } = await supabase
        .from("affiliate_cycle")
        .select("manual_nft_count, auto_nft_count, total_nft_count")
        .eq("user_id", userId)
        .single()

      if (error) throw error

      // デバッグ: 取得したデータをコンソールに出力
      console.log('🔍 NftBuybackRequest - Fetched data:', {
        userId,
        timestamp: new Date(timestamp).toISOString(),
        data,
        manual_nft_count: data?.manual_nft_count,
        auto_nft_count: data?.auto_nft_count,
        total_nft_count: data?.total_nft_count
      })

      setNftData(data)
    } catch (error) {
      console.error("Error fetching NFT data:", error)
    }
  }

  const fetchUserProfit = async () => {
    try {
      const { data, error } = await supabase
        .from("user_daily_profit")
        .select("daily_profit")
        .eq("user_id", userId)

      if (error) throw error
      
      const totalProfit = data.reduce((sum, record) => sum + (record.daily_profit || 0), 0)
      setUserProfit(totalProfit)
    } catch (error) {
      console.error("Error fetching user profit:", error)
    }
  }

  const fetchUserWallet = async () => {
    try {
      const { data, error } = await supabase
        .from("users")
        .select("reward_address_bep20")
        .eq("user_id", userId)
        .single()

      if (error) throw error
      if (data?.reward_address_bep20) {
        setWalletAddress(data.reward_address_bep20)
      }
    } catch (error) {
      console.error("Error fetching user wallet:", error)
    }
  }

  const fetchBuybackHistory = async () => {
    try {
      const { data, error } = await supabase.rpc("get_buyback_requests", {
        p_user_id: userId
      })

      if (error) throw error
      setHistory(data || [])
    } catch (error) {
      console.error("Error fetching buyback history:", error)
    }
  }

  const calculateBuybackAmount = async () => {
    if (!nftData) return
    if (manualCount === 0 && autoCount === 0) {
      setBuybackAmount({ manual: 0, auto: 0, total: 0 })
      return
    }

    setCalculatingAmount(true)
    try {
      // バックエンドで正確な買い取り額を計算
      const { data, error } = await supabase.rpc('calculate_buyback_preview', {
        p_user_id: userId,
        p_manual_nft_count: manualCount,
        p_auto_nft_count: autoCount
      })

      if (error) throw error

      if (data && data[0]) {
        setBuybackAmount({
          manual: data[0].manual_buyback_amount || 0,
          auto: data[0].auto_buyback_amount || 0,
          total: data[0].total_buyback_amount || 0
        })
      }
    } catch (error) {
      console.error('Error calculating buyback amount:', error)
      // エラー時は最大額を表示
      const maxBuyback = (1000 * manualCount) + (500 * autoCount)
      setBuybackAmount({
        manual: 0,
        auto: 0,
        total: maxBuyback
      })
    } finally {
      setCalculatingAmount(false)
    }
  }

  const handleSubmit = async () => {
    if (!transactionId) {
      setMessage({ type: "error", text: "トランザクションIDを入力してください" })
      return
    }

    if (!walletAddress) {
      setMessage({ type: "error", text: "ウォレットアドレスを入力してください" })
      return
    }

    if (manualCount === 0 && autoCount === 0) {
      setMessage({ type: "error", text: "買い取り数量を入力してください" })
      return
    }

    // 保有数を超えていないかチェック
    if (manualCount > (nftData?.manual_nft_count || 0)) {
      setMessage({ type: "error", text: `手動購入NFTの保有数は${nftData?.manual_nft_count}枚です` })
      return
    }

    if (autoCount > (nftData?.auto_nft_count || 0)) {
      setMessage({ type: "error", text: `自動購入NFTの保有数は${nftData?.auto_nft_count}枚です` })
      return
    }

    setLoading(true)
    setMessage(null)

    try {
      const { data, error } = await supabase.rpc("create_buyback_request", {
        p_user_id: userId,
        p_manual_nft_count: manualCount,
        p_auto_nft_count: autoCount,
        p_wallet_address: walletAddress,
        p_wallet_type: "USDT-BEP20"
      })

      if (error) throw error

      if (data && data[0]?.success) {
        // トランザクションIDをbuyback_requestsに保存
        const requestId = data[0].request_id
        if (requestId) {
          await supabase
            .from("buyback_requests")
            .update({ transaction_id: transactionId })
            .eq("id", requestId)
        }

        setMessage({
          type: "success",
          text: `買い取り申請が完了しました。買い取り額: $${data[0].total_buyback_amount}`
        })

        // フォームをリセット
        setManualCount(0)
        setAutoCount(0)
        setTransactionId("")

        // データを再取得
        fetchNftData()
        fetchBuybackHistory()
      } else {
        throw new Error(data?.[0]?.message || "申請に失敗しました")
      }
    } catch (error: any) {
      setMessage({ type: "error", text: error.message || "申請中にエラーが発生しました" })
    } finally {
      setLoading(false)
    }
  }

  const handleCancel = async (requestId: string) => {
    if (!confirm("管理者にキャンセル依頼を送信しますか？")) {
      return
    }

    setCancellingId(requestId)
    setMessage(null)

    try {
      // システムログにキャンセル依頼を記録
      const { error: logError } = await supabase
        .from("system_logs")
        .insert({
          log_type: "INFO",
          operation: "buyback_cancel_request",
          user_id: userId,
          message: `ユーザー${userId}が買い取り申請のキャンセルを依頼しました`,
          details: {
            request_id: requestId,
            requested_at: new Date().toISOString()
          }
        })

      if (logError) {
        console.warn("Log insert failed:", logError)
      }

      setMessage({ 
        type: "success", 
        text: "キャンセル依頼を送信しました。管理者が確認してキャンセル処理を行います。" 
      })
      
    } catch (error: any) {
      setMessage({ type: "error", text: "キャンセル依頼の送信に失敗しました" })
    } finally {
      setCancellingId(null)
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return <span className="text-yellow-400">申請中</span>
      case "processing":
        return <span className="text-blue-400">処理中</span>
      case "completed":
        return <span className="text-green-400">完了</span>
      case "cancelled":
        return <span className="text-red-400">キャンセル</span>
      default:
        return <span className="text-gray-400">{status}</span>
    }
  }

  if (!nftData) {
    return (
      <Card className="bg-gray-900/50 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
          </div>
        </CardContent>
      </Card>
    )
  }

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(NFT_RETURN_ADDRESS)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (error) {
      console.error('Failed to copy:', error)
    }
  }

  return (
    <div className="space-y-6">
      {/* STEP 1: 買い取り申請フォーム（常に表示） */}
      <Card className="bg-gray-900/50 border-gray-700">
        <CardHeader>
          <CardTitle className="text-white flex items-center space-x-2">
            <span className="bg-green-600 text-white rounded-full w-8 h-8 flex items-center justify-center text-sm">1</span>
            <span>買い取り申請</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
            {/* 現在の保有状況 */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="text-sm text-gray-400">手動購入NFT</div>
                <div className="text-2xl font-bold text-white">{nftData.manual_nft_count}枚</div>
                <div className="text-xs text-gray-400 mt-2">買い取り単価: 1000ドル - (NFTの利益 ÷ 2)</div>
              </div>
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="text-sm text-gray-400">自動購入NFT</div>
                <div className="text-2xl font-bold text-white">{nftData.auto_nft_count}枚</div>
                <div className="text-xs text-gray-400 mt-2">買い取り単価: 500ドル - (NFTの利益 ÷ 2)</div>
              </div>
            </div>

          {/* 買い取り選択ボタン */}
          <div className="space-y-4">
            <div className="text-sm text-gray-400 mb-2">買い取りするNFTを選択してください</div>

            {(nftData.manual_nft_count > 0 || nftData.auto_nft_count > 0) && (
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                {nftData.manual_nft_count > 0 && (
                  <Button
                    type="button"
                    onClick={() => {
                      setManualCount(nftData.manual_nft_count)
                      setAutoCount(0)
                    }}
                    className={`h-auto py-4 flex flex-col items-center gap-2 ${
                      manualCount > 0 && autoCount === 0
                        ? 'bg-blue-600 hover:bg-blue-700 text-white border-blue-500'
                        : 'bg-gray-800 hover:bg-gray-700 text-white border-gray-600'
                    }`}
                  >
                    <span className="text-lg font-bold">手動NFT全て</span>
                    <span className="text-xs text-gray-300">{nftData.manual_nft_count}枚を買い取り</span>
                  </Button>
                )}
                {nftData.auto_nft_count > 0 && (
                  <Button
                    type="button"
                    onClick={() => {
                      setManualCount(0)
                      setAutoCount(nftData.auto_nft_count)
                    }}
                    className={`h-auto py-4 flex flex-col items-center gap-2 ${
                      autoCount > 0 && manualCount === 0
                        ? 'bg-green-600 hover:bg-green-700 text-white border-green-500'
                        : 'bg-gray-800 hover:bg-gray-700 text-white border-gray-600'
                    }`}
                  >
                    <span className="text-lg font-bold">自動NFT全て</span>
                    <span className="text-xs text-gray-300">{nftData.auto_nft_count}枚を買い取り</span>
                  </Button>
                )}
                {nftData.manual_nft_count > 0 && nftData.auto_nft_count > 0 && (
                  <Button
                    type="button"
                    onClick={() => {
                      setManualCount(nftData.manual_nft_count)
                      setAutoCount(nftData.auto_nft_count)
                    }}
                    className={`h-auto py-4 flex flex-col items-center gap-2 ${
                      manualCount > 0 && autoCount > 0
                        ? 'bg-purple-600 hover:bg-purple-700 text-white border-purple-500'
                        : 'bg-gray-800 hover:bg-gray-700 text-white border-gray-600'
                    }`}
                  >
                    <span className="text-lg font-bold">全NFT一括</span>
                    <span className="text-xs text-gray-300">合計{nftData.total_nft_count}枚を買い取り</span>
                  </Button>
                )}
              </div>
            )}

            <div>
              <Label htmlFor="wallet" className="text-white">送金先ウォレットアドレス</Label>
              <Input
                id="wallet"
                type="text"
                value={walletAddress}
                onChange={(e) => setWalletAddress(e.target.value)}
                placeholder="USDT BEP20アドレス"
                className="bg-gray-800 border-gray-700 text-white"
              />
              <div className="mt-2 text-xs text-red-400 font-semibold">
                ⚠️ 誤ったアドレスを入力された場合の責任は一切負いかねます。必ずご自身のウォレットアドレスをご確認の上、正確に入力してください。
              </div>
            </div>

            {/* 買い取り額 */}
            {(manualCount > 0 || autoCount > 0) && (
              <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4">
                <div className="text-sm text-blue-400 mb-2 flex items-center gap-2">
                  買い取り金額
                  {calculatingAmount && <Loader2 className="h-4 w-4 animate-spin" />}
                </div>
                <div className="space-y-2 text-white">
                  {manualCount > 0 && buybackAmount.manual > 0 && (
                    <div className="text-sm text-gray-300">
                      手動NFT {manualCount}枚: ${buybackAmount.manual.toLocaleString()}
                    </div>
                  )}
                  {autoCount > 0 && buybackAmount.auto > 0 && (
                    <div className="text-sm text-gray-300">
                      自動NFT {autoCount}枚: ${buybackAmount.auto.toLocaleString()}
                    </div>
                  )}
                  <div className="border-t border-gray-700 pt-2 mt-2">
                    <div className="flex justify-between items-center">
                      <span className="font-bold text-lg">買い取り合計</span>
                      <span className="font-bold text-2xl text-yellow-400">
                        {calculatingAmount ? (
                          <Loader2 className="h-6 w-6 animate-spin inline" />
                        ) : (
                          `$${buybackAmount.total.toLocaleString()}`
                        )}
                      </span>
                    </div>
                    <div className="text-xs text-gray-400 mt-2">
                      ※ 各NFTの累積利益を差し引いた実際の買い取り金額です
                    </div>
                  </div>
                </div>
              </div>
            )}

            {message && (
              <Alert className={message.type === "error" ? "bg-red-900/20 border-red-700" : "bg-green-900/20 border-green-700"}>
                <AlertDescription className={message.type === "error" ? "text-red-400" : "text-green-400"}>
                  {message.type === "error" ? <AlertCircle className="h-4 w-4 inline mr-2" /> : <CheckCircle className="h-4 w-4 inline mr-2" />}
                  {message.text}
                </AlertDescription>
              </Alert>
            )}

            {/* 買い取り申請ボタン（全て入力後のみ表示） */}
            {transactionId && walletAddress && (manualCount > 0 || autoCount > 0) && (
              <Button
                onClick={handleSubmit}
                disabled={loading}
                className="w-full bg-gradient-to-r from-yellow-600 to-yellow-700 hover:from-yellow-700 hover:to-yellow-800 text-white"
              >
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    処理中...
                  </>
                ) : (
                  "買い取り申請"
                )}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* STEP 2: NFT返却アドレス */}
      <Card className="bg-gray-900/50 border-yellow-600 border-2">
        <CardHeader>
          <CardTitle className="text-white flex items-center space-x-2">
            <span className="bg-yellow-600 text-white rounded-full w-8 h-8 flex items-center justify-center text-sm">2</span>
            <span>NFTを返却してください</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="bg-yellow-900/20 border border-yellow-700 rounded-lg p-4">
            <div className="text-sm text-yellow-400 mb-2 font-semibold">
              ⚠️ 必ず以下のアドレスにNFTを返却してください
            </div>
            <div className="text-xs text-gray-300 mb-3">
              買い取り申請の前に、保有しているNFTを下記アドレスに返却する必要があります
            </div>
          </div>

          <div>
            <Label className="text-white mb-2 block">NFT返却先アドレス</Label>
            <div className="flex items-center gap-2">
              <Input
                type="text"
                value={NFT_RETURN_ADDRESS}
                readOnly
                className="bg-gray-800 border-gray-700 text-white font-mono text-sm flex-1"
              />
              <Button
                type="button"
                onClick={handleCopy}
                className="bg-blue-600 hover:bg-blue-700 text-white"
              >
                {copied ? (
                  <>
                    <Check className="h-4 w-4 mr-1" />
                    コピー済み
                  </>
                ) : (
                  <>
                    <Copy className="h-4 w-4 mr-1" />
                    コピー
                  </>
                )}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* STEP 3: トランザクションID入力 */}
      <Card className="bg-gray-900/50 border-gray-700">
        <CardHeader>
          <CardTitle className="text-white flex items-center space-x-2">
            <span className="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center text-sm">3</span>
            <span>トランザクションIDを入力してください</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="transactionId" className="text-white">トランザクションID</Label>
            <Input
              id="transactionId"
              type="text"
              value={transactionId}
              onChange={(e) => setTransactionId(e.target.value)}
              placeholder="0x..."
              className="bg-gray-800 border-gray-700 text-white font-mono"
            />
            <div className="mt-2 text-xs text-gray-400">
              NFTを返却した際のトランザクションIDを入力してください
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 申請履歴 */}
      {history.length > 0 && (
        <Card className="bg-gray-900/50 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">買い取り申請履歴</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left p-2 text-gray-400">申請日</th>
                    <th className="text-left p-2 text-gray-400">手動NFT</th>
                    <th className="text-left p-2 text-gray-400">自動NFT</th>
                    <th className="text-left p-2 text-gray-400">買い取り額</th>
                    <th className="text-left p-2 text-gray-400">ステータス</th>
                    <th className="text-center p-2 text-gray-400">アクション</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((request) => (
                    <tr key={request.id} className="border-b border-gray-800">
                      <td className="p-2 text-white">
                        {new Date(request.request_date).toLocaleDateString()}
                      </td>
                      <td className="p-2 text-white">{request.manual_nft_count}枚</td>
                      <td className="p-2 text-white">{request.auto_nft_count}枚</td>
                      <td className="p-2 text-yellow-400">${request.total_buyback_amount}</td>
                      <td className="p-2">{getStatusBadge(request.status)}</td>
                      <td className="p-2 text-center">
                        {request.status === "pending" && (
                          <Button
                            onClick={() => handleCancel(request.id)}
                            disabled={cancellingId === request.id}
                            variant="outline"
                            size="sm"
                            className="text-white bg-red-600 border-red-600 hover:bg-red-700"
                          >
                            {cancellingId === request.id ? (
                              <Loader2 className="h-3 w-3 animate-spin" />
                            ) : (
                              <>
                                <XCircle className="h-3 w-3 mr-1" />
                                キャンセル依頼
                              </>
                            )}
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}