import { useEffect, useRef, useState } from 'react'
import './dashboard.css'
import UsersList from './UsersList'
import SuggestionsPage from './SuggesstionsPage'
import AnalyticsPage from './FoodWastePage' 
import FoodSavedPage from './FoodSavedPage' 
import SustainabilityImpactPage from './SustainabilityImpactPage' 
import AiRecommendationsPage from './AiRecommendationsPage' 
import './users.css'

type HomeDashboardProps = {
  onLogout: () => void
}

function LeafIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path
        d="M4 14c0-6 5-10 15-10 0 10-4 15-10 15-3 0-5-2-5-5Z"
        fill="currentColor"
      />
      <path
        d="M4 20 12 12"
        stroke="#fff"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
    </svg>
  )
}

function ArrowIcon() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
    >
      <path d="m9 18 6-6-6-6" />
    </svg>
  )
}

function HomeDashboard({ onLogout }: HomeDashboardProps) {
  const [activeNav, setActiveNav] = useState('Dashboard')
  const [darkMode, setDarkMode] = useState(false)
  const [showAdminMenu, setShowAdminMenu] = useState(false)
  const [ripples, setRipples] = useState<{ id: number; x: number; y: number }[]>([])
  
  // Comprehensive state for all MongoDB metrics & live lists
  const [metrics, setMetrics] = useState({
    totalUsers: 3,
    usersDelta: '12%',
    foodSaved: '14.8',
    foodSavedDelta: '18%',
    co2Reduced: '37',
    co2Delta: '22%',
    aiRecommendations: 34,
    aiDelta: '15%',
    wasteReduction: '32%',
    pendingSuggestions: 2,
    recentSuggestions: [
      { text: 'Please add notification alerts before dairy expires', time: '2h ago' },
      { text: 'Allow bulk export of weekly cafeteria waste records', time: '4h ago' }
    ],
    recentUsers: [] as { id?: string; name?: string; avatar?: string }[],
    foodSavedUsers: [] as { id?: string; name?: string; avatar?: string }[],
    sustainabilityUsers: [] as { id?: string; name?: string; avatar?: string }[],
    aiUsers: [] as { id?: string; name?: string; avatar?: string }[]
  })
  const [loadingMetrics, setLoadingMetrics] = useState(true)

  // View states for separate dashboard cards
  const [showUsersList, setShowUsersList] = useState(false)
  const [showSuggestionsPage, setShowSuggestionsPage] = useState(false)
  const [showAnalyticsPage, setShowAnalyticsPage] = useState(false)
  const [showFoodSavedPage, setShowFoodSavedPage] = useState(false)
  const [showSustainabilityPage, setShowSustainabilityPage] = useState(false)
  const [showAiRecommendationsPage, setShowAiRecommendationsPage] = useState(false)

  const lastRippleTime = useRef(0)
  const cardRefs = useRef<Record<string, HTMLDivElement | null>>({})
  const adminMenuRef = useRef<HTMLDivElement | null>(null)

  const bars = [30, 45, 25, 60, 40, 70, 50, 80, 55, 90, 65, 95, 75, 100, 60, 85]
  const navItems = [
    'Dashboard',
    'Users',
    'Analytics',
    'Sustainability',
    'Suggestions',
    'Help Centre',
  ]

  // Fetch live metrics and user data from backend API safely
  useEffect(() => {
    fetch('http://localhost:5000/api/dashboard/metrics')
      .then((res) => res.json())
      .then((data) => {
        if (data) {
          const extractVal = (item: any, fallback: any) => {
            if (item === undefined || item === null) return fallback
            if (typeof item === 'object') return item.value ?? fallback
            return item
          }

          setMetrics({
            totalUsers: extractVal(data.totalUsers, 3),
            usersDelta: extractVal(data.usersDelta, '12%'),
            foodSaved: extractVal(data.foodSaved, '14.8'),
            foodSavedDelta: extractVal(data.foodSavedDelta, '18%'),
            co2Reduced: extractVal(data.co2Reduced, '37'),
            co2Delta: extractVal(data.co2Delta, '22%'),
            aiRecommendations: extractVal(data.aiRecommendations, 34),
            aiDelta: extractVal(data.aiDelta, '15%'),
            wasteReduction: extractVal(data.wasteReduction, '32%'),
            pendingSuggestions: extractVal(data.pendingSuggestions, 2),
            recentSuggestions: data.recentSuggestions ?? [
              { text: 'Please add notification alerts before dairy expires', time: '2h ago' },
              { text: 'Allow bulk export of weekly cafeteria waste records', time: '4h ago' }
            ],
            recentUsers: data.recentUsers ?? [],
            foodSavedUsers: data.foodSavedUsers ?? (data.recentUsers ? data.recentUsers.slice(0, 2) : []),
            sustainabilityUsers: data.sustainabilityUsers ?? (data.recentUsers ?? []),
            aiUsers: data.aiUsers ?? (data.recentUsers ? data.recentUsers.slice(0, 2) : [])
          })
        }
        setLoadingMetrics(false)
      })
      .catch((err) => {
        console.error('Failed to fetch dashboard metrics:', err)
        setLoadingMetrics(false)
      })
  }, [])

  // Close admin menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        adminMenuRef.current &&
        !adminMenuRef.current.contains(event.target as Node)
      ) {
        setShowAdminMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  // Auto-scroll to selected card from navbar
  useEffect(() => {
    if (activeNav === 'Dashboard') {
      window.scrollTo({ top: 0, behavior: 'smooth' })
      return
    }

    if (activeNav === 'Sustainability') {
      setShowSustainabilityPage(true)
      return
    }

    const targetElement = cardRefs.current[activeNav]
    if (targetElement) {
      targetElement.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      })
    }
  }, [activeNav])

  const createRipple = (event: React.MouseEvent<HTMLDivElement>) => {
    const now = Date.now()
    if (now - lastRippleTime.current < 180) return
    lastRippleTime.current = now

    const id = now + Math.random()
    const newRipple = { id, x: event.clientX, y: event.clientY }

    setRipples((previousRipples) => [...previousRipples.slice(-5), newRipple])

    window.setTimeout(() => {
      setRipples((previousRipples) =>
        previousRipples.filter((ripple) => ripple.id !== id),
      )
    }, 1600)
  }

  // Render subpage views if respective cards were clicked
  if (showUsersList) {
    return <UsersList onBack={() => setShowUsersList(false)} />
  }
  if (showSuggestionsPage) {
    return <SuggestionsPage onBack={() => setShowSuggestionsPage(false)} />
  }
  if (showAnalyticsPage) {
    return <AnalyticsPage onBack={() => setShowAnalyticsPage(false)} />
  }
  if (showFoodSavedPage) {
    return <FoodSavedPage onBack={() => setShowFoodSavedPage(false)} />
  }
  if (showSustainabilityPage) {
    return <SustainabilityImpactPage onBack={() => setShowSustainabilityPage(false)} />
  }
  if (showAiRecommendationsPage) {
    return <AiRecommendationsPage onBack={() => setShowAiRecommendationsPage(false)} />
  }

  return (
    <div
      className={
        darkMode ? 'bitez-dashboard dark-dashboard' : 'bitez-dashboard'
      }
      onMouseMove={createRipple}
    >
      <div className="ripple-background">
        {ripples.map((ripple) => (
          <span
            key={ripple.id}
            className="cursor-ripple"
            style={{
              left: `${ripple.x}px`,
              top: `${ripple.y}px`,
            }}
          />
        ))}
      </div>

      <div className="wrap">
        {/* NAVBAR */}
        <div className="navbar">
          <div className="brand">
            <span className="leaf">
              <LeafIcon />
            </span>
            BITEZ
          </div>

          <div className="nav-links">
            {navItems.map((item) => (
              <button
                key={item}
                type="button"
                className={activeNav === item ? 'active' : ''}
                onClick={() => setActiveNav(item)}
              >
                {item}
              </button>
            ))}
          </div>

          <div className="nav-right">
            <button
              type="button"
              className="toggle"
              onClick={() => setDarkMode(!darkMode)}
            >
              <span>☀️</span>
              <span className={darkMode ? 'switch dark' : 'switch'} />
              <span>🌙</span>
            </button>

            <button type="button" className="icon-btn" aria-label="Search">
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <circle cx="11" cy="11" r="7" />
                <path d="m21 21-4.3-4.3" />
              </svg>
            </button>

            <div className="admin-menu-container" ref={adminMenuRef}>
              <button
                type="button"
                className="admin-chip"
                onClick={() => setShowAdminMenu(!showAdminMenu)}
              >
                <span className="avatar">AK</span>
                Admin
                <svg
                  width="12"
                  height="12"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  style={{
                    transform: showAdminMenu ? 'rotate(180deg)' : 'rotate(0deg)',
                    transition: 'transform 0.2s ease',
                  }}
                >
                  <path d="m6 9 6 6 6-6" />
                </svg>
              </button>

              {showAdminMenu && (
                <div className="admin-dropdown">
                  <button
                    type="button"
                    className="dropdown-item"
                    onClick={() => setShowAdminMenu(false)}
                  >
                    <span className="dropdown-icon-wrap">
                      🔔
                      <span className="menu-notif-badge" />
                    </span>
                    Notifications
                  </button>
                  <button
                    type="button"
                    className="dropdown-item"
                    onClick={() => setShowAdminMenu(false)}
                  >
                    <span>⚙️</span> Settings
                  </button>
                  <button
                    type="button"
                    className="dropdown-item logout"
                    onClick={() => {
                      setShowAdminMenu(false)
                      onLogout()
                    }}
                  >
                    <span>🚪</span> Logout
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* TOP GRID */}
        <div className="grid">
          {/* VIEW DATABASE CARD (REPLACED QUICK ACTIONS) */}
          <div 
            className="card quick-actions"
            onClick={() => window.open('https://cloud.mongodb.com', '_blank')}
            style={{ cursor: 'pointer' }}
          >
            <div className="plus-circle" style={{ background: '#10b981', color: '#fff' }}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8-4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
              </svg>
            </div>
            <h3>View Database</h3>
            <p>Open MongoDB Atlas Explorer</p>
          </div>

          {/* REGISTERED USERS */}
          <div
            ref={(el) => { cardRefs.current['Users'] = el }}
            className={`card ${activeNav === 'Users' ? 'highlighted-card' : ''}`}
            onClick={() => setShowUsersList(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">
                  <svg
                    width="15"
                    height="15"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                  >
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </span>
                Registered Users
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="metric">
              {loadingMetrics ? '...' : metrics.totalUsers}
            </div>
            <div className="delta">
              ↑ {metrics.usersDelta} <span className="muted">this week</span>
            </div>
            <div className="card-foot">
              <div className="avatar-stack">
                {metrics.recentUsers && metrics.recentUsers.length > 0 ? (
                  metrics.recentUsers.map((u, i) => (
                    <span
                      key={u.id || i}
                      className="av"
                      title={u.name || `User ${i + 1}`}
                      style={{
                        backgroundImage: `url('${u.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(u.name || 'User')}`}')`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                      }}
                    />
                  ))
                ) : (
                  <>
                    <span className="av" style={{ backgroundImage: "url('https://api.dicebear.com/7.x/avataaars/svg?seed=Bhadra')" }} />
                    <span className="av" style={{ backgroundImage: "url('https://api.dicebear.com/7.x/avataaars/svg?seed=Test%20User')" }} />
                    <span className="av" style={{ backgroundImage: "url('https://api.dicebear.com/7.x/avataaars/svg?seed=Dithin%20Krishna')" }} />
                  </>
                )}
              </div>
              <button
                type="button"
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowUsersList(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>

          {/* FOOD SAVED */}
          <div 
            className="card"
            onClick={() => setShowFoodSavedPage(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">
                  <svg
                    width="15"
                    height="15"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                  >
                    <path d="M11 20A7 7 0 0 1 4 13c0-6 7-11 7-11s7 5 7 11a7 7 0 0 1-7 7Z" />
                  </svg>
                </span>
                Food Saved
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="metric">
              {metrics.foodSaved} <small>kg</small>
            </div>
            <div className="delta">
              ↑ {metrics.foodSavedDelta} <span className="muted">this month</span>
            </div>
            <div className="bars">
              {bars.map((height, index) => (
                <span
                  key={index}
                  className={index > bars.length - 5 ? 'active' : ''}
                  style={{ height: `${height}%` }}
                />
              ))}
            </div>
            <div className="card-foot">
              <div className="avatar-stack">
                {(metrics.foodSavedUsers && metrics.foodSavedUsers.length > 0 ? metrics.foodSavedUsers : metrics.recentUsers.slice(0, 2)).map((u, i) => (
                  <span
                    key={u.id || i}
                    className="av"
                    title={u.name || `User ${i + 1}`}
                    style={{
                      backgroundImage: `url('${u.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(u.name || 'User')}`}')`,
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                    }}
                  />
                ))}
              </div>
              <button 
                type="button" 
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowFoodSavedPage(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>

          {/* SUSTAINABILITY */}
          <div
            ref={(el) => { cardRefs.current['Sustainability'] = el }}
            className={`card ${activeNav === 'Sustainability' ? 'highlighted-card' : ''}`}
            onClick={() => setShowSustainabilityPage(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">
                  <LeafIcon size={15} />
                </span>
                Sustainability Impact
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="metric">
              {metrics.co2Reduced} kg <small>CO₂</small>
            </div>
            <div className="delta">
              ↑ {metrics.co2Delta} <span className="muted">this month</span>
            </div>
            <svg
              className="linechart"
              viewBox="0 0 220 64"
              preserveAspectRatio="none"
            >
              <polyline
                points="0,50 30,44 60,48 90,36 120,40 150,24 180,20 220,6"
                fill="none"
                stroke="#2f7d4f"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <div className="card-foot">
              <div className="avatar-stack">
                {(metrics.sustainabilityUsers && metrics.sustainabilityUsers.length > 0 ? metrics.sustainabilityUsers : metrics.recentUsers).map((u, i) => (
                  <span
                    key={u.id || i}
                    className="av"
                    title={u.name || `User ${i + 1}`}
                    style={{
                      backgroundImage: `url('${u.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(u.name || 'User')}`}')`,
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                    }}
                  />
                ))}
              </div>
              <button 
                type="button" 
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowSustainabilityPage(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>
        </div>

        {/* SECOND GRID */}
        <div className="grid">
          {/* AI RECOMMENDATIONS */}
          <div 
            className="card"
            onClick={() => setShowAiRecommendationsPage(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">🤖</span>
                AI Recommendations
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="metric">{metrics.aiRecommendations}</div>
            <div className="delta">
              ↑ {metrics.aiDelta} <span className="muted">this week</span>
            </div>
            <div className="card-foot">
              <div className="avatar-stack">
                {(metrics.aiUsers && metrics.aiUsers.length > 0 ? metrics.aiUsers : metrics.recentUsers.slice(0, 2)).map((u, i) => (
                  <span
                    key={u.id || i}
                    className="av"
                    title={u.name || `User ${i + 1}`}
                    style={{
                      backgroundImage: `url('${u.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(u.name || 'User')}`}')`,
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                    }}
                  />
                ))}
              </div>
              <button 
                type="button" 
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowAiRecommendationsPage(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>

          {/* FOOD ANALYTICS */}
          <div
            ref={(el) => { cardRefs.current['Analytics'] = el }}
            className={`card ${activeNav === 'Analytics' ? 'highlighted-card' : ''}`}
            onClick={() => setShowAnalyticsPage(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">📊</span>
                Food Waste Analytics
              </div>
              <span className="more">⋯</span>
            </div>
            <p className="card-description">Weekly food waste trends</p>
            <svg
              className="linechart analytics-chart"
              viewBox="0 0 220 64"
              preserveAspectRatio="none"
            >
              <polyline
                points="0,30 25,36 50,26 75,32 100,22 125,26 150,18 175,10 220,2"
                fill="none"
                stroke="#2f7d4f"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <div className="delta waste-down">↓ {metrics.wasteReduction}</div>
            <p className="small-text">compared to last week ({metrics.totalUsers} active users)</p>
            <div className="card-foot">
              <div />
              <button
                type="button"
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowAnalyticsPage(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>

          {/* USER SUGGESTIONS */}
          <div
            ref={(el) => { cardRefs.current['Suggestions'] = el }}
            className={`card ${activeNav === 'Suggestions' ? 'highlighted-card' : ''}`}
            onClick={() => setShowSuggestionsPage(true)}
            style={{ cursor: 'pointer' }}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">💬</span>
                User Suggestions
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="metric suggestion-metric">{metrics.pendingSuggestions}</div>
            <p className="small-text">Pending replies from platform users</p>
            <div className="suggestion-list">
              {metrics.recentSuggestions.map((sug, idx) => (
                <div className="list-row" key={idx}>
                  <span className="list-dot">👤</span>
                  <span className="list-text">{sug.text}</span>
                  <span className="list-time">{sug.time}</span>
                </div>
              ))}
            </div>
            <div className="card-foot">
              <div />
              <button
                type="button"
                className="arrow-btn"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowSuggestionsPage(true)
                }}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>

          {/* HELP CENTRE */}
          <div
            ref={(el) => { cardRefs.current['Help Centre'] = el }}
            className={`card ${activeNav === 'Help Centre' ? 'highlighted-card' : ''}`}
          >
            <div className="card-head">
              <div className="card-title">
                <span className="ic">🕒</span>
                Recent Activity
              </div>
              <span className="more">⋯</span>
            </div>
            <div className="activity-row">
              <span className="activity-icon blue">👤</span>
              <div>
                <div className="activity-title">{metrics.totalUsers} Total Registered Users</div>
                <div className="activity-sub">Live MongoDB Sync Active</div>
              </div>
              <span className="activity-time">Live</span>
            </div>
          </div>
        </div>

        {/* BOTTOM */}
        <div className="bottom-row">
          <div className="overview-card">
            <div className="overview-left">
              <h2>🍃 Sustainability Overview</h2>
              <p className="sub">Together for a greener tomorrow with {metrics.totalUsers} members</p>
              <div className="stat-pills">
                <div className="pill">
                  <span className="pic">🍃</span>
                  <div>
                    <div className="plabel">Food Saved</div>
                    <div className="pval">{metrics.foodSaved} kg</div>
                  </div>
                </div>
                <div className="pill">
                  <span className="pic">☁️</span>
                  <div>
                    <div className="plabel">CO₂ Reduced</div>
                    <div className="pval">{metrics.co2Reduced} kg</div>
                  </div>
                </div>
                <div className="pill">
                  <span className="pic">👥</span>
                  <div>
                    <div className="plabel">Users Impacted</div>
                    <div className="pval">{metrics.totalUsers}</div>
                  </div>
                </div>
                <div className="pill">
                  <span className="pic">📦</span>
                  <div>
                    <div className="plabel">Donations Made</div>
                    <div className="pval">18 kg</div>
                  </div>
                </div>
              </div>
            </div>

            <div className="banner">
              <div className="quote">
                Small actions<br />make a big impact
              </div>
              <button 
                type="button" 
                className="arrow-btn"
                onClick={() => setShowSustainabilityPage(true)}
              >
                <ArrowIcon />
              </button>
            </div>
          </div>
        </div>

        {/* FOOTER */}
        <div className="footer">
          <div className="footer-brand">
            <span className="leaf small-leaf">
              <LeafIcon size={12} />
            </span>
            BITEZ
            <span className="footer-tag">
              Less Waste • Healthier You • A Greener Planet
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}

export default HomeDashboard