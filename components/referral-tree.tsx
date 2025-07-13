"use client"

import { useState, useEffect } from "react"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ChevronDown, ChevronRight, Users, TrendingUp, AlertCircle } from "lucide-react"

interface ReferralNode {
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  level_num: number
  total_investment: number
  nft_count: number
  path: string
  parent_user_id: string | null
  children?: ReferralNode[]
  operation_status?: 'operating' | 'waiting' | 'not_approved'
  operation_start_date?: string | null
}

interface ReferralTreeProps {
  userId: string
}

export function ReferralTree({ userId }: { userId: string }) {
  console.log('ReferralTree component mounted with userId:', userId)
  
  const [treeData, setTreeData] = useState<ReferralNode[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [isMobile, setIsMobile] = useState(false)
  // const [fallbackMode, setFallbackMode] = useState(false)

  const fetchReferralTreeFallback = async () => {
    try {
      setLoading(true)
      setError(null)

      if (!supabase) {
        throw new Error("Supabase client is not configured")
      }

      console.log('ReferralTree: Fetching data for userId:', userId)

      // テスト: まず全ユーザーのtotal_purchasesを確認
      const { data: testData, error: testError } = await supabase
        .from("users")
        .select("user_id, total_purchases")
        .gt("total_purchases", 0)
        .limit(5)
      
      console.log('Test query - all users with purchases:', testData, 'error:', testError)

      // テスト: このユーザーに紹介者がいるかチェック
      const { data: referralsCheck, error: referralsError } = await supabase
        .from("users")
        .select("user_id, email, total_purchases, referrer_user_id")
        .eq("referrer_user_id", userId)
      
      console.log(`Referrals check for ${userId}:`, referralsCheck, 'error:', referralsError)

      // Fallback: Get direct referrals manually (キャッシュ無効化)
      const { data: level1, error: level1Error } = await supabase
        .from("users")
        .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
        .eq("referrer_user_id", userId)

      if (level1Error) {
        throw level1Error
      }

      const treeNodes: ReferralNode[] = []

      console.log('Level1 raw data:', level1)

      if (level1 && level1.length > 0) {
        for (const user1 of level1) {
          const totalPurchases = parseFloat(user1.total_purchases) || 0
          const nftCount1 = Math.floor(totalPurchases / 1100)
          const operationalAmount1 = nftCount1 * 1000
          console.log('Level1 user:', user1.user_id, 'purchase:', totalPurchases, 'nftCount:', nftCount1, 'operational:', operationalAmount1)
          
          // 運用ステータスを計算
          const operationStatus = await getOperationStatus(user1.user_id)
          
          const node1: ReferralNode = {
            user_id: user1.user_id,
            email: user1.email,
            full_name: user1.full_name,
            coinw_uid: user1.coinw_uid,
            level_num: 1,
            total_investment: operationalAmount1,
            nft_count: nftCount1,
            path: user1.user_id,
            parent_user_id: user1.referrer_user_id,
            children: [],
            operation_status: operationStatus.status,
            operation_start_date: operationStatus.start_date
          }

          // Get level 2
          const { data: level2, error: level2Error } = await supabase
            .from("users")
            .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
            .eq("referrer_user_id", user1.user_id)

          if (!level2Error && level2 && level2.length > 0) {
            for (const user2 of level2) {
              const totalPurchases2 = parseFloat(user2.total_purchases) || 0
              const nftCount2 = Math.floor(totalPurchases2 / 1100)
              const operationalAmount2 = nftCount2 * 1000
              console.log('Level2 user:', user2.user_id, 'purchase:', totalPurchases2, 'nftCount:', nftCount2, 'operational:', operationalAmount2)
              
              // 運用ステータスを計算
              const operationStatus2 = await getOperationStatus(user2.user_id)
              
              const node2: ReferralNode = {
                user_id: user2.user_id,
                email: user2.email,
                full_name: user2.full_name,
                coinw_uid: user2.coinw_uid,
                level_num: 2,
                total_investment: operationalAmount2,
                nft_count: nftCount2,
                path: `${user1.user_id}->${user2.user_id}`,
                parent_user_id: user2.referrer_user_id,
                children: [],
                operation_status: operationStatus2.status,
                operation_start_date: operationStatus2.start_date
              }

              // Get level 3
              const { data: level3, error: level3Error } = await supabase
                .from("users")
                .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
                .eq("referrer_user_id", user2.user_id)

              if (!level3Error && level3 && level3.length > 0) {
                for (const user3 of level3) {
                  const totalPurchases3 = parseFloat(user3.total_purchases) || 0
                  const nftCount3 = Math.floor(totalPurchases3 / 1100)
                  const operationalAmount3 = nftCount3 * 1000
                  console.log('Level3 user:', user3.user_id, 'purchase:', totalPurchases3, 'nftCount:', nftCount3, 'operational:', operationalAmount3)
                  
                  // 運用ステータスを計算
                  const operationStatus3 = await getOperationStatus(user3.user_id)
                  
                  const node3: ReferralNode = {
                    user_id: user3.user_id,
                    email: user3.email,
                    full_name: user3.full_name,
                    coinw_uid: user3.coinw_uid,
                    level_num: 3,
                    total_investment: operationalAmount3,
                    nft_count: nftCount3,
                    path: `${user1.user_id}->${user2.user_id}->${user3.user_id}`,
                    parent_user_id: user3.referrer_user_id,
                    operation_status: operationStatus3.status,
                    operation_start_date: operationStatus3.start_date
                  }
                  node2.children!.push(node3)
                }
              }
              node1.children!.push(node2)
            }
          }
          treeNodes.push(node1)
        }
      }

      setTreeData(treeNodes)
    } catch (err) {
      console.error("Error fetching referral tree (fallback):", err)
      setError(err instanceof Error ? err.message : "Unknown error occurred")
    } finally {
      setLoading(false)
    }
  }

  // 運用ステータスを計算する関数（ユーザーIDベース）
  const getOperationStatus = async (userId: string) => {
    try {
      // 直接purchasesテーブルから承認済み購入を検索
      const { data: purchases, error } = await supabase
        .from('purchases')
        .select('admin_approved, admin_approved_at')
        .eq('user_id', userId)
        .eq('admin_approved', true)
        .order('admin_approved_at', { ascending: false })
        .limit(1)

      if (error || !purchases || purchases.length === 0) {
        return { status: 'not_approved' as const, start_date: null }
      }

      const approvedPurchase = purchases[0]
      if (!approvedPurchase.admin_approved_at) {
        return { status: 'not_approved' as const, start_date: null }
      }

      const approvalDate = new Date(approvedPurchase.admin_approved_at)
      const operationStartDate = new Date(approvalDate)
      operationStartDate.setDate(operationStartDate.getDate() + 15)
      
      const now = new Date()
      const status = now >= operationStartDate ? 'operating' : 'waiting'
      
      return {
        status,
        start_date: operationStartDate.toISOString()
      }
    } catch (err) {
      console.error('Error getting operation status for:', userId, err)
      return { status: 'not_approved' as const, start_date: null }
    }
  }

  const fetchReferralTree = async () => {
    console.log('fetchReferralTree called with userId:', userId)
    try {
      setLoading(true)
      setError(null)

      if (!supabase) {
        console.log('Supabase client not configured')
        throw new Error("Supabase client is not configured")
      }

      console.log('Calling RPC get_referral_tree...')
      const { data, error } = await supabase.rpc("get_referral_tree", {
        root_user_id: userId,
      })
      
      console.log('RPC result:', { data, error })

      if (error) {
        console.error("RPC function error:", error)
        console.log('Switching to fallback method...')
        // Try fallback method
        await fetchReferralTreeFallback()
        return
      }

      if (data && data.length > 0) {
        const tree = buildTreeStructure(data)
        setTreeData(tree)
      } else {
        setTreeData([])
      }
    } catch (err) {
      console.error("Error fetching referral tree:", err)
      console.log('Switching to fallback method due to error...')
      // Try fallback method
      await fetchReferralTreeFallback()
    } finally {
      setLoading(false)
    }
  }

  const buildTreeStructure = (flatData: any[]): ReferralNode[] => {
    const nodeMap = new Map<string, ReferralNode>()
    const rootNodes: ReferralNode[] = []

    // Create a map of all nodes, but only include Level 1-3
    flatData.forEach((dbNode) => {
      const levelNum = Number(dbNode.level_num) || 1
      // Only include Level 1-3 nodes
      if (levelNum > 3) return

      const purchaseAmount = Number(dbNode.personal_purchases) || Number(dbNode.personal_investment) || Number(dbNode.total_purchases) || 0
      const nftCount = Math.floor(purchaseAmount / 1100)
      const operationalAmount = nftCount * 1000  // 運用額は1000ドル×NFT数
      console.log('Building node for:', dbNode.user_id, 'purchase:', purchaseAmount, 'nftCount:', nftCount, 'operational:', operationalAmount)
      
      // RPCから運用ステータス情報を取得（またはデフォルト値）
      const operationStatus = dbNode.operation_status || 'not_approved'
      const operationStartDate = dbNode.operation_start_date || null
      
      const node: ReferralNode = {
        user_id: dbNode.user_id || '',
        email: dbNode.email || '',
        full_name: dbNode.full_name || '',
        coinw_uid: dbNode.coinw_uid || '',
        level_num: levelNum,
        total_investment: operationalAmount,  // 運用額を表示
        nft_count: nftCount,
        path: dbNode.path || dbNode.user_id || '',
        parent_user_id: dbNode.parent_user_id || null,
        children: [],
        operation_status: operationStatus,
        operation_start_date: operationStartDate
      }
      nodeMap.set(node.user_id, node)
    })

    // Build the tree structure
    flatData.forEach((dbNode) => {
      const levelNum = Number(dbNode.level_num) || 1
      // Only include Level 1-3 nodes
      if (levelNum > 3) return

      const currentNode = nodeMap.get(dbNode.user_id)
      if (!currentNode) return

      if (dbNode.parent_user_id && nodeMap.has(dbNode.parent_user_id)) {
        const parentNode = nodeMap.get(dbNode.parent_user_id)!
        if (!parentNode.children) {
          parentNode.children = []
        }
        parentNode.children.push(currentNode)
      } else if (dbNode.level_num === 1) {
        rootNodes.push(currentNode)
      }
    })

    return rootNodes
  }

  const toggleNode = (nodeId: string) => {
    const newExpanded = new Set(expandedNodes)
    if (newExpanded.has(nodeId)) {
      newExpanded.delete(nodeId)
    } else {
      newExpanded.add(nodeId)
    }
    setExpandedNodes(newExpanded)
  }

  const renderNode = (node: ReferralNode, depth = 0) => {
    const hasChildren = node.children && node.children.length > 0
    const isExpanded = expandedNodes.has(node.user_id)
    // スマホでは横幅を減らす
    const paddingLeft = depth > 0 ? depth * (isMobile ? 20 : 40) : 0

    const getLevelColor = (level: number) => {
      switch (level) {
        case 1:
          return "border-blue-500 bg-blue-500/10"
        case 2:
          return "border-green-500 bg-green-500/10"
        case 3:
          return "border-purple-500 bg-purple-500/10"
        default:
          return "border-gray-500 bg-gray-500/10"
      }
    }

    const getLevelBadgeColor = (level: number) => {
      switch (level) {
        case 1:
          return "text-blue-400 bg-blue-900/50 border-blue-500/50"
        case 2:
          return "text-green-400 bg-green-900/50 border-green-500/50"
        case 3:
          return "text-purple-400 bg-purple-900/50 border-purple-500/50"
        default:
          return "text-gray-400 bg-gray-900/50 border-gray-500/50"
      }
    }

    // 運用ステータスバッジを取得する関数
    const getOperationStatusBadge = (status?: string) => {
      switch (status) {
        case 'operating':
          return (
            <span className="px-1.5 py-0.5 rounded text-xs font-medium bg-green-900/50 text-green-400 border border-green-500/50 whitespace-nowrap">
              運用中
            </span>
          )
        case 'waiting':
          return (
            <span className="px-1.5 py-0.5 rounded text-xs font-medium bg-yellow-900/50 text-yellow-400 border border-yellow-500/50 whitespace-nowrap">
              運用開始前
            </span>
          )
        case 'not_approved':
          return (
            <span className="px-1.5 py-0.5 rounded text-xs font-medium bg-red-900/50 text-red-400 border border-red-500/50 whitespace-nowrap">
              未承認
            </span>
          )
        default:
          return null
      }
    }

    return (
      <div key={node.user_id} className="relative">
        {depth > 0 && (
          <div 
            className="absolute left-0 top-0 w-px h-full bg-gray-600/30" 
            style={{ left: `${(depth - 1) * (isMobile ? 20 : 40) + 20}px` }}
          />
        )}
        
        <div className="mb-3" style={{ paddingLeft: `${paddingLeft}px` }}>
          <div 
            className={`border-l-4 rounded-lg ${getLevelColor(node.level_num)} backdrop-blur-sm transition-all duration-200 hover:shadow-lg ${hasChildren ? 'cursor-pointer' : ''}`}
            onClick={() => hasChildren && toggleNode(node.user_id)}
          >
            <div className="p-2 sm:p-4">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                <div className="flex items-start sm:items-center gap-2 flex-1 min-w-0">
                  {hasChildren && (
                    <div className="p-1.5 h-7 w-7 flex items-center justify-center flex-shrink-0">
                      {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                    </div>
                  )}
                  
                  <span className={`px-2 py-0.5 rounded-full text-xs font-bold border whitespace-nowrap flex-shrink-0 ${getLevelBadgeColor(node.level_num)}`}>
                    Lv{node.level_num}
                  </span>
                  
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center space-x-2">
                      <span className="font-medium text-white text-sm sm:text-base truncate block">{node.email}</span>
                      {getOperationStatusBadge(node.operation_status)}
                    </div>
                    <div className="text-xs text-gray-500 mt-0.5 truncate">
                      ID: {node.user_id}
                    </div>
                  </div>
                </div>

                <div className="text-right flex-shrink-0 ml-8 sm:ml-0">
                  <div className="text-base sm:text-xl font-bold text-yellow-400 whitespace-nowrap">
                    ${(node.total_investment || 0).toLocaleString()}
                  </div>
                  <div className="text-xs sm:text-sm text-gray-400 whitespace-nowrap">
                    {node.nft_count || 0} NFT
                  </div>
                  {/* デバッグ用 */}
                  {process.env.NODE_ENV === 'development' && (
                    <div className="text-xs text-red-400">
                      Debug: {node.total_investment}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>

        {hasChildren && isExpanded && (
          <div className="relative">
            {node.children!.map((child, index) => (
              <div key={child.user_id}>
                {depth === 0 && (
                  <div 
                    className="absolute left-5 w-8 h-px bg-gray-600/30" 
                    style={{ top: `${index * 100 + 50}px` }}
                  />
                )}
                {renderNode(child, depth + 1)}
              </div>
            ))}
          </div>
        )}
      </div>
    )
  }

  const getStats = () => {
    // Since we're limiting to Level 3, there should be no Level 4+ users
    return {
      totalPeople: 0,
      totalInvestment: 0,
      averageInvestment: 0,
    }
  }

  const getAllNodes = (nodes: ReferralNode[]): ReferralNode[] => {
    let allNodes: ReferralNode[] = []

    nodes.forEach((node) => {
      allNodes.push(node)
      if (node.children && node.children.length > 0) {
        allNodes = allNodes.concat(getAllNodes(node.children))
      }
    })

    return allNodes
  }

  useEffect(() => {
    // モバイル判定
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 640)
    }
    checkMobile()
    window.addEventListener('resize', checkMobile)
    
    console.log('ReferralTree useEffect triggered with userId:', userId)
    if (userId) {
      console.log('Calling fetchReferralTree...')
      fetchReferralTree()
    } else {
      console.log('No userId provided, skipping fetch')
    }
    
    return () => window.removeEventListener('resize', checkMobile)
  }, [userId])

  if (loading) {
    return (
      <Card className="bg-gray-900/50 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-gray-400">読み込み中...</div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-900/50 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-red-400">
            <AlertCircle className="h-6 w-6 mx-auto mb-2" />
            <p>紹介ツリーの取得に失敗しました</p>
            <p className="text-sm mt-2">{error}</p>
            <Button
              onClick={fetchReferralTree}
              variant="outline"
              size="sm"
              className="mt-4 text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent"
            >
              再試行
            </Button>
          </div>
        </CardContent>
      </Card>
    )
  }

  const stats = getStats()

  return (
    <div className="space-y-6">
      <Card className="bg-gray-900/50 border-gray-700">
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-white flex items-center space-x-2">
            <Users className="h-5 w-5" />
            <span>紹介ツリー</span>
          </CardTitle>
          <Button
            onClick={fetchReferralTree}
            variant="outline"
            size="sm"
            className="text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent"
          >
            更新
          </Button>
        </CardHeader>
        <CardContent className="p-3 sm:p-6 overflow-x-hidden">
          <div className="mb-4 sm:mb-6">
            <div className="text-xs sm:text-sm text-gray-400 mb-2">
              <div className="flex flex-wrap gap-2 sm:gap-4">
                <div className="flex items-center space-x-1 sm:space-x-2">
                  <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-blue-500 rounded-full"></div>
                  <span>Lv1: 直接紹介</span>
                </div>
                <div className="flex items-center space-x-1 sm:space-x-2">
                  <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-green-500 rounded-full"></div>
                  <span>Lv2: 間接紹介</span>
                </div>
                <div className="flex items-center space-x-1 sm:space-x-2">
                  <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-purple-500 rounded-full"></div>
                  <span>Lv3: 第3階層</span>
                </div>
              </div>
            </div>
            <div className="bg-gray-800/50 border border-gray-700 rounded-lg px-3 py-2 text-xs sm:text-sm text-gray-300">
              <div className="flex items-center gap-2">
                <ChevronRight className="w-3 h-3 sm:w-4 sm:h-4 text-gray-400" />
                <span>各メンバーをクリックするとLevel3まで展開できます</span>
              </div>
            </div>
          </div>

          {treeData.length === 0 ? (
            <div className="text-center text-gray-400 py-8">紹介者がいません</div>
          ) : (
            <div className="space-y-2 overflow-x-auto max-w-full">{treeData.map((node) => renderNode(node))}</div>
          )}
        </CardContent>
      </Card>

    </div>
  )
}
