"use client"

import { useState, useEffect, Suspense } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { 
  CheckCircle, 
  Clock, 
  ArrowRight, 
  MessageSquare,
  Shield,
  Timer,
  Users
} from "lucide-react"
import Image from "next/image"

function PaymentSubmittedContent() {
  const [countdown, setCountdown] = useState(10)
  const router = useRouter()
  const searchParams = useSearchParams()
  const amount = searchParams.get("amount")
  const nftCount = searchParams.get("nftCount")

  useEffect(() => {
    const timer = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(timer)
          router.push("/dashboard")
          return 0
        }
        return prev - 1
      })
    }, 1000)

    return () => clearInterval(timer)
  }, [router])

  const goToDashboard = () => {
    router.push("/dashboard")
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center space-x-4">
            <Image src="/images/hash-pilot-logo.png" alt="HashPilot Logo" width={40} height={40} />
            <span className="text-xl font-bold text-white">HASH PILOT</span>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-12">
        <div className="max-w-2xl mx-auto">
          {/* メイン確認カード */}
          <Card className="bg-gray-800/80 backdrop-blur-sm border-gray-700 shadow-2xl mb-8">
            <CardContent className="text-center p-8">
              {/* 成功アイコン */}
              <div className="w-20 h-20 bg-green-500/20 rounded-full flex items-center justify-center mx-auto mb-6">
                <CheckCircle className="w-12 h-12 text-green-400" />
              </div>

              {/* メインメッセージ */}
              <h1 className="text-3xl font-bold text-white mb-4">
                送金情報を受付ました！
              </h1>
              
              <p className="text-lg text-gray-300 mb-6">
                ご提出いただいた送金情報を確認中です。
                <br />
                管理者の確認完了まで少々お待ちください。
              </p>

              {/* 購入詳細 */}
              {(amount || nftCount) && (
                <div className="bg-blue-900/20 rounded-lg p-4 mb-6">
                  <h3 className="text-white font-semibold mb-2">購入詳細</h3>
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    {nftCount && (
                      <div>
                        <span className="text-gray-400">NFT数量:</span>
                        <p className="text-white font-bold">{nftCount}個</p>
                      </div>
                    )}
                    {amount && (
                      <div>
                        <span className="text-gray-400">送金金額:</span>
                        <p className="text-green-400 font-bold">${amount} USDT</p>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* 自動遷移カウントダウン */}
              <div className="bg-gray-700/50 rounded-lg p-4 mb-6">
                <div className="flex items-center justify-center gap-2 text-gray-300">
                  <Timer className="w-4 h-4" />
                  <span className="text-sm">
                    {countdown}秒後にダッシュボードに自動移動します
                  </span>
                </div>
              </div>

              {/* ダッシュボードボタン */}
              <Button
                onClick={goToDashboard}
                className="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 text-lg"
                size="lg"
              >
                <ArrowRight className="w-5 h-5 mr-2" />
                ダッシュボードに戻る
              </Button>
            </CardContent>
          </Card>

          {/* 次のステップ案内 */}
          <div className="grid md:grid-cols-3 gap-4 mb-8">
            <Card className="bg-gray-800/60 border-gray-700">
              <CardContent className="p-4 text-center">
                <Clock className="w-8 h-8 text-yellow-400 mx-auto mb-2" />
                <h3 className="text-white font-semibold mb-1">確認待ち</h3>
                <p className="text-sm text-gray-400">
                  管理者が送金を確認中です
                </p>
              </CardContent>
            </Card>

            <Card className="bg-gray-800/60 border-gray-700">
              <CardContent className="p-4 text-center">
                <Shield className="w-8 h-8 text-blue-400 mx-auto mb-2" />
                <h3 className="text-white font-semibold mb-1">承認処理</h3>
                <p className="text-sm text-gray-400">
                  確認後、NFTが有効化されます
                </p>
              </CardContent>
            </Card>

            <Card className="bg-gray-800/60 border-gray-700">
              <CardContent className="p-4 text-center">
                <Users className="w-8 h-8 text-green-400 mx-auto mb-2" />
                <h3 className="text-white font-semibold mb-1">運用開始</h3>
                <p className="text-sm text-gray-400">
                  ダッシュボードで利益を確認できます
                </p>
              </CardContent>
            </Card>
          </div>

          {/* 重要な注意事項 */}
          <Card className="bg-yellow-900/20 border-yellow-700/50">
            <CardHeader>
              <CardTitle className="text-yellow-200 flex items-center gap-2">
                <MessageSquare className="w-5 h-5" />
                重要なお知らせ
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="text-yellow-100 space-y-2">
                <p className="flex items-start gap-2">
                  <span className="text-yellow-400 font-bold">•</span>
                  <span>送金確認には数時間〜24時間程度かかる場合があります。</span>
                </p>
                <p className="flex items-start gap-2">
                  <span className="text-yellow-400 font-bold">•</span>
                  <span>承認完了後、ダッシュボードでNFTステータスが「承認済み」に変更されます。</span>
                </p>
                <p className="flex items-start gap-2">
                  <span className="text-yellow-400 font-bold">•</span>
                  <span>NFT有効化後、翌営業日から日利配布が開始されます。</span>
                </p>
                <p className="flex items-start gap-2">
                  <span className="text-red-400 font-bold">⚠</span>
                  <span className="text-red-200">
                    <strong>追加でNFT購入申請を行わないでください。</strong>
                    重複申請となり処理が遅れる可能性があります。
                  </span>
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  )
}

export default function PaymentSubmittedPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-white">読み込み中...</p>
        </div>
      </div>
    }>
      <PaymentSubmittedContent />
    </Suspense>
  )
}