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
}

interface ReferralTreeProps {
  userId: string
}

export function ReferralTree({ userId }: { userId: string }) {
  const [treeData, setTreeData] = useState<ReferralNode[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  // const [fallbackMode, setFallbackMode] = useState(false)

  const fetchReferralTreeFallback = async () => {
    try {
      setLoading(true)
      setError(null)

      if (!supabase) {
        throw new Error("Supabase client is not configured")
      }

      // Fallback: Get direct referrals manually
      const { data: level1, error: level1Error } = await supabase
        .from("users")
        .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
        .eq("referrer_user_id", userId)

      if (level1Error) {
        throw level1Error
      }

      const treeNodes: ReferralNode[] = []

      if (level1 && level1.length > 0) {
        for (const user1 of level1) {
          const node1: ReferralNode = {
            user_id: user1.user_id,
            email: user1.email,
            full_name: user1.full_name,
            coinw_uid: user1.coinw_uid,
            level_num: 1,
            total_investment: Math.floor((Number(user1.total_purchases) || 0) / 1000) * 1000,
            nft_count: Math.floor((Number(user1.total_purchases) || 0) / 1000),
            path: user1.user_id,
            parent_user_id: user1.referrer_user_id,
            children: [],
          }

          // Get level 2
          const { data: level2, error: level2Error } = await supabase
            .from("users")
            .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
            .eq("referrer_user_id", user1.user_id)

          if (!level2Error && level2 && level2.length > 0) {
            for (const user2 of level2) {
              const node2: ReferralNode = {
                user_id: user2.user_id,
                email: user2.email,
                full_name: user2.full_name,
                coinw_uid: user2.coinw_uid,
                level_num: 2,
                total_investment: Math.floor((Number(user2.total_purchases) || 0) / 1000) * 1000,
                nft_count: Math.floor((Number(user2.total_purchases) || 0) / 1000),
                path: `${user1.user_id}->${user2.user_id}`,
                parent_user_id: user2.referrer_user_id,
                children: [],
              }

              // Get level 3
              const { data: level3, error: level3Error } = await supabase
                .from("users")
                .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
                .eq("referrer_user_id", user2.user_id)

              if (!level3Error && level3 && level3.length > 0) {
                for (const user3 of level3) {
                  const node3: ReferralNode = {
                    user_id: user3.user_id,
                    email: user3.email,
                    full_name: user3.full_name,
                    coinw_uid: user3.coinw_uid,
                    level_num: 3,
                    total_investment: Math.floor((Number(user3.total_purchases) || 0) / 1000) * 1000,
                    nft_count: Math.floor((Number(user3.total_purchases) || 0) / 1000),
                    path: `${user1.user_id}->${user2.user_id}->${user3.user_id}`,
                    parent_user_id: user3.referrer_user_id,
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

  const fetchReferralTree = async () => {
    try {
      setLoading(true)
      setError(null)

      if (!supabase) {
        throw new Error("Supabase client is not configured")
      }

      const { data, error } = await supabase.rpc("get_referral_tree", {
        target_user_id: userId,
      })

      if (error) {
        console.error("RPC function error:", error)
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

      const investment = Number(dbNode.personal_investment) || 0
      const node: ReferralNode = {
        user_id: dbNode.user_id || '',
        email: dbNode.email || '',
        full_name: dbNode.full_name || '',
        coinw_uid: dbNode.coinw_uid || '',
        level_num: levelNum,
        total_investment: Math.floor(investment / 1000) * 1000,
        nft_count: Math.floor(investment / 1000),
        path: dbNode.path || dbNode.user_id || '',
        parent_user_id: dbNode.referrer_id || null,
        children: []
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

      if (dbNode.referrer_id && nodeMap.has(dbNode.referrer_id)) {
        const parentNode = nodeMap.get(dbNode.referrer_id)!
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
    const paddingLeft = depth > 0 ? depth * 40 : 0

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

    return (
      <div key={node.user_id} className="relative">
        {depth > 0 && (
          <div 
            className="absolute left-0 top-0 w-px h-full bg-gray-600/30" 
            style={{ left: `${(depth - 1) * 40 + 20}px` }}
          />
        )}
        
        <div className="mb-3" style={{ paddingLeft: `${paddingLeft}px` }}>
          <div 
            className={`border-l-4 rounded-lg ${getLevelColor(node.level_num)} backdrop-blur-sm transition-all duration-200 hover:shadow-lg ${hasChildren ? 'cursor-pointer' : ''}`}
            onClick={() => hasChildren && toggleNode(node.user_id)}
          >
            <div className="p-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  {hasChildren && (
                    <div className="p-1.5 h-7 w-7 flex items-center justify-center">
                      {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                    </div>
                  )}
                  
                  <span className={`px-3 py-1 rounded-full text-xs font-bold border ${getLevelBadgeColor(node.level_num)}`}>
                    Level {node.level_num}
                  </span>
                  
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className="font-medium text-white">{node.email}</span>
                    </div>
                    <div className="text-xs text-gray-500 mt-0.5">
                      ID: {node.user_id}
                    </div>
                  </div>
                </div>

                <div className="text-right">
                  <div className="text-xl font-bold text-yellow-400">
                    ${(node.total_investment || 0).toLocaleString()}
                  </div>
                  <div className="text-sm text-gray-400">
                    {node.nft_count || 0} NFT保有
                  </div>
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
    if (userId) {
      fetchReferralTree()
    }
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
        <CardContent className="p-6">
          <div className="text-sm text-gray-400 mb-6">
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                <span>Level 1: 直接紹介</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span>Level 2: 間接紹介</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
                <span>Level 3: 第3階層</span>
              </div>
            </div>
          </div>

          {treeData.length === 0 ? (
            <div className="text-center text-gray-400 py-8">紹介者がいません</div>
          ) : (
            <div className="space-y-2">{treeData.map((node) => renderNode(node))}</div>
          )}
        </CardContent>
      </Card>

    </div>
  )
}
