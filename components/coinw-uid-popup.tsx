"use client"

import { useEffect, useState } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { AlertCircle } from "lucide-react"
import Link from "next/link"

interface CoinwUidPopupProps {
  userId: string
  coinwUid: string | null
}

export function CoinwUidPopup({ userId, coinwUid }: CoinwUidPopupProps) {
  console.log('[CoinwUidPopup] Component rendered with props:', { userId, coinwUid })

  const [isVisible, setIsVisible] = useState(false)
  const [isMounted, setIsMounted] = useState(false)
  const [dontShowAgain, setDontShowAgain] = useState(false)

  useEffect(() => {
    console.log('[CoinwUidPopup] useEffect triggered')
    setIsMounted(true)

    // クライアントサイドでのみlocalStorageにアクセス
    if (typeof window !== 'undefined') {
      const storageKey = `coinw_uid_confirmed_${userId}`
      const confirmed = localStorage.getItem(storageKey)
      console.log('[CoinwUidPopup] Storage check:', { userId, storageKey, confirmed, shouldShow: !confirmed })
      if (!confirmed) {
        console.log('[CoinwUidPopup] Showing popup')
        setIsVisible(true)
      } else {
        console.log('[CoinwUidPopup] Already confirmed, not showing')
      }
    }
  }, [userId])

  const handleConfirm = () => {
    if (typeof window !== 'undefined' && dontShowAgain) {
      localStorage.setItem(`coinw_uid_confirmed_${userId}`, 'true')
    }
    setIsVisible(false)
  }

  // SSRとのハイドレーションミスマッチを防ぐ
  if (!isMounted || !isVisible) {
    return null
  }

  return (
    <div className="fixed inset-0 bg-black/80 z-[100] flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        <Card className="bg-gradient-to-br from-red-900 to-orange-900 border-red-500 border-2 shadow-2xl">
          <CardContent className="p-6">
            <div className="flex items-start gap-4 mb-4">
              <div className="flex-shrink-0">
                <div className="w-12 h-12 bg-red-500 rounded-full flex items-center justify-center animate-pulse">
                  <AlertCircle className="w-7 h-7 text-white" />
                </div>
              </div>
              <div className="flex-1">
                <h3 className="text-white font-bold text-xl mb-2">
                  ⚠️ 重要なお知らせ！
                </h3>
              </div>
            </div>

            <div className="space-y-4 mb-6">
              <div className="bg-white/10 rounded-lg p-4 border border-white/20">
                <p className="text-white text-base font-bold mb-2">
                  報酬の支払い先に指定しているCoinWのUIDの確認を必ずお願いします。
                </p>
                <p className="text-red-200 text-sm font-semibold">
                  ※間違っていた場合の保証はできかねます。
                </p>
              </div>

              {coinwUid ? (
                <div className="bg-white/10 rounded-lg p-4 border border-white/20">
                  <p className="text-gray-300 text-sm mb-2">現在登録されているCoinW UID:</p>
                  <p className="text-white font-mono text-lg font-bold break-all">
                    {coinwUid}
                  </p>
                </div>
              ) : (
                <div className="bg-yellow-900/30 rounded-lg p-4 border border-yellow-500">
                  <p className="text-yellow-200 text-sm font-bold">
                    ⚠️ CoinW UIDが未設定です。プロフィールから必ず設定してください。
                  </p>
                </div>
              )}
            </div>

            <div className="space-y-3">
              {/* 次回から表示しないチェックボックス */}
              <div className="flex items-center gap-2 px-2 py-1">
                <input
                  type="checkbox"
                  id="dontShowAgain"
                  checked={dontShowAgain}
                  onChange={(e) => setDontShowAgain(e.target.checked)}
                  className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer"
                />
                <label
                  htmlFor="dontShowAgain"
                  className="text-gray-300 text-sm cursor-pointer select-none"
                >
                  次回から表示しない
                </label>
              </div>

              <Link href="/profile">
                <Button
                  onClick={handleConfirm}
                  className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 text-base"
                >
                  プロフィール編集画面へ
                </Button>
              </Link>

              <Button
                onClick={handleConfirm}
                className="w-full bg-gray-700 hover:bg-gray-600 text-white border border-gray-500 font-medium"
              >
                確認しました
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
