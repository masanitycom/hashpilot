"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { NftBuybackRequest } from "@/components/nft-buyback-request"
import { checkUserNFTPurchase } from "@/lib/check-nft-purchase"

export default function NftBuybackPage() {
  const [user, setUser] = useState<any>(null)
  const [userData, setUserData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const router = useRouter()

  useEffect(() => {
    checkUserAccess()
  }, [])

  const checkUserAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push("/login")
        return
      }

      // basarasystems@gmail.com は管理画面にリダイレクト
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        router.push("/admin")
        return
      }

      setUser(user)

      // ユーザーデータを取得
      const { data: userInfo, error } = await supabase
        .from("users")
        .select("user_id, email, full_name")
        .eq("id", user.id)
        .single()

      if (error) {
        console.error("Error fetching user data:", error)
        router.push("/dashboard")
        return
      }

      // NFT購入チェック
      const { hasApprovedPurchase } = await checkUserNFTPurchase(userInfo.user_id)
      if (!hasApprovedPurchase) {
        console.log("User has no approved NFT purchase, redirecting to /nft")
        router.push("/dashboard")
        return
      }

      setUserData(userInfo)
    } catch (error) {
      console.error("Error checking user access:", error)
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <div className="text-white">読み込み中...</div>
      </div>
    )
  }

  if (!userData) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="container mx-auto p-4 md:p-6 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center space-x-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => router.push("/dashboard")}
            className="text-gray-400 hover:text-white"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold">NFT買い取り申請</h1>
            <p className="text-gray-400">保有中のNFTを買い取り申請できます。手動購入NFTは1000ドル-利益額、自動購入NFTは500ドル-利益額で買い取り可能です。</p>
          </div>
        </div>

        {/* NFT買い取り申請コンポーネント */}
        <NftBuybackRequest userId={userData.user_id} />
      </div>
    </div>
  )
}