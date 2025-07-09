"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { createClient } from "@/lib/supabase"
import { Users, DollarSign, TrendingUp, Award, Search } from "lucide-react"

interface OrganizationData {
  user_id: string
  email: string
  level4_users: number
  level4_total_purchases: number
  avg_purchase_per_level4_user: number
  total_downline_users: number
  total_downline_purchases: number
}

interface PurchasePattern {
  purchase_amount: number
  organizations_count: number
  percentage: number
}

export default function ReferralOrganizationAnalysis() {
  const [organizations, setOrganizations] = useState<OrganizationData[]>([])
  const [patterns, setPatterns] = useState<PurchasePattern[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchEmail, setSearchEmail] = useState("")

  useEffect(() => {
    fetchAnalysisData()
  }, [])

  const fetchAnalysisData = async () => {
    try {
      setLoading(true)
      const supabase = createClient()

      // Get top organizations with 4th level users
      const { data: orgData, error: orgError } = await supabase.rpc("analyze_top_referral_organizations")

      if (orgError) {
        console.error("Error fetching organization data:", orgError)
        setError(`Error fetching data: ${orgError.message}`)
        return
      }

      // Process the data
      const topOrgs = orgData?.filter((item: any) => item.analysis_type === "Top 4th Level Organizations") || []

      const purchasePatterns = orgData?.filter((item: any) => item.analysis_type === "Purchase Pattern Analysis") || []

      setOrganizations(topOrgs)
      setPatterns(purchasePatterns)
    } catch (err) {
      console.error("Error fetching analysis data:", err)
      setError(`Error: ${err}`)
    } finally {
      setLoading(false)
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat("ja-JP", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const getRankBadge = (index: number) => {
    const colors = [
      "bg-yellow-100 text-yellow-800", // 1st
      "bg-gray-100 text-gray-800", // 2nd
      "bg-orange-100 text-orange-800", // 3rd
      "bg-blue-100 text-blue-800", // Others
    ]
    return colors[Math.min(index, 3)]
  }

  const filteredOrganizations = organizations.filter((org) =>
    org.email.toLowerCase().includes(searchEmail.toLowerCase()),
  )

  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TrendingUp className="h-5 w-5" />
            紹介組織分析
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-red-600">
            <TrendingUp className="h-5 w-5" />
            紹介組織分析 - エラー
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-red-600">{error}</p>
          <Button onClick={fetchAnalysisData} className="mt-4">
            再試行
          </Button>
        </CardContent>
      </Card>
    )
  }

  const totalLevel4Users = organizations.reduce((sum, org) => sum + org.level4_users, 0)
  const totalLevel4Purchases = organizations.reduce((sum, org) => sum + org.level4_total_purchases, 0)

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Users className="h-4 w-4 text-blue-600" />
              <span className="text-sm font-medium">4段目組織数</span>
            </div>
            <p className="text-2xl font-bold text-blue-800">{organizations.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Award className="h-4 w-4 text-green-600" />
              <span className="text-sm font-medium">4段目ユーザー数</span>
            </div>
            <p className="text-2xl font-bold text-green-800">{totalLevel4Users}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <DollarSign className="h-4 w-4 text-purple-600" />
              <span className="text-sm font-medium">4段目総購入額</span>
            </div>
            <p className="text-2xl font-bold text-purple-800">{formatCurrency(totalLevel4Purchases)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-orange-600" />
              <span className="text-sm font-medium">平均購入額</span>
            </div>
            <p className="text-2xl font-bold text-orange-800">
              {formatCurrency(totalLevel4Purchases / Math.max(totalLevel4Users, 1))}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Search */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            組織検索
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2">
            <input
              type="text"
              placeholder="メールアドレスで検索..."
              value={searchEmail}
              onChange={(e) => setSearchEmail(e.target.value)}
              className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <Button onClick={() => setSearchEmail("")} variant="outline">
              クリア
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Top Organizations */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Award className="h-5 w-5" />
            4段目組織ランキング
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredOrganizations.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Users className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>該当する組織が見つかりません</p>
              </div>
            ) : (
              filteredOrganizations.map((org, index) => (
                <div key={org.user_id} className="border rounded-lg p-4 hover:bg-gray-50 transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-3">
                      <Badge className={getRankBadge(index)}>#{index + 1}</Badge>
                      <div>
                        <h3 className="font-semibold">{org.email}</h3>
                        <p className="text-sm text-gray-600">ID: {org.user_id}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-lg font-bold text-blue-600">{formatCurrency(org.level4_total_purchases)}</p>
                      <p className="text-sm text-gray-600">4段目購入額</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                    <div>
                      <p className="text-gray-600">4段目ユーザー</p>
                      <p className="font-semibold">{org.level4_users}人</p>
                    </div>
                    <div>
                      <p className="text-gray-600">平均購入額</p>
                      <p className="font-semibold">{formatCurrency(org.avg_purchase_per_level4_user)}</p>
                    </div>
                    <div>
                      <p className="text-gray-600">総組織人数</p>
                      <p className="font-semibold">{org.total_downline_users}人</p>
                    </div>
                    <div>
                      <p className="text-gray-600">総購入額</p>
                      <p className="font-semibold">{formatCurrency(org.total_downline_purchases)}</p>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </CardContent>
      </Card>

      {/* Purchase Patterns */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <DollarSign className="h-5 w-5" />
            4段目購入パターン分析
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {patterns.map((pattern, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <p className="font-semibold">{formatCurrency(pattern.purchase_amount)}</p>
                  <p className="text-sm text-gray-600">購入額</p>
                </div>
                <div className="text-center">
                  <p className="font-semibold">{pattern.organizations_count}</p>
                  <p className="text-sm text-gray-600">組織数</p>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-blue-600">{pattern.percentage}%</p>
                  <p className="text-sm text-gray-600">割合</p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
