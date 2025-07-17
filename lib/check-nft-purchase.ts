import { supabase } from "@/lib/supabase"

export async function checkUserNFTPurchase(userId: string): Promise<{
  hasPurchased: boolean
  hasApprovedPurchase: boolean
  totalNFTs: number
}> {
  try {
    // usersテーブルのhas_approved_nftフィールドを確認
    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("has_approved_nft")
      .eq("user_id", userId)
      .single()

    if (userError || !userData) {
      console.error("Error fetching user data:", userError)
      return {
        hasPurchased: false,
        hasApprovedPurchase: false,
        totalNFTs: 0
      }
    }

    // affiliate_cycleテーブルでNFT保有数を確認
    const { data: cycleData, error: cycleError } = await supabase
      .from("affiliate_cycle")
      .select("total_nft_count")
      .eq("user_id", userId)
      .single()

    const totalNFTs = cycleData?.total_nft_count || 0
    const hasApprovedPurchase = userData.has_approved_nft === true
    const hasPurchased = hasApprovedPurchase || totalNFTs > 0

    return {
      hasPurchased,
      hasApprovedPurchase,
      totalNFTs
    }
  } catch (error) {
    console.error("Error checking NFT purchase:", error)
    return {
      hasPurchased: false,
      hasApprovedPurchase: false,
      totalNFTs: 0
    }
  }
}

export async function redirectIfNoNFT(router: any, userId: string): Promise<boolean> {
  const { hasApprovedPurchase } = await checkUserNFTPurchase(userId)
  
  if (!hasApprovedPurchase) {
    router.push("/dashboard")
    return true
  }
  
  return false
}