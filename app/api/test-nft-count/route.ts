import { createClient } from "@supabase/supabase-js"
import { NextResponse } from "next/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const userId = searchParams.get("userId") || "2BF53B"

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  try {
    // 1. affiliate_cycleから直接データを取得
    const { data: cycleData, error: cycleError } = await supabase
      .from("affiliate_cycle")
      .select("*")
      .eq("user_id", userId)
      .single()

    if (cycleError) {
      return NextResponse.json({ error: "Cycle data error", details: cycleError }, { status: 500 })
    }

    // 2. usersテーブルからも確認
    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("user_id, email, full_name")
      .eq("user_id", userId)
      .single()

    if (userError) {
      return NextResponse.json({ error: "User data error", details: userError }, { status: 500 })
    }

    // 3. 買い取り申請履歴を確認
    const { data: buybackHistory, error: buybackError } = await supabase
      .from("buyback_requests")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })

    return NextResponse.json({
      userId,
      cycleData,
      userData,
      buybackHistory: buybackHistory || [],
      timestamp: new Date().toISOString()
    })
  } catch (error) {
    return NextResponse.json({ error: "Server error", details: error }, { status: 500 })
  }
}