"use client"

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { AlertTriangle } from "lucide-react"

interface DormantUserBannerProps {
  isActive: boolean
  hasApprovedNft: boolean
}

export function DormantUserBanner({ isActive, hasApprovedNft }: DormantUserBannerProps) {
  // アクティブユーザーの場合は何も表示しない
  // 新規ユーザー（hasApprovedNft = false）の場合も表示しない
  if (isActive || !hasApprovedNft) {
    return null
  }

  return (
    <Alert className="bg-red-900/30 border-red-700 mb-6">
      <AlertTriangle className="h-5 w-5 text-red-400" />
      <AlertTitle className="text-red-300 font-bold">
        アカウント解約済み
      </AlertTitle>
      <AlertDescription className="text-red-200 mt-2">
        <p>全てのNFTを売却したため、このアカウントは解約状態です。</p>
        <p>過去の履歴は閲覧できますが、新規投資はできません。</p>
        <p className="mt-2 font-medium">
          投資を再開するには、新しい紹介リンクから新規アカウントを作成してください。
        </p>
      </AlertDescription>
    </Alert>
  )
}
