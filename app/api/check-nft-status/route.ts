import { createClient } from "@supabase/supabase-js"
import { NextResponse } from "next/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const userIds = searchParams.get("userIds") || "Y9FVT1,7A9637"
  const userIdArray = userIds.split(",").map(id => id.trim())

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  try {
    // Query 1: Check purchases table with operation start dates
    const { data: purchasesData, error: purchasesError } = await supabase
      .from("purchases")
      .select(`
        user_id,
        amount_usd,
        nft_quantity,
        admin_approved,
        admin_approved_at,
        is_auto_purchase,
        payment_status,
        created_at
      `)
      .in("user_id", userIdArray)
      .order("created_at", { ascending: true })

    if (purchasesError) {
      return NextResponse.json({ error: "Purchases query error", details: purchasesError }, { status: 500 })
    }

    // Calculate operation start dates and status
    const purchasesWithStatus = purchasesData?.map(purchase => {
      const operationStartDate = purchase.admin_approved_at 
        ? new Date(new Date(purchase.admin_approved_at).getTime() + 15 * 24 * 60 * 60 * 1000)
        : null
      
      const operationStatus = purchase.admin_approved_at
        ? (operationStartDate && operationStartDate <= new Date() ? 'Started' : 'Waiting')
        : 'Not Approved'

      return {
        ...purchase,
        operation_start_date: operationStartDate?.toISOString(),
        operation_status: operationStatus
      }
    })

    // Query 2: Check daily profit records
    const { data: dailyProfitData, error: dailyProfitError } = await supabase
      .from("user_daily_profit")
      .select("user_id, daily_profit, date")
      .in("user_id", userIdArray)
      .order("date", { ascending: false })

    if (dailyProfitError) {
      return NextResponse.json({ error: "Daily profit query error", details: dailyProfitError }, { status: 500 })
    }

    // Aggregate daily profit data
    const profitSummary = userIdArray.map(userId => {
      const userProfits = dailyProfitData?.filter(p => p.user_id === userId) || []
      return {
        user_id: userId,
        profit_days: userProfits.length,
        total_profit: userProfits.reduce((sum, p) => sum + (p.daily_profit || 0), 0),
        first_profit_date: userProfits.length > 0 ? userProfits[userProfits.length - 1]?.date : null,
        latest_profit_date: userProfits.length > 0 ? userProfits[0]?.date : null
      }
    })

    // Query 3: Check affiliate cycle status
    const { data: affiliateCycleData, error: affiliateCycleError } = await supabase
      .from("affiliate_cycle")
      .select(`
        user_id,
        total_nft_count,
        available_usdt,
        phase,
        cum_usdt,
        next_action,
        updated_at
      `)
      .in("user_id", userIdArray)

    if (affiliateCycleError) {
      return NextResponse.json({ error: "Affiliate cycle query error", details: affiliateCycleError }, { status: 500 })
    }

    // Query 4: Check users table for basic info
    const { data: usersData, error: usersError } = await supabase
      .from("users")
      .select(`
        user_id,
        email,
        full_name,
        has_approved_nft,
        is_active,
        created_at
      `)
      .in("user_id", userIdArray)

    if (usersError) {
      return NextResponse.json({ error: "Users query error", details: usersError }, { status: 500 })
    }

    return NextResponse.json({
      userIds: userIdArray,
      purchases: purchasesWithStatus || [],
      dailyProfitSummary: profitSummary,
      affiliateCycle: affiliateCycleData || [],
      users: usersData || [],
      timestamp: new Date().toISOString(),
      analysis: {
        note: "Check if operation_start_date has passed and daily profits should be running",
        currentDate: new Date().toISOString()
      }
    })
  } catch (error) {
    return NextResponse.json({ error: "Server error", details: error }, { status: 500 })
  }
}